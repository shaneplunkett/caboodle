# Music

Incus guest on Cube running Aurral, Shane's music library. Aurral syncs her
YouTube Music playlists, finds each track with its download sources, and
serves the library over Subsonic. Lidarr, Soulseek and SUB/WAVE are later
work in the Linear project "Run my own music library and radio station".

## Where the music lives

Aurral's Downloads Folder is its library, not a scratch folder. It's
`/data/downloads/aurral` in the container, which is `Media/downloads/aurral`
on the NAS, beside SABnzbd's and Deluge's folders. Its state, including the
database, is `/var/lib/aurral`.

- **Keep the NAS at `/data`.** Aurral's database stores every file by its
  path in the container, so moving the mount orphans the whole library. A
  Lidarr or Navidrome added later reads the same tree, and Aurral's
  **Remote path mappings** cover any that see it at another path.
- **The music has no offsite copy.** Restic backs up `/var/lib/aurral`,
  where the database, playlists and settings live, but never the NAS.
  Everything in the library can be found again, and a restored database
  re-searches whatever went missing.

## Sign-in

Aurral's own OIDC login with Pocket ID, at `https://aurral.shaneplunkett.com`.
Anyone in `aurral_admins` signs in as an admin, and the group is checked on
every sign-in. The local admin account from the desktop test box came over
with the database, so link it once from **Settings > Account > Connect
single sign-on** rather than letting SSO make a second account. Its password
stays as the way in when Pocket ID is down.

Subsonic players sign in with the Aurral username and password, not SSO.

## Secrets

`aurral-env` holds the OIDC client secret as an env file. From
`modules/agenix`:

```sh
printf 'OIDC_CLIENT_SECRET=%s\n' "$(rbw get aurral-oidc-client-secret)" | agenix -e aurral-env.age
```

## Gotchas

- **yt-dlp breaks whenever YouTube changes.** The image bundles it, so a
  wave of failed YouTube downloads usually means the image needs a bump.
  Aurral's playlist import reads only public playlists, so it never needs a
  Google sign-in.
- **The API key gives admin access.** It's in **Settings > System**. The
  approve, deny and manual-search endpoints in its API docs work through
  the review queue and Wanted without clicking through each track.
