{
  virtualisation.incus.preseed.storage_pools = [
    {
      name = "nas-cache";
      driver = "btrfs";
      config.source = "/mnt/cache/incus";
    }
  ];

  systemd.services.incus.after = [ "mnt-cache.mount" ];
}
