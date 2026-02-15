{ pkgs, lib, hostname, username, modulesPath, ... }:

{
  imports = [ (modulesPath + "/profiles/qemu-guest.nix") ];

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

  # SPICE guest agent (clipboard sharing, resolution scaling)
  services.spice-vdagentd.enable = true;

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
