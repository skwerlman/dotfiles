# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:
let
  my-py-pkgs = python-packages: with python-packages; [
    python-language-server
  ];
  python3-with-pkgs = pkgs.python3Full.withPackages my-py-pkgs;
in
{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

  nixpkgs.config.packageOverrides = pkgs: rec {
    zeronet = pkgs.lib.overrideDerivation pkgs.zeronet (attrs: rec {
      buildInputs = with pkgs; [ openssl_1_0_2 ] ++ attrs.buildInputs;
      version = "0.6.5-git";
      src = pkgs.fetchFromGitHub {
        owner = "HelloZeroNet";
        repo = "ZeroNet";
        rev = "719df4ac88a06321298711753cad6a79db002f6e";
        sha256 = "0dddvsv0gb3fnxcgfczaxhw0jgy7aza40qbyld4b22jpaggbxi3r";
      };
      postFixup = ''
        makeWrapper "$out/share/zeronet.py" "$out/bin/zeronet" \
          --set PYTHONPATH "$PYTHONPATH" \
          --set PATH ${pkgs.python2Packages.python}/bin \
          --set LD_LIBRARY_PATH ${pkgs.openssl_1_0_2.out}/lib
      '';
    });
    hwloc = pkgs.hwloc.override {
      x11Support = true;
    };
    ckb-next = pkgs.lib.overrideDerivation pkgs.ckb-next (attrs: rec {
      version = "0.4.0";
      src = pkgs.fetchFromGitHub {
        owner = "ckb-next";
        repo = "ckb-next";
        rev = "v0.4.0";
        sha256 = "0q42k6hrb9im0q23f8r0mxcjp7kqcdkmbv6w1gqmnpph0drygwfv";
      };
      patches = (pkgs.lib.filter (x: ! (pkgs.lib.hasSuffix "install-dirs.patch" (builtins.toString x))) attrs.patches) ++ [
        ./patches/ckb-next-install-dirs.patch
      ];
    });
    netdata = pkgs.lib.overrideDerivation pkgs.netdata (attrs: rec {
      buildInputs = [ pkgs.lm_sensors ] ++ attrs.buildInputs;
    });

  };

  nixpkgs.config.allowUnfree = true;

  nix.useSandbox = true;

#  boot.loader.grub.enable = true;
#  boot.loader.grub.enableCryptodisk = true;
#  boot.loader.grub.efiSupport = true;
##  boot.loader.grub.trustedBoot.enable = true;
##  boot.loader.grub.trustedBoot.systemHasTPM = "YES_TPM_is_activated";
#  boot.loader.grub.memtest86.enable = true;
#  boot.loader.grub.useOSProber = true;
#  boot.loader.grub.configurationName = "NixOS GRUB2 Menu";
#  boot.loader.grub.device = "/dev/disk/by-uuid/BE9F-2EC7";

  hardware.cpu.amd.updateMicrocode = true;
  hardware.enableKSM = true;

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  boot.kernelPackages = pkgs.linuxPackages_5_0;
  boot.kernelParams = [
    "amd_iommu=on"
    "hugepagesz=1GB"
    "hugepages=16"
  ];
  boot.blacklistedKernelModules = [ "nvidia" "nouveau" ];
  boot.kernelModules = [ "kvm-amd" "vfio_virqfd" "vfio_pci" "vfio_iommu_type1" "vfio" ];
  boot.extraModprobeConfig = ''
    options vfio-pci ids=10de:1e07,10de:10f7,10de:1ad6,a0de:1ad7 disable_idle_d3=1
    options kvm ignore_msrs=1
  '';
  boot.postBootCommands = ''
    DEVS="0000:0a:00.0 0000:0a:00.1 0000:0a:00.2 0000:0a:00.3"

    for DEV in $DEVS; do
      echo "vfio-pci" > /sys/bus/pci/devices/$DEV/driver_override
    done
    modprobe -i vfio-pci


    # unbind xhci driver from usb-c port
    echo "0000:0a:00.2" > /sys/bus/pci/devices/0000:0a:00.2/driver/unbind
    # bind vfio driver to usb-c port
    echo "0x10de 0x1ad6" > /sys/bus/pci/drivers/vfio-pci/new_id

    touch /dev/shm/looking-glass
    chown skw:kvm /dev/shm/looking-glass
    chmod 660 /dev/shm/looking-glass
 '';

  virtualisation = {
    libvirtd = {
      enable = true;
      qemuOvmf = true;
      qemuVerbatimConfig = ''
        namespaces = []
      '';
    };
  };

  systemd.mounts = [
    # disable mounting hugepages by systemd,
    # it doesn't know about 1G pagesize
    { where = "/dev/hugepages";
      enable = false;
    }
    { where = "/dev/hugepages/hugepages-1048576kB";
      enable  = true;
      what  = "hugetlbfs";
      type  = "hugetlbfs";
      options = "pagesize=1G";
      requiredBy  = [ "basic.target" ];
    }
  ];

  networking.hostName = "tr4";
  networking.networkmanager.enable = true;

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Select internationalisation properties.
  # i18n = {
  #   consoleFont = "Lat2-Terminus16";
  #   consoleKeyMap = "us";
  #   defaultLocale = "en_US.UTF-8";
  # };

  # Set your time zone.
  time.timeZone = "America/New_York";

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    # programming languages
    erlangR21
    beam.packages.erlangR21.elixir_1_8
    python3-with-pkgs

    # git
    git
    git-lfs
    gitAndTools.git-extras
    gitAndTools.gitflow

    # drivers
    ckb-next
    jmtpfs
    libusb
    libusb1

    # useful packages
    atop
    bind
    binutils
    cjdns
    curl
    dmidecode
    ethtool
    gnupg
    graphviz
    hddtemp
    htop
    hwinfo
    hwloc
    iotop
    killall
    lm_sensors
    lshw
    mtr
    numactl
    p7zip
    pciutils
    sysstat
    unzip
    usbutils
    utillinux
    wget
    zip

    # user packages
    atom
    discord
    feh
    filezilla
    firefox-bin
    gparted
    kitty
    looking-glass-client
    mpv
    ncmpcpp
    neofetch
    networkmanagerapplet
    nix-index
    nix-prefetch-github
    nix-prefetch-scripts
    obs-studio
    paprefs
    pavucontrol
    pulseaudio-ctl
    qdirstat
    rofi-unwrapped
    scrot
    steam
    sublime3
    tor-browser-bundle-bin
    transmission-gtk
    vlc
    wineWowPackages.staging
    wireshark-qt
    wxhexeditor
    xorg.xwininfo
    ycmd
    youtube-dl

    # themes
    arc-icon-theme
    arc-theme
    libsForQt512.qtstyleplugins
    lxappearance
    qt5ct

    # misc
    linuxPackages_5_0.nvidia_x11
  ];

  fonts.fonts = with pkgs; [
    noto-fonts
    noto-fonts-cjk
    noto-fonts-emoji
    fira-code
    fira-code-symbols
  ];

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  programs.gnupg.agent = { enable = true; enableSSHSupport = true; };

  # List services that you want to enable:

  boot.initrd.luks.devices = [
    {
      name = "root";
      device = "/dev/disk/by-uuid/f3a72a29-f01f-42d7-a0c2-50fb52f9d4fa";
      preLVM = true;
      allowDiscards = true;
    }
  ];

  # Enable the OpenSSH daemon.
  # services.openssh.enable = true;

  # enable corsair drivers
  hardware.ckb-next.enable = true;

  # # ups support
  # power.ups.enable = true;
  # power.ups.ups = {
  #   "optiups2250b" = {
  #     driver = "usbhid-ups";
  #     port = "auto";
  #   };
  # };

  # Enable CUPS to print documents.
  # services.printing.enable = true;

  # Enable sound.
  sound.enable = true;
  hardware.pulseaudio.enable = true;
  # module-alsa-sink is to enable stereo on the arctis 7 (lets hope it doesnt change card id)
  # module-native-protocol-tcp is to allow qemu to connect without permission issues
  hardware.pulseaudio.extraConfig = ''
    load-module module-alsa-sink device=hw:1,1
    load-module module-alsa-sink device=hw:2,1
    load-module module-native-protocol-tcp auth-ip-acl=127.0.0.1 auth-anonymous=1
  '';
  hardware.pulseaudio.extraClientConf = ''
    autospawn=yes
  '';

  # https://github.com/NixOS/nixpkgs/issues/42433
  programs.dconf.enable = true;

  # Enable the X11 windowing system.
  services.xserver.enable = true;
  services.xserver.layout = "us";

  # enable nvidia driver (requires allowUnfree from above)
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.opengl.driSupport32Bit = true;

  # enable gpu overclocking
  services.xserver.deviceSection = ''
  Option "Coolbits" "28"
  '';

  # configure lightdm
  services.xserver.displayManager.lightdm.greeters.gtk = {
    theme.name = "Arc-Dark";
    theme.package = pkgs.arc-theme;
    iconTheme.name = "Arc";
    iconTheme.package = pkgs.arc-icon-theme;
  };

  # enable i3
  services.xserver.windowManager.i3.enable = true;
  services.xserver.windowManager.i3.package = pkgs.i3-gaps;
  services.xserver.windowManager.i3.extraPackages = with pkgs; [
    rofi
    i3lock
    i3status-rust
    i3blocks-gaps
  ];

  services.xserver.xrandrHeads = [
    {
      output = "DP-0";
      primary = true;
    }
    { output = "HDMI-0"; }
  ];

  services.irqbalance.enable = true;

  services.udev = {
    extraRules = ''
      # This rule is needed for basic functionality of the controller in Steam and keyboard/mouse emulation
      SUBSYSTEM=="usb", ATTRS{idVendor}=="28de", MODE="0666"

      # This rule is necessary for gamepad emulation
      KERNEL=="uinput", MODE="0660", GROUP="users", OPTIONS+="static_node=uinput"

      # Valve HID devices over USB hidraw
      KERNEL=="hidraw*", ATTRS{idVendor}=="28de", MODE="0666"
      # Valve HID devices over bluetooth hidraw
      KERNEL=="hidraw*", KERNELS=="*28DE:*", MODE="0666"

      # DualShock 4 over USB hidraw
      KERNEL=="hidraw*", ATTRS{idVendor}=="054c", ATTRS{idProduct}=="05c4", MODE="0666"
      # DualShock 4 wireless adapter over USB hidraw
      KERNEL=="hidraw*", ATTRS{idVendor}=="054c", ATTRS{idProduct}=="0ba0", MODE="0666"
      # DualShock 4 Slim over USB hidraw
      KERNEL=="hidraw*", ATTRS{idVendor}=="054c", ATTRS{idProduct}=="09cc", MODE="0666"
      # DualShock 4 over bluetooth hidraw
      KERNEL=="hidraw*", KERNELS=="*054C:05C4*", MODE="0666"
      # DualShock 4 Slim over bluetooth hidraw
      KERNEL=="hidraw*", KERNELS=="*054C:09CC*", MODE="0666"

      # Nintendo Switch Pro Controller over USB hidraw
      KERNEL=="hidraw*", ATTRS{idVendor}=="057e", ATTRS{idProduct}=="2009", MODE="0666"
      # Nintendo Switch Pro Controller over bluetooth hidraw
      KERNEL=="hidraw*", KERNELS=="*057E:2009*", MODE="0666"
    '';
  };

  services.mpd = {
    enable = true;
    musicDirectory = "/home/skw/Music";
    playlistDirectory = "/home/skw/Playlists";
    user = "skw";
    group = "users";
    dataDir = "/home/skw/.local/share/mpd/data";
    dbFile = "${config.services.mpd.dataDir}/tag_cache";
    extraConfig = ''
      auto_update "yes"
      audio_output {
        type            "pulse"
        name            "MPD pulseaudio"
        server          "127.0.0.1"
      }
      audio_output {
        type            "fifo"
        name            "my_fifo"
        path            "/tmp/mpd.fifo"
        format          "44100:16:2"
      }
    '';
  };

  services.tor = {
    enable = true;
    client = {
      enable = true;
      socksIsolationOptions = [ "IsolateClientAddr" "IsolateSOCKSAuth" "IsolateClientProtocol" "IsolateDestPort" "IsolateDestAddr" ];
      socksPolicy = "accept 127.0.0.0/24";
      transparentProxy = {
        enable = true;
      };
    };
    controlSocket = {
      enable = true;
    };
  };

  services.zeronet = {
    enable = true;
    tor = true;
    torAlways = true;
    port = 43110;
  };

  services.netdata.enable = true;
  services.netdata.config = {
    global = {
      "history" = "259200";
    };
  };

  services.postgresql = {
    enable = true;
  };

  services.samba = {
    enable = true;
    syncPasswordsByPam = true;
    securityType = "user";
    shares = {
      drives = {
        browsable = "yes";
        comment = "NixOS";
        "guest ok" = "no";
        path = "/mnt";
        "read only" = true;
        "valid users" = "skw";
      };
      home = {
        browsable = "yes";
        comment = "NixOS";
        "guest ok" = "no";
        path = "/home/skw";
        "read only" = true;
        "valid users" = "skw";
      };
    };
  };

  services.compton = {
    enable = true;
    backend = "glx";
    refreshRate = 120;
    vSync = "opengl-swc";
    extraOptions = ''
      paint-on-overlay = true;
      sw-opti = true;
    '';
  };

  # raise limits for proton's esync
  systemd.extraConfig = "DefaultLimitNOFILE=1048576";
  security.pam.loginLimits = [{
    domain = "*";
    type = "hard";
    item = "nofile";
    value = "1048576";
  }];

  programs.zsh.enable = true;

  programs.zsh.ohMyZsh.enable = true;
  programs.zsh.ohMyZsh.theme = "wedisagree";
  programs.zsh.ohMyZsh.plugins = [
    "gitfast"
    "git-prompt"
    "git-flow"
    "git-extras"
    "mix-fast"
  ];

  # Define a user account. Don't forget to set a password with ‘passwd’.
  # users.users.guest = {
  #   isNormalUser = true;
  #   uid = 1000;
  # };
  environment.sessionVariables = {
    QT_QPA_PLATFORMTHEME = [
      "qt5ct"
    ];
  };
  users.users.skw = {
    isNormalUser = true;
    home = "/home/skw";
    extraGroups = [
      "wheel"
      "qemu-libvirtd"
      "audio"
      "video"
      "libvirtd"
      "kvm"
      "networkmanager"
      "zeronet"
    ];
    uid = 1000;
    shell = pkgs.zsh;
  };

  /* skw ALL=(ALL) NOPASSWD: /home/skw/scripts/win10vm.sh */
  security.sudo.extraRules = [
    {
      commands = [
        {
          command = "/home/skw/scripts/win10vm.sh";
          options = [ "NOPASSWD" ];
        }
      ];
      users = [ "skw" ];
      runAs = "root";
    }
    /* {
      commands = [
        {
          command = "/home/skw/scripts/update.sh";
          options = [ "NOPASSWD" ];
        }
      ];
      users = [ "skw" ];
      runAs = "root";
      } */
  ];

  boot.supportedFilesystems = [
    "fuse.dislocker"
    "zfs"
  ];

  fileSystems = {
    "/mnt/code" = {
      device = "/dev/sdd4";
      fsType = "ext4";
      options = [ "nofail" ];
    };
    "/mnt/archroot" = {
      device = "/dev/sdd5";
      fsType = "ext4";
      options = [ "nofail" ];
    };
    "/mnt/old" = {
      device = "/dev/sdb6";
      fsType = "ext4";
      options = [ "nofail" ];
    };
    /* "/mnt/ntfs/tardigrade" = {
      device = "/dev/sda1";
      fsType = "ntfs-3g";
      options = [ "nofail" "dmask=022" "fmask=133" "gid=100" "uid=1000" ];
    }; */
    "/mnt/ntfs/winblows" = {
      device = "/dev/sdb4";
      fsType = "ntfs-3g";
      options = [ "nofail" "errors=remount-ro" ];
    };
    "/mnt/ntfs/warez" = {
      device = "/dev/sde3";
      fsType = "ntfs-3g";
      options = [ "nofail" ];
    };
    "/mnt/ntfs/recording" = {
      device = "/dev/sdc1";
      fsType = "ntfs-3g";
      options = [ "nofail" ];
    };
  };

  # This value determines the NixOS release with which your system is to be
  # compatible, in order to avoid breaking some software such as database
  # servers. You should change this only after NixOS release notes say you
  # should.
  system.stateVersion = "19.03"; # Did you read the comment?

}
