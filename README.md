# NixOS VM Configuration

Universal NixOS configuration for virtual machines. Works on **any VM platform**
(Parallels, UTM, QEMU/KVM, VirtualBox, VMware) on both **aarch64** and **x86_64**.

## Quick Install

1. Create a VM with **UEFI/EFI enabled** and boot the [NixOS ISO](https://nixos.org/download/)
2. Once booted, run:

```bash
curl -sL https://raw.githubusercontent.com/htelsiz/nixos-vm/main/install.sh | sudo bash
```

The installer will prompt you for:
- **Disk** to install to
- **Hostname** (default: `nixvm`)
- **Username** (default: `ht`)
- **Password**

## VM Setup Notes

| Platform | Architecture | EFI Setting |
|----------|-------------|-------------|
| UTM | aarch64 | Enabled by default |
| Parallels | aarch64 | Enabled by default |
| QEMU/KVM | x86_64 or aarch64 | Use OVMF/UEFI firmware |
| VirtualBox | x86_64 | Settings > System > Enable EFI |
| VMware | x86_64 | VM Settings > Firmware: UEFI |

## After Install

Rebuild after editing config:

```bash
sudo nixos-rebuild switch --flake /etc/nixos
```

Edit settings (hostname/username/arch):

```bash
sudo vim /etc/nixos/settings.nix
```

## What's Included

- KDE Plasma 6 desktop (Wayland)
- Zsh with Oh My Zsh
- Git, Docker, Tailscale
- Firefox, 1Password
- Home Manager for user config
- PipeWire audio
- OpenSSH

## Customizing

- **System packages**: `configuration.nix` > `environment.systemPackages`
- **User packages**: `home.nix` > `home.packages`
- **Services**: `configuration.nix` > `services.*`
- **Disk layout**: `disko-config.nix`
