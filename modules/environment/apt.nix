{
  config,
  lib,
  ...
}: let
  cfg = config.apt;
in {
  options.apt = {
    packages = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      description = "Packages to install with apt";
      default = [];
    };
  };

  config.icbinn.activationScripts.apt = lib.mkIf (cfg.packages != []) ''
    apt-get update
    apt-get install -y ${lib.escapeShellArgs cfg.packages}
  '';
}
