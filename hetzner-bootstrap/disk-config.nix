{ lib, disko, ... }: {
  imports = [ disko.nixosModules.disko ];

  disko.devices = {
    disk = {
      sda = { # Assuming /dev/sda, common for Hetzner Cloud VMs. Please verify.
        type = "disk";
        device = "/dev/sda"; 
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              type = "EF00";
              size = "512M";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
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