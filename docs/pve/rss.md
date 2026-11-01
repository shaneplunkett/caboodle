# RSS

NixOS Incus container on PVE running FreshRSS, the feed reader at
`https://rss.shaneplunkett.com`. Its size is `homelab.guest` in `flake.nix`,
`terraform/incus.tf` makes it, and the service is `modules/services/freshrss`.

## Signing in

The ingress gates it with oauth2-proxy, so Pocket ID's passkey is the only
login. FreshRSS takes the username from the `X-User` header the ingress
sends, which is the Pocket ID user's `sub` (a UUID), not their username.
Anyone else who gets through the gate is registered as a normal user on their
first visit.

`/api/` skips the gate so phone apps work, and the gate doesn't set `X-User`
there, so a client could send its own. That's why the nginx map ignores the
header under `/api/`. Keep that exception if you touch it.

## Phone apps

Apps use the Google Reader API (`https://rss.shaneplunkett.com/api/greader.php`)
with the username and a separate API password, which each user sets under
Settings, Profile. Readrops, FeedMe and NetNewsWire all speak it.

## Extensions

The YouTube and Af_Readability extensions start switched off. FreshRSS
keeps which extensions are on, and their settings, in each user's own config,
so turn them on under Settings, Extensions:

- **YouTube** plays videos inside the article. Turn on the no-cookie domain
  in its settings.
- **Af_Readability** fetches the full article for feeds that only send a
  summary. Tick the feeds you want in its settings. It only applies to new
  articles, not ones already fetched.

For a site Af_Readability gets wrong, a feed's own "Article CSS selector on
original website" setting does the same job by hand.

## Backups

To restore a user, put their `backup.sqlite` back as `db.sqlite` with the
service stopped.

## Theme

`modules/services/freshrss/theme` adds a Catppuccin theme to the FreshRSS
package, picked per user under Settings, Display. It's Latte in light mode and
Mocha in dark, and it sits on top of the stock Origine theme
so FreshRSS updates mostly carry through.

- **Origine's dark mode is cut out at build time.** Its dark rules are more
  specific than ours and would override them, so the build copies
  `origine.css` up to its `prefers-color-scheme: dark` block. If the theme
  suddenly looks half Origine after an update, check that block still exists
  and is still last in the file.
- **Icons come from Lucide.** `icons.txt` maps each FreshRSS icon name to a
  Lucide icon, and the build bakes in a grey stroke because FreshRSS shows
  icons as `<img>`, which can't inherit a colour. An icon FreshRSS adds later
  falls back to its own until it's added to the map.
- **FreshRSS caches pages,** so after a theme change the old icons can hang
  around until a hard refresh.
