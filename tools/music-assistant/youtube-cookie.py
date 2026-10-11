#!/usr/bin/env nix-shell
#!nix-shell -i python3 -p "python3.withPackages (p: [ p.yt-dlp ])" rbw wl-clipboard
"""Sign in to YouTube Music in a throwaway Chrome profile and hand the cookie
to Music Assistant.

Run it when Music Assistant's YouTube Music source stops working with a 401
or "Unable to fetch PO Token". Chrome opens on a fresh profile: sign in, close
the window, and the cookie goes to Music Assistant. The profile is deleted
straight after, so no browser is left to rotate the cookie.

If the source doesn't exist yet, the cookie goes to the clipboard to paste
into Music Assistant's add-source form. The cookie is never printed.
"""

import json
import subprocess
import sys
import tempfile
import urllib.request
from pathlib import Path

from yt_dlp.cookies import extract_cookies_from_browser

MUSIC_ASSISTANT = "http://192.168.1.117:8095"
LOGIN_ENTRY = "music-assistant-admin"
YOUTUBE_DOMAINS = {"youtube.com", "music.youtube.com"}
SIGN_IN = (
    "https://accounts.google.com/ServiceLogin?service=youtube&continue=https://music.youtube.com/"
)


def youtube_cookie() -> str:
    with tempfile.TemporaryDirectory(prefix="youtube-cookie-") as profile:
        print("Sign in to YouTube Music in the Chrome window, then close it.")
        subprocess.run(
            [
                "google-chrome-stable",
                f"--user-data-dir={profile}",
                "--password-store=basic",
                "--no-first-run",
                "--no-default-browser-check",
                SIGN_IN,
            ],
            check=True,
            stderr=subprocess.DEVNULL,
        )
        jar = extract_cookies_from_browser(
            "chrome", str(Path(profile) / "Default"), keyring="BASICTEXT"
        )
    cookies = {c.name: c.value for c in jar if c.domain.lstrip(".") in YOUTUBE_DOMAINS}
    if "__Secure-3PAPISID" not in cookies:
        sys.exit("No YouTube sign-in came back. Sign in before closing the window.")
    return "; ".join(f"{name}={value}" for name, value in cookies.items())


def rbw(*args: str) -> str:
    return subprocess.run(
        ["rbw", "get", *args], check=True, capture_output=True, text=True
    ).stdout.strip()


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
    cookie = youtube_cookie()

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
