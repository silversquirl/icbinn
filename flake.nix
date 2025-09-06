{
  inputs.nixpkgs.url = "nixpkgs";

  outputs = {nixpkgs, ...}: {
    lib.icbinnConfiguration = {
      extraSpecialArgs ? {},
      lib ? nixpkgs.lib,
      modules ? [],
    }:
      lib.evalModules {
        specialArgs =
          {modulesPath = "${nixpkgs}/nixos/modules";}
          // extraSpecialArgs;
        modules = [./modules] ++ modules;
      };

    lib.activationApp = config: {
      type = "app";
      program = "${config.config.icbinn.activationPackage}";
    };
  };
}
