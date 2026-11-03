{
  lib,
  buildGoModule,
}:
buildGoModule {
  pname = "linear-bridge";
  version = "0.1.0";

  src = lib.cleanSource ./.;

  vendorHash = null;

  ldflags = [
    "-s"
    "-w"
  ];

  meta = {
    description = "Files Alertmanager's alerts as Linear issues and comments when they resolve";
    homepage = "https://github.com/shaneplunkett/caboodle/tree/main/pkgs/linear-bridge";
    license = lib.licenses.mit;
    mainProgram = "linear-bridge";
  };
}
