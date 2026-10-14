_: {

  homebrew = {
    enable = true;

    casks = [
      "ghostty"
      "tailscale-app"
    ];

    brews = [
      "mas"
    ];

    masApps = {
    };
    onActivation = {
      cleanup = "uninstall";
      autoUpdate = false;
      upgrade = false;
    };

  };
}
