# File management: COSMIC Files, which also compresses and extracts archives
# from its right-click menu, so there's no separate archive app. It shares
# libcosmic and the Catppuccin theme with the file picker (cosmic.nix), and
# mounts drives and network shares through GIO, so gvfs runs on the desktop.
{ pkgs, ... }:
{
  home.packages = [ pkgs.cosmic-files ];

  xdg = {
    # Listed as "Files" in vicinae.
    desktopEntries."com.system76.CosmicFiles" = {
      name = "Files";
      comment = "Access and organise files";
      exec = "cosmic-files %U";
      icon = "com.system76.CosmicFiles";
      terminal = false;
      type = "Application";
      categories = [
        "Utility"
        "FileManager"
      ];
      mimeType = [ "inode/directory" ];
    };

    mimeApps.defaultApplications."inode/directory" = "com.system76.CosmicFiles.desktop";
  };
}
