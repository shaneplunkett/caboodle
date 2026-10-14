{
  config,
  lib,
  pkgs,
  ...
}:
let
  collector = pkgs.writeShellApplication {
    name = "amdgpu-dump-collector";
    runtimeInputs = [
      pkgs.python3
      pkgs.systemd
    ];
    text = ''
      exec python3 ${./amdgpu-dump-collector.py} "$@"
    '';
  };
in
{
  # The kernel emits ADD after creating data and failing_device. Do not use
  # RUN here: the copy and journal collection must outlive the udev worker.
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="devcoredump", KERNEL=="devcd[0-9]*", TAG+="systemd", ENV{SYSTEMD_WANTS}+="amdgpu-dump@%k.service"
  '';

  systemd.services."amdgpu-dump@" = {
    description = "Save AMDGPU device crash dump %i before it expires";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${lib.getExe collector} /sys/class/devcoredump/%i /var/lib/amdgpu-crash-dumps";
      User = "root";
      Group = "users";
      UMask = "0027";
      StateDirectory = "amdgpu-crash-dumps";
      StateDirectoryMode = "0750";
      TimeoutStartSec = "90s";
      NoNewPrivileges = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      ProtectKernelTunables = true;
      ProtectKernelModules = true;
      ProtectControlGroups = true;
      PrivateTmp = true;
      PrivateNetwork = true;
    };
  };

  system.build = {
    amdgpuDumpCollector = collector;
    amdgpuDumpCollectorTest =
      pkgs.runCommand "amdgpu-dump-collector-tests"
        {
          nativeBuildInputs = [ pkgs.python3 ];
        }
        ''
          python3 ${./test-amdgpu-dump-collector.py} ${./amdgpu-dump-collector.py} ${lib.getExe collector}
          touch "$out"
        '';
  };

  # Every desktop build must pass the fixture tests before this can go live.
  system.extraDependencies = [ config.system.build.amdgpuDumpCollectorTest ];
}
