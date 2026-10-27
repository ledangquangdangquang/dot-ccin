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
      Environment = "NEWTAB_PORT=${toString newtabPort} NEWTAB_DIR=${config.home.homeDirectory}/.config/newtab";
      ExecStart = "${pkgs.python3}/bin/python3 ${./newtab-server.py}";
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
      # Keep DNS on WARP Families (modules/warp.nix); Firefox DoH would bypass the filter.
      DNSOverHTTPS = {
        Enabled = false;
        Locked = true;
      };

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
        focus_website = true; # focus page, not urlbar, so Vimium works on new tabs
        background_color = "#1e1e2e";
      };
    };
    profiles.default = {
      settings = {
        "layout.spellcheckDefault" = 0;
        "widget.use-xdg-desktop-portal.file-picker" = 0; # GTK picker instead of GNOME portal (Nautilus)
        "browser.download.useDownloadDir" = false;
        "browser.download.always_ask_before_handling_new_types" = true;
        "browser.startup.homepage" = newtabUrl;
        "browser.startup.page" = 3;
        "browser.sessionstore.resume_from_crash" = true;
        "browser.urlbar.suggest.history" = false;
        "browser.urlbar.suggest.bookmark" = false;
        "browser.urlbar.suggest.topsites" = false;
        "browser.urlbar.suggest.openpage" = false;
        "browser.urlbar.suggest.searches" = false;
        "browser.urlbar.suggest.engines" = false;
        "browser.urlbar.suggest.quickactions" = false;
        "browser.urlbar.quicksuggest.enabled" = false;
        "browser.toolbars.bookmarks.visibility" = "never"; # collapsed = tabs + nav pinned (userChrome.css); Ctrl+Shift+B toggles to auto-hide
        "browser.ctrlTab.sortByRecentlyUsed" = true; # Ctrl+Tab shows tab previews like Alt+Tab
        # Smoothfox "Natural Smooth Scrolling V3" (spring physics, tuned for 100Hz+)
        "apz.overscroll.enabled" = true;
        "general.smoothScroll" = true;
        "general.smoothScroll.msdPhysics.enabled" = true;
        "general.smoothScroll.msdPhysics.continuousMotionMaxDeltaMS" = 12;
        "general.smoothScroll.msdPhysics.motionBeginSpringConstant" = 600;
        "general.smoothScroll.msdPhysics.regularSpringConstant" = 650;
        "general.smoothScroll.msdPhysics.slowdownMinDeltaMS" = 25;
        "general.smoothScroll.msdPhysics.slowdownMinDeltaRatio" = "2";
        "general.smoothScroll.msdPhysics.slowdownSpringConstant" = 250;
        "general.smoothScroll.currentVelocityWeighting" = "1";
        "general.smoothScroll.stopDecelerationWeighting" = "1";
        "mousewheel.default.delta_multiplier_y" = 300;
        "toolkit.legacyUserProfileCustomizations.stylesheets" = true; # load userChrome.css
        # Performance, from Betterfox Fastfox
        "gfx.content.skia-font-cache-size" = 20;
        "content.notify.interval" = 100000;
        "gfx.canvas.accelerated.cache-size" = 512;
        "javascript.options.baselinejit.threshold" = 50;
        "media.cache_readahead_limit" = 3600;
        "media.cache_resume_threshold" = 1800;
        "image.mem.decode_bytes_at_a_time" = 32768;
        "network.buffer.cache.size" = 65535;
        "network.buffer.cache.count" = 48;
        "network.http.max-connections" = 1800;
        "network.http.max-persistent-connections-per-server" = 10;
        "network.http.max-urgent-start-excessive-connections-per-host" = 5;
        "network.http.request.max-start-delay" = 5;
        "network.dnsCacheExpiration" = 3600;
        "browser.sessionstore.interval" = 60000;
        # Less background work: telemetry, studies, local AI models
        "datareporting.policy.dataSubmissionEnabled" = false;
        "datareporting.healthreport.uploadEnabled" = false;
        "datareporting.usage.uploadEnabled" = false;
        "toolkit.telemetry.unified" = false;
        "toolkit.telemetry.enabled" = false;
        "toolkit.telemetry.server" = "data:,";
        "toolkit.telemetry.archive.enabled" = false;
        "toolkit.telemetry.newProfilePing.enabled" = false;
        "toolkit.telemetry.shutdownPingSender.enabled" = false;
        "toolkit.telemetry.updatePing.enabled" = false;
        "toolkit.telemetry.bhrPing.enabled" = false;
        "toolkit.telemetry.firstShutdownPing.enabled" = false;
        "browser.newtabpage.activity-stream.feeds.telemetry" = false;
        "browser.newtabpage.activity-stream.telemetry" = false;
        "app.shield.optoutstudies.enabled" = false;
        "app.normandy.enabled" = false;
        "browser.ml.enable" = false;
        "browser.ml.chat.enabled" = false;
        "browser.ml.linkPreview.enabled" = false;
        "browser.tabs.groups.smart.enabled" = false;
        # Instant fullscreen (no animation)
        "full-screen-api.transition-duration.enter" = "0 0";
        "full-screen-api.transition-duration.leave" = "0 0";
        # Migrated from the old FirefoxCss/user.js
        "gfx.canvas.accelerated.cache-items" = 4096;
        "browser.cache.jsbc_compression_level" = 3;
        "network.http.pacing.requests.enabled" = false;
        "network.ssl_tokens_cache_capacity" = 10240;
        "network.predictor.enabled" = false;
        "network.predictor.enable-prefetch" = false;
        "layout.css.grid-template-masonry-value.enabled" = true;
        "dom.enable_web_task_scheduling" = true;
        "dom.security.sanitizer.enabled" = true;
        "urlclassifier.trackingSkipURLs" = "*.reddit.com, *.twitter.com, *.twimg.com, *.tiktok.com";
        "urlclassifier.features.socialtracking.skipURLs" = "*.instagram.com, *.twitter.com, *.twimg.com";
        "network.cookie.sameSite.noneRequiresSecure" = true;
        "browser.helperApps.deleteTempFileOnExit" = true;
        "security.remote_settings.crlite_filters.enabled" = true;
        "security.pki.crlite_mode" = 2;
        "browser.urlbar.update2.engineAliasRefresh" = true;
        "browser.urlbar.suggest.quicksuggest.sponsored" = false;
        "browser.urlbar.suggest.quicksuggest.nonsponsored" = false;
        "security.insecure_connection_text.enabled" = true;
        "security.insecure_connection_text.pbmode.enabled" = true;
        "dom.security.https_first" = true;
        "dom.security.https_first_schemeless" = true;
        "security.mixed_content.block_display_content" = true;
        "extensions.postDownloadThirdPartyPrompt" = false;
        "media.peerconnection.ice.proxy_only_if_behind_proxy" = true;
        "media.peerconnection.ice.default_address_only" = true;
        "webchannel.allowObject.urlWhitelist" = "";
        "browser.crashReports.unsubmittedCheck.autoSubmit2" = false;
        "dom.private-attribution.submission.enabled" = false;
        "browser.privatebrowsing.vpnpromourl" = "";
        "browser.tabs.tabmanager.enabled" = false;
        "browser.display.focus_ring_on_anything" = true;
        "browser.display.focus_ring_style" = 0;
        "browser.display.focus_ring_width" = 0;
        "layout.css.prefers-color-scheme.content-override" = 2;
        "cookiebanners.service.mode" = 1;
        "cookiebanners.service.mode.privateBrowsing" = 1;
        "full-screen-api.warning.delay" = -1;
        "browser.urlbar.suggest.calculator" = true;
        "browser.urlbar.unitConversion.enabled" = true;
        "browser.newtabpage.activity-stream.feeds.topsites" = false;
        "extensions.pocket.enabled" = false;
        "browser.menu.showViewImageInfo" = true;
        "layout.word_select.eat_space_to_next_word" = false;
        "signon.rememberSignons" = true;
        "reader.color_scheme" = "auto";
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
    };
  };
}
