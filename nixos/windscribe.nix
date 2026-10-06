{ pkgs, ... }:
{
  services.windscribe.enable = true;

  # The GUI runs as coru and needs to reach the helper's group-owned socket.
  users.users.coru.extraGroups = [ "windscribe" ];

  environment.systemPackages = [ pkgs.windscribe ];
}
