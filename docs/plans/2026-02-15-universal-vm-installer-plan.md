# Universal NixOS VM Installer — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Repurpose the nixos-vm repo into a universal NixOS VM installer with disko-based declarative partitioning, dual-arch support, and an interactive installer script.

**Architecture:** A Nix flake with disko + home-manager inputs exposes a `mkHost` function parameterized by `{ system, hostname, username }`. A `settings.nix` file (committed with defaults, overwritten by the installer) drives the config. The interactive `install.sh` detects arch, prompts for disk/hostname/username, runs disko to partition, then `nixos-install` to build. No `hardware-configuration.nix` — broad VM kernel modules are included directly.

**Tech Stack:** NixOS flakes, disko (nix-community/disko), home-manager, bash

**Design simplifications from disko API research:**
- No `disk-device.nix` needed — disko CLI accepts `--arg disks '[ "/dev/sdX" ]'`
- No `hardware-configuration.nix` needed — broad VM kernel modules in `configuration.nix` cover all hypervisors
- No `nixos-generate-config` step — eliminates the disko/hardware-config `fileSystems` conflict entirely
- Config named by hostname (not `nixvm-aarch64`) — `nixos-rebuild switch --flake /etc/nixos` just works

---

### Task 1: Create `settings.nix`

**Files:**
- Create: `settings.nix`

**Step 1: Write settings.nix**

```nix
# settings.nix — defaults, overwritten by install.sh at install time
{
  hostname = "nixvm";
  username = "ht";
  system = "aarch64-linux";
}
```

**Step 2: Commit**

```bash
git add settings.nix
git commit -m "feat: add settings.nix with install-time defaults"
```

---

### Task 2: Create `disko-config.nix`

**Files:**
- Create: `disko-config.nix`

**Step 1: Write disko-config.nix**

```nix
# disko-config.nix — declarative disk layout for any VM platform
# Device is overridden at install time via: --arg disks '[ "/dev/sdX" ]'
{ disks ? [ "/dev/vda" ], ... }: {
  disko.devices = {
    disk = {
      main = {
        type = "disk";
        device = builtins.elemAt disks 0;
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              size = "512M";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [ "umask=0077" ];
              };
            };
            root = {
              size = "100%";
              content = {
                type = "filesystem";
                format = "ext4";
                mountpoint = "/";
              };
            };
          };
        };
      };
    };
  };
}
```

**Step 2: Commit**

```bash
git add disko-config.nix
git commit -m "feat: add disko-config.nix with GPT + ESP + ext4 layout"
```

---

### Task 3: Rewrite `flake.nix`

**Files:**
- Modify: `flake.nix`

**Step 1: Rewrite flake.nix**

```nix
{
  description = "Universal NixOS VM configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, disko, home-manager, ... }@inputs:
    let
      settings = import ./settings.nix;

      mkHost = { system, hostname, username }: nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs hostname username; };
        modules = [
          disko.nixosModules.disko
          ./disko-config.nix
          ./configuration.nix

          home-manager.nixosModules.home-manager
          {
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              users.${username} = import ./home.nix;
              extraSpecialArgs = { inherit username; };
            };
          }
        ];
      };
    in
    {
      nixosConfigurations.${settings.hostname} = mkHost {
        inherit (settings) system hostname username;
      };
    };
}
```

**Step 2: Update flake.lock**

```bash
nix flake update
```

If nix is not available on the dev machine, skip this — the lock will be generated at install time.

**Step 3: Commit**

```bash
git add flake.nix flake.lock
git commit -m "feat: rewrite flake with disko, dual-arch mkHost, settings.nix"
```

---

### Task 4: Update `configuration.nix`

**Files:**
- Modify: `configuration.nix`

**Step 1: Rewrite configuration.nix**

