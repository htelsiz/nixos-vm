{ pkgs, lib, inputs, hostname, username, modulesPath, config, ... }:

let
  isX86 = pkgs.stdenv.hostPlatform.isx86_64;
in
{
  imports = [ (modulesPath + "/profiles/qemu-guest.nix") ];

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # Hostname
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

    # Broad VM kernel module support
    initrd.availableKernelModules = [
      "xhci_pci" "virtio_pci" "virtio_scsi" "virtio_blk"
      "ahci" "sd_mod" "sr_mod" "usbhid"
      "hv_vmbus" "hv_storvsc"
    ];
  };

  # Timezone & Locale
  time.timeZone = "America/Chicago";
  i18n.defaultLocale = "en_US.UTF-8";

  # Nix settings
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # ===========================================================================
  # Stylix - System-Wide Theming (Catppuccin Mocha)
  # ===========================================================================
  stylix = {
    enable = true;
    base16Scheme = "${pkgs.base16-schemes}/share/themes/catppuccin-mocha.yaml";
    polarity = "dark";

    image =
      pkgs.runCommand "catppuccin-wallpaper.png"
        { nativeBuildInputs = [ pkgs.imagemagick ]; }
        ''
          magick -size 3840x2160 xc:'#1e1e2e' $out
        '';

    fonts = {
      monospace = {
        package = pkgs.iosevka-bin;
        name = "Iosevka Term Extended";
      };
      sansSerif = {
        package = pkgs.iosevka-bin;
        name = "Iosevka Extended";
      };
      serif = {
        package = pkgs.iosevka-bin;
        name = "Iosevka Extended";
      };
      emoji = {
        package = pkgs.noto-fonts-color-emoji;
        name = "Noto Color Emoji";
      };
      sizes = {
        applications = 11;
        desktop = 11;
        popups = 11;
        terminal = 12;
      };
    };

    cursor = {
      package = pkgs.catppuccin-cursors.mochaDark;
      name = "catppuccin-mocha-dark-cursors";
      size = 24;
    };

    targets = {
      gtk.enable = true;
      qt.enable = false;
    };
  };

  # Nerd Font Symbols fallback (for Starship, eza icons, etc.)
  fonts.packages = [ pkgs.nerd-fonts.symbols-only ];

  # ===========================================================================
  # User
  # ===========================================================================
  users.users.${username} = {
    isNormalUser = true;
    description = username;
    shell = pkgs.zsh;
    extraGroups = [ "networkmanager" "wheel" "docker" "libvirtd" "video" ];
    initialPassword = "changeme";
  };

  security.sudo.wheelNeedsPassword = false;

  # ===========================================================================
  # Desktop - KDE Plasma 6
  # ===========================================================================
  services = {
    xserver = {
      enable = true;
      xkb = {
        layout = "us";
        variant = "";
      };
    };
    displayManager.sddm = {
      enable = true;
      wayland.enable = true;
    };
    desktopManager.plasma6.enable = true;
    printing.enable = true;

    # SPICE guest agent (clipboard sharing, resolution scaling)
    spice-vdagentd.enable = true;

    # Networking
    openssh.enable = true;
    tailscale.enable = true;
  };

  networking.networkmanager.enable = true;

  # ===========================================================================
  # Environment Variables
  # ===========================================================================
  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    MOZ_ENABLE_WAYLAND = "1";
    XDG_CURRENT_DESKTOP = "KDE";
  };

  environment.etc."brave-flags.conf".text = ''
    --enable-features=WebRTCPipeWireCapturer
    --ozone-platform-hint=auto
  '';
  environment.etc."chromium-flags.conf".text = ''
    --enable-features=WebRTCPipeWireCapturer
    --ozone-platform-hint=auto
  '';

  # ===========================================================================
  # Audio - PipeWire (full config)
  # ===========================================================================
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = isX86;
    pulse.enable = true;

    # High-quality SoX resampling
    extraConfig.pipewire = {
      "10-resampler" = {
        "context.properties" = {
          "resample.quality" = 10;
        };
      };
    };
  };

  # ===========================================================================
  # Programs
  # ===========================================================================
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
    chromium.enablePlasmaBrowserIntegration = true;
    steam.enable = isX86;
    gamemode.enable = true;
    virt-manager.enable = true;
  };

  # ===========================================================================
  # Packages
  # ===========================================================================
  environment.systemPackages = with pkgs; [
    # === Core Tools ===
    vim
    git
    wget
    curl
    htop
    btop
    neofetch
    unzip
    ripgrep
    fd
    fzf
    jq
    yq
    bat
    eza
    zoxide
    dust
    duf
    procs
    sd
    tokei
    hyperfine
    tldr
    mosh
    tree
    file
    qrencode
    nix-tree
    nix-diff

    # === Nix Workflow ===
    nh
    nix-output-monitor
    nvd
    nix-index
    comma

    # === Nix Linting & Formatting ===
    deadnix
    statix
    nixfmt

    # === Code Editors ===
    zed-editor

    # === Languages & Runtimes ===
    nodejs_22
    corepack_22
    python3
    python3Packages.pip
    go
    (pkgs.fenix.stable.withComponents [
      "cargo"
      "clippy"
      "rust-src"
      "rust-std"
      "rustc"
      "rustfmt"
    ])
    pkgs.fenix.rust-analyzer
    uv

    # === Cloud CLIs ===
    gh
    azure-cli
    google-cloud-sdk
    gam
    nodePackages.vercel

    # === Containers & Kubernetes ===
    docker-compose
    lazydocker
    lazygit
    k9s
    kubectl
    terraform

    # === AI Tools (nixpkgs) ===
    claude-code
    inputs.claude-desktop-linux.packages.${pkgs.stdenv.hostPlatform.system}.default
    aider-chat
    mods
    glow

    # === AI Tools (llm-agents.nix) ===
    llm-agents.codex
    llm-agents.gemini-cli
    llm-agents.goose-cli
    llm-agents.crush
    llm-agents.copilot-cli
    llm-agents.opencode
    llm-agents.coderabbit-cli
    llm-agents.ck
    llm-agents.amp
    llm-agents.jules
    llm-agents.qwen-code
    llm-agents.mistral-vibe
    llm-agents.cursor-agent
    llm-agents.droid
    llm-agents.pi
    llm-agents.forge
    llm-agents.ccusage
    llm-agents.ccstatusline

    # === System Integration ===
    bluez
    kdePackages.ksshaskpass

    # === Fonts ===
    nerd-fonts.fira-code
    nerd-fonts.jetbrains-mono
    nerd-fonts.meslo-lg
    nerd-fonts.iosevka

    # === Terminal ===
    ghostty

    # === Clipboard & Screenshots ===
    wl-clipboard
    xclip
    libnotify
    flameshot

    # === Web Browsers ===
    brave

    # === Code Editors (GUI) ===
    vscode

    # === Communication ===
    telegram-desktop
    signal-desktop

    # === Media ===
    vlc

    # === Productivity ===
    obsidian
    libreoffice
    qbittorrent

    # === Security ===
    keepassxc
    bitwarden-desktop

    # === Crypto ===
    electrum

    # === Creative ===
    obs-studio
    gimp
    inkscape
    blender
    kdePackages.kdenlive
    audacity

    # === System Utilities ===
    timeshift
    gparted
    filezilla
    remmina

    # === Audio Tools ===
    pavucontrol
    helvum

    # === Gaming (arch-independent) ===
    kdotool
  ]
  ++ lib.optionals isX86 [
    # === x86_64-only packages ===
    code-cursor
    discord
    vesktop
    zoom-us
    teams-for-linux
    spotify
    ledger-live-desktop
    monero-gui

    # Gaming
    lutris
    protonup-qt
    mangohud
    bottles
    wineWowPackages.stable
    winetricks
  ];

  # ===========================================================================
  # Virtualization
  # ===========================================================================
  virtualisation.docker.enable = true;
  virtualisation.libvirtd.enable = true;

  # ===========================================================================
  # Hardware
  # ===========================================================================
  hardware.bluetooth.enable = true;

  # Power management
  powerManagement.cpuFreqGovernor = lib.mkDefault "ondemand";

  system.stateVersion = "24.11";
}
