{
  config,
  lib,
  ...
}: {
  options.system.checks = lib.mkOption {
    type = lib.types.listOf lib.types.package;
    default = [];
  };
  config.icbinn.activationPackage.extraDerivationArgs = {
    successfulChecks = config.system.checks;
  };
}
