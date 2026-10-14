{ pkgs, ... }:
let
  houdini = pkgs.waydroid-houdini;
in
{
  virtualisation.waydroid = {
    enable = true;
  };

  networking.nftables.enable = true;

  # Waydroid layers /var/lib/waydroid/overlay over the image's partitions,
  # so ARM translation has to be copied there rather than linked from the
  # store. This replaces the expired libhoudini that waydroid_script put in
  # by hand, and leaves its libndk files and the native-bridge props in
  # waydroid.cfg alone. multi-user.target is there so a switch starts it
  # too, not only a container start; a switch that brings a new build while
  # a session is running fails this unit until the session stops.
  systemd.services.waydroid-houdini = {
    description = "Install libhoudini into the Waydroid overlay";
    wantedBy = [
      "multi-user.target"
      "waydroid-container.service"
    ];
    before = [ "waydroid-container.service" ];
    path = [
      pkgs.diffutils
      pkgs.util-linux
    ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      src=${houdini}/system
      dst=/var/lib/waydroid/overlay/system

      if cmp -s "$src/lib/libhoudini.so" "$dst/lib/libhoudini.so" \
        && cmp -s "$src/lib64/libhoudini.so" "$dst/lib64/libhoudini.so"; then
        exit 0
      fi

      # The overlay is a lower layer of the running session's root, and
      # changing it underneath a mount is undefined.
      if mountpoint -q /var/lib/waydroid/rootfs; then
        echo "Stop the Waydroid session, then restart waydroid-houdini." >&2
        exit 1
      fi

      cd "$src"
      find . -type f | while read -r file; do
        case "$file" in
          ./bin/*) install -D -m 755 -o root -g 2000 "$file" "$dst/$file" ;;
          *) install -D -m 644 -o root -g root "$file" "$dst/$file" ;;
        esac
      done
    '';
  };
}
