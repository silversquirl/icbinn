{
  config,
  lib,
  pkgs,
  ...
}: {
  options = {
    nix.enable = lib.mkEnableOption "managing Nix through icbinn";
    nix.package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.nixVersions.latest;
      defaultText = lib.literalExpression "pkgs.nixVersions.latest";
    };

    environment.systemPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [];
      description = ''
        The set of packages to be installed into the default system profile.
      '';
    };
  };

  config = {
    environment.systemPackages = lib.mkIf config.nix.enable [config.nix.package];
    icbinn.activationScripts.system-packages = lib.mkIf (config.environment.systemPackages != []) ''
      ${config.nix.package}/bin/nix-env -i ${lib.escapeShellArgs config.environment.systemPackages}
    '';
    systemd.tmpfiles.settings."00-current-system" = {
      "/run/current-system/sw"."L+" = {argument = "${builtins.dirOf builtins.storeDir}/var/nix/profiles/default";};
    };
  };
}
