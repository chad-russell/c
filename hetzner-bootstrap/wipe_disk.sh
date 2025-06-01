vgchange -an
wipefs -a /dev/sda
sgdisk --zap-all /dev/sda

# Clear first 10 MiB
dd if=/dev/zero of=/dev/sda bs=1M count=10

# Clear last 10 MiB
DISK_SIZE=$(blockdev --getsize64 /dev/sda)
dd if=/dev/zero of=/dev/sda bs=1M seek=$((DISK_SIZE / 1048576 - 10)) count=10

# Fresh GPT table
parted /dev/sda -- mklabel gpt