let
  dataDir = "/var/lib/maintainerr";
  port = 6246;
in
{
  homelab = {
    backup = {
      paths = [ dataDir ];
      exclude = [ "${dataDir}/logs" ];
    };

    arr.databases = [ "${dataDir}/maintainerr.sqlite" ];
  };

  virtualisation.oci-containers.containers.maintainerr = {
    image = "ghcr.io/maintainerr/maintainerr:3.30.1";
    ports = [ "${toString port}:${toString port}" ];
    volumes = [ "${dataDir}:/opt/data" ];
    environment.TZ = "Australia/Melbourne";
  };

  systemd.tmpfiles.rules = [ "d ${dataDir} 0750 1000 1000 -" ];

  networking.firewall.allowedTCPPorts = [ port ];
}
