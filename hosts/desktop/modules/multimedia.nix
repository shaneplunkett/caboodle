{ config, pkgs, ... }:
{
  # Not programs.obs-studio.enableVirtualCamera: it hardcodes video_nr=1,
  # which the Facecam already takes alongside video0.
  boot = {
    extraModulePackages = [
      config.boot.kernelPackages.v4l2loopback
    ];
    kernelModules = [ "v4l2loopback" ];
    extraModprobeConfig = ''
      options v4l2loopback devices=1 video_nr=10 card_label="OBS Virtual Camera" exclusive_caps=1
    '';
  };

  programs.obs-studio = {
    enable = true;
    plugins = [ pkgs.obs-studio-plugins.obs-backgroundremoval ];
  };

  environment.systemPackages = [ pkgs.cameractrls-gtk4 ];

  services.pipewire.extraConfig.pipewire."20-obs-virtual-mic" = {
    "context.modules" = [
      {
        name = "libpipewire-module-loopback";
        args = {
          "node.description" = "OBS Virtual Mic";
          "capture.props" = {
            "node.name" = "obs_virtual_mic_sink";
            "media.class" = "Audio/Sink";
            "audio.position" = [ "MONO" ];
          };
          "playback.props" = {
            "node.name" = "obs_virtual_mic_source";
            "media.class" = "Audio/Source";
            "audio.position" = [ "MONO" ];
          };
        };
      }
    ];
  };
}
