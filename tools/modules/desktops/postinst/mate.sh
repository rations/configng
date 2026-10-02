#!/bin/bash
set +e
# overwrite stock lightdm greeter configuration
if [ -d /etc/armbian/lightdm ]; then cp -R /etc/armbian/lightdm /etc/; fi
# The shared greeter configuration names XFCE's session; log in to MATE.
if [ -f /etc/lightdm/lightdm.conf.d/11-armbian.conf ]; then sed -i 's/^user-session=.*/user-session=mate/' /etc/lightdm/lightdm.conf.d/11-armbian.conf; fi

# disable Pulseaudio timer scheduling which does not work with sndhdmi driver
if [ -f /etc/pulse/default.pa ]; then sed "s/load-module module-udev-detect$/& tsched=0/g" -i /etc/pulse/default.pa; fi

# Pivuan: picom is the compositor on XLibre, with Pivuan Audio's settings
# (/etc/pivuan/picom.conf: XRender in step with the screen, no shadows), which
# move windows smoothly on the Pi 5 without redraw trails. marco's own
# compositor is turned off (compositing-manager=false below).
desktops_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
install -Dm 0644 "${desktops_dir}/branding/picom/pivuan-picom.conf" /etc/pivuan/picom.conf
install -Dm 0644 "${desktops_dir}/branding/picom/pivuan-picom.desktop" /etc/xdg/autostart/pivuan-picom.desktop

##dconf desktop settings
keys=/etc/dconf/db/local.d/00-desktop
profile=/etc/dconf/profile/user

install -Dv /dev/null $keys
install -Dv /dev/null $profile

echo "[org/mate/desktop/background]
picture-options='zoom'
picture-uri='file:///usr/share/backgrounds/pivuan/background-dark-gray.png'
primary-color='#456789'
secondary-color='#FFFFFF'

[org/mate/desktop/applications/terminal]
exec='mate-terminal'

[org/mate/desktop/default-applications/terminal]
exec='mate-terminal'

[org/mate/desktop/interface]
clock-show-date=true
cursor-theme='DMZ-White'
gtk-theme='Numix'
icon-theme='Numix'
scaling-factor=uint32 0
toolkit-accessibility=false

[org/mate/desktop/screensaver]
picture-options='zoom'
picture-uri='file:///usr/share/backgrounds/pivuan/background-dark-gray.png'
primary-color='#456789'
secondary-color='#FFFFFF'

[org/mate/desktop/wm/preferences]
num-workspaces=2
theme='Numix'

[org/mate/marco/general]
compositing-manager=false

[org/mate/settings-daemon/plugins/power]
button-power='interactive'
lid-close-ac-action='nothing'
lid-close-battery-action='nothing'
sleep-inactive-ac-timeout=0
sleep-inactive-battery-timeout=0

[org/mate/settings-daemon/plugins/xsettings]
buttons-have-icons=true
menus-have-icons=true

[org/mate/sounds]
login-enabled=false
logout-enabled=false
plug-enabled=false
switch-enabled=false
tile-enabled=false
unplug-enabled=false

[org/mate/panel/general]
object-id-list=['menu-bar', 'notification-area', 'clock', 'show-desktop-button', 'window-list', 'workspace-switcher']
toplevel-id-list=['top', 'bottom']

[org/mate/panel/toplevels/top]
expand=true
orientation='top'
size=24

[org/mate/panel/toplevels/bottom]
expand=true
orientation='bottom'
size=24

[org/mate/panel/menubar]
icon-name='pivuan'

[org/mate/panel/objects/menu-bar]
locked=true
toplevel-id='top'
position=0
object-type='menu-bar'

[org/mate/panel/objects/notification-area]
locked=true
toplevel-id='top'
position=10
panel-right-stick=true
object-type='applet'
applet-iid='NotificationAreaAppletFactory::NotificationArea'

[org/mate/panel/objects/clock]
locked=true
toplevel-id='top'
position=0
panel-right-stick=true
object-type='applet'
applet-iid='ClockAppletFactory::ClockApplet'

[org/mate/panel/objects/show-desktop-button]
locked=true
toplevel-id='bottom'
position=0
object-type='applet'
applet-iid='WnckletFactory::ShowDesktopApplet'

[org/mate/panel/objects/window-list]
locked=true
toplevel-id='bottom'
position=1
object-type='applet'
applet-iid='WnckletFactory::WindowListApplet'

[org/mate/panel/objects/workspace-switcher]
locked=true
toplevel-id='bottom'
position=0
panel-right-stick=true
object-type='applet'
applet-iid='WnckletFactory::WorkspaceSwitcherApplet'" >> $keys

echo "user-db:user
system-db:local" >> $profile

dconf update

# System dconf database + gsettings schema override handle defaults
# for both new and existing users without touching user databases

# Override MATE default schema for wallpaper
mkdir -p /usr/share/glib-2.0/schemas
rm -f /usr/share/glib-2.0/schemas/90-armbian-mate.gschema.override
cat > /usr/share/glib-2.0/schemas/90-pivuan-mate.gschema.override <<- 'GSEOF'
[org.mate.background]
picture-filename='/usr/share/backgrounds/pivuan/background-dark-gray.png'
picture-options='zoom'
primary-color='#456789'

[org.mate.interface]
gtk-theme='Numix'
icon-theme='Numix'

[org.mate.Marco.general]
theme='Numix'
num-workspaces=2
compositing-manager=false

[org.mate.caja.desktop]
home-icon-visible=false
computer-icon-visible=false
trash-icon-visible=false
volumes-visible=false
GSEOF

#re-compile schemas
if [ -d /usr/share/glib-2.0/schemas ]; then glib-compile-schemas /usr/share/glib-2.0/schemas; fi

# Pivuan logo on the panel's menu bar (icon-name 'pivuan' above): unthemed
# icons are looked up in /usr/share/pixmaps.
if [ -f /usr/share/pixmaps/pivuan/pivuan.png ]; then ln -sfn pivuan/pivuan.png /usr/share/pixmaps/pivuan.png; fi

# List the Pivuan backgrounds in Appearance > Background ("Pivuan Dark Gray", ...).
mkdir -p /usr/share/mate-background-properties
{
	echo '<?xml version="1.0"?>'
	echo '<!DOCTYPE wallpapers SYSTEM "mate-wp-list.dtd">'
	echo '<wallpapers>'
	for image in /usr/share/backgrounds/pivuan/background-*.png; do
		[ -f "$image" ] || continue
		colour=${image##*/background-}
		colour=${colour%.png}
		name=$(echo "$colour" | tr '-' ' ' | awk '{ for (i = 1; i <= NF; i++) $i = toupper(substr($i, 1, 1)) substr($i, 2); print }')
		echo '  <wallpaper deleted="false">'
		echo "    <name>Pivuan $name</name>"
		echo "    <filename>$image</filename>"
		echo '    <options>zoom</options>'
		echo '  </wallpaper>'
	done
	echo '</wallpapers>'
} > /usr/share/mate-background-properties/pivuan.xml
