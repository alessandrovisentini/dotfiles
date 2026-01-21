{pkgs, lib, ...}: let
  swayEgpuLauncher = pkgs.writeShellScriptBin "sway-egpu-launcher" ''
    EGPU="/dev/dri/by-path/pci-0000:54:00.0-card"
    IGPU="/dev/dri/by-path/pci-0000:00:02.0-card"
    export WLR_DRM_DEVICES="$(readlink -f "$EGPU"):$(readlink -f "$IGPU")"
    exec sway "$@"
  '';
in {
  specialisation = {
    # Dual GPU: AMD RX 7600 eGPU (primary renderer) + Intel Iris Xe iGPU (display output)
    egpu.configuration = {
      system.nixos.tags = ["egpu"];

      boot = {
        initrd.kernelModules = ["amdgpu" "i915"];
        kernelParams = ["amdgpu.pcie_gen_cap=0x40000"];
      };

      services.xserver.videoDrivers = lib.mkForce ["amdgpu" "modesetting"];

      hardware.graphics = lib.mkForce {
        enable = true;
        enable32Bit = true;
      };

      environment.sessionVariables.AMD_VULKAN_ICD = "RADV";

      environment.etc."wayland-sessions/sway-egpu.desktop".text = ''
        [Desktop Entry]
        Name=Sway (eGPU)
        Comment=Sway with AMD eGPU as primary renderer
        Exec=${swayEgpuLauncher}/bin/sway-egpu-launcher
        Type=Application
        DesktopNames=sway
      '';
    };
  };
}
