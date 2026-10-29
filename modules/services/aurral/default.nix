let
  dataDir = "/var/lib/aurral";
  port = 3001;
in
{
  homelab.monitoring.units = [ "podman-aurral.service" ];

  virtualisation.oci-containers.containers.aurral = {
    image = "ghcr.io/lklynet/aurral:2.12.0";
    ports = [ "${toString port}:3001" ];
    volumes = [
      "${dataDir}:/config"
      "/mnt/media:/data"
    ];
    environment = {
      PUID = "99";
      PGID = "100";
      TZ = "Australia/Melbourne";
    };
  };

  systemd.services.podman-aurral.environment.XDG_RUNTIME_DIR = "/run";

  systemd.tmpfiles.rules = [ "d ${dataDir} 0750 99 100 -" ];

  networking.firewall.allowedTCPPorts = [ port ];
}
