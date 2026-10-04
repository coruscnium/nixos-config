{ ... }:

# Session restore (ksmserverrc). KDE 6.1+ reopens the apps that were running at
# logout; Spectacle gets restored on every login in region-capture mode and blocks
# the desktop until Esc (KDE bug 489190). On Wayland the exclude list matches
# DESKTOP FILE IDS, not executable names.
{
  programs.plasma.session.sessionRestore.excludeApplications = [
    "org.kde.spectacle.desktop"
  ];
}
