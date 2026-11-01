# Dispatcharr

Dispatcharr turns internet TV streams into a tuner Plex can watch and record
from, by pretending to be an HDHomeRun. It runs in a container on arr
(`modules/services/arr/dispatcharr.nix`). It went in when the building's
aerial died, so the HDHomeRun had nothing to tune, and it feeds Plex the
Melbourne free-to-air channels from i.mjh.nz instead.

The HDHomeRun is still the better tuner when the aerial works. Off the
aerial, Seven and ABC come in at broadcast quality, where online they stop at
720p. It doesn't need the internet, and it doesn't depend on Plex keeping an
unsupported tuner working.

Dispatcharr's own guides are at
[dispatcharr.github.io/Dispatcharr-Docs](https://dispatcharr.github.io/Dispatcharr-Docs/).
Read those before the source code. Their FAQ disagrees with the obvious way
to do a couple of things here.

## Signing in

The web UI sits behind the oauth2-proxy gate. Dispatcharr has no OIDC and
no way to skip its login for local addresses, so it signs you in from the
`X-Email` header the gate sends. That's its Reverse Proxy Auth setting. It
only believes the header from a proxy named in `DISPATCHARR_TRUSTED_PROXIES`,
which the module sets to the ingress host.

- **The admin's email has to match your Pocket ID email.** The header is
  matched to an account by username, then by email.
- **The admin password is the way in when Pocket ID is down.** Keep it in
  Bitwarden.
- **The default trusted proxies never sign anyone in.** Unset, Dispatcharr
  trusts private addresses for client IPs but not for sign-in.

To set it up on a fresh install:

1. Open `https://dispatcharr.shaneplunkett.com` and get through the passkey
   gate.
2. Make the admin account. Use any username, and put your Pocket ID email
   in the email box. If the form has no email box, make the username your
   email instead.
3. Settings, System, Reverse Proxy Auth: turn it on with the header
   `X-Email`, and save.
4. Check it in a private window. After the passkey you land straight in,
   with no Dispatcharr password.

## Setting it up

The order follows their Getting Started guide.

### Stream settings

Do these first, so every source added later just works.

1. Settings, Network, User-Agents: add `mjh Apple TV` with
   `otg/1.5.1 (AppleTv Apple TV 4; tvOS16.0; appletv.client) libcurl/7.58.0 OpenSSL/1.0.2o zlib/1.2.11 clib/1.8.56`.
2. Settings, Streaming, Stream Settings: set the Default User-Agent to
   `mjh Apple TV` and the Default Stream Profile to Streamlink, and save.
   Leave the rest. MPEG-TS output and no HDHR output profile is what Plex
   expects from an HDHomeRun.

The Melbourne playlist also has `mjh Apple TV` set on it, under the
playlist's own User-Agent. That's harmless, and it's how to give a future
source a different one.

Why both:

- **Ten won't play with any other user agent.** Its stream is encrypted,
  and the key server answers 404 to Dispatcharr's built-in ones (VLC,
  TiviMate). i.mjh.nz's Melbourne, Sydney and NZ playlists all ask for the
  Apple TV one, but Dispatcharr ignores the `#EXTVLCOPT` lines that say so.
- **The default ffmpeg profile sends Plex every quality at once.** It runs
  with `-map 0`, and each Melbourne stream is HLS with four to six quality
  levels, so Nine arrived with twenty-odd video tracks. Plex gives up with
  "the live TV session has ended". Streamlink picks the best one and sends
  only that.
- **The Proxy profile doesn't help.** It falls back to ffmpeg for anything
  that isn't MPEG-TS, and these are HLS.

### Playlist and guide

In M3U & EPG:

1. Under M3U Accounts, Add. Name it `Melbourne FTA`, set the Account Type
   to Standard (not Xtream Codes), and the URL to
   `https://i.mjh.nz/au/Melbourne/kodi-tv.m3u8`. Leave the rest and save.
   The `tvh-tv.m3u8` next to it pipes through ffmpeg for Tvheadend, which
   Dispatcharr can't use.
2. It loads the groups and shows Pending Setup, which means it's waiting
   for you to pick groups. Click its edit icon, then the Groups button at
   the bottom. Every group starts ticked. Leave Auto Channel Sync off on
   all of them, then Save and Refresh.
3. Under EPGs, Add EPG. Name it `Melbourne guide`, source type Standard
   (XMLTV, not Dummy), URL `https://i.mjh.nz/au/Melbourne/epg.xml.gz`, and
   save. It shows no channels mapped until there are channels.

The playlist has four groups:

- **Melbourne** has the local channels: Seven, Nine and Ten with their
  extras, ABC TV and Channel 31.
- **Au** has the national ones (SBS, NITV and the other ABC channels) and
  about 140 online-only channels the networks run, like BBC Food or
  Daria on Adult Animation.
- **World** has Red Bull TV, Al Jazeera, CNA and DW.
- **Default Group** is empty.

### Channels

Channels are made from the Streams table, on the right of the Channels
page:

