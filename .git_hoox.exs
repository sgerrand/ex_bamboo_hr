%{
  parallel: true,
  hooks: [
    pre_commit: [
      {GitHoox.Hooks.Shell,
       run: "mix format --check-formatted",
       files: ~w(**/*.ex **/*.exs)},
      {GitHoox.Hooks.Shell,
       run: "actionlint {staged_files}",
       files: ~w(.github/workflows/*.yml .github/workflows/*.yaml)},
      {GitHoox.Hooks.Shell,
       run: "check-jsonschema --builtin-schema vendor.github-workflows {staged_files}",
       files: ~w(.github/workflows/*.yml .github/workflows/*.yaml)},
      {GitHoox.Hooks.Shell,
       run: "check-jsonschema --builtin-schema vendor.dependabot {staged_files}",
       files: ~w(.github/dependabot.yml .github/dependabot.yaml)},
      {GitHoox.Hooks.Shell,
       run:
         "check-jsonschema --schemafile https://raw.githubusercontent.com/googleapis/release-please/main/schemas/config.json {staged_files}",
       files: ~w(release-please-config.json)},
      {GitHoox.Hooks.Shell,
       run:
         "check-jsonschema --schemafile https://raw.githubusercontent.com/googleapis/release-please/main/schemas/manifest.json {staged_files}",
       files: ~w(.release-please-manifest.json)},
      {GitHoox.Hooks.Shell, run: "mado check {staged_files}", files: ~w(**/*.md)}
    ]
  ]
}
