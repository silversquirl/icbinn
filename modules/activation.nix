{
  config,
  lib,
  pkgs,
  ...
}: let
  activationSnippet = name: value: let
    entry =
      if builtins.isString value
      then {
        deps = [];
        text = value;
        supportsDeactivation = false;
      }
      else value;
  in
    entry
    // {
      text = let
        logged = ''
          info "''${DEACTIVATE:+de}activating '${name}'"
          ${entry.text}
        '';

        wrapped =
          if entry.supportsDeactivation
          then logged
          else ''
            if ((DEACTIVATE)); then
              info "skipping deactivation of '${name}'"
            else

            ${logged}

            fi
          '';
      in ''
        #### Activation script snippet ${name}:
        _localstatus=0
        ${wrapped}

        ((_localstatus)) && error "Activation script snippet '${name}' failed ($_localstatus)"
      '';
    };

  allSnippets = let
    snippets = builtins.mapAttrs activationSnippet config.icbinn.activationScripts;
  in
    lib.textClosureMap lib.id snippets (builtins.attrNames snippets);
in {
  options.icbinn = {
    activationScripts = lib.mkOption {
      default = {};

      description = ''
        A set of shell script fragments that are executed when the configuration is activated or deactivated.
        For example, enabling and restarting services, updating caches, etc.

        Unlike NixOS activation scripts, these scripts are *not* executed on every boot.
      '';

      type = lib.types.attrsOf (lib.types.either lib.types.str
        (lib.types.submodule {
          options = {
            deps = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [];
              description = "List of dependencies. The script will run after these.";
            };
            text = lib.mkOption {
              type = lib.types.lines;
              description = "The content of the script.";
            };
            supportsDeactivation = lib.mkOption {
              type = lib.types.bool;
              default = false;
              description = "Whether this script supports deactivation when DEACTIVATE=1 is set.";
            };
          };
        }));
    };

    activationPackage = lib.mkOption {
      type = lib.types.submodule {
        options = {
          name = lib.mkOption {
            type = lib.types.str;
            default = "activation-script.sh";
            description = "Name of the package.";
          };

          runtimeShell = lib.mkOption {
            type = lib.types.path;
            default = pkgs.runtimeShell;
          };

          runtimeInputs = lib.mkOption {
            type = lib.types.listOf (lib.types.either lib.types.package lib.types.path);
            apply = lib.makeBinPath;
          };
          runtimePath = lib.mkOption {
            type = lib.types.listOf lib.types.path;
            apply = builtins.concatStringsSep ":";
          };

          checkPhase = lib.mkOption {
            type = lib.types.lines;
          };

          extraDerivationArgs = lib.mkOption {
            type = let
              arg = lib.types.either lib.types.str lib.types.path;
            in
              lib.types.attrsOf (lib.types.either arg (lib.types.listOf arg));
            default = {};
          };
        };

        config = {
          runtimeInputs = lib.mkBefore [
            pkgs.coreutils
            pkgs.gnugrep
            pkgs.gnused
            pkgs.findutils
            pkgs.smfh
          ];

          runtimePath = lib.mkAfter [
            "/usr/sbin"
            "/usr/bin"
            "/sbin"
            "/bin"
          ];

          checkPhase = lib.mkMerge [
            (lib.mkBefore "runHook preCheck")
            ''${pkgs.stdenv.shellDryRun} "$out"''
            (lib.mkAfter "runHook postCheck")
          ];
        };
      };
      default = {};

      apply = opts:
        pkgs.stdenvNoCC.mkDerivation ({
            manifestPath = config.smfh.manifest;
            gcRootPath = config.smfh.gcRoot.path;
            activationPath = ./activation.sh;
            snippets = allSnippets;
            passAsFile = ["snippets"];

            dontUnpack = true;
            doCheck = true;

            buildPhase = ''
              {
              cat <<EOF
              #!$runtimeShell
              export PATH=$runtimeInputs:$runtimePath
              _smfhManifest=$manifestPath
              _smfhGcRoot=$gcRootPath
              EOF

              echo
              cat "$activationPath"

              echo
              cat "$snippetsPath"

              echo 'exit $_status'
              } >"$out"
              chmod +x "$out"
            '';
          }
          // lib.removeAttrs opts ["extraDerivationArgs"]
          // opts.extraDerivationArgs);
    };
  };
}