1. Click in the Group column header and search the group.
2. Tick the streams you want. The tick-all box at the top takes everything
   the search matches, so filter before using it.
3. Click Create Channels, and pick how to number them.

Using the provider's numbers gives each channel its real number from the
playlist. A number that's taken, or a stream without one, gets the lowest
free number instead, which starts at 1. So make channels with real numbers
and channels without them in separate batches, and give the ones without a
starting number of their own.

The lineup is four batches:

1. **Group `Melbourne`, tick-all, provider's numbers.** All 15 land on their
   real numbers: 10, 10 Comedy 11, 10 Drama 12, Nickelodeon 13, ABC TV 21,
   Channel 31 44, Seven 71, 7two 72, 7mate 74, 7flix 76, Channel 9 91,
   9Gem 92, 9Go! 93, 9Life 94, 9Rush 96.
2. **Group `Au`, tick by hand, provider's numbers:** ABC Entertains 23,
   ABC NEWS 24, SBS 30, SBS2 31, SBS World Movies 32, SBS Food 33, NITV 34.
3. **Group `Au`, ABC Family alone, provider's numbers.** It lands on 22.
   ABC Kids also claims 22, since the two share a slot on air, and isn't
   set up.
4. **Group `Au`, by hand, starting number 100:** BBC Food 100, BBC Comedy
   101, BBC Top Gear 102, BBC Home & Garden 103, BBC Antiques Roadshow 104.
   These have no numbers in the playlist.

Don't use Auto Channel Sync on these groups. Their FAQ says it's for event
groups whose names change, and that each refresh wipes edits to the
channels it made. Its channels are also tagged as auto-created, and
Dispatcharr deletes those when their stream drops out of the playlist.
Turning it off later leaves its channels behind with the tag still on, so
delete them and make them again by hand.

### Guide matching

New channels match the guide on their own, by the `tvg-id` the playlist
gives them. If one doesn't, the Channels table's toolbar menu (the one with
Assign #s) has Auto-Match EPG, which matches every channel when none are
selected. Two things catch you out:

- **New channels have no listings until the EPG refreshes.** Dispatcharr only
  loads listings for channels that exist when it fetches the guide. Hit the
  refresh icon on the EPG after adding channels.
- **The online-only channels match empty guide entries.** i.mjh.nz lists the
  BBC ones with no programmes, so they show blank in Plex. Tick them in
  the Channels table (the left one), click Edit above it, then under EPG
  Operations use Assign Dummy EPG to clear the assignment, and save. A
  channel with no guide match gets placeholder listings of its own name.
  The channel editor's Use Dummy button does the same for one channel.

## Plex

Use the arr host's LAN address and port 9191 for everything in Plex, as
`http://<arr's lanAddress>:9191/...`. Dispatcharr's HDHR and EPG buttons
copy URLs built from however you reached the UI, which is the gated name,
and Plex can't get past the gate.

- Tuner: `http://<arr's lanAddress>:9191/hdhr`
- Guide: `http://<arr's lanAddress>:9191/output/epg?cachedlogos=false`.
  Without `cachedlogos=false` Plex shows no channel logos.

Plex only offers an XMLTV guide when a DVR is created. "Add another device"
on an existing DVR uses that DVR's guide and asks for a postcode, with no
XMLTV option. So Dispatcharr's DVR replaced the HDHomeRun's, which used
Plex's own guide. When the aerial's back, the HDHomeRun needs its own DVR
beside this one. Plex's forum suggests running the setup in two browser
tabs so each DVR gets its own guide, but that's untested here.

### Setting up the DVR

1. Before deleting a DVR, screenshot its recording schedule and its DVR
   Settings. Both go with it, and the schedule is what mum records.
2. Settings, Manage, Live TV & DVR. Delete the old DVR, then set up a new
   one. Plex's button for it has changed names over the years.
3. If Plex doesn't find the tuner, click "Don't see your HDHomeRun device?
   Enter its network address manually", paste the tuner URL and Connect.
   It shows as Dispatcharr HDHomeRun with 10 tuners and the channel count.
4. When it asks for a country and postcode, click the link to use an XMLTV
   guide instead, and paste the guide URL.
5. Check every channel is paired with its guide entry, then Continue.

### DVR settings

The DVR's settings go with the DVR when it's deleted, so a new DVR needs
them set again:

- **Convert video while recording: off.** On, it re-encodes to about four
  times the broadcast's size and breaks the ad cutting.
- **Minutes before start 5, after end 15.** Seven runs late.
- **Detect commercials: detect and delete.**
- **Postprocessing script:** the HEVC script from `modules/services/plex`
  shrinks and deinterlaces broadcast recordings. These streams are already
  progressive H.264, so whether it's worth running on them is still open.

Set them in the DVR's settings, or from the shell:

```sh
ssh root@plex 't=$(grep -o "PlexOnlineToken=\"[^\"]*" "/var/lib/plex/Plex Media Server/Preferences.xml" | cut -d\" -f2); curl -X PUT "http://127.0.0.1:32400/livetv/dvrs/<dvr id>/prefs?startOffsetMinutes=5&endOffsetMinutes=15&comskipEnabled=true&comskipMethod=1&X-Plex-Token=$t"'
```

New recording rules start from these.

### Adding channels later

1. Make them in Dispatcharr and refresh its EPG.
2. Make Plex reload the guide, which it otherwise does once a day:
   ```sh
   ssh root@plex 't=$(grep -o "PlexOnlineToken=\"[^\"]*" "/var/lib/plex/Plex Media Server/Preferences.xml" | cut -d\" -f2); curl -X POST "http://127.0.0.1:32400/livetv/dvrs/<dvr id>/reloadGuide?X-Plex-Token=$t"'
   ```
3. Reload the channel matching page in Plex. A page opened before the
   reload still has the old guide list.
4. Tick each new channel and pick its guide entry from the dropdown by
   hand, then save. A ticked channel without a guide entry is unticked
   again on save.

### Recordings

Recording rules survive deleting a DVR, but they won't record anything from
a different guide. A rule follows the guide's ID for the show, and Plex's
guide uses `plex://show/...` where an XMLTV guide uses
`tv.plex.xmltv://show/<title>`. Make each rule again from the new guide,
then delete the old one. A show that isn't on this week can't be made yet,
so its old rule stays until it airs.

This guide never says which airings are new. The source has no `<new/>` or
`<previously-shown/>` tags, and Plex treats every XMLTV listing without
`<previously-shown/>` as new, so "new airings only" records everything.
Limit each rule to the network's main channel instead (Show Advanced, Limit
to Channel), because repeats air on the extras. Plex also skips an episode
already in the library.

