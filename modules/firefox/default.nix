{
  pkgs,
  config,
  ...
}: let
  fcitx5Gtk3Cache =
    pkgs.runCommand "fcitx5-gtk3-immodules-cache" {
      nativeBuildInputs = [pkgs.gtk3.dev];
    } ''
      mkdir -p $out
      gtk-query-immodules-3.0 \
        ${pkgs.fcitx5-gtk}/lib/gtk-3.0/3.0.0/immodules/im-fcitx5.so \
        > $out/immodules.cache
    '';

  wrapFirefox = firefox:
    pkgs.symlinkJoin {
      name = "firefox-with-fcitx";
      paths = [firefox];
      nativeBuildInputs = [pkgs.makeWrapper];
      postBuild = ''
        wrapProgram $out/bin/firefox \
          --set GTK_IM_MODULE fcitx \
          --set GTK_IM_MODULE_FILE ${fcitx5Gtk3Cache}/immodules.cache \
          --set XMODIFIERS @im=fcitx
      '';
      meta = firefox.meta;
      passthru =
        firefox.passthru
        // {
          override = args: wrapFirefox (firefox.override args);
        };
    };

  firefoxWithFcitx = wrapFirefox pkgs.firefox;

  newtabPort = 8918;
  newtabUrl = "http://127.0.0.1:${toString newtabPort}/";
in {
  home.file.".mozilla/firefox/default/user.js".force = true;

  systemd.user.services.newtab-server = {
    Unit = {
      Description = "Static server for the Catppuccin Firefox new tab page";
      After = ["network.target"];
    };
    Service = {
      Type = "simple";
      ExecStart = "${pkgs.python3}/bin/python3 -m http.server ${toString newtabPort} --bind 127.0.0.1 --directory ${config.home.homeDirectory}/.config/newtab";
      Restart = "on-failure";
    };
    Install = {
      WantedBy = ["default.target"];
    };
  };

  programs.firefox = {
    enable = true;
    configPath = ".mozilla/firefox";
    package =
      if pkgs.stdenv.isDarwin
      then pkgs.firefox-bin
      else firefoxWithFcitx;
    nativeMessagingHosts = with pkgs; [ff2mpv-rust];
    policies = {
      PromptForDownloadLocation = true;

      # about:support
      ExtensionSettings = {
        # DDict
        "jid1-wC71d7poAZYEGA@jetpack" = {
          install_url = "https://addons.mozilla.org/firefox/downloads/file/3918715/ddict-4.4.1.xpi";
          installation_mode = "force_installed";
        };

        # FirefoxColor
        "FirefoxColor@mozilla.com" = {
          install_url = "https://addons.mozilla.org/firefox/downloads/file/3643624/firefox_color-2.1.7.xpi";
          installation_mode = "force_installed";
        };

        # Ublock origin
        "uBlock0@raymondhill.net" = {
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi";
          installation_mode = "force_installed";
        };
        # Authenticator
        "authenticator@mymindstorm" = {
          install_url = "https://addons.mozilla.org/firefox/downloads/file/4353166/auth_helper-8.0.2.xpi";
          installation_mode = "force_installed";
        };
        # Bitwarden
        "{446900e4-71c2-419f-a6a7-df9c091e268b}" = {
          install_url = "https://addons.mozilla.org/firefox/downloads/file/4562769/bitwarden_password_manager-2025.8.1.xpi";
          installation_mode = "force_installed";
        };
        # Stylus
        "{7a7a4a92-a2a0-41d1-9fd7-1e92480d612d}" = {
          install_url = "https://addons.mozilla.org/firefox/downloads/file/4554444/styl_us-2.3.16.xpi";
          installation_mode = "force_installed";
        };
        # Tampermonkey
        "firefox@tampermonkey.net" = {
          install_url = "https://addons.mozilla.org/firefox/downloads/file/4405733/tampermonkey-5.3.3.xpi";
          installation_mode = "force_installed";
        };
        # Vimium
        "{d7742d87-e61d-4b78-b8a1-b469842139fa}" = {
          install_url = "https://addons.mozilla.org/firefox/downloads/file/4524018/vimium_ff-2.3.xpi";
          installation_mode = "force_installed";
        };
        # New Tab Override
        "newtaboverride@agenedia.com" = {
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/new-tab-override/latest.xpi";
          installation_mode = "force_installed";
        };
      };

      # Configure New Tab Override to open the Catppuccin startup page
      "3rdparty".Extensions."newtaboverride@agenedia.com" = {
        type = "custom_url";
        url = newtabUrl;
        background_color = "#1e1e2e";
      };
    };
    profiles.default = {
      settings = {
        "layout.spellcheckDefault" = 0;
        "browser.download.useDownloadDir" = false;
        "browser.download.always_ask_before_handling_new_types" = true;
        "browser.startup.homepage" = newtabUrl;
        "browser.startup.page" = 1;
        "browser.urlbar.suggest.history" = false;
        "browser.urlbar.suggest.bookmark" = false;
        "browser.urlbar.suggest.topsites" = false;
        "browser.urlbar.suggest.openpage" = false;
        "browser.urlbar.suggest.searches" = false;
        "browser.urlbar.suggest.engines" = false;
        "browser.urlbar.suggest.quickactions" = false;
        "browser.urlbar.quicksuggest.enabled" = false;
      };
      search = {
        force = true;
        default = "ddg"; # DuckDuckGo
        privateDefault = "ddg";
      };
      extensions.force = true; # override extension
      extensions.settings."{d7742d87-e61d-4b78-b8a1-b469842139fa}" = {
        settings = builtins.fromJSON (builtins.readFile ./ExtensionConfig/vimium/vimium-options.json);
        force = true;
      };
      userChrome = ./FirefoxCss/chrome/userChrome.css;
      extraConfig = builtins.readFile (pkgs.fetchurl {
        url = "https://raw.githubusercontent.com/yokoffing/Betterfox/8e415d1633f10fe0192d9c938e4ca2628eeec9f9/user.js";
        hash = "sha256-yelDvg0IKbd0xv4QfaZVca+Io6J7bjeIW/6DQBH1B4c=";
      });
    };
  };
}
