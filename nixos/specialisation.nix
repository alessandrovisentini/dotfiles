{pkgs, lib, ...}: let
  # Run a command on the AMD eGPU instead of the default Intel iGPU (PRIME offload).
  # Usage: prime-run <cmd>   |   Steam launch options: prime-run %command%
  primeRun = pkgs.writeShellScriptBin "prime-run" ''
    export DRI_PRIME=1
    exec "$@"
  '';
in {
  specialisation = {
    # Dual GPU: Intel Iris Xe iGPU is the default renderer; AMD RX 7600 eGPU stays
    # available for game offload via prime-run. Both DRM nodes load, compositor
    # auto-detects them (external monitor on the eGPU still works).
    egpu.configuration = {
      system.nixos.tags = ["egpu"];

      boot = {
        initrd.kernelModules = ["amdgpu" "i915"];
        kernelParams = ["amdgpu.pcie_gen_cap=0x40000"];
      };

      services.xserver.videoDrivers = lib.mkForce ["modesetting" "amdgpu"];

      hardware.graphics = lib.mkForce {
        enable = true;
        enable32Bit = true;
      };

      environment.sessionVariables.AMD_VULKAN_ICD = "RADV";

      environment.systemPackages = [primeRun];
    };
  };
}
