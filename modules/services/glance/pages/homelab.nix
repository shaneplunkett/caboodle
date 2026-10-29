{
  lib,
  nodes,
}:
{
  name = "Homelab";
  width = "wide";

  columns = [
    {
      size = "full";
      widgets = [
        (import ../widgets/services {
          inherit lib nodes;
          group = "homelab";
        })
      ];
    }
    {
      size = "small";
      widgets = [
        (import ../widgets/alerts { inherit nodes; })
        (import ../widgets/releases)
        (import ../widgets/dns { inherit nodes; })
        (import ../widgets/blocked { inherit nodes; })
        (import ../widgets/backups { inherit lib nodes; })
      ];
    }
  ];
}
