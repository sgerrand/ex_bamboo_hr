# Compares the endpoints this client calls with BambooHR's public OpenAPI spec.
#
# Usage:
#
#     elixir scripts/spec_drift.exs [SPEC_URL_OR_PATH]
#
# Fails (exit 1) when the client calls an endpoint that is missing from the
# spec or marked deprecated in it. Endpoints in the spec that the client does
# not cover are listed for information only.
#
# When GITHUB_STEP_SUMMARY is set, the report is also written there.

Mix.install([
  {:req, "~> 0.5"},
  {:yaml_elixir, "~> 2.11"}
])

defmodule SpecDrift do
  @default_spec_url "https://d40bgjb2zs35x.cloudfront.net/main/latest/docs/openapi/public-openapi.yaml"
  @methods ~w(get post put patch delete)
  @client_aliases [[:Client], [:BambooHR, :Client]]

  # Endpoints the client calls on purpose even though the spec does not list
  # them. Each needs a reason.
  @allowed_unlisted %{}

  def main(args) do
    source = List.first(args, @default_spec_url)
    spec = load_spec(source)
    implemented = implemented_endpoints("lib/**/*.ex")
    documented = documented_endpoints(spec)

    unlisted =
      implemented
      |> Enum.reject(fn {key, _} -> Map.has_key?(documented, key) end)
      |> Enum.reject(fn {key, _} -> Map.has_key?(@allowed_unlisted, key) end)

    deprecated =
      Enum.filter(implemented, fn {key, _} -> match?(%{deprecated: true}, documented[key]) end)

    missing =
      documented
      |> Enum.reject(fn {key, op} -> op.deprecated or Map.has_key?(implemented, key) end)
      |> Enum.sort_by(fn {{method, path}, op} -> {op.tag, path, method} end)

    report = report(source, implemented, documented, unlisted, deprecated, missing)
    IO.puts(report)
    write_step_summary(report)

    if unlisted != [] or deprecated != [], do: System.halt(1)
  end

  defp load_spec("http" <> _ = url), do: Req.get!(url, decode_body: false).body |> parse_yaml()
  defp load_spec(path), do: path |> File.read!() |> parse_yaml()

  defp parse_yaml(body), do: YamlElixir.read_from_string!(body)

  # Spec paths look like "/api/v1_2/datasets/{datasetName}/fields". They are
  # keyed as {"GET", "/v1_2/datasets/{}/fields"} so parameter names don't
  # matter.
  defp documented_endpoints(%{"paths" => paths}) do
    for {path, operations} <- paths,
        {method, op} <- operations,
        method in @methods,
        into: %{} do
      key = {String.upcase(method), path |> String.replace_prefix("/api", "") |> normalize()}
      {key, %{path: path, deprecated: op["deprecated"] == true, tag: tag(op)}}
    end
  end

  defp tag(%{"tags" => [tag | _]}), do: tag
  defp tag(_op), do: "Untagged"

  defp normalize(path), do: String.replace(path, ~r/\{[^}]+\}/, "{}")

  # Finds `Client.get/post/put/delete` calls and returns a map of
  # {method, versioned_path} => ["file:line", ...].
  defp implemented_endpoints(glob) do
    glob
    |> Path.wildcard()
    |> Enum.flat_map(&file_endpoints/1)
    |> Enum.group_by(fn {key, _location} -> key end, fn {_key, location} -> location end)
  end

  defp file_endpoints(file) do
    ast = file |> File.read!() |> Code.string_to_quoted!(columns: false)
    functions = collect_functions(ast)

    ast
    |> collect_client_calls()
    |> Enum.flat_map(fn {method, path_ast, opts_ast, line, enclosing} ->
      version = api_version(opts_ast)

      path_ast
      |> resolve_paths(enclosing, functions)
      |> Enum.map(fn
        {:ok, path} -> {{method, "/#{version}#{normalize(path)}"}, "#{file}:#{line}"}
        :error -> unresolved!(file, line)
      end)
    end)
  end

  defp unresolved!(file, line) do
    IO.puts(:stderr, "#{file}:#{line}: cannot work out the request path for this call")
    System.halt(2)
  end

  # Returns [{name, params, body}] for every def/defp in the file.
  defp collect_functions(ast) do
    {_, functions} =
      Macro.prewalk(ast, [], fn
        {kind, _, [head, [do: body]]} = node, acc when kind in [:def, :defp] ->
          {name, params} = function_head(head)
          {node, [{name, params, body} | acc]}

        node, acc ->
          {node, acc}
      end)

    functions
  end

  defp function_head({:when, _, [head | _]}), do: function_head(head)
  defp function_head({name, _, params}) when is_list(params), do: {name, params}
  defp function_head({name, _, _}), do: {name, []}

  defp collect_client_calls(ast) do
    {_ast, {_enclosing, calls}} =
      Macro.prewalk(ast, {nil, []}, fn
        {kind, _, [head, _]} = node, {_enclosing, calls} when kind in [:def, :defp] ->
          {node, {function_head(head), calls}}

        {{:., _, [{:__aliases__, _, alias}, method]}, meta, [path | rest]} = node,
        {enclosing, calls}
        when alias in @client_aliases and method in [:get, :post, :put, :delete] ->
          opts = Enum.at(rest, 1, [])
          call = {method |> to_string() |> String.upcase(), path, opts, meta[:line], enclosing}
          {node, {enclosing, [call | calls]}}

        node, acc ->
          {node, acc}
      end)

    calls
  end

  defp resolve_paths(path_ast, enclosing, functions) do
    case literal_path(path_ast) do
      {:ok, path} -> [{:ok, path}]
      :error -> resolve_through_callers(path_ast, enclosing, functions)
    end
  end

  # A path passed in as a function parameter, e.g. `defp upload(client, path, ...)`.
  # Resolved by finding every call to that function in the same file and
  # reading the literal passed in that position.
  defp resolve_through_callers({var, _, context}, {name, params}, functions)
       when is_atom(var) and is_atom(context) do
    with index when is_integer(index) <- Enum.find_index(params, &match?({^var, _, _}, &1)),
         [_ | _] = paths <- caller_paths(name, length(params), index, functions) do
      paths
    else
      _ -> [:error]
    end
  end

  defp resolve_through_callers(_path_ast, _enclosing, _functions), do: [:error]

  defp caller_paths(name, arity, index, functions) do
    for {_, _, body} <- functions,
        {^name, _, args} <- body |> Macro.prewalker() |> Enum.to_list(),
        is_list(args) and length(args) == arity do
      literal_path(Enum.at(args, index))
    end
  end

  defp literal_path(path) when is_binary(path), do: {:ok, path}

  defp literal_path({:<<>>, _, parts}) do
    {:ok,
     Enum.map_join(parts, fn
       part when is_binary(part) -> part
       _interpolation -> "{}"
     end)}
  end

  defp literal_path(_ast), do: :error

  defp api_version(opts) when is_list(opts) do
    case Keyword.get(opts, :api_version, "v1") do
      version when is_binary(version) -> version
      _ -> "v1"
    end
  end

  defp api_version(_opts), do: "v1"

  defp report(source, implemented, documented, unlisted, deprecated, missing) do
    """
    # BambooHR API spec drift

    Spec: #{source}

    - Endpoints in spec: #{map_size(documented)}
    - Endpoints called by this client: #{map_size(implemented)}

    ## Called by this client but not in the spec

    #{implemented_list(unlisted)}

    ## Called by this client but deprecated in the spec

    #{implemented_list(deprecated)}

    ## In the spec but not covered by this client

    Deprecated endpoints are left out of this list.

    #{missing_list(missing)}
    """
  end

  defp implemented_list([]), do: "None."

  defp implemented_list(endpoints) do
    endpoints
    |> Enum.sort()
    |> Enum.map_join("\n", fn {{method, path}, locations} ->
      "- `#{method} #{path}` (#{Enum.join(locations, ", ")})"
    end)
  end

  defp missing_list([]), do: "None."

  defp missing_list(endpoints) do
    Enum.map_join(endpoints, "\n", fn {{method, _}, op} ->
      "- #{op.tag}: `#{method} #{op.path}`"
    end)
  end

  defp write_step_summary(report) do
    case System.get_env("GITHUB_STEP_SUMMARY") do
      nil -> :ok
      "" -> :ok
      path -> File.write!(path, report, [:append])
    end
  end
end

SpecDrift.main(System.argv())
