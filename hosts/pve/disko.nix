_: {
  disko.devices.disk.main = {
    type = "disk";
    device = "/dev/disk/by-id/nvme-Samsung_SSD_970_EVO_Plus_1TB_S6P7NS0X654691W";
    content = {
      type = "gpt";
      partitions = {
        ESP = {
          size = "1G";
          type = "EF00";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
            mountOptions = [ "umask=0077" ];
          };
        };
        root = {
          size = "100G";
          content = {
            type = "filesystem";
            format = "ext4";
            mountpoint = "/";
          };
        };
        incus = {
          size = "100%";
          content = {
            type = "lvm_pv";
            vg = "incus";
          };
        };
      };
    };
  };

  disko.devices.lvm_vg.incus = {
    type = "lvm_vg";
    lvs = { };
  };
}
