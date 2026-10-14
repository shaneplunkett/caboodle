{ lib, ... }:
{
  catppuccin = {
    enable = true;
    autoEnable = true;
    flavor = "mocha";
    accent = "mauve";

    hyprland.enable = false;

    nvim.enable = false;

    rofi.enable = false;

    # Only the Linux desktop styles Qt with Kvantum (linux/theme.nix).
    kvantum.enable = lib.mkDefault false;

    # The upstream module imports a generated TOML derivation during module
    # evaluation, which makes cross-platform `nix flake check` try to build the
    # target platform's generator locally. Starship consumes our shared palette
    # directly instead.
    starship.enable = false;
  };
}
