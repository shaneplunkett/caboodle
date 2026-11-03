{ config, ... }:
{
  imports = [
    ../modules/services/github-runner
  ];

  deployment.targetHost = config.homelab.lanAddress;
}
