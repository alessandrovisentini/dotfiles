{pkgs, lib, ...}: {
  specialisation = {
    egpu.configuration = {
      system.nixos.tags = ["egpu"];

      # Custom kernel without simpledrm
      boot.kernelPackages = pkgs.linuxPackages.extend (self: super: {
        kernel = super.kernel.override {
          structuredExtraConfig = with lib.kernel; {
            DRM_SIMPLEDRM = lib.mkForce no;
            SYSFB_SIMPLEFB = lib.mkForce no;
          };
        };
      });

      boot = {
        initrd.kernelModules = ["amdgpu"];
        blacklistedKernelModules = ["i915" "xe"];
        kernelParams = [
          "pcie_port_pm=off"
          "module_blacklist=i915,xe"
          "i915.modeset=0"
          "xe.modeset=0"
          "amdgpu.pcie_gen_cap=0x40000"
        ];
      };

      services.xserver.videoDrivers = ["amdgpu"];

      hardware.graphics = lib.mkForce {
        enable = true;
        enable32Bit = true;
        extraPackages = [];
      };
    };
  };
}
