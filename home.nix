{ pkgs, ... }:

{
  home.username = "ht";
  home.homeDirectory = "/home/ht";
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
      nrb = "sudo nixos-rebuild switch --flake /etc/nixos#phoenix-vm";
      nrbt = "sudo nixos-rebuild test --flake /etc/nixos#phoenix-vm";
    };
  };

  # Git
  programs.git = {
    enable = true;
    userName = "ht";
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
