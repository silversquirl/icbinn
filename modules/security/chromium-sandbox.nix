{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.security.chromium-sandbox;
  name = cfg.package.passthru.sandboxExecutableName;
in {
  options.security.chromium-sandbox = {
    enable = lib.mkEnableOption "chromium SUID sandbox wrapper";
    package = lib.mkOption {
      types = lib.types.package;
      default = pkgs.chromium.sandbox;
      defaultString = lib.literalExpression "pkgs.chromium.sandbox";
      description = "The chromium sandbox package to use";
    };
  };

  config = lib.mkIf cfg.enable {
    security.wrappers.${name} = {
      setuid = true;
      owner = "root";
      group = "root";
      source = "${cfg.package}/bin/${name}";
    };
  };
}
