{pkgs, lib, ...}: let
  # PRIME offload to the AMD eGPU. Usage: prime-run <cmd>
  primeRun = pkgs.writeShellScriptBin "prime-run" ''
    export DRI_PRIME=1
    exec "$@"
  '';
in {
  specialisation = {
    # Dual GPU: Intel iGPU default + AMD eGPU available for offload via prime-run.
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
