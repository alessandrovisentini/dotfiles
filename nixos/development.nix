{
  config,
  pkgs,
  ...
}: {
  users.users.${config.local.device.userName}.extraGroups = [
    "adbusers"
    "docker"
  ];
}
