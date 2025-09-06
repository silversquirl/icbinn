# Reimplementation of environment.etc on top of smfh
{
  config,
  lib,
  pkgs,
  ...
}: {
  options.environment.etc = lib.mkOption {
    default = {};
    example = lib.literalExpression ''
      { example-configuration-file =
          { source = "/nix/store/.../etc/dir/file.conf.example";
            mode = "0440";
          };
        "default/useradd".text = "GROUP=100 ...";
      }
    '';
    description = ''
      Set of files that have to be linked in {file}`/etc`.
    '';

    type = lib.types.attrsOf (
      lib.types.submodule (
        {
          name,
          config,
          options,
          ...
        }: {
          options = {
            enable = lib.mkOption {
              type = lib.types.bool;
              default = true;
              description = ''
                Whether this /etc file should be generated.  This
                option allows specific /etc files to be disabled.
              '';
            };

            target = lib.mkOption {
              type = lib.types.str;
              default = name;
              defaultText = lib.literalMD "attribute name";
              description = "Name of symlink (relative to {file}`/etc`).";
            };

            text = lib.mkOption {
              default = null;
              type = lib.types.nullOr lib.types.lines;
              description = "Text of the file.";
            };

            source = lib.mkOption {
              type = lib.types.path;
              description = "Path of the source file.";
            };

            mode = lib.mkOption {
              type =
                lib.types.either
                (lib.types.strMatching "0?[0-7]{3}")
                (lib.types.enum ["symlink" "direct-symlink"]);
              default = "symlink";
              example = "0600";
              description = ''
                If set to something else than `symlink`,
                the file is copied instead of symlinked, with the given
                file mode.
              '';
            };

            uid = lib.mkOption {
              default = 0;
              type = lib.types.int;
              description = ''
                UID of created file. Only takes effect when the file is
                copied (that is, the mode is not 'symlink').
              '';
            };

            gid = lib.mkOption {
              default = 0;
              type = lib.types.int;
              description = ''
                GID of created file. Only takes effect when the file is
                copied (that is, the mode is not 'symlink').
              '';
            };
          };

          config.source = lib.mkIf (config.text != null) (
            let
              name' = "etc-" + lib.replaceStrings ["/"] ["-"] name;
            in
              lib.mkDerivedConfig options.text (pkgs.writeText name')
          );
        }
      )
    );
  };

  config.smfh.files = let
    toSmfh = entry: let
      isLink = entry.mode == "symlink" || entry.mode == "direct-symlink";
    in
      lib.mkMerge [
        {
          inherit (entry) source;
          target = "/etc/${entry.target}";
          type =
            if isLink
            then "symlink"
            else "copy";
        }
        (lib.mkIf (!isLink) {
          inherit (entry) uid gid;
          permissions = entry.mode;
        })
      ];
    toSmfhConfig = name: entry: {"/etc/${name}" = toSmfh entry;};
    configs = lib.mapAttrsToList toSmfhConfig config.environment.etc;
  in
    lib.mkMerge configs;
}
