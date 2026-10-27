_: {
  imports = [ ../../modules/services/smartctl ];

  services.prometheus.exporters.smartctl = {
    devices = map (id: "/dev/disk/by-id/${id}") [
      "ata-ST12000VN0008-2YS101_ZV7086XX"
      "ata-ST12000VN0008-2YS101_ZRT05E1B"
      "ata-ST12000VN0008-2PH103_ZTN1CAYB"
      "ata-ST12000VN0008-2PH103_ZTN1D2SG"
      "ata-ST12000VN0008-2YS101_ZRS0SDXQ"
      "ata-ST16000NE000-2RW103_ZL2LZPS0"
      "ata-ST16000NE000-2RW103_ZL2LZPP2"
      "nvme-KINGSTON_SNV2S1000G_50026B7785387B08"
      "nvme-Samsung_SSD_970_EVO_Plus_1TB_S6P7NS0X654691W"
    ];
  };
}
