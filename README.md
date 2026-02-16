# NixOS VM Configuration

Universal NixOS configuration for virtual machines. Works on **any VM platform**
(Parallels, UTM, QEMU/KVM, VirtualBox, VMware) on both **aarch64** and **x86_64**.

Full desktop environment with KDE Plasma 6, AI tools, dev tools, gaming, and Catppuccin Mocha theming.

## Quick Install

1. Create a VM with **UEFI/EFI enabled** and boot the [NixOS minimal ISO](https://nixos.org/download/#nixos-iso)
2. Once booted, run:

```bash
curl -sL https://raw.githubusercontent.com/htelsiz/nixos-vm/main/install.sh | sudo bash
```

The installer auto-detects your architecture and prompts for:
- **Disk** to install to
- **Hostname** (default: `nixvm`)
- **Username** (default: `ht`)
- **Password**

---

## Mac Setup (Apple Silicon)

### Option A: UTM (Recommended, free)

1. Download [UTM](https://mac.getutm.app/) from the website or `brew install --cask utm`
2. Download the [NixOS minimal ISO (aarch64)](https://channels.nixos.org/nixos-25.05/latest-nixos-minimal-aarch64-linux.iso)
3. Create a new VM in UTM:
   - **Type**: Virtualize > Linux
   - **Boot ISO**: Select the NixOS ISO
   - **Memory**: 8 GB minimum (16 GB recommended for building from source)
   - **CPU**: 4+ cores
   - **Disk**: 80 GB minimum (120 GB recommended)
   - **Network**: Shared Network
4. Boot the VM and run the install command above
5. After install, shut down, remove the ISO from the CD/DVD drive, and boot again

### Option B: Parallels

1. Create a new VM: **Install Windows or another OS from a DVD or image file**
2. Select the NixOS aarch64 ISO
3. Choose **Other Linux** as the OS type
4. Settings:
   - **CPU & Memory**: 4+ cores, 8+ GB RAM
   - **Hard Disk**: 80+ GB
   - EFI is enabled by default on Apple Silicon
5. Boot and run the install command

### Notes for Apple Silicon

- Architecture is `aarch64-linux` (auto-detected by the installer)
- Some packages are **x86_64-only** and will be skipped: Steam, Discord, Spotify, Cursor IDE, Zoom, Teams, Lutris, MangoHud
- All AI tools (Claude Desktop, Claude Code, codex, gemini, goose, etc.) work on aarch64
- All dev tools (Rust, Go, Node, Python, Docker, Terraform, etc.) work on aarch64

---

## Mac Setup (Intel)

### Option A: UTM

Same as Apple Silicon above but use the [x86_64 ISO](https://channels.nixos.org/nixos-25.05/latest-nixos-minimal-x86_64-linux.iso) and select **Emulate** > **x86_64** (slower) or **Virtualize** if on Intel Mac.

### Option B: VirtualBox

1. Download [VirtualBox](https://www.virtualbox.org/wiki/Downloads)
2. Create a new VM:
   - **Type**: Linux, **Version**: Other Linux (64-bit)
   - **Memory**: 8+ GB
   - **Hard Disk**: 80+ GB (VDI, dynamically allocated)
3. **Settings > System > Enable EFI** (required)
4. **Settings > Display > Video Memory**: 128 MB
5. Mount the NixOS x86_64 ISO and boot
6. Run the install command

### Option C: VMware Fusion

1. Create a new VM from the NixOS x86_64 ISO
2. Settings:
   - **Processors & Memory**: 4+ cores, 8+ GB RAM
   - **Hard Disk**: 80+ GB
   - **Firmware**: UEFI (in VM Settings > Advanced)
3. Boot and run the install command

### Notes for Intel Mac

- Architecture is `x86_64-linux` (auto-detected)
- All packages are available including Steam, Discord, Spotify, Cursor IDE, gaming tools

---

## Linux Setup (QEMU/KVM)

```bash
# Download NixOS minimal ISO
mkdir -p ~/VMs/isos ~/VMs/images
curl -Lo ~/VMs/isos/nixos-minimal.iso \
  https://channels.nixos.org/nixos-25.05/latest-nixos-minimal-x86_64-linux.iso

# Create disk and VM
qemu-img create -f qcow2 ~/VMs/images/nixvm.qcow2 120G
virt-install \
  --name nixvm \
  --ram 16384 --vcpus 8 \
  --disk path=$HOME/VMs/images/nixvm.qcow2,format=qcow2,bus=virtio \
  --cdrom $HOME/VMs/isos/nixos-minimal.iso \
  --os-variant nixos-unstable \
  --network bridge=virbr0,model=virtio \
  --graphics spice --video qxl \
  --boot uefi --noautoconsole

# Connect to the VM
virt-viewer nixvm
# or
virt-manager
```

Then run the install command inside the VM.

---

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

### Desktop
- KDE Plasma 6 (Wayland) with wobbly windows, blur, magic lamp, and more
- Stylix system-wide Catppuccin Mocha theming (Iosevka fonts, dark cursors)
- Ghostty terminal with custom keybinds
- Zsh + Starship powerline prompt

### AI Tools
- **Claude Desktop** (GUI) + **Claude Code** (CLI)
- codex, gemini-cli, goose, aider, amp, cursor-agent
- mods, glow, ck, pi, qwen-code, mistral-vibe, forge, jules, and more

### Dev Tools
- Rust (fenix nightly toolchain + rust-analyzer)
- Go, Node.js 22, Python 3, uv
- Docker, kubectl, Terraform, GitHub CLI
- Zed, VS Code, Cursor IDE (x86_64 only)
- nh, nix-output-monitor, deadnix, statix, nixfmt

### Desktop Apps
- Brave, Firefox
- Discord, Telegram, Signal (x86_64 only for some)
- Spotify, VLC, OBS Studio
- Obsidian, LibreOffice, KeePassXC, Bitwarden
- GIMP, Inkscape, Blender, Kdenlive, Audacity

### Gaming (x86_64 only)
- Steam, Lutris, Bottles
- MangoHud, Gamemode, ProtonUp-Qt
- Wine + Winetricks

### Audio
- PipeWire with SoX high-quality resampling
- EasyEffects with RNNoise noise suppression
- pavucontrol, helvum

### Services
- Tailscale, OpenSSH, Docker, libvirtd
- CUPS printing

## Customizing

- **System packages**: `configuration.nix` > `environment.systemPackages`
- **User packages/config**: `home.nix`
- **Theme**: `configuration.nix` > `stylix` block
- **Services**: `configuration.nix` > `services.*`
- **Disk layout**: `disko-config.nix`
- **Settings**: `settings.nix` (hostname, username, architecture)
