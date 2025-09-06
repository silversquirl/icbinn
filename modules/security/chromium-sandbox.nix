{pkgs, ...}: let
  sandbox = pkgs.chromium.sandbox;
  name = sandbox.passthru.sandboxExecutableName;
in {
  security.wrappers.${name} = {
    setuid = true;
    owner = "root";
    group = "root";
    source = "${sandbox}/bin/${name}";
  };
}
