# Issue tracker: Linear

Issues and PRDs for this repo live in Linear: workspace `metrokitten`, team `SHA` (Shane). Use the Linear MCP server's tools (`list_issues`, `get_issue`, `save_issue`, `save_comment`, `save_project`, …). Check `get_workspace` says `metrokitten` before writing.

## Conventions

- **Create an issue**: `save_issue` with team `SHA`, real newlines in markdown (no `\n` escapes).
- **Read an issue**: `get_issue` with `SHA-<n>` (plus `list_comments` for discussion).
- **List issues**: `list_issues` filtered to team `SHA` / the project.
- **Comment on an issue**: `save_comment`.
- **Apply / remove labels**: `save_issue` with labels; create missing labels first with `create_issue_label`.
- **Close**: comment the resolution, then set the state to Done via `save_issue` (look up state IDs with `list_issue_statuses`).
- **Projects**: group related work with `save_project` on team `SHA`, then reference the project on `save_issue`.
- **Issue relations (blocked-by etc.)**: `save_issue` with `blockedBy` or `blocks`.

## Pull requests as a triage surface

**PRs as a request surface: no.** _(Linear is not the PR surface for this repo; pull requests live on the forge and are handled with `fj` independently of triage.)_

## When a skill says "publish to the issue tracker"

Create a Linear issue on team `SHA` (in the relevant project if one exists). Express blocking edges with `save_issue`'s `blockedBy`, publishing blockers first so identifiers exist.

## When a skill says "fetch the relevant ticket"

`get_issue` + `list_comments` for `SHA-<n>`.

## Wayfinding operations

Used by `/wayfinder`. The **map** is a Linear **project** with issues as tickets.

- **Map**: a Linear project holding the Notes / Decisions-so-far / Fog body in its description (`save_project` on team `SHA`;
- **Child ticket**: an issue in the map project, labelled `wayfinder:<type>` (`research`/`prototype`/`grilling`/`task`). Once claimed, the ticket is assigned to the driving dev.
- **Blocking**: Linear's native relations, set with `save_issue`'s `blockedBy` and read with `get_issue`. A ticket is unblocked when every blocker is done.
- **Frontier query**: `list_issues` scoped to the project, drop any with an open blocker or an assignee; first in project order wins.
- **Claim**: assign the issue to yourself via `save_issue` — the session's first write.
- **Resolve**: comment the answer, move the issue to Done, then append a context pointer to the map's Decisions-so-far.
