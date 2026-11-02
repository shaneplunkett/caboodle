{
  lib,
  buildGoModule,
}:
buildGoModule {
  pname = "unifi-cli";
  version = "0.1.0";

  src = lib.cleanSource ./.;

  vendorHash = "sha256-Vm+4TDe8MH2vn0GhmD8ruqMykfZuPQs3FG66gMj93yc=";

  ldflags = [
    "-s"
    "-w"
  ];

  postInstall = ''
    mv $out/bin/unifi-cli $out/bin/unifi
  '';

  meta = {
    description = "Read-only CLI for Shane's UniFi Cloud Gateway Max — exposes drops/latency/events the UI hides";
    homepage = "https://github.com/shaneplunkett/caboodle/tree/main/pkgs/unifi-cli";
    license = lib.licenses.mit;
    mainProgram = "unifi";
  };
}
