# minirack ✿

A little visual planner for the 10" minirack. Drag gear into the rack, plug
cables between ports, and leave notes on anything.

```sh
bun tools/minirack/server.ts
# → http://127.0.0.1:4545
```

There are no dependencies to install, just Bun. Set `PORT` or `HOST` to change
where it listens (`HOST=0.0.0.0` to reach it from another machine).

## Where the layout lives

Everything saves to [`rack.json`](rack.json) as you go, so committing that
file is how a layout persists. If the file changes on disk while a tab is
open (a `git pull`, say), the app notices and asks which version to keep, so
it never silently overwrites.
