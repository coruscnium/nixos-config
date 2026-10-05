{ ... }:

# Spectacle restores in region-capture mode and blocks login until Esc (KDE bug 489190).
# On Wayland the exclude list matches desktop-file ids, not executable names.
{
  programs.plasma.session.sessionRestore.excludeApplications = [
    "org.kde.spectacle.desktop"
  ];
}
