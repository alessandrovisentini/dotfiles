{config, ...}: {
  home-manager.users.${config.local.device.userName} = {
    pkgs,
    config,
    ...
  }: {
    xdg.configFile."mimeapps.list".force = true;

    xdg.mimeApps = {
      enable = true;
      defaultApplications = {
        "text/html"                = "firefox.desktop";
        "x-scheme-handler/http"   = "firefox.desktop";
        "x-scheme-handler/https"  = "firefox.desktop";
        "x-scheme-handler/about"  = "firefox.desktop";
        "x-scheme-handler/unknown"= "firefox.desktop";

        "x-scheme-handler/mailto" = "org.gnome.Geary.desktop";

        "image/jpeg"              = "imv.desktop";
        "image/png"               = "imv.desktop";
        "image/gif"               = "imv.desktop";
        "image/webp"              = "imv.desktop";
        "image/bmp"               = "imv.desktop";
        "image/tiff"              = "imv.desktop";
        "image/avif"              = "imv.desktop";
        "image/heic"              = "imv.desktop";
        "image/svg+xml"           = "org.inkscape.Inkscape.desktop";

        "video/mp4"               = "mpv.desktop";
        "video/x-matroska"        = "mpv.desktop";
        "video/x-msvideo"         = "mpv.desktop";
        "video/webm"              = "mpv.desktop";
        "video/quicktime"         = "mpv.desktop";
        "video/mpeg"              = "mpv.desktop";
        "video/ogg"               = "mpv.desktop";
        "video/x-flv"             = "mpv.desktop";
        "video/3gpp"              = "mpv.desktop";

        "audio/mpeg"              = "mpv.desktop";
        "audio/ogg"               = "mpv.desktop";
        "audio/flac"              = "mpv.desktop";
        "audio/x-flac"            = "mpv.desktop";
        "audio/x-wav"             = "mpv.desktop";
        "audio/wav"               = "mpv.desktop";
        "audio/mp4"               = "mpv.desktop";
        "audio/aac"               = "mpv.desktop";
        "audio/webm"              = "mpv.desktop";

        "application/pdf"         = "org.gnome.Papers.desktop";

        "application/msword"                                                      = "writer.desktop";
        "application/vnd.openxmlformats-officedocument.wordprocessingml.document" = "writer.desktop";
        "application/vnd.oasis.opendocument.text"                                 = "writer.desktop";

        "application/vnd.ms-excel"                                            = "calc.desktop";
        "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"   = "calc.desktop";
        "application/vnd.oasis.opendocument.spreadsheet"                      = "calc.desktop";

        "application/vnd.ms-powerpoint"                                                = "impress.desktop";
        "application/vnd.openxmlformats-officedocument.presentationml.presentation"   = "impress.desktop";
        "application/vnd.oasis.opendocument.presentation"                             = "impress.desktop";

        "application/vnd.oasis.opendocument.graphics" = "draw.desktop";

        "application/epub+zip"           = "calibre-ebook-viewer.desktop";
        "application/x-mobipocket-ebook" = "calibre-ebook-viewer.desktop";
        "application/x-cbz"              = "calibre-ebook-viewer.desktop";
        "application/x-cbr"              = "calibre-ebook-viewer.desktop";

        "text/plain" = "org.gnome.TextEditor.desktop";

        "font/ttf"                = "org.gnome.font-viewer.desktop";
        "font/otf"                = "org.gnome.font-viewer.desktop";
        "font/collection"         = "org.gnome.font-viewer.desktop";
        "application/x-font-ttf" = "org.gnome.font-viewer.desktop";

        "inode/directory" = "org.gnome.Nautilus.desktop";

        "application/zip"                    = "org.gnome.Nautilus.desktop";
        "application/x-tar"                  = "org.gnome.Nautilus.desktop";
        "application/x-compressed-tar"       = "org.gnome.Nautilus.desktop";
        "application/x-bzip2-compressed-tar" = "org.gnome.Nautilus.desktop";
        "application/x-xz-compressed-tar"    = "org.gnome.Nautilus.desktop";
        "application/x-7z-compressed"        = "org.gnome.Nautilus.desktop";
        "application/x-rar"                  = "org.gnome.Nautilus.desktop";
      };
    };
  };
}
