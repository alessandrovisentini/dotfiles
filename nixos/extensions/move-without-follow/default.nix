{stdenvNoCC}:
stdenvNoCC.mkDerivation {
  pname = "gnome-shell-extension-move-without-follow";
  version = "0.1.0";
  src = ./.;
  dontConfigure = true;
  dontBuild = true;
  installPhase = ''
    runHook preInstall
    uuid="move-without-follow@local"
    target="$out/share/gnome-shell/extensions/$uuid"
    mkdir -p "$target"
    install -m644 extension.js metadata.json -t "$target/"
    runHook postInstall
  '';
  passthru.extensionUuid = "move-without-follow@local";
}
