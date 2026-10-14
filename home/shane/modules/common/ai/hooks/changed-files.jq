.tool_input as $t
| ($t | objects | .file_path // empty),
  (($t | if type == "object" then (.command // .patch // "") else . end)
    | strings | split("\n")[]
    | capture("^\\*\\*\\* (Add File|Update File|Move to): (?<path>.+)$")? | .path)
