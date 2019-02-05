# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

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

  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.kernelParams = [ "amd_iommu=on" ];
  boot.blacklistedKernelModules = [ "nvidia" "nouveau" ];
  boot.kernelModules = [ "kvm-amd" "vfio_virqfd" "vfio_pci" "vfio_iommu_type1" "vfio" ];
  boot.extraModprobeConfig = "options vfio-pci ids=10de:13c0,10de:0fbb";
  boot.postBootCommands = ''
    DEVS="0000:0b:00.0 0000:0b:00.1"

    for DEV in $DEVS; do
      echo "vfio-pci" > /sys/bus/pci/devices/$DEV/driver_override
    done
    modprobe -i vfio-pci

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

  networking.hostName = "tr4";
  networking.networkmanager.enable = true;
  networking.hosts = {
    "192.168.1.1" = [ "router.lan" ];
    "192.168.1.69" = [ "nas.lan" ];
    "192.168.9.75" = [ "tetrarch.lan" ];
  };

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
    beam.packages.erlangR21.elixir_1_8

    # git
    git
    git-lfs
    gitAndTools.git-extras
    gitAndTools.gitflow

    # drivers
    ckb-next
    libusb
    libusb1

    # useful packages
    wget
    curl
    gnupg
    lm_sensors
    dmidecode
    atop
    bind
    ethtool
    graphviz
    htop
    hwloc
    iotop
    lshw
    numactl
    sysstat
    unzip
    usbutils
    utillinux

    # user packages
    atom
    obs-studio
    neofetch
    looking-glass-client
    networkmanagerapplet
    rofi-unwrapped
    rxvt_unicode_with-plugins
    scrot
    steam
    sublime3
    wineWowPackages.staging
    firefox-bin
    feh

    # themes
    qt5ct
    libsForQt512.qtstyleplugins
    lxappearance
    arc-theme
    arc-icon-theme
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

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  networking.firewall.enable = true;

  # Enable CUPS to print documents.
  # services.printing.enable = true;

  # Enable sound.
  sound.enable = true;
  hardware.pulseaudio.enable = true;
  # module-alsa-sink is to enable stereo on the arctis 7 (lets hope it doesnt change card id)
  # module-native-protocol-tcp is to allow qemu to connect without permission issues
  hardware.pulseaudio.extraConfig = ''
    load-module module-alsa-sink device=hw:1,1
    load-module module-native-protocol-tcp auth-ip-acl=127.0.0.1 auth-anonymous=1
  '';

  # https://github.com/NixOS/nixpkgs/issues/42433
  programs.dconf.enable = true;

  # Enable the X11 windowing system.
  services.xserver.enable = true;
  services.xserver.layout = "us";

  # enable nvidia driver (requires allowUnfree from above)
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.opengl.driSupport32Bit = true;

  # enable i3
  services.xserver.windowManager.i3.enable = true;
  services.xserver.windowManager.i3.package = pkgs.i3-gaps;
  services.xserver.windowManager.i3.extraPackages = with pkgs; [
    rofi
    i3lock
    i3status-rust
    i3blocks-gaps
  ];

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
    "nix-zsh-completions"
  ];

  /* services.udev = {
    extraRules = ''
      SUBSYSTEM=="vfio", OWNER="root", GROUP="kvm"
    '';
  }; */

  services.nginx = {
    enable = true;
    virtualHosts."192.168.1.66" = {
      default = true;
      listen = [{ addr = "192.168.1.66"; }];
      root = "/";
      extraConfig = ''
        autoindex on;
      '';
    };
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

  # Define a user account. Don't forget to set a password with ‘passwd’.
  # users.users.guest = {
  #   isNormalUser = true;
  #   uid = 1000;
  # };
  users.users.skw = {
    isNormalUser = true;
    home = "/home/skw";
    extraGroups = [ "wheel" "qemu-libvirtd" "audio" "video" "libvirtd" "kvm" "networkmanager" ];
    uid = 1000;
    shell = pkgs.zsh;
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

  boot.supportedFilesystems = [
    "fuse.dislocker"
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
  system.stateVersion = "18.09"; # Did you read the comment?

}