```nix
{ pkgs, lib, hostname, username, ... }:

{
  # Allow unfree packages (1Password, etc.)
  nixpkgs.config.allowUnfree = true;

  # Hostname (from settings.nix via specialArgs)
  networking.hostName = hostname;

  # Boot (GRUB EFI — efiInstallAsRemovable works across all VM platforms)
  boot = {
    loader.grub = {
      enable = true;
      device = "nodev";
      efiSupport = true;
      efiInstallAsRemovable = true;
    };
    loader.efi.canTouchEfiVariables = false;
    tmp.useTmpfs = true;

    # Broad VM kernel module support (covers all hypervisors)
    initrd.availableKernelModules = [
      "xhci_pci" "virtio_pci" "virtio_scsi" "virtio_blk"  # QEMU/KVM/UTM
      "ahci" "sd_mod" "sr_mod" "usbhid"                    # VirtualBox/VMware/general
      "hv_vmbus" "hv_storvsc"                               # Hyper-V
    ];
  };

  # Timezone & Locale
  time.timeZone = "America/Chicago";
  i18n.defaultLocale = "en_US.UTF-8";

  # Nix settings
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # User (from settings.nix via specialArgs)
  users.users.${username} = {
    isNormalUser = true;
    description = username;
    shell = pkgs.zsh;
    extraGroups = [ "networkmanager" "wheel" "docker" "libvirtd" "video" ];
    initialPassword = "changeme";
  };

  # Passwordless sudo for wheel
  security.sudo.wheelNeedsPassword = false;

  # Desktop - KDE Plasma 6
  services.desktopManager.plasma6.enable = true;
  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
  };

  # Networking
  networking.networkmanager.enable = true;
  services.openssh.enable = true;
  services.tailscale.enable = true;

  # Audio - PipeWire
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
  };

  # Programs
  programs = {
    zsh = {
      enable = true;
      enableCompletion = true;
      autosuggestions.enable = true;
      syntaxHighlighting.enable = true;
    };
    firefox.enable = true;
    git.enable = true;
    direnv.enable = true;
    _1password.enable = true;
    _1password-gui = {
      enable = true;
      polkitPolicyOwners = [ username ];
    };
  };

  # Packages
  environment.systemPackages = with pkgs; [
    vim
    git
    curl
    wget
    htop
    tmux
    ripgrep
    fd
    jq
    unzip
    tree
  ];

  # Virtualization
  virtualisation.docker.enable = true;

  # Power management
  powerManagement.cpuFreqGovernor = lib.mkDefault "ondemand";

  system.stateVersion = "24.11";
}
```

Changes from original:
- Function args: `{ pkgs, lib, hostname, username, ... }` (receives specialArgs)
- `networking.hostName = hostname;` (was `"phoenix-vm"`)
- `users.users.${username}` (was `users.users.ht`)
- `polkitPolicyOwners = [ username ];` (was `[ "ht" ]`)
- Added `boot.initrd.availableKernelModules` with broad VM module support
- Removed `fileSystems` and `swapDevices` (disko handles these)

**Step 2: Commit**

```bash
git add configuration.nix
git commit -m "feat: parameterize config with hostname/username, add broad VM modules"
```

---

### Task 5: Update `home.nix`

**Files:**
- Modify: `home.nix`

**Step 1: Rewrite home.nix**

```nix
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
    userName = username;
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
```

Changes from original:
- Function args: `{ pkgs, username, ... }` (receives extraSpecialArgs)
- `home.username = username;` (was `"ht"`)
- `home.homeDirectory = "/home/${username}";` (was `"/home/ht"`)
- `userName = username;` (was `"ht"`)
- Rebuild aliases use `--flake /etc/nixos` (no `#name` — matches hostname automatically)

**Step 2: Commit**

```bash
git add home.nix
git commit -m "feat: parameterize home.nix with username from specialArgs"
```

---

### Task 6: Delete `hardware-configuration.nix`

**Files:**
- Delete: `hardware-configuration.nix`

**Step 1: Delete the file**

```bash
git rm hardware-configuration.nix
```

**Step 2: Commit**

