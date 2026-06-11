{
  config,
  pkgs,
  ...
}: {
  users.users.${config.local.device.userName}.extraGroups = [
    "docker"
  ];
}
