{
  config,
  lib,
  pkgs,
  ...
}: {
  options.hardware.graphics = {
    enable = lib.mkOption {
      description = ''
        Whether to enable hardware accelerated graphics drivers.

        This is required to allow most graphical applications and
        environments to use hardware rendering, video encode/decode
        acceleration, etc.

        This option should be enabled by default by the corresponding modules,
        so you do not usually have to set it yourself.
      '';
      type = lib.types.bool;
      default = false;
    };

    enable32Bit = lib.mkOption {
      description = ''
        On 64-bit systems, whether to also install 32-bit drivers for
        32-bit applications (such as Wine).
      '';
      type = lib.types.bool;
      default = false;
    };

    package = lib.mkOption {
      description = ''
        The package that provides the default driver set.
      '';
      type = lib.types.package;
    };

    package32 = lib.mkOption {
      description = ''
        The package that provides the 32-bit driver set. Used when {option}`enable32Bit` is enabled.
      '';
      type = lib.types.package;
    };

    extraPackages = lib.mkOption {
      description = ''
        Additional packages to add to the default graphics driver lookup path.
        This can be used to add OpenCL drivers, VA-API/VDPAU drivers, etc.

        ::: {.note}
        intel-media-driver supports hardware Broadwell (2014) or newer. Older hardware should use the mostly unmaintained intel-vaapi-driver driver.
        :::
      '';
      type = lib.types.listOf lib.types.package;
      default = [];
      example = lib.literalExpression "[ pkgs.intel-media-driver pkgs.intel-ocl pkgs.intel-vaapi-driver ]";
    };

    extraPackages32 = lib.mkOption {
      description = ''
        Additional packages to add to 32-bit graphics driver lookup path on 64-bit systems.
        Used when {option}`enable32Bit` is set. This can be used to add OpenCL drivers, VA-API/VDPAU drivers, etc.

        ::: {.note}
        intel-media-driver supports hardware Broadwell (2014) or newer. Older hardware should use the mostly unmaintained intel-vaapi-driver driver.
        :::
      '';
      type = lib.types.listOf lib.types.package;
      default = [];
      example = lib.literalExpression "[ pkgs.pkgsi686Linux.intel-media-driver pkgs.pkgsi686Linux.intel-vaapi-driver ]";
    };
  };

  config = let
    cfg = config.hardware.graphics;
  in
    lib.mkIf cfg.enable {
      assertions = [
        {
          assertion = cfg.enable32Bit -> pkgs.stdenv.hostPlatform.isx86_64;
          message = "`hardware.graphics.enable32Bit` is only supported on an x86_64 system.";
        }
      ];

      smfh.files = {
        "/run/opengl-driver".source = pkgs.symlinkJoin {
          name = "graphics-drivers";
          paths = [cfg.package] ++ cfg.extraPackages;
        };
        "/run/opengl-driver-32" =
          if pkgs.stdenv.hostPlatform.isi686
          then {source = "opengl-driver";}
          else
            lib.mkIf cfg.enable32Bit {
              source = pkgs.symlinkJoin {
                name = "graphics-drivers-32bit";
                paths = [cfg.package32] ++ cfg.extraPackages32;
              };
            };
      };

      hardware.graphics.package = lib.mkDefault pkgs.mesa;
      hardware.graphics.package32 = lib.mkDefault pkgs.pkgsi686Linux.mesa;
    };
}
