{
  config,
  lib,
  ...
}: {
  options = {
    boot.kernel.sysctl = lib.mkOption {
      type = lib.types.submodule {
        freeformType = lib.types.attrsOf (lib.types.nullOr (
          lib.types.oneOf [
            lib.types.bool
            lib.types.str
            lib.types.int
          ]
        ));
        options.enable = lib.mkEnableOption "sysctl";
      };
      default = {};
      example = lib.literalExpression ''
        { "net.ipv4.tcp_syncookies" = false; "vm.swappiness" = 60; }
      '';
      description = ''
        Runtime parameters of the Linux kernel, as set by
        {manpage}`sysctl(8)`.  Note that sysctl
        parameters names must be enclosed in quotes
        (e.g. `"vm.swappiness"` instead of
        `vm.swappiness`).  The value of each
        parameter may be a string, integer, boolean, or null
        (signifying the option will not appear at all).
      '';
    };
  };

  config = let
    cfg = config.boot.kernel.sysctl;
  in
    lib.mkIf cfg.enable {
      environment.etc."sysctl.d/60-icbinn.conf".text =
        lib.concatStrings
        (lib.mapAttrsToList (n: v:
          lib.optionalString (v != null) "${n}=${
            if v == false
            then "0"
            else toString v
          }\n")
        (builtins.removeAttrs cfg ["enable"]));

      systemd.services.icbinn-activation.requires = ["systemd-sysctl.service"];
    };
}
