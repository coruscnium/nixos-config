# Security & privacy: password manager, 2FA, VPN.
{ pkgs, ... }:

{
  home.packages = [
    pkgs."proton-pass" # password manager
    pkgs."ente-auth" # TOTP 2FA authenticator
  ];
}
