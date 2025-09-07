{pkgs, ...}: {
  specialisation = {
    egpu.configuration = {
      system.nixos.tags = ["egpu"];

      boot = {
        # Ensure module for external graphics is loaded
        initrd.kernelModules = ["amdgpu"];

        # Disable the integrated graphics module
        blacklistedKernelModules = ["i915" "xe"];

        kernelParams = [
          "pcie_port_pm=off"
          "module_blacklist=i915,xe"
          "i915.modeset=0"
          "xe.modeset=0"
          "amdgpu.pcie_gen_cap=0x40000" # Force AMD GPU to use full width (optional)
        ];
      };

      # Use external graphics
      services.xserver.videoDrivers = ["amdgpu"];
    };
  };
}
