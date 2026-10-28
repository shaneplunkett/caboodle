_: {
  imports = [ ../../modules/services/smartctl ];

  services.prometheus.exporters.smartctl = {
    devices = map (id: "/dev/disk/by-id/${id}") [
      "nvme-Samsung_SSD_970_EVO_Plus_1TB_S6P7NS0X654705D"
      "nvme-Samsung_SSD_970_EVO_Plus_1TB_S4EWNM0W350900P"
    ];
  };
}
