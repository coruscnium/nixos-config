{ pkgs, ... }:

# Players plus the PipeWire / EasyEffects tooling.
# deepfilternet was dropped per your instruction (tinkering, not in use).
{
  home.packages = with pkgs; [
    harmonoid
    spotify
    spicetify-cli
    lrcget

    easyeffects
    calf
    lsp-plugins

    helvum
    qpwgraph
    pavucontrol
    coppwr                         # replaces pipewire-controller
    pipewire-control-center        # target of toggle_pw_control_center.sh
  ];
}
