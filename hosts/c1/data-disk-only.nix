{ ... }:
{
  disko.devices = {
    disk = {
      # Data disk - the 2TB SSD
      data = {
        device = "/dev/nvme1n1";
        type = "disk";
        content = {
          type = "gpt";
          partitions = {
            root = {
              size = "100%";
              content = {
                type = "btrfs";
                extraArgs = [ "-f" ];
                subvolumes = {
                  "@" = {
                    mountpoint = "/data";  # Changed to avoid conflict with root
                    mountOptions = [ "compress=zstd" "noatime" ];
                  };
                };
              };
            };
          };
        };
      };
    };
  };
} 