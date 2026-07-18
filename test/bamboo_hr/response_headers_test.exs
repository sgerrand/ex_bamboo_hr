defmodule BambooHR.ResponseHeadersTest do
  use ExUnit.Case, async: true

  alias BambooHR.ResponseHeaders

  describe "location/1" do
    test "extracts the first Location header value" do
      assert ResponseHeaders.location(%{"location" => ["https://example.com/1", "ignored"]}) ==
               %{"location" => "https://example.com/1"}
    end

    test "returns an empty map when there is no location key" do
      assert ResponseHeaders.location(%{"content-type" => ["application/json"]}) == %{}
    end

    test "returns an empty map when the location value is an empty list" do
      assert ResponseHeaders.location(%{"location" => []}) == %{}
    end

    test "returns an empty map for a non-map input" do
      assert ResponseHeaders.location(nil) == %{}
      assert ResponseHeaders.location("not headers") == %{}
      assert ResponseHeaders.location([{"location", "https://example.com/1"}]) == %{}
    end
  end
end
