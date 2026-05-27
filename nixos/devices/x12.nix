# ThinkPad X12 Detachable Gen 1
{
  boot.initrd.luks.devices."luks-5cbfb211-230a-4462-ba9b-80c2395d8dd4".crypttabExtraOpts = [ "tpm2-device=auto" ];

  local.device = {
    userName = "alessandrovisentini";
    hostName = "x12";

    hasTabletMode = true;
    hasTouchscreen = true;
    hasAccelerometer = true;
    hasFingerprint = true;
    hasIpu6Camera = true;
    hasThunderbolt = true;

    detachableTouchpadSwayId = "6127:24830:Darfon_Thinkpad_X12_Detachable_Gen_1_Folio_case_-1";
    detachableKeyboardHints = ["Darfon Thinkpad X12" "Folio case"];
  };
}
