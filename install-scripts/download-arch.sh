if [[ $UID != 0 ]]; then
    echo "$(tput bold)$(tput setaf 1)Please run this script with sudo in order to write to your usb drive:$(tput sgr 0)"  
    echo "sudo $0 $*"
    exit 1
fi

lsblk
echo "$(tput bold)$(tput setaf 1)Choose your usb device (ex sda or sdb or sdc) or press Ctrl+C to exit$(tput sgr 0)"
read usbdrive
read -p "You chose /dev/$usbdrive Press ENTER to continue, or Ctrl+C to exit"

echo Getting the latest arch version...
archiso_latest=$(curl -s https://www.archlinux.org/download/ | grep "Current Release" | awk '{print $3}' | sed -e 's/<.*//')
echo Downloading version: $archiso_latest and writing to /dev/$usbdrive


curl -L http://mirrors.kernel.org/archlinux/iso/$archiso_latest/archlinux-$archiso_latest-x86_64.iso | sudo dd bs=4M of=/dev/$usbdrive oflag=sync

echo "$(tput bold)$(tput setaf 2)Done!$(tput sgr 0)"
#or if you're root
#curl -L http://mirrors.kernel.org/archlinux/iso/$archiso_latest/archlinux-$archiso_latest-x86_64.iso > /dev/sdX

#or, torrent the iso and
#dd bs=4M if=/path/to/archlinux.iso of=/dev/sdX status=progress oflag=sync
