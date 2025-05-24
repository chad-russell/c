{ ... }:
{
  disko.devices = {
    disk = {
      # System disk (btrfs) - 512GB nvme
      system = {
        device = "/dev/nvme0n1";
        type = "disk";
        content = {
          type = "gpt";
          partitions = {
            boot = {
              size = "512M";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [ "defaults" ];
              };
            };
            root = {
              size = "100%";
              content = {
                type = "btrfs";
                extraArgs = [ "-f" ];
                subvolumes = {
                  "@" = {
                    mountpoint = "/";
                    mountOptions = [ "compress=zstd" "noatime" ];
                  };
                  "@nix" = {
                    mountpoint = "/nix";
                    mountOptions = [ "compress=zstd" "noatime" ];
                  };
                  "@var" = {
                    mountpoint = "/var";
                    mountOptions = [ "compress=zstd" "noatime" ];
                  };
                  "@home" = {
                    mountpoint = "/home";
                    mountOptions = [ "compress=zstd" "noatime" ];
                  };
                  "@tmp" = {
                    mountpoint = "/tmp";
                    mountOptions = [ "noatime" ];
                  };
                };
              };
            };
          };
        };
      };

      # # Data disk (ext4 for SeaweedFS volume storage) - the 2TB SSD
      # data = {
      #   device = "/dev/nvme1n1";
      #   type = "disk";
      #   content = {
      #     type = "gpt";
      #     partitions = {
      #       seaweedfs = {
      #         size = "100%";
      #         type = "8300";
      #         content = {
      #           type = "filesystem";
      #           format = "ext4";
      #           mountpoint = "/var/lib/seaweedfs";
      #           mountOptions = [ "noatime" "defaults" ];
      #         };
      #       };
      #     };
      #   };
      # };
    };
  };
}
