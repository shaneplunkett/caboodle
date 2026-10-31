{ nodes, ... }:
let
  inherit (nodes.mirror.config.users) users groups;
  idmap = 1000000;
in
{
  systemd.services.mirror-pool = {
    description = "Make the mirror guest's folder on the pool";
    wantedBy = [ "incus.service" ];
    before = [ "incus.service" ];
    unitConfig.RequiresMountsFor = [ "/mnt/user" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      install -d -o ${toString (idmap + users.mirror.uid)} -g ${toString (idmap + groups.mirror.gid)} \
        -m 0700 /mnt/user/mirror
    '';
  };
}
