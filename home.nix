{ pkgs, lib, username, inputs, ... }:

{
  home.username = username;
  home.homeDirectory = "/home/${username}";
  home.stateVersion = "24.11";

  # Disable Stylix Qt/KDE theming — KDE Plasma 6 manages its own theming
  stylix.targets.qt.enable = false;
  stylix.targets.kde.enable = false;

  # ===========================================================================
  # Theme Packages
  # ===========================================================================
  home.packages = with pkgs; [
    # Color schemes
    (catppuccin-kde.override {
      flavour = [ "mocha" ];
      accents = [ "lavender" ];
    })
    dracula-theme
    nordic

    # Icon themes
    tela-icon-theme
    colloid-icon-theme
    whitesur-icon-theme

    # Cursor themes
    catppuccin-cursors.mochaDark
    bibata-cursors

    # XDG Portal
    kdePackages.xdg-desktop-portal-kde
  ];

  # ===========================================================================
  # Session Configuration
  # ===========================================================================
  home.sessionPath = [ "$HOME/.npm-global/bin" ];

  home.shellAliases = {
    virt-manager = "GDK_BACKEND=x11 virt-manager";
  };

  # ===========================================================================
  # GTK Theming
  # ===========================================================================
  gtk = {
    enable = true;
    gtk2.force = true;
    iconTheme = {
      name = "WhiteSur-dark";
      package = pkgs.whitesur-icon-theme;
    };
  };

  # ===========================================================================
  # Programs
  # ===========================================================================
  programs = {
    home-manager.enable = true;

    # -------------------------------------------------------------------------
    # KDE Plasma (via plasma-manager)
    # -------------------------------------------------------------------------
    plasma = {
      enable = true;
      overrideConfig = false;

      workspace = {
        clickItemTo = "select";
        lookAndFeel = "org.kde.breezedark.desktop";
      };

      kwin = {
        effects = {
          shakeCursor.enable = true;
          translucency.enable = true;
          wobblyWindows.enable = true;
          desktopSwitching.animation = "slide";
          minimization.animation = "magiclamp";
        };
      };

      configFile = {
        kwinrc = {
          Compositing = {
            AnimationSpeed = 2;
            Backend = "OpenGL";
            GLCore = true;
            Enabled = true;
          };
          Plugins = {
            blurEnabled = true;
            contrastEnabled = true;
            glideEnabled = true;
            slideEnabled = true;
            magiclampEnabled = true;
            wobblywindowsEnabled = true;
            sheetEnabled = true;
            scaleEnabled = false;
          };
          "Effect-glide" = {
            GlideDuration = 200;
            GlideInCurve = 7;
            GlideOutCurve = 7;
          };
          "Effect-blur" = {
            BlurStrength = 8;
            NoiseStrength = 3;
          };
          "Effect-wobblywindows" = {
            Stiffness = 4;
            Drag = 3;
            MoveFactor = 15;
          };
        };
      };
    };

    # -------------------------------------------------------------------------
    # Zsh
    # -------------------------------------------------------------------------
    zsh = {
      enable = true;
      enableCompletion = true;
      autosuggestion.enable = true;
      syntaxHighlighting.enable = true;
      completionInit = "autoload -Uz compinit && compinit";

      shellAliases = {
        # Navigation
        ".." = "cd ..";
        "..." = "cd ../..";
        "...." = "cd ../../..";
        "c" = "clear";

        # Modern replacements
        ls = "eza --icons --group-directories-first";
        ll = "eza -lah --icons --group-directories-first --git";
        la = "eza -a --icons --group-directories-first";
        lt = "eza --tree --level=2 --icons --group-directories-first";
        llt = "eza -lah --tree --level=2 --icons --group-directories-first --git";
        cat = "bat";
        df = "duf";
        du = "dust";
        ps = "procs";

        # Git shortcuts
        gs = "git status";
        ga = "git add";
        gc = "git commit";
        gp = "git push";
        gpl = "git pull";
        gl = "git log --oneline --graph --decorate -20";
        gla = "git log --oneline --graph --decorate --all";
        gd = "git diff";
        gds = "git diff --staged";
        gco = "git checkout";
        gcb = "git checkout -b";
        gb = "git branch";
        gst = "git stash";
        gstp = "git stash pop";

        # Quick edits
        e = "$EDITOR";
        se = "sudo $EDITOR";

        # Safety nets
        rm = "rm -i";
        mv = "mv -i";
        cp = "cp -i";

        # Network
        ports = "ss -tulanp";
        myip = "curl -s https://ifconfig.me";
        localip = "ip -brief addr";

        # Misc
        weather = "curl -s 'wttr.in?format=3'";
        path = "echo $PATH | tr ':' '\\n'";
        now = "date '+%Y-%m-%d %H:%M:%S'";

        # NixOS system management (nh)
        nrb = "nh os switch";
        nrbu = "cd /etc/nixos && sudo nix flake update && nh os switch";
        nrbt = "nh os test";
        nrb-raw = "sudo nixos-rebuild switch --flake /etc/nixos";

        # Nix maintenance
        nixgc = "nh clean all --keep 3";

        # Tailscale
        ts = "tailscale status";

        # Service management
        sc = "systemctl";
        scu = "systemctl --user";

        # Quick system info
        temps = "sensors 2>/dev/null | grep -E 'Core|Tctl|edge'";
      };

      initContent = ''
        export EDITOR="vim"

        # Load API keys for AI tools
        [[ -f ~/.config/goose/secrets.env ]] && source ~/.config/goose/secrets.env

        # Dynamic terminal title
        precmd() { print -Pn "\e]0;%~\a" }
        preexec() { print -Pn "\e]0;$1 — %~\a" }

        # Case-insensitive tab completion
        autoload -Uz compinit && compinit
        zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'

        # History
        HISTSIZE=50000
        SAVEHIST=50000
        setopt SHARE_HISTORY
        setopt HIST_IGNORE_DUPS
        setopt HIST_IGNORE_SPACE
        setopt HIST_FIND_NO_DUPS
        setopt INC_APPEND_HISTORY

        # fzf: use fd for file search, bat for preview (Catppuccin colors)
        export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
        export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
        export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --exclude .git'
        export FZF_DEFAULT_OPTS='--height 40% --border --info=inline --color=bg+:#313244,bg:#1e1e2e,spinner:#f5e0dc,hl:#f38ba8,fg:#cdd6f4,header:#f38ba8,info:#cba6f7,pointer:#f5e0dc,marker:#f5e0dc,fg+:#cdd6f4,prompt:#cba6f7,hl+:#f38ba8'
        export FZF_CTRL_T_OPTS="--preview 'bat --color=always --style=numbers --line-range=:500 {}'"
        export FZF_ALT_C_OPTS="--preview 'eza --tree --level=2 --icons --color=always {}'"

        # Quick function: mkcd
        mkcd() { mkdir -p "$1" && cd "$1" }

        # Quick function: extract - universal archive extractor
        extract() {
          if [ -f "$1" ]; then
            case "$1" in
              *.tar.bz2) tar xjf "$1" ;;
              *.tar.gz)  tar xzf "$1" ;;
              *.tar.xz)  tar xJf "$1" ;;
              *.bz2)     bunzip2 "$1" ;;
              *.gz)      gunzip "$1" ;;
              *.tar)     tar xf "$1" ;;
              *.tbz2)    tar xjf "$1" ;;
              *.tgz)     tar xzf "$1" ;;
              *.zip)     unzip "$1" ;;
              *.7z)      7z x "$1" ;;
              *.rar)     unrar x "$1" ;;
              *.xz)      xz -d "$1" ;;
              *)         echo "Cannot extract '$1'" ;;
            esac
          else
            echo "'$1' is not a valid file"
          fi
        }
      '';
    };

    # -------------------------------------------------------------------------
    # Starship Prompt (Catppuccin Mocha Powerline)
    # -------------------------------------------------------------------------
    starship = {
      enable = true;
      enableZshIntegration = true;
      settings = {
        palette = lib.mkForce "catppuccin_mocha";
        palettes.catppuccin_mocha = {
          rosewater = "#f5e0dc";
          flamingo = "#f2cdcd";
          pink = "#f5c2e7";
          mauve = "#cba6f7";
          red = "#f38ba8";
          maroon = "#eba0ac";
          peach = "#fab387";
          yellow = "#f9e2af";
          green = "#a6e3a1";
          teal = "#94e2d5";
          sky = "#89dceb";
          sapphire = "#74c7ec";
          blue = "#89b4fa";
          lavender = "#b4befe";
          text = "#cdd6f4";
          subtext1 = "#bac2de";
          subtext0 = "#a6adc8";
          overlay2 = "#9399b2";
          overlay1 = "#7f849c";
          overlay0 = "#6c7086";
          surface2 = "#585b70";
          surface1 = "#45475a";
          surface0 = "#313244";
          base = "#1e1e2e";
          mantle = "#181825";
          crust = "#11111b";
        };

        format = builtins.concatStringsSep "" [
          "[](lavender)"
          "$os"
          "$username"
          "$hostname"
          "[](bg:blue fg:lavender)"
          "$directory"
          "[](fg:blue bg:surface1)"
          "$git_branch"
          "$git_status"
          "[](fg:surface1 bg:surface0)"
          "$nix_shell"
          "$python"
          "$rust"
          "$golang"
          "$nodejs"
          "$lua"
          "$java"
          "$docker_context"
          "[](fg:surface0 bg:mantle)"
          "$cmd_duration"
          "$time"
          "[](fg:mantle)"
          "$line_break"
          "$character"
        ];

        character = {
          success_symbol = "[❯](bold lavender)";
          error_symbol = "[❯](bold red)";
          vimcmd_symbol = "[❮](bold green)";
        };

        os = {
          disabled = false;
          style = "bg:lavender fg:crust";
          symbols = {
            NixOS = "󱄅 ";
            Macos = "󰀵 ";
            Linux = "󰌽 ";
            Windows = "󰍲 ";
          };
        };

        username = {
          show_always = false;
          style_user = "bg:lavender fg:crust";
          style_root = "bg:red fg:crust";
          format = "[ $user]($style)";
        };

        hostname = {
          ssh_only = true;
          style = "bg:lavender fg:crust";
          format = "[@$hostname ]($style)";
        };

        directory = {
          style = "bg:blue fg:crust";
          format = "[ $path ]($style)[$read_only]($read_only_style)";
          read_only = " 󰌾";
          read_only_style = "bg:blue fg:red";
          truncation_length = 0;
          truncate_to_repo = false;
          substitutions = {
            Documents = "󰈙 ";
            Downloads = " ";
            Music = "󰝚 ";
            Pictures = "󰋩 ";
            Videos = "󰿎 ";
            Projects = " ";
            ".config" = " ";
          };
        };

        git_branch = {
          symbol = "";
          style = "bg:surface1";
          format = "[[ $symbol $branch ](fg:lavender bg:surface1)]($style)";
          truncation_length = 25;
          truncation_symbol = "…";
        };

        git_status = {
          style = "bg:surface1";
          format = "[[($all_status$ahead_behind )](fg:peach bg:surface1)]($style)";
          ahead = "⇡\${count}";
          behind = "⇣\${count}";
          diverged = "⇕⇡\${ahead_count}⇣\${behind_count}";
          conflicted = "=\${count}";
          untracked = "?\${count}";
          stashed = "󰏗\${count}";
          modified = "!\${count}";
          staged = "+\${count}";
          renamed = "»\${count}";
          deleted = "✘\${count}";
        };

        nix_shell = {
          symbol = " ";
          style = "bg:surface0";
          format = "[[ $symbol$state ](fg:sapphire bg:surface0)]($style)";
          impure_msg = "";
          pure_msg = "pure";
          unknown_msg = "";
        };

        python = {
          symbol = " ";
          style = "bg:surface0";
          format = "[[ $symbol($version )](fg:yellow bg:surface0)]($style)";
        };
        rust = {
          symbol = "󱘗 ";
          style = "bg:surface0";
          format = "[[ $symbol($version )](fg:peach bg:surface0)]($style)";
        };
        golang = {
          symbol = " ";
          style = "bg:surface0";
          format = "[[ $symbol($version )(fg:sky bg:surface0)]($style)";
        };
        nodejs = {
          symbol = "󰎙 ";
          style = "bg:surface0";
          format = "[[ $symbol($version )](fg:green bg:surface0)]($style)";
        };
        lua = {
          symbol = "󰢱 ";
          style = "bg:surface0";
          format = "[[ $symbol($version )](fg:blue bg:surface0)]($style)";
        };
        java = {
          symbol = " ";
          style = "bg:surface0";
          format = "[[ $symbol($version )](fg:maroon bg:surface0)]($style)";
        };

        docker_context = {
          symbol = "󰡨 ";
          style = "bg:surface0";
          format = "[[ $symbol$context ](fg:sapphire bg:surface0)]($style)";
          only_with_files = true;
        };

        cmd_duration = {
          min_time = 1000;
          style = "bg:mantle";
          format = "[[  $duration ](fg:yellow bg:mantle)]($style)";
          show_milliseconds = false;
        };

        time = {
          disabled = false;
          style = "bg:mantle";
          format = "[[  $time ](fg:subtext0 bg:mantle)]($style)";
          time_format = "%H:%M";
        };
      };
    };

    # -------------------------------------------------------------------------
    # Direnv
    # -------------------------------------------------------------------------
    direnv = {
      enable = true;
      enableZshIntegration = true;
      nix-direnv.enable = true;
    };

    # -------------------------------------------------------------------------
    # Zoxide
    # -------------------------------------------------------------------------
    zoxide = {
      enable = true;
      enableZshIntegration = true;
    };

    # -------------------------------------------------------------------------
    # Bat
    # -------------------------------------------------------------------------
    bat = {
      enable = true;
      config = {
        style = "numbers,changes,header";
        italic-text = "always";
      };
    };

    # -------------------------------------------------------------------------
    # fzf
    # -------------------------------------------------------------------------
    fzf = {
      enable = true;
      enableZshIntegration = true;
    };

    # -------------------------------------------------------------------------
    # Git
    # -------------------------------------------------------------------------
    git = {
      enable = true;
      settings = {
        user.name = "htelsiz";
        user.email = "hakantelsiz@utexas.edu";
        init.defaultBranch = "main";
        pull.rebase = false;
      };
    };

    # -------------------------------------------------------------------------
    # Ghostty Terminal
    # -------------------------------------------------------------------------
    ghostty = {
      enable = true;
      clearDefaultKeybinds = true;

      settings = {
        adjust-cell-height = "10%";
        background-blur-radius = 60;
        background-opacity = 1.00;
        bold-is-bright = false;
        cursor-style = "bar";
        font-family = [
          "Iosevka Term Extended"
          "Symbols Nerd Font Mono"
        ];
        font-size = 12;
        window-theme = "dark";

        confirm-close-surface = false;
        gtk-single-instance = true;
        mouse-hide-while-typing = true;
        shell-integration = "detect";
        shell-integration-features = "cursor,sudo";
        term = "xterm-256color";
        wait-after-command = false;

        selection-background = "#2d3f76";
        selection-foreground = "#c8d3f5";

        quick-terminal-position = "center";
        unfocused-split-opacity = 0.5;
        window-height = 32;
        window-save-state = "always";
        window-width = 110;

        keybind = [
          "ctrl+shift+c=copy_to_clipboard"
          "ctrl+shift+v=paste_from_clipboard"
          "ctrl+v=paste_from_clipboard"
          "ctrl+shift+plus=increase_font_size:1"
          "ctrl+shift+minus=decrease_font_size:1"
          "ctrl+shift+zero=reset_font_size"
          "ctrl+shift+t=new_tab"

          "alt+s>r=reload_config"
          "alt+s>x=close_surface"
          "alt+s>n=new_window"
          "alt+s>c=new_tab"

          "alt+s>shift+l=next_tab"
          "alt+s>shift+h=previous_tab"
          "alt+s>comma=move_tab:-1"
          "alt+s>period=move_tab:1"
          "alt+s>one=goto_tab:1"
          "alt+s>two=goto_tab:2"
          "alt+s>three=goto_tab:3"
          "alt+s>four=goto_tab:4"
          "alt+s>five=goto_tab:5"
          "alt+s>six=goto_tab:6"
          "alt+s>seven=goto_tab:7"
          "alt+s>eight=goto_tab:8"
          "alt+s>nine=goto_tab:9"

          "alt+s>backslash=new_split:right"
          "alt+s>minus=new_split:down"
          "alt+s>j=goto_split:bottom"
          "alt+s>k=goto_split:top"
          "alt+s>h=goto_split:left"
          "alt+s>l=goto_split:right"
          "alt+s>z=toggle_split_zoom"
          "alt+s>e=equalize_splits"
        ];
      };
    };
  };

  # ===========================================================================
  # EasyEffects (noise suppression)
  # ===========================================================================
  services.easyeffects = {
    enable = true;
    preset = "noise-suppression";
  };

  xdg.configFile."easyeffects/input/noise-suppression.json".text = builtins.toJSON {
    input = {
      blocklist = [ ];
      plugins_order = [ "rnnoise#0" ];
      "rnnoise#0" = {
        bypass = false;
        input-gain = 0.0;
        output-gain = 0.0;
        enable-vad = true;
        vad-thres = 50.0;
        release = 20.0;
        model-name = "";
      };
    };
  };
}
