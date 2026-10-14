{ pkgs, ... }:
{
  services.wivrn = {
    enable = true;
    openFirewall = true;
    autoStart = true;
  };

  hardware.steam-hardware.enable = true;

  hardware.graphics.enable32Bit = true;

  environment.systemPackages = with pkgs; [
    monado-vulkan-layers
    opencomposite
  ];
}
