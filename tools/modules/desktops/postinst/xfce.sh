#!/bin/bash
set +e
# overwrite stock lightdm greeter configuration
if [ -d /etc/armbian/lightdm ]; then cp -R /etc/armbian/lightdm /etc/; fi


#Adjust xsettings.xml for NumixBlue Theme Ubuntu
if [ -f /etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml ]; then sed -i 's/Xfce-dusk/NumixBlue/g' /etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml; fi

# Adjust menu
if [ -f /etc/xdg/menus/xfce-applications.menu ]; then
sed -i -n '/<Menuname>Settings<\/Menuname>/{p;:a;N;/<Filename>xfce4-session-logout.desktop<\/Filename>/!ba;s/.*\n/\
\t<Separator\/>\n\t<Merge type="all"\/>\n        <Separator\/>\n        <Filename>armbian-donate.desktop<\/Filename>\
\n        <Filename>armbian-support.desktop<\/Filename>\n/};p' /etc/xdg/menus/xfce-applications.menu
fi

# Hide few items
if [ -f /usr/share/applications/display-im6.q16.desktop ]; then mv /usr/share/applications/display-im6.q16.desktop /usr/share/applications/display-im6.q16.desktop.hidden; fi
if [ -f /usr/share/applications/display-im6.desktop ]; then  mv /usr/share/applications/display-im6.desktop /usr/share/applications/display-im6.desktop.hidden; fi
if [ -f /usr/share/applications/vim.desktop ]; then  mv /usr/share/applications/vim.desktop /usr/share/applications/vim.desktop.hidden; fi
if [ -f /usr/share/applications/libreoffice-startcenter.desktop ]; then mv /usr/share/applications/libreoffice-startcenter.desktop /usr/share/applications/libreoffice-startcenter.desktop.hidden; fi

# Disable Pulseaudio timer scheduling which does not work with sndhdmi driver
if [ -f /etc/pulse/default.pa ]; then sed "s/load-module module-udev-detect$/& tsched=0/g" -i  /etc/pulse/default.pa; fi

# Pivuan: picom is the compositor on XLibre, with Pivuan Audio's settings
# (/etc/pivuan/picom.conf: XRender in step with the screen, no shadows), which
# move windows smoothly on the Pi 5 without redraw trails. xfwm4's own
# compositor is turned off; windows move with their contents (no box) and
# resizing shows an outline, as in Pivuan Audio's JWM.
desktops_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
install -Dm 0644 "${desktops_dir}/branding/picom/pivuan-picom.conf" /etc/pivuan/picom.conf
install -Dm 0644 "${desktops_dir}/branding/picom/pivuan-picom.desktop" /etc/xdg/autostart/pivuan-picom.desktop
xfwm4_xml=/etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/xfwm4.xml
if [ -f "$xfwm4_xml" ]; then
	sed -i -E 's/(name="(use_compositing|box_move)" type="bool" value=)"true"/\1"false"/' "$xfwm4_xml"
fi
