{ config, lib, ... }:
{
  nixpkgs.hostPlatform = "x86_64-linux";

  virtualisation.podman.autoPrune = {
    enable = true;
    dates = "daily";
    flags = [ "--all" ];
  };

  programs.nh.clean = {
    dates = "daily";
    extraArgs = "--keep 1";
  };

  systemd.services.clean-after-deploy = {
    description = "Drop the last deploy's generation and images";
    wantedBy = [ "multi-user.target" ];
    after = map (name: "podman-${name}.service") (
      builtins.attrNames config.virtualisation.oci-containers.containers
    );
    restartTriggers = [ config.system.configurationRevision ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart =
        lib.optional config.programs.nh.clean.enable "${config.systemd.package}/bin/systemctl start --no-block nh-clean.service"
        ++ lib.optional config.virtualisation.podman.enable "${config.systemd.package}/bin/systemctl start --no-block podman-prune.service";
    };
  };

  users.users.root.openssh.authorizedKeys.keys =
  [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINfq31bP+xQwlO/joZeGU6LaLYZXV2ql7TLSv5ToVUtJ"
  ]
  ++ lib.optional config.homelab.deployedByRunner "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEwMm4iT56bQb/ujy15aoiHBZueU5FexFQNusMCq7BFD runner-deploy";

  system.stateVersion = "26.11";
}