```bash
git commit -m "chore: remove hardware-configuration.nix (disko + broad VM modules replace it)"
```

---

### Task 7: Rewrite `install.sh`

**Files:**
- Modify: `install.sh`

**Step 1: Rewrite install.sh**

```bash
#!/usr/bin/env bash
# Universal NixOS VM Installer
# Works on: Parallels, UTM, QEMU/KVM, VirtualBox, VMware
# Requires: Boot NixOS ISO in a UEFI-enabled VM, then run this script.

set -euo pipefail

REPO_URL="https://github.com/htelsiz/nixos-vm"
TMPDIR="/tmp/nixos-vm"

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

info()  { echo -e "${CYAN}::${NC} $*"; }
warn()  { echo -e "${YELLOW}!!${NC} $*"; }
error() { echo -e "${RED}ERROR:${NC} $*" >&2; exit 1; }
ok()    { echo -e "${GREEN}OK:${NC} $*"; }

# --- Header ---
echo ""
echo -e "${BOLD}================================${NC}"
echo -e "${BOLD}   NixOS VM Installer${NC}"
echo -e "${BOLD}================================${NC}"
echo ""

# --- Prerequisites ---
[[ $EUID -eq 0 ]] || error "Must run as root: sudo bash install.sh"

info "Checking network..."
ping -c 1 -W 5 github.com &>/dev/null || error "No network. Configure networking first (e.g., nmtui)."
ok "Network available"

# --- Architecture ---
ARCH=$(uname -m)
case "$ARCH" in
  aarch64) SYSTEM="aarch64-linux" ;;
  x86_64)  SYSTEM="x86_64-linux" ;;
  *)       error "Unsupported architecture: $ARCH" ;;
esac
info "Architecture: $SYSTEM"

# --- EFI Check ---
if [[ ! -d /sys/firmware/efi/efivars ]]; then
  error "BIOS boot detected. This installer requires UEFI.
       Enable EFI/UEFI in your VM settings and boot the ISO again."
fi
ok "EFI boot confirmed"

# --- Disk Selection ---
echo ""
info "Available disks:"
echo ""

mapfile -t DISKS < <(lsblk -dnpo NAME,SIZE,TYPE,RM,RO \
  | awk '$3 == "disk" && $4 == "0" && $5 == "0" { print $1 }')

if [[ ${#DISKS[@]} -eq 0 ]]; then
  error "No suitable disks found. Run 'lsblk' to inspect."
fi

for i in "${!DISKS[@]}"; do
  SIZE=$(lsblk -dnpo SIZE "${DISKS[$i]}" | tr -d ' ')
  echo "  $((i + 1))) ${DISKS[$i]}  ($SIZE)"
done
echo ""

read -rp "Select disk [1]: " DISK_CHOICE
DISK_CHOICE="${DISK_CHOICE:-1}"

if ! [[ "$DISK_CHOICE" =~ ^[0-9]+$ ]] || (( DISK_CHOICE < 1 || DISK_CHOICE > ${#DISKS[@]} )); then
  error "Invalid selection: $DISK_CHOICE"
fi

DISK="${DISKS[$((DISK_CHOICE - 1))]}"
DISK_SIZE=$(lsblk -dnpo SIZE "$DISK" | tr -d ' ')

echo ""
echo -e "  ${BOLD}Selected:${NC} $DISK ($DISK_SIZE)"
echo ""
warn "THIS WILL ERASE ALL DATA on $DISK ($DISK_SIZE)"
read -rp "Continue? [y/N]: " CONFIRM
[[ "$CONFIRM" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 0; }

# --- User Configuration ---
echo ""
read -rp "Hostname [nixvm]: " INPUT_HOSTNAME
HOSTNAME="${INPUT_HOSTNAME:-nixvm}"

read -rp "Username [ht]: " INPUT_USERNAME
USERNAME="${INPUT_USERNAME:-ht}"

echo ""
echo -e "  ${BOLD}Summary:${NC}"
echo "    Disk:     $DISK ($DISK_SIZE)"
echo "    Arch:     $SYSTEM"
echo "    Hostname: $HOSTNAME"
echo "    Username: $USERNAME"
echo ""

# --- Clone Config ---
info "[1/5] Cloning configuration..."
rm -rf "$TMPDIR"
nix-shell -p git --run "git clone $REPO_URL $TMPDIR"

# --- Write Settings ---
info "[2/5] Writing settings..."
cat > "$TMPDIR/settings.nix" <<EOF
{
  hostname = "$HOSTNAME";
  username = "$USERNAME";
  system = "$SYSTEM";
}
EOF

# --- Partition & Format ---
info "[3/5] Partitioning $DISK with disko..."
nix --experimental-features "nix-command flakes" run github:nix-community/disko -- \
  --mode destroy,format,mount \
  --arg disks "[ \"$DISK\" ]" \
  "$TMPDIR/disko-config.nix"
ok "Disk partitioned and mounted at /mnt"

# --- Install NixOS ---
info "[4/5] Installing NixOS (this will take a while)..."
mkdir -p /mnt/etc
cp -a "$TMPDIR" /mnt/etc/nixos
nixos-install --flake "/mnt/etc/nixos#$HOSTNAME" --no-root-passwd

# --- Set Password ---
info "[5/5] Set password for '$USERNAME':"
nixos-enter --root /mnt -c "passwd $USERNAME"

# --- Done ---
echo ""
echo -e "${GREEN}${BOLD}================================${NC}"
echo -e "${GREEN}${BOLD}   Installation complete!${NC}"
echo -e "${GREEN}${BOLD}================================${NC}"
echo ""
echo "  Reboot and log in as '$USERNAME'"
echo "  Default password (if you skipped above): changeme"
echo ""
echo "  After login, rebuild with:"
echo "    sudo nixos-rebuild switch --flake /etc/nixos"
echo ""
```

