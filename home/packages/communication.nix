# Chat / calls / email.
{ pkgs, ... }:

{
  home.packages = [
    pkgs."tutanota-desktop" # Tuta Mail (encrypted email)
    # discord
    # signal-desktop
    # element-desktop
  ];
}
