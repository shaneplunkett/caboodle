{
  type = "custom-api";
  title = "Proxmox";
  cache = "1m";
  url = "https://proxmox.shaneplunkett.com/api2/json/cluster/resources";
  headers = {
    Accept = "application/json";
    Authorization = "PVEAPIToken=homepage@pve!dashboard=\${HOMEPAGE_VAR_PROXMOX_TOKEN}";
  };
  template = builtins.readFile ./template.html;
}
