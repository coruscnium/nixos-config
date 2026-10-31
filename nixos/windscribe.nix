# ParkerrDev/nixpkgs-windscribe's module is self-contained: it installs the
# package, declares the windscribe user/group, wires the setgid engine wrapper
# and the /opt/windscribe bind mount, and runs both services. Nothing else here
# except one packaging workaround.
{ pkgs, ... }:

{
  services.windscribe = {
    enable = true;
    variant = "gui";
    autoStart = true;

    # patchelf >= 0.18 (nixpkgs 26.11, was 0.15.2) aborts while patching
    # windscribeopenvpn: "Assertion `splitIndex == -1' failed". autoPatchelfHook
    # grows the ELF twice per file -- interpreter first, RUNPATH second -- and
    # this binary's section layout survives exactly one growth.
    #
    # Growing the RUNPATH first, while the file is still pristine, is the one
    # order patchelf does handle. The hook's own --set-rpath then finds enough
    # room and only shrinks the string in place, so it never shifts again. The
    # placeholder never becomes the loaded RUNPATH: auto-patchelf builds that
    # from scratch and does not carry existing entries over.
    package = pkgs.windscribe.overrideAttrs (old: {
      postPatch = (old.postPatch or "") + ''
        patchelf --set-rpath "$(printf '%0512d' 0)" opt/windscribe/windscribeopenvpn
      '';
    });
  };
}
