#!/usr/bin/env bash
# NixOS VM Auto-Install Script for phoenix-vm (UTM/Parallels on Apple Silicon)
# Run: curl -sL https://raw.githubusercontent.com/htelsiz/nixos-vm/main/install.sh | sudo bash

set -euo pipefail

echo "=== NixOS phoenix-vm Auto-Installation ==="

# Must be root
[[ $EUID -eq 0 ]] || exec sudo bash "$0" "$@"

# Find disk
DISK=$(lsblk -dpno NAME | grep -E 'vda|sda' | head -1)
[[ -n "$DISK" ]] || { echo "No disk found"; lsblk; exit 1; }
echo "Using disk: $DISK"

PART1="${DISK}1"
PART2="${DISK}2"

# Unmount if mounted
umount -R /mnt 2>/dev/null || true

# Partition
echo "[1/6] Partitioning..."
wipefs -af "$DISK"
parted "$DISK" --script mklabel gpt
parted "$DISK" --script mkpart ESP fat32 1MiB 512MiB
parted "$DISK" --script set 1 esp on
parted "$DISK" --script mkpart primary 512MiB 100%

# Refresh partition table
partprobe "$DISK"
sleep 2

# Format
echo "[2/6] Formatting..."
mkfs.fat -F32 -n BOOT "$PART1"
mkfs.ext4 -F -L nixos "$PART2"

# Refresh again
partprobe "$DISK"
sleep 1

# Mount using device paths (not labels)
echo "[3/6] Mounting..."
mount "$PART2" /mnt
mkdir -p /mnt/boot
mount "$PART1" /mnt/boot

# Clone config
echo "[4/6] Cloning nixos-vm config..."
mkdir -p /mnt/etc
nix-shell -p git --run "git clone https://github.com/htelsiz/nixos-vm /mnt/etc/nixos"

# Generate hardware config
echo "[5/6] Generating hardware config..."
nixos-generate-config --root /mnt --show-hardware-config > /mnt/etc/nixos/hardware-configuration.nix

# Install with flake
echo "[6/6] Installing NixOS with phoenix-vm flake..."
nixos-install --flake /mnt/etc/nixos#phoenix-vm --no-root-passwd

echo ""
echo "=== Done! ==="
echo "Reboot and login as 'ht' with password 'changeme'"
echo "Then change your password with: passwd"
