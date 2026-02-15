#!/usr/bin/env bash
# Universal NixOS VM Installer
# Works on: Parallels, UTM, QEMU/KVM, VirtualBox, VMware
# Requires: Boot NixOS ISO in a UEFI-enabled VM, then run this script.

set -euo pipefail

REPO_URL="https://github.com/htelsiz/nixos-vm"
CLONE_DIR="/tmp/nixos-vm"

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
[[ "$HOSTNAME" =~ ^[a-zA-Z][a-zA-Z0-9-]*$ ]] || error "Invalid hostname: '$HOSTNAME' (letters, digits, hyphens only)"

read -rp "Username [ht]: " INPUT_USERNAME
USERNAME="${INPUT_USERNAME:-ht}"
[[ "$USERNAME" =~ ^[a-z_][a-z0-9_-]*$ ]] || error "Invalid username: '$USERNAME' (lowercase letters, digits, underscores, hyphens only)"

echo ""
echo -e "  ${BOLD}Summary:${NC}"
echo "    Disk:     $DISK ($DISK_SIZE)"
echo "    Arch:     $SYSTEM"
echo "    Hostname: $HOSTNAME"
echo "    Username: $USERNAME"
echo ""

# --- Clone Config ---
info "[1/5] Cloning configuration..."
rm -rf "$CLONE_DIR"
nix-shell -p git --run "git clone $REPO_URL $CLONE_DIR"

# --- Write Settings ---
info "[2/5] Writing settings..."
cat > "$CLONE_DIR/settings.nix" <<EOF
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
  "$CLONE_DIR/disko-config.nix"
ok "Disk partitioned and mounted at /mnt"

# --- Install NixOS ---
info "[4/5] Installing NixOS (this will take a while)..."
mkdir -p /mnt/etc
cp -a "$CLONE_DIR" /mnt/etc/nixos
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
