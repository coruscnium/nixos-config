{ pkgs, ... }:

# 3D, CAD and 2D creative tools.
{
  home.packages = with pkgs; [
    blender
    freecad
    openscad
    solvespace
    krita
    gimp
  ];
}
