# ParkerrDev/nixpkgs-windscribe's module is self-contained: it installs the
# package, declares the windscribe user/group, wires the setgid engine wrapper
# and the /opt/windscribe bind mount, and runs both services. Nothing else here.
{
  services.windscribe = {
    enable = true;
    variant = "gui";
    autoStart = true;
  };
}
