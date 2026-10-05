{ pkgs, ... }:

# Players plus the PipeWire / EasyEffects tooling.
{
  home.packages = with pkgs; [
    harmonoid
    spotify
    spicetify-cli
    lrcget

    easyeffects
    calf
    lsp-plugins

    pipewire-control-center # target of toggle_pw_control_center.sh
  ];
}
