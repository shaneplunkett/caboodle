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

## Back rails and cable lengths

Turn on back rails in the layout card to mount gear on the back of the rack,
like a patch panel the wall lines plug into, so moving the rack means
unplugging one row. The back rails draw beside the rack, lined up with it. The
front view shows their outside and the rear view their inside, so a cable
through the rack draws as a line in the rear view.

Each cable's card gives a length to buy, and the layout card adds them up into
a shopping list. A cable runs square to the rack, plus 4 cm at each end for the
plug, rounded up to a stock length. Set the layout's depth to the gap between
the front and back rails. The planner doesn't know how deep each device is, so
a cable to a device's back port assumes the jack sits near the rails, which
errs long.
