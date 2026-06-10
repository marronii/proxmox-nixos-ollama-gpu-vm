{ config, lib, pkgs, ... }:

{
  imports = [ ./hardware-configuration.nix ];

  # ---------------------------------------------------------------------------
  # Boot
  # ---------------------------------------------------------------------------

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # EFI boot partition.
  #
  # Adjust the device path according to your VM disk layout.
  fileSystems."/boot" = {
    device = "/dev/vda1";
    fsType = "vfat";
  };

  # Linux 6.12 LTS was used in the reference setup for compatibility with
  # NVIDIA RTX 50xx / Blackwell GPUs and the selected NVIDIA driver package.
  boot.kernelPackages = pkgs.linuxPackages_6_12;

  # Prevent conflicting framebuffer or open-source GPU modules from binding
  # to the NVIDIA device.
  boot.blacklistedKernelModules = [
    "nouveau"
    "nvidiafb"
    "nova_core"
  ];

  # Ensure NVIDIA kernel modules are available during boot.
  boot.kernelModules = [
    "nvidia"
    "nvidia_uvm"
    "nvidia_drm"
    "nvidia_modeset"
  ];

  # ---------------------------------------------------------------------------
  # NVIDIA GPU
  # ---------------------------------------------------------------------------

  # Enables the graphics stack.
  #
  # In newer NixOS releases, hardware.graphics replaces the older
  # hardware.opengl option.
  hardware.graphics.enable = true;

  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia = {
    modesetting.enable = true;

    # RTX 50xx / Blackwell GPUs require NVIDIA Open Kernel Modules.
    open = true;

    nvidiaSettings = false;

    # Beta driver package was used in the reference setup because it provided
    # support for the tested RTX 5060 Ti GPU.
    package = config.boot.kernelPackages.nvidiaPackages.beta;
  };

  # Required for NVIDIA drivers and CUDA-enabled packages.
  nixpkgs.config.allowUnfree = true;
  nixpkgs.config.cudaSupport = true;

  # ---------------------------------------------------------------------------
  # Ollama
  # ---------------------------------------------------------------------------

  services.ollama = {
    enable = true;

    # CUDA-enabled Ollama package.
    #
    # This replaces older acceleration-based configuration patterns.
    package = pkgs.ollama-cuda;

    # Listen on all interfaces.
    #
    # For public or untrusted networks, consider binding only to localhost
    # or protecting this port behind a reverse proxy, VPN, or firewall rule.
    host = "0.0.0.0";
    port = 11434;

    environmentVariables = {
      # Allows Ollama to find NVIDIA/OpenGL runtime libraries.
      LD_LIBRARY_PATH = "/run/opengl-driver/lib";

      # Optional: increases the default context size.
      # Tune this according to your GPU VRAM and model size.
      OLLAMA_NUM_CTX = "8192";
    };
  };

  # ---------------------------------------------------------------------------
  # Networking
  # ---------------------------------------------------------------------------

  networking = {
    hostName = "nixos-ollama";

    # Example static network configuration.
    #
    # Replace the interface name, IP address, gateway, and DNS servers according
    # to your own environment.
    interfaces."<your-network-interface>".ipv4.addresses = [{
      address = "192.168.x.x";
      prefixLength = 24;
    }];

    defaultGateway = "192.168.x.1";

    nameservers = [
      "1.1.1.1"
      "8.8.8.8"
    ];

    firewall = {
      enable = true;

      # 22    = SSH
      # 11434 = Ollama API
      allowedTCPPorts = [ 22 11434 ];
    };
  };

  # ---------------------------------------------------------------------------
  # SSH
  # ---------------------------------------------------------------------------

  services.openssh = {
    enable = true;

    settings = {
      # For public templates, SSH key authentication is recommended.
      # Enable password authentication only for local lab environments.
      PasswordAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  # ---------------------------------------------------------------------------
  # User
  # ---------------------------------------------------------------------------

  users.users.example = {
    isNormalUser = true;

    # wheel = sudo access
    # video = GPU/video device access
    extraGroups = [ "wheel" "video" ];

    # Prefer setting the password manually after installation:
    #
    #   sudo passwd example
    #
    # Avoid publishing initialPassword in public repositories.
  };

  # For public templates, it is safer to require a sudo password.
  security.sudo.wheelNeedsPassword = true;

  # ---------------------------------------------------------------------------
  # System packages
  # ---------------------------------------------------------------------------

  environment.systemPackages = with pkgs; [
    git
    htop
    curl
    nvtopPackages.nvidia
  ];

  # Keep this value aligned with the NixOS version used when the system was
  # originally installed.
  system.stateVersion = "26.05";
}
