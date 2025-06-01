{
  disko.devices = {
    disk = {
      main = {
        type   = "disk";
        device = "/dev/sda";
        content = {
          type = "gpt";
          partitions = {
            # 1MiB slice for legacy GRUB core.img on GPT
            boot = {
              size     = "1M";
              type     = "EF02";
              priority = 1;
            };
            # Root partition (rest-of-disk)
            root = {
              size = "100%";
              content = {
                type       = "filesystem";
                format     = "ext4";
                mountpoint = "/";
              };
            };
          };
        };
      };
    };
  };
}