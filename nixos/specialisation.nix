{lib, ...}: {
  # AMD eGPU
  specialisation = {
    # eGPU only iGPU off
    egpu.configuration = {
      system.nixos.tags = ["egpu"];

      boot = {
        initrd.kernelModules = ["amdgpu"];
        # the LUKS password prompt needs this
        kernelParams = ["amdgpu.pcie_gen_cap=0x40000" "module_blacklist=i915,xe"];
        blacklistedKernelModules = ["i915" "xe"];
      };

      services.xserver.videoDrivers = lib.mkForce ["amdgpu"];

      hardware.graphics = lib.mkForce {
        enable = true;
        enable32Bit = true;
      };

      environment.sessionVariables.AMD_VULKAN_ICD = "RADV";

      # Take simpledrm out of the seat
      services.udev.extraRules = ''
        SUBSYSTEM=="drm", ENV{ID_PATH}=="*simple-framebuffer*", TAG-="master-of-seat", TAG-="seat"
      '';
    };
  };
}
