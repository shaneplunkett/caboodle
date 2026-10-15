# COSMIC Files mounts drives and network shares through GIO, so gvfs runs on
# the desktop.
{ pkgs, ... }:
{
  home.packages = [ pkgs.cosmic-files ];

  xdg = {
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
