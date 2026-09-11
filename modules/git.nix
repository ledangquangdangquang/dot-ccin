{pkgs, ...}: {
  programs.delta = {
    enable = true;
    enableGitIntegration = true;
  };

  programs.git = {
    enable = true;
    settings = {
      user = {
        name = "ledangquangdangquang";
        email = "quang.ld224113@sis.hust.edu.vn";
      };
      init.defaultBranch = "main";
      credential.helper = "${pkgs.git-credential-manager}/bin/git-credential-manager";
      credential.credentialStore = "secretservice";
      pull.rebase = true;
      push.autoSetupRemote = true;
      core.editor = "nvim";
      core.excludesFile = "~/.config/git/ignore";
      merge.conflictstyle = "diff3";
      diff.colorMoved = "default";
      alias.acp = ''!f() { git add -A && git commit -m "$1" && git push; }; f'';
    };
  };

  home.file.".config/git/ignore".text = ''
    .DS_Store
    *.swp
    .direnv/
    result
  '';

  home.packages = [pkgs.git-credential-manager];

  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    settings."github.com" = {
      IdentityFile = "~/.ssh/id_ed25519";
      User = "git";
    };
  };

  services.ssh-agent.enable = true;
}