**Step 2: Make executable**

```bash
chmod +x install.sh
```

**Step 3: Lint with shellcheck (if available)**

```bash
shellcheck install.sh
```

Expected: No errors (warnings about `read -r` already handled with `-r` flag).

**Step 4: Commit**

```bash
git add install.sh
git commit -m "feat: rewrite install.sh as interactive universal VM installer"
```

---

### Task 8: Update `README.md`

**Files:**
- Modify: `README.md`

**Step 1: Rewrite README.md**

```markdown
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

- **System packages**: `configuration.nix` → `environment.systemPackages`
- **User packages**: `home.nix` → `home.packages`
- **Services**: `configuration.nix` → `services.*`
- **Disk layout**: `disko-config.nix`
```

**Step 2: Commit**

```bash
git add README.md
git commit -m "docs: update README for universal VM installer"
```

---

### Task 9: Verify flake evaluates

**Step 1: Check nix is available**

```bash
nix --version
```

If nix is not installed, skip this task — verification will happen at install time.

**Step 2: Update flake lock**

```bash
nix flake update
```

**Step 3: Check flake**

```bash
nix flake check
```

Expected: No errors.

**Step 4: Dry-run build**

```bash
nix build .#nixosConfigurations.nixvm.config.system.build.toplevel --dry-run
```

Expected: Shows derivations to build without errors.

**Step 5: Commit lock if updated**

```bash
git add flake.lock
git commit -m "chore: update flake.lock with disko input"
```

---

### Task 10: Final commit — squash or verify clean history

**Step 1: Verify all files are committed**

```bash
git status
```

Expected: Clean working tree.

**Step 2: Verify file structure**

```bash
ls -la
```

Expected files:
- `flake.nix`
- `flake.lock`
- `configuration.nix`
- `home.nix`
- `disko-config.nix`
- `settings.nix`
- `install.sh` (executable)
- `README.md`
- `docs/plans/` (design + plan docs)

Expected ABSENT:
- `hardware-configuration.nix` (deleted)
