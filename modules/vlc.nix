{pkgs, ...}: let
  vlc = ["vlc.desktop"];
in {
  home.packages = [pkgs.vlc];

  xdg.mimeApps.defaultApplications = {
    "application/mxf" = vlc;
    "application/ogg" = vlc;
    "application/sdp" = vlc;
    "application/vnd.apple.mpegurl" = vlc;
    "application/vnd.ms-asf" = vlc;
    "application/vnd.rn-realmedia" = vlc;
    "application/x-extension-m4a" = vlc;
    "application/x-extension-mp4" = vlc;
    "application/x-matroska" = vlc;
    "application/x-mpegurl" = vlc;
    "application/x-ogg" = vlc;
    "application/xspf+xml" = vlc;

    "audio/aac" = vlc;
    "audio/ac3" = vlc;
    "audio/flac" = vlc;
    "audio/m4a" = vlc;
    "audio/mp4" = vlc;
    "audio/mpeg" = vlc;
    "audio/ogg" = vlc;
    "audio/vnd.dts" = vlc;
    "audio/vnd.rn-realaudio" = vlc;
    "audio/webm" = vlc;
    "audio/x-aiff" = vlc;
    "audio/x-ape" = vlc;
    "audio/x-flac" = vlc;
    "audio/x-m4a" = vlc;
    "audio/x-matroska" = vlc;
    "audio/x-mpegurl" = vlc;
    "audio/x-ms-wma" = vlc;
    "audio/x-musepack" = vlc;
    "audio/x-ogg" = vlc;
    "audio/x-opus+ogg" = vlc;
    "audio/x-scpls" = vlc;
    "audio/x-speex" = vlc;
    "audio/x-vorbis+ogg" = vlc;
    "audio/x-wav" = vlc;

    "video/3gpp" = vlc;
    "video/3gpp2" = vlc;
    "video/avi" = vlc;
    "video/divx" = vlc;
    "video/dv" = vlc;
    "video/mp2t" = vlc;
    "video/mp4" = vlc;
    "video/mpeg" = vlc;
    "video/ogg" = vlc;
    "video/quicktime" = vlc;
    "video/vnd.mpegurl" = vlc;
    "video/vnd.rn-realvideo" = vlc;
    "video/webm" = vlc;
    "video/x-flv" = vlc;
    "video/x-m4v" = vlc;
    "video/x-matroska" = vlc;
    "video/x-mpeg2" = vlc;
    "video/x-ms-asf" = vlc;
    "video/x-ms-wmv" = vlc;
    "video/x-msvideo" = vlc;
    "video/x-ogm+ogg" = vlc;
    "video/x-theora+ogg" = vlc;
  };
}
