#exec gnome-session

#urxvt settings
xrdb -merge ~/.Xresources

#enable natural scrolling, tapping, and mouse acceleration 
xinput --set-prop 'ELAN0501:01 04F3:3060 Touchpad' 'libinput Natural Scrolling Enabled' 1
xinput --set-prop 'ELAN0501:01 04F3:3060 Touchpad' 'libinput Tapping Enabled' 1
xinput set-prop 'ELAN0501:01 04F3:3060 Touchpad' 'libinput Accel Speed' 0.6

#enable touchpad gestures
libinput-gestures-setup autostart
libinput-gestures-setup start

#xrandr
if [-z $(xrandr | grep HDMI) ]; then
	xrandr --output eDP-1-1 --auto --brightness 0.5
else
	xrandr --output eDP-1-1 --auto --right-of HDMI-0 --brightness 0.5	
fi


eval $(/usr/bin/gnome-keyring-daemon --start --components=pkcs11,secrets,ssh)
export SSH_AUTH_SOCK

#start i3
exec i3
