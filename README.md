# Arch Install Cheatsheet for UEFI systemd-boot and GNOME / i3

# Download [wip]
```bash
export archiso_latest=$(curl -s https://www.archlinux.org/download/ | grep "Current Release" | awk '{print $3}' | sed -e 's/<.*//')
export archiso_link=http://mirrors.kernel.org/archlinux/iso/$archiso_latest/archlinux-$archiso_latest-x86_64.iso
wget "$archiso_link"
dd bs=4M if=/path/to/archlinux.iso of=/dev/sdx status=progress oflag=sync
```

### Connect to wifi
```bash
wifi-menu
```

# Pre-install

## Partitioning

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
d - delete partition
p - print status
w - write
q - quit
```

## Formatting
```bash
mkfs.fat -F32 /dev/sda1
mkfs.ext4 /dev/sda2
mkswap /dev/sda3
swapon /dev/sda3
mkfs.ext4 /dev/sda4
```

## Mount
```bash
mount /dev/sda2 /mnt
mkdir /mnt/home
mkdir /mnt/boot
mount /dev/sda1 /mnt/boot
mount /dev/sda4 /mnt/home
# lsblk to make sure
```

# Pacstrap
#### Optional - Edit the Mirrorlist
```bash
nano /etc/pacman.d/mirrorlist
```
---
```bash
pacstrap -i base base-devel vim git
genfstab -U /mnt >> /mnt/etc/fstab # so that linux auto mounts /root /boot /home
```

# Post Pacstrap
```bash
arch-chroot /mnt

# Timezone
ln -sf /usr/share/zoneinfo/Region/City /etc/localtime
# Run hwclock(8) to generate /etc/adjtime: 
hwclock --systohc

# Hostname
echo Arun-Predator-Linux > /etc/hostname

# Set root passwwd
passwd

```
## Localization

```bash
# Uncomment en_CA.UTF-8 UTF-8
vim /etc/locale.gen 

echo LANG=en_US.UTF-8 > /etc/locale.conf
locale-gen
```

# DONE
```bash
# exit chroot
exit
reboot
```



