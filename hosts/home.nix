{
  imports = [
    ../modules/services/home-assistant
    ../modules/services/matterjs-server
    ../modules/services/mosquitto
    ../modules/services/music-assistant
    ../modules/services/zigbee2mqtt
  ];

  systemd.network.networks."50-eth0".networkConfig.IPv6AcceptRA = true;
}