To make a rule again:

1. In the guide, open the show's next airing on its main channel and click
   Record.
2. Choose the whole series.
3. Click Show Advanced. Set Limit to Channel to the main channel, and check
   the rest matches the old rule: airings, minutes before and after,
   commercials, Keep, and the TV Shows library. The DVR's defaults fill in
   most of it.
4. Save, then check the schedule shows the next airings on that channel
   only, before deleting the old rule.

Mum's rules, set to match the ones she had on the HDHomeRun. All of them
record 5 minutes before and 15 after, delete ads, allow partial airings
and go into TV Shows:

| Show                | Channel         | Keep        |
| ------------------- | --------------- | ----------- |
| My Kitchen Rules    | Seven (71)      | 5 unwatched |
| Gogglebox Australia | 10              | all         |
| The Block           | Channel 9 (91)  | all         |

Block Island, I'm A Celebrity, MasterChef Australia and The Piano still
have their old rules, waiting for a new season. MasterChef's only airing
as old repeats on 10 Comedy.

## Gotchas

- **Seven only works from an Australian IP.** Traffic out of a VPN breaks
  it.
- **Online, ABC, Seven and Ten stop at 720p.** Nine and SBS go to 1080p.
  Streamlink already takes the best on offer.
- **Plex doesn't support emulated tuners.** They work, but a Plex update can
  break them, as 1.43.0 did for a while.
- **Plex calls every listing NEW,** even a JAG repeat from 2003. See
  Recordings.
- **Live TV plays for a second, buffers, then plays.** Dispatcharr is ready
  in about a second and a half, so it's Plex's transcoder catching up.
- **Plex shows live TV as "Recording: Live TV - Session".** That's its
  pause buffer, not a recording.
- **A recording that starts while the tuner can't get a signal sticks at
  100% forever.** Cancel it from Plex's activity menu, or find its id and
  delete it:
  ```sh
  ssh root@plex 't=$(grep -o "PlexOnlineToken=\"[^\"]*" "/var/lib/plex/Plex Media Server/Preferences.xml" | cut -d\" -f2); curl -s "http://127.0.0.1:32400/activities?X-Plex-Token=$t"'
  ssh root@plex 't=$(grep -o "PlexOnlineToken=\"[^\"]*" "/var/lib/plex/Plex Media Server/Preferences.xml" | cut -d\" -f2); curl -X DELETE "http://127.0.0.1:32400/activities/<uuid>?X-Plex-Token=$t"'
  ```
- **The playlist and EPG links only answer the LAN.** Network Access limits
  M3U and EPG to private addresses by default, which suits Plex.

## Ideas

- **Proper new and repeat flags.** The source gives each episode an
  `original-air-date`, which Dispatcharr drops. A small step that adds
  `<previously-shown/>` wherever that date isn't the airing date would make
  "new airings only" work again.
- **More channels.** The Au group has BBC News (the one with listings is
  `mjh-bbc-news`), Adult Animation, and about 130 more.

## Backups

Dispatcharr's Postgres lives in `db/`, which the backup skips because a
live copy of it is useless. Dispatcharr dumps the database into `backups/`
every night at 3am instead and keeps three. To restore, put the files back
as in [docs/hetzner](../hetzner/README.md), start the container, and restore
the newest dump from Settings, Backup & Restore.
