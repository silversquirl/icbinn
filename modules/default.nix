{
  lib,
  modulesPath,
  ...
}: {
  imports = [
    ./activation.nix
    ./checks.nix
    ./environment/apt.nix
    ./environment/etc.nix
    ./environment/packages.nix
    ./environment/shell-env.nix
    ./security/apparmor.nix
    ./security/chromium-sandbox.nix
    ./smfh.nix
    ./systemd/activation.nix
    ./systemd/systemd.nix
    ./systemd/tmpfiles.nix
    "${modulesPath}/hardware/graphics.nix"
    "${modulesPath}/misc/nixpkgs.nix"
    "${modulesPath}/security/wrappers"
  ];

  smfh.gcRoot = lib.mkDefault {
    enable = true;
    name = "icbinn-manifest.json";
  };
}
