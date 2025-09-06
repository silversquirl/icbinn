{lib, ...}: {
  options.systemd.services = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule ({config, ...}: {
      partOf = ["icbinn-activation.target"];
      wantedBy = ["icbinn-activation.target"];
    }));
  };

  config = {
    systemd.targets.icbinn-activation = {
      description = "Start all units managed by icbinn";
      requires = ["sysinit-reactivation.target"];
      after = ["sysinit-reactivation.target"];
    };

    icbinn.activationScripts.restart-systemd-services = {
      text = ''
        systemctl daemon-reload
        if ((DEACTIVATE)); then
          systemctl stop icbinn-activation.target
        else
          systemctl restart icbinn-activation.target
        fi
      '';
      supportsDeactivation = true;
    };
  };
}
