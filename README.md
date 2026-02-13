# NixOS VM Configuration

Minimal NixOS configuration for running in UTM/Parallels on Apple Silicon (aarch64-linux).

## Quick Install

Boot the NixOS ISO in your VM, then run:

```bash
curl -sL https://raw.githubusercontent.com/htelsiz/nixos-vm/main/install.sh | sudo bash
```

This will partition, format, and install NixOS with KDE Plasma 6.

## Manual Install

```bash
# Clone this repo
sudo git clone https://github.com/htelsiz/nixos-vm /etc/nixos

# Generate hardware config for your VM
sudo nixos-generate-config --show-hardware-config > /etc/nixos/hardware-configuration.nix

# Install/rebuild
sudo nixos-rebuild switch --flake /etc/nixos#phoenix-vm
```

## Default Credentials

- User: `ht`
- Password: `changeme` (change after first login!)

## What's Included

- KDE Plasma 6 desktop
- Zsh with Oh My Zsh
- Git, Docker, Tailscale
- Firefox, 1Password
- Home Manager for user config
