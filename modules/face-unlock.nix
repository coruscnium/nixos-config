# Windows Hello–style face unlock via the ASUS IR camera.
#
# Howdy matches the face against an enrolled model. It can be spoofed with a
# decent printed photo, so it is configured `sufficient` (face OR password,
# never face alone) and is deliberately NOT wired into sudo/su/polkit.
{ ... }:

{
  services.howdy = {
    enable = true;
    control = "sufficient";
    settings = {
      core.abort_if_lid_closed = true;
      video = {
        device_path = "/dev/video2"; # ASUS IR camera (video0/1 are RGB)
        certainty = 3.5;
      };
    };
  };

  # Drives the IR illuminator so the camera can see you in the dark. Needs a
  # one-time interactive `sudo linux-enable-ir-emitter configure`.
  services.linux-enable-ir-emitter = {
    enable = true;
    device = "video2";
  };

  # Howdy enables itself in EVERY PAM service by default. Turn the global off
  # and opt in only where it belongs, so privilege escalation stays
  # password-only and a face misread can never lock you out.
  security.pam.howdy.enable = false;
  security.pam.services.login.howdy.enable = true;
  security.pam.services.sddm.howdy.enable = true;
  security.pam.services.sddm-greeter.howdy.enable = true;
  security.pam.services.kde.howdy.enable = true; # Plasma lock screen

  # Where Howdy keeps enrolled face models. This directory must be traversable
  # by the *user*, not just root: kscreenlocker runs its PAM auth as uid 1000,
  # so a root-only models dir makes Howdy fail (EACCES) before it ever opens the
  # camera. `d` only sets the mode when it creates the dir, so `z` is needed too
  # to re-apply the mode on every activation. Howdy writes the model files
  # themselves world-readable, so the directory mode is the only thing that
  # blocks the lock screen.
  systemd.tmpfiles.rules = [
    "d /var/lib/howdy 0755 root root -"
    "z /var/lib/howdy 0755 root root -"
    "d /var/lib/howdy/models 0755 root root -"
    "z /var/lib/howdy/models 0755 root root -"
  ];
}
