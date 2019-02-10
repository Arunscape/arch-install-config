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
