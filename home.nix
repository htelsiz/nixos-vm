{ pkgs, username, ... }:

{
  home.username = username;
  home.homeDirectory = "/home/${username}";
  home.stateVersion = "24.11";

  programs.home-manager.enable = true;

  # Zsh
  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    oh-my-zsh = {
      enable = true;
      theme = "agnoster";
      plugins = [ "git" "docker" "kubectl" ];
    };
    shellAliases = {
      ll = "ls -la";
      nrb = "sudo nixos-rebuild switch --flake /etc/nixos";
      nrbt = "sudo nixos-rebuild test --flake /etc/nixos";
    };
  };

  # Git
  programs.git = {
    enable = true;
    settings.user.name = username;
  };

  # Packages
  home.packages = with pkgs; [
    neofetch
    bat
    eza
    fzf
    lazygit
  ];
}
