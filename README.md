# arch-install-config

# Download [wip]
```bash
export archiso_latest=$(curl -s https://www.archlinux.org/download/ | grep "Current Release" | awk '{print $3}' | sed -e 's/<.*//')
export archiso_link=http://mirrors.kernel.org/archlinux/iso/$archiso_latest/archlinux-$archiso_latest-x86_64.iso
wget "$archiso_link"
dd bs=4M if=/path/to/archlinux.iso of=/dev/sdx status=progress oflag=sync
```

# Partitioning

```bash
wipefs -a /dev/sda
fdisk /dev/sda
```
|           | size | mount point |
|-----------|------|-------------|
| /dev/sda1 | 256M | /boot       |
| /dev/sda2 | 32G  | /           |
| /dev/sda3 | 24G  | SWAP        |
| /dev/sda4 |      | /home       |

### fdisk:
```
g - create GPT disklabel
n - new partition
t - change partition type (1=EFI)
d -delete partition
```

