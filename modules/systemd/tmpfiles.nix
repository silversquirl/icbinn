{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.systemd.tmpfiles;
  systemd = config.systemd.package;

  attrsWith' = placeholder: elemType:
    lib.types.attrsWith {
      inherit elemType placeholder;
    };

  escapeArgument = lib.strings.escapeC ["\t" "\n" "\r" " " "\\"];

  # generates a single entry for a tmpfiles.d rule
  settingsEntryToRule = path: entry: ''
    '${entry.type}' '${path}' '${entry.mode}' '${entry.user}' '${entry.group}' '${entry.age}' ${escapeArgument entry.argument}
  '';

  # generates a list of tmpfiles.d rules from the attrs (paths) under tmpfiles.settings.<name>
  pathsToRules =
    lib.mapAttrsToList (path: types:
      lib.concatStrings (lib.mapAttrsToList (_type: settingsEntryToRule path) types));

  mkRuleFileContent = paths: lib.concatStrings (pathsToRules paths);
in {
  options.systemd.tmpfiles = {
    enableDefaultRules = lib.mkEnableOption "default tmpfiles rules provided by systemd";

    settings = lib.mkOption {
      description = ''
        Declare systemd-tmpfiles rules to create, delete, and clean up volatile
        and temporary files and directories.

        Even though the service is called `*tmp*files` you can also create
        persistent files.
      '';
      example = {
        "10-mypackage" = {
          "/var/lib/my-service/statefolder".d = {
            mode = "0755";
            user = "root";
            group = "root";
          };
        };
      };
      default = {};
      type = attrsWith' "config-name" (
        attrsWith' "path" (
          attrsWith' "tmpfiles-type" (
            lib.types.submodule (
              {name, ...}: {
                options.type = lib.mkOption {
                  type = lib.types.str;
                  default = name;
                  defaultText = "‹tmpfiles-type›";
                  example = "d";
                  description = ''
                    The type of operation to perform on the file.

                    The type consists of a single letter and optionally one or more
                    modifier characters.

                    Please see the upstream documentation for the available lib.types and
                    more details:
                    {manpage}`tmpfiles.d(5)`
                  '';
                };
                options.mode = lib.mkOption {
                  type = lib.types.str;
                  default = "-";
                  example = "0755";
                  description = ''
                    The file access mode to use when creating this file or directory.
                  '';
                };
                options.user = lib.mkOption {
                  type = lib.types.str;
                  default = "-";
                  example = "root";
                  description = ''
                    The user of the file.

                    This may either be a numeric ID or a user/group name.

                    If omitted or when set to `"-"`, the user and group of the user who
                    invokes systemd-tmpfiles is used.
                  '';
                };
                options.group = lib.mkOption {
                  type = lib.types.str;
                  default = "-";
                  example = "root";
                  description = ''
                    The group of the file.

                    This may either be a numeric ID or a user/group name.

                    If omitted or when set to `"-"`, the user and group of the user who
                    invokes systemd-tmpfiles is used.
                  '';
                };
                options.age = lib.mkOption {
                  type = lib.types.str;
                  default = "-";
                  example = "10d";
                  description = ''
                    Delete a file when it reaches a certain age.

                    If a file or directory is older than the current time minus the age
                    field, it is deleted.

                    If set to `"-"` no automatic clean-up is done.
                  '';
                };
                options.argument = lib.mkOption {
                  type = lib.types.str;
                  default = "";
                  example = "";
                  description = ''
                    An argument whose meaning depends on the type of operation.

                    Please see the upstream documentation for the meaning of this
                    parameter in different situations:
                    {manpage}`tmpfiles.d(5)`
                  '';
                };
              }
            )
          )
        )
      );
    };

    packages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [];
      example = lib.literalExpression "[ pkgs.lvm2 ]";
      apply = map lib.getLib;
      description = ''
        List of packages containing {command}`systemd-tmpfiles` rules.

        All files ending in .conf found in
        {file}`«pkg»/lib/tmpfiles.d`
        will be included.
        If this folder does not exist or does not contain any files an error will be returned instead.

        If a {file}`lib` output is available, rules are searched there and only there.
        If there is no {file}`lib` output it will fall back to {file}`out`
        and if that does not exist either, the default output will be used.
      '';
    };
  };

  config = {
    warnings = lib.flatten (
      lib.mapAttrsToList (
        name: paths:
          lib.mapAttrsToList (
            path: entries:
              lib.mapAttrsToList (
                type': entry:
                  lib.optional (lib.match ''.*\\([nrt]|x[0-9A-Fa-f]{2}).*'' entry.argument != null) (
                    lib.concatStringsSep " " [
                      "The argument option of ${name}.${type'}.${path} appears to"
                      "contain escape sequences, which will be escaped again."
                      "Unescape them if this is not intended: \"${entry.argument}\""
                    ]
                  )
              )
              entries
          )
          paths
      )
      cfg.settings
    );

    # Allow systemd-tmpfiles to be restarted by switch-to-configuration. This
    # service is not pulled into the normal boot process. It only exists for
    # switch-to-configuration.
    #
    # This needs to be a separate unit because it does not execute
    # systemd-tmpfiles with `--boot` as that is supposed to only be executed
    # once at boot time.
    #
    # Keep this aligned with the upstream `systemd-tmpfiles-setup.service` unit.
    systemd.services."systemd-tmpfiles-resetup" = {
      description = "Re-setup tmpfiles on a system that is already running.";

      requiredBy = ["sysinit-reactivation.target"];
      after = [
        "local-fs.target"
        "systemd-sysusers.service"
        "systemd-journald.service"
      ];
      before = [
        "sysinit-reactivation.target"
        "shutdown.target"
      ];
      conflicts = ["shutdown.target"];

      unitConfig.DefaultDependencies = false;

      path = lib.mkForce [];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "systemd-tmpfiles --create --remove --exclude-prefix=/dev";
        SuccessExitStatus = "DATAERR CANTCREAT";
        ImportCredential = [
          "tmpfiles.*"
          "loging.motd"
          "login.issue"
          "network.hosts"
          "ssh.authorized_keys.root"
        ];
        RestrictSUIDSGID = false;
      };
    };

    smfh.extraFiles = let
      json =
        pkgs.runCommand "smfh-manifest-tmpfiles.json" {
          paths = map (p: p + "/lib/tmpfiles.d") cfg.packages;
          nativeBuildInputs = [pkgs.jq];
        } ''
          first_exists() { [ -e "$1" ]; }
          for path in $paths; do
            if ! first_exists "$path"/*.conf; then
              echo "ERROR: The path '$path' from systemd.tmpfiles.packages contains no *.conf files." >&2
              exit 1
            fi
            for file in "$path"/*.conf; do
              jq -cn --arg source "$file" --arg target "/etc/tmpfiles.d/''${file##*/}" \
                '{$source, $target, type: "symlink"}' \
                >>"$out"
            done
          done
        '';
    in [json];

    systemd.tmpfiles.packages =
      # Default tmpfiles rules provided by systemd
      lib.optional (cfg.enableDefaultRules) (
        pkgs.runCommand "systemd-default-tmpfiles" {} ''
          mkdir -p $out/lib/tmpfiles.d
          cd $out/lib/tmpfiles.d

          ln -s "${systemd}/example/tmpfiles.d/home.conf"
          ln -s "${systemd}/example/tmpfiles.d/journal-nocow.conf"
          ln -s "${systemd}/example/tmpfiles.d/portables.conf"
          ln -s "${systemd}/example/tmpfiles.d/static-nodes-permissions.conf"
          ln -s "${systemd}/example/tmpfiles.d/systemd.conf"
          ln -s "${systemd}/example/tmpfiles.d/systemd-nologin.conf"
          ln -s "${systemd}/example/tmpfiles.d/systemd-nspawn.conf"
          ln -s "${systemd}/example/tmpfiles.d/systemd-tmp.conf"
          ln -s "${systemd}/example/tmpfiles.d/tmp.conf"
          ln -s "${systemd}/example/tmpfiles.d/var.conf"
          ln -s "${systemd}/example/tmpfiles.d/x11.conf"
        ''
      )
      ++ (lib.mapAttrsToList
        (name: paths:
          pkgs.writeTextDir "lib/tmpfiles.d/${name}.conf" (mkRuleFileContent paths))
        cfg.settings);
  };
}
