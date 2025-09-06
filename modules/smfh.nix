{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.smfh;
  manifest =
    pkgs.runCommand "smfh-manifest.json" {
      smfhManifest = builtins.toJSON {
        version = 1;
        clobber_by_default = cfg.clobberByDefault;
        files = map (lib.filterAttrs (n: v: v != null)) (builtins.attrValues cfg.files);
      };
      inherit (cfg) extraFiles;
      passAsFile = ["smfhManifest"];
      nativeBuildInputs = [pkgs.jq];
    } ''
      jq -cs '
        # Merge extraFiles into manifest
        .[0].files += [.[1:][]] | .[0] |
        # Replace @manifest@ placeholder
        .files[].source |= if . == "@manifest@" then $ENV.out end
      ' "$smfhManifestPath" $extraFiles >"$out"
    '';
in {
  options.smfh = {
    files = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule ({name, ...}: {
        options = {
          type = lib.mkOption {
            type = lib.types.enum ["directory" "copy" "symlink" "modify" "delete"];
            default = "symlink";
            description = "Operation to perform to create this file";
          };

          target = lib.mkOption {
            type = lib.types.pathWith {
              inStore = false;
              absolute = true;
            };
            default = name;
            defaultText = lib.literalMD "attribute name";
            description = "Path to target file";
            apply = lib.strings.normalizePath;
          };

          source = lib.mkOption {
            type = lib.types.nullOr (lib.types.either lib.types.path (lib.types.enum ["@manifest@"]));
            description = "Path to source file. You may use `@manifest@` to refer to the generated manifest file.";
          };

          clobber = lib.mkOption {
            type = lib.types.nullOr lib.types.bool;
            default = null;
            description = "Whether to overwrite existing files";
          };

          permissions = lib.mkOption {
            type = lib.types.nullOr (lib.types.strMatching "[0-7]{3}");
            default = null;
            description = "Permissions to set on the target file";
          };
          uid = lib.mkOption {
            type = lib.types.nullOr lib.types.int;
            default = null;
            description = "User ID to set on the target file";
          };
          gid = lib.mkOption {
            type = lib.types.nullOr lib.types.int;
            default = null;
            description = "Group ID to set on the target file";
          };
        };
      }));
      default = {};
      description = "Files to add to the smfh manifest";
    };

    extraFiles = lib.mkOption {
      type = lib.types.listOf lib.types.path;
      default = [];
      example = lib.literalExpression ''
        [(pkgs.writeText "foo.json" '''{"type":"symlink","target":"/etc/mtab","source":"/proc/mounts"}''')]
      '';
      description = ''
        Extra JSON to insert at the end of the smfh manifest's files array.
        Allows generating parts of the manifest based on derivation output.
      '';
    };

    clobberByDefault = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to overwrite existing files";
    };

    gcRoot = {
      enable = lib.mkEnableOption "GC root for smfh manifest";

      dir = lib.mkOption {
        type = lib.types.pathWith {
          inStore = false;
          absolute = true;
        };
        description = "The Nix GC root directory.";
        default = "${builtins.dirOf builtins.storeDir}/var/nix/gcroots";
        defaultText = lib.literalExpression ''"''${builtins.dirOf builtins.storeDir}/var/nix/gcroots"'';
      };

      name = lib.mkOption {
        type = lib.types.pathWith {absolute = false;};
        description = "Name of the GC root. The manifest file will be symlinked to this name inside the GC root directory.";
      };

      path = lib.mkOption {
        internal = true;
        readOnly = true;
        default = "${cfg.gcRoot.dir}/${cfg.gcRoot.name}";
      };
    };

    manifest = lib.mkOption {
      type = lib.types.path;
      readOnly = true;
      internal = true;
      description = "Path to smfh manifest";
      defaultText = lib.literalMD "generated manifest file";
      default = manifest;
    };
  };

  config = {
    # Link manifest into GC root dir
    # TODO: it might be beneficial to generate a second version of the manifest with non-symlinks' source paths removed, to avoid unnecessarily blocking them from being GC'd
    smfh.files = lib.mkIf cfg.gcRoot.enable {
      "${cfg.gcRoot.path}" = {
        type = "symlink";
        source = "@manifest@";
      };
    };
  };
}
