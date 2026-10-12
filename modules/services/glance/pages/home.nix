{ nodes, secrets }:
{
  name = "Home";
  width = "wide";

  head-widgets = [
    {
      type = "search";
      search-engine = "google";
      autofocus = true;
      bangs = [
        {
          title = "GitHub";
          shortcut = "!gh";
          url = "https://github.com/search?q={QUERY}";
        }
        {
          title = "Nix packages";
          shortcut = "!np";
          url = "https://search.nixos.org/packages?channel=unstable&query={QUERY}";
        }
        {
          title = "NixOS options";
          shortcut = "!no";
          url = "https://search.nixos.org/options?channel=unstable&query={QUERY}";
        }
        {
          title = "YouTube";
          shortcut = "!yt";
          url = "https://www.youtube.com/results?search_query={QUERY}";
        }
      ];
    }
  ];

  columns = [
    {
      size = "small";
      widgets = [
        (import ../widgets/alerts { inherit nodes; })
        (import ../widgets/linear { inherit secrets; })
        (import ../widgets/immich { inherit secrets; })
      ];
    }
    {
      size = "full";
      widgets = [
        (import ../widgets/feeds)
      ];
    }
    {
      size = "small";
      widgets = [
        {
          type = "clock";
          hour-format = "24h";
        }
        {
          type = "weather";
          location = "Melbourne, Australia";
          hour-format = "24h";
          hide-location = true;
        }
        {
          type = "calendar";
          first-day-of-week = "monday";
        }
      ];
    }
  ];
}
