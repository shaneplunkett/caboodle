#!/usr/bin/env nix-shell
#!nix-shell -i python3 -p "python3.withPackages (p: [ p.yt-dlp p.secretstorage ])" rbw wl-clipboard
"""Copy the YouTube Music login cookie from a browser into Music Assistant.

Run it when Music Assistant's YouTube Music source stops working with a 401
or "Unable to fetch PO Token". Pass the browser profile that's signed in to
YouTube Music, in yt-dlp's form: chrome, chrome:Profile, chromium:Default.
docs/pve/home.md explains why that profile should be one you keep for this.

If the source doesn't exist yet, the cookie goes to the clipboard to paste
into Music Assistant's add-source form. The cookie is never printed.
"""

import json
import subprocess
import sys
import urllib.request

from yt_dlp.cookies import extract_cookies_from_browser

MUSIC_ASSISTANT = "http://192.168.1.117:8095"
LOGIN_ENTRY = "music-assistant-admin"
YOUTUBE_DOMAINS = {"youtube.com", "music.youtube.com"}


def youtube_cookie(spec: str) -> str:
    browser, _, profile = spec.partition(":")
    jar = extract_cookies_from_browser(browser, profile or None)
    cookies = {c.name: c.value for c in jar if c.domain.lstrip(".") in YOUTUBE_DOMAINS}
    if "__Secure-3PAPISID" not in cookies:
        sys.exit(f"{spec} isn't signed in to YouTube. Sign in at music.youtube.com there first.")
    return "; ".join(f"{name}={value}" for name, value in cookies.items())


def rbw(*args: str) -> str:
    return subprocess.run(["rbw", "get", *args], check=True, capture_output=True, text=True).stdout.strip()


def post(path: str, body: dict, token: str | None = None):
    request = urllib.request.Request(
        MUSIC_ASSISTANT + path,
        json.dumps(body).encode(),
        {"Content-Type": "application/json"},
    )
    if token:
        request.add_header("Authorization", f"Bearer {token}")
    with urllib.request.urlopen(request) as response:
        return json.load(response)


def command(token: str, name: str, **args):
    return post("/api", {"message_id": name, "command": name, "args": args}, token)


def main() -> None:
    spec = sys.argv[1] if len(sys.argv) > 1 else "chrome"
    cookie = youtube_cookie(spec)

    login = post(
        "/auth/login",
        {
            "provider_id": "builtin",
            "credentials": {
                "username": rbw("-f", "username", LOGIN_ENTRY),
                "password": rbw(LOGIN_ENTRY),
            },
            "device_name": "youtube-cookie script",
        },
    )
    token = login["token"]
    try:
        sources = command(token, "config/providers", provider_domain="ytmusic")
        if not sources:
            subprocess.run(["wl-copy"], input=cookie, text=True, check=True)
            print("No YouTube Music source yet. The cookie's on the clipboard: paste it")
            print("into Login Cookie under Settings, Music Sources, Add a music source.")
            return
        for source in sources:
            command(
                token,
                "config/providers/save",
                provider_domain="ytmusic",
                instance_id=source["instance_id"],
                values={"cookie": cookie},
            )
            print(f"Updated the cookie on {source.get('name') or source['instance_id']}.")
    finally:
        command(token, "auth/logout")


if __name__ == "__main__":
    main()
