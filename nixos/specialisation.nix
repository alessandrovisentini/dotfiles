{pkgs, lib, ...}: {
  specialisation = {
    egpu.configuration = {
      system.nixos.tags = ["egpu"];
      boot = {
        initrd.kernelModules = ["amdgpu"];
        blacklistedKernelModules = ["i915" "xe"];
        kernelParams = [
          "pcie_port_pm=off"
          "module_blacklist=i915,xe"
          "i915.modeset=0"
          "xe.modeset=0"

          # Prevent simpledrm from initializing
          "initcall_blacklist=simpledrm_platform_driver_init"

          # Keep the framebuffer disabling for good measure
          "video=efifb:off"
          "video=vesafb:off"
          "video=simplefb:off"

          "amdgpu.pcie_gen_cap=0x40000"
        ];
      };

      services.xserver.videoDrivers = lib.mkForce ["amdgpu"];

      hardware.graphics = lib.mkForce {
        enable = true;
        enable32Bit = true;
        extraPackages = [];
      };
    };
  };
}
