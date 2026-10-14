{ pkgs, ... }: {
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
    wireplumber = {
      enable = true;
      configPackages = [
        (pkgs.writeTextDir "share/wireplumber/wireplumber.conf.d/10-bluez.conf" ''
          monitor.bluez.properties = {
            bluez5.roles = [ a2dp_sink a2dp_source bap_sink bap_source hsp_hs hsp_ag hfp_hf hfp_ag ]
            bluez5.enable-sbc-xq = true
            bluez5.enable-msbc = true
            bluez5.enable-hw-volume = true
          }
        '')
      ];
    };

    raopOpenFirewall = true;
    extraConfig.pipewire = {
      "10-airplay" = {
        name = "libpipewire-module-raop-discover";
      };
    };
  };

}
