{
  pkgs,
  lib,
  config,
  ...
}: let
  cfg = config.security.apparmor;
in {
  options.security.apparmor = let
    inherit (lib) types;
  in {
    enable = lib.mkEnableOption "AppArmor";
    policies = lib.mkOption {
      description = ''
        AppArmor policies.
      '';
      type = types.attrsOf (types.submodule {
        options = {
          state = lib.mkOption {
            description = "How strictly this policy should be enforced";
            type = types.enum [
              "disable"
              "complain"
              "enforce"
            ];
            # should enforce really be the default?
            # the docs state that this should only be used once one is REALLY sure nothing's gonna break
            default = "enforce";
          };

          profile = lib.mkOption {
            description = "The profile file contents. Incompatible with path.";
            type = types.lines;
          };

          path = lib.mkOption {
            description = "A path of a profile file to include. Incompatible with profile.";
            type = types.nullOr types.path;
            default = null;
          };
        };
      });
      default = {};
    };
    includes = lib.mkOption {
      type = types.attrsOf types.lines;
      default = {};
      description = ''
        List of paths to be added to AppArmor's searched paths
        when resolving `include` directives.
      '';
      apply = lib.mapAttrs pkgs.writeText;
    };
  };

  config = let
    # TODO: enforce/complain
    # TODO: check, using `apparmor_parser -d`
    apparmorProfile = name: policy: {
      name = "apparmor.d/${name}";
      value.enable = cfg.enable && policy.state != "disable";
      value.text = policy.profile;
    };
  in {
    environment.etc = lib.mapAttrs' apparmorProfile cfg.policies;
    # TODO: includes

    icbinn.activationScripts.apparmor = {
      text = "systemctl reload apparmor";
      supportsDeactivation = true;
    };
  };
}
