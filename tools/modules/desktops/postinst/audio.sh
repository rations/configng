#!/bin/bash
#
# Pivuan Audio: JWM on XLibre, started from the xlogin login screen
# (simple-login-gui) on tty1 instead of a display manager.
#
# Run by module_desktop_branding after the packages are installed, before
# module_update_skel copies /etc/skel into existing home directories.
#
set +e
desktops_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# 1. JWM: the Pivuan menu, tray and look in /etc/jwm/pivuan.jwmrc, and a
#    ~/.jwmrc for each user that includes it.
install -Dm 0644 "${desktops_dir}/branding/jwm/pivuan.jwmrc" /etc/jwm/pivuan.jwmrc
cat > /etc/skel/.jwmrc << 'EOF'
<?xml version="1.0"?>
<!--
    Your JWM settings. The Pivuan menu, tray and look come from the Include
    below. Add your own settings under it; to change the Pivuan ones, replace
    the Include line with the contents of /etc/jwm/pivuan.jwmrc. Then choose
    "Restart JWM" in the menu.
-->
<JWM>
    <Include>/etc/jwm/pivuan.jwmrc</Include>
</JWM>
EOF

# 2. The session xlogin starts: ~/.xinitrc. /usr/lib/pivuan/audio-session makes
#    the user's folders and pcmanfm bookmarks; dbus-run-session gives the
#    session a D-Bus bus (pcmanfm's trash and mounts, nm-applet, blueman,
#    PulseAudio, JACK's claim on the sound card). /usr/lib/pivuan/pulse-session
#    (started by JWM) runs PulseAudio and hands it over to JACK while JACK runs.
install -Dm 0755 "${desktops_dir}/branding/jwm/pivuan-audio-session" /usr/lib/pivuan/audio-session
install -Dm 0755 "${desktops_dir}/branding/jwm/pivuan-pulse-session" /usr/lib/pivuan/pulse-session
#    /usr/lib/pivuan/autostart (started by JWM) runs the user's ~/.config/autostart
#    entries, such as the screen layout lxrandr saves. picom, the compositor, gets
#    Pivuan's settings (no shadows or fading) rather than /etc/xdg/picom.conf.
install -Dm 0755 "${desktops_dir}/branding/jwm/pivuan-autostart" /usr/lib/pivuan/autostart
install -Dm 0644 "${desktops_dir}/branding/picom/pivuan-picom.conf" /etc/pivuan/picom.conf
#    The panel and the desktop background come from /usr/lib/pivuan/jwm-desktop (included by
#    pivuan.jwmrc), which reads the user's Desktop Settings (System > Desktop Settings in the
#    menu: the pivuan-desktop-settings package, rations/pivuan desktop-settings/, whose
#    defaults are jwm-desktop's).
install -Dm 0755 "${desktops_dir}/branding/jwm/pivuan-jwm-desktop" /usr/lib/pivuan/jwm-desktop
#    The on-screen keyboard for touchscreens: /usr/lib/pivuan/keyboard shows and hides Onboard
#    (the panel button, when Desktop Settings has the keyboard on, and System > On-screen
#    Keyboard in the menu), and Onboard's first settings dock it above the panel and start it
#    hidden.
install -Dm 0755 "${desktops_dir}/branding/jwm/pivuan-keyboard" /usr/lib/pivuan/keyboard
install -Dm 0644 "${desktops_dir}/branding/onboard/onboard-defaults.conf" /etc/onboard/onboard-defaults.conf
#    Onboard also comes up by itself when a text box is tapped in programs that tell the
#    accessibility bus (at-spi2-core) where the text box is: the GTK and Qt ones. It needs GTK's
#    accessibility on (the GNOME setting toolkit-accessibility), set here by default so Onboard
#    does not ask; the schemas are compiled again for it (no dpkg trigger sees this file).
install -Dm 0644 "${desktops_dir}/branding/onboard/90_pivuan-onboard.gschema.override" \
	/usr/share/glib-2.0/schemas/90_pivuan-onboard.gschema.override
for compile in /usr/lib/*/glib-2.0/glib-compile-schemas /usr/bin/glib-compile-schemas; do
	[ -x "${compile}" ] && "${compile}" /usr/share/glib-2.0/schemas && break
done
#    The screen's brightness (Desktop Settings and the panel's brightness button): the
#    backlight, which this udev rule lets the video group set, else the screen's own setting
#    over HDMI (DDC/CI, ddcutil through /dev/i2c-*: i2c-dev loaded at boot), else dimming.
install -Dm 0755 "${desktops_dir}/branding/jwm/pivuan-brightness" /usr/lib/pivuan/brightness
install -Dm 0644 "${desktops_dir}/branding/udev/90-pivuan-backlight.rules" \
	/etc/udev/rules.d/90-pivuan-backlight.rules
install -d /etc/modules-load.d
echo i2c-dev > /etc/modules-load.d/pivuan-i2c-dev.conf
modprobe i2c-dev 2> /dev/null
#    The Pivuan menu is jgmenu: /usr/lib/pivuan/menu opens it (the panel button, Alt+F1, a right
#    click on the desktop) with its look from /etc/pivuan/jgmenurc, and /usr/lib/pivuan/menu-items
#    makes it each time it opens: the programs by category from their .desktop files
#    (/etc/xdg/menus/pivuan-applications.menu and its categories' .directory files), the Windows
#    programs installed in Wine (/usr/lib/pivuan/wine-menu), and Log Out, Reboot and Shut Down,
#    which ask first (/usr/lib/pivuan/session). The on-screen keyboard has its own menu entry.
install -Dm 0755 "${desktops_dir}/branding/jwm/pivuan-menu" /usr/lib/pivuan/menu
install -Dm 0755 "${desktops_dir}/branding/jwm/pivuan-menu-items" /usr/lib/pivuan/menu-items
install -Dm 0755 "${desktops_dir}/branding/jwm/pivuan-session" /usr/lib/pivuan/session
install -Dm 0755 "${desktops_dir}/branding/jwm/pivuan-wine-menu" /usr/lib/pivuan/wine-menu
install -Dm 0644 "${desktops_dir}/branding/jgmenu/pivuan-jgmenurc" /etc/pivuan/jgmenurc
install -Dm 0644 "${desktops_dir}/branding/jgmenu/pivuan-applications.menu" /etc/xdg/menus/pivuan-applications.menu
for directory in "${desktops_dir}"/branding/jgmenu/pivuan-*.directory; do
	install -Dm 0644 "${directory}" "/usr/share/desktop-directories/${directory##*/}"
done
install -Dm 0644 "${desktops_dir}/branding/jwm/pivuan-keyboard.desktop" /usr/share/applications/pivuan-keyboard.desktop
#    Desktop icons: /usr/lib/pivuan/desktop-icons runs pcmanfm's desktop (on or off in Desktop
#    Settings). Extract Here in pcmanfm's right-click menu for zip and tar archives (a libfm
#    file-manager action) runs /usr/lib/pivuan/extract-here.
install -Dm 0755 "${desktops_dir}/branding/jwm/pivuan-desktop-icons" /usr/lib/pivuan/desktop-icons
install -Dm 0755 "${desktops_dir}/branding/jwm/pivuan-extract-here" /usr/lib/pivuan/extract-here
install -Dm 0644 "${desktops_dir}/branding/pcmanfm/pivuan-extract-here.desktop" \
	/usr/share/file-manager/actions/pivuan-extract-here.desktop
#    Plugin Licenses (pivuan-plugin-licenses, in the Audio menu) starts the license services of
#    Windows plugins, such as iLok's, only when they are wanted. It replaces
#    /usr/lib/pivuan/wine-session, which kept Wine and those services (about 1 GB) running for
#    the whole session.
rm -f /usr/lib/pivuan/wine-session
#    XDG_CURRENT_DESKTOP: Wine makes menu entries and desktop shortcuts for the programs it
#    installs only when it is set. /usr/lib/pivuan/session-env: with a touchscreen, GTK 3
#    programs take a tap as a click. A ~/.xinitrc that is still one Pivuan Audio wrote before is
#    replaced; one the user changed is left alone.
install -Dm 0644 "${desktops_dir}/branding/jwm/pivuan-session-env" /usr/lib/pivuan/session-env
cat > /etc/skel/.xinitrc << 'EOF'
#!/bin/sh
[ -x /usr/lib/pivuan/audio-session ] && /usr/lib/pivuan/audio-session
[ -r /usr/lib/pivuan/session-env ] && . /usr/lib/pivuan/session-env
export XDG_CURRENT_DESKTOP=JWM
exec dbus-run-session jwm
EOF
chmod 0755 /etc/skel/.xinitrc
old_xinitrc_1="$(printf '%s\n' '#!/bin/sh' \
	'[ -x /usr/lib/pivuan/audio-session ] && /usr/lib/pivuan/audio-session' \
	'exec dbus-run-session jwm')"
old_xinitrc_2="$(printf '%s\n' '#!/bin/sh' \
	'[ -x /usr/lib/pivuan/audio-session ] && /usr/lib/pivuan/audio-session' \
	'export XDG_CURRENT_DESKTOP=JWM' 'exec dbus-run-session jwm')"
for xinitrc in /home/*/.xinitrc; do
	[ -f "${xinitrc}" ] || continue
	case "$(cat "${xinitrc}")" in
		"${old_xinitrc_1}" | "${old_xinitrc_2}") cat /etc/skel/.xinitrc > "${xinitrc}" ;;
	esac
done

#    GTK programs (pcmanfm, Volume Control, file dialogs) use the Pivuan icons
#    (pivuan-icon-theme, Haiku's icons, with Numix for the ones it lacks). The theme
#    stays GTK's own; lxappearance changes both. A double click may move 16 pixels between
#    its clicks, so a finger's double tap counts (/usr/lib/pivuan/audio-session adds it for
#    users who already have the file).
mkdir -p /etc/skel/.config/gtk-3.0 /etc/skel/.config/gtk-4.0
for gtk in gtk-3.0 gtk-4.0; do
	printf '[Settings]\ngtk-icon-theme-name=Pivuan\ngtk-double-click-distance=16\n' \
		> "/etc/skel/.config/${gtk}/settings.ini"
done
printf 'gtk-icon-theme-name="Pivuan"\n' > /etc/skel/.gtkrc-2.0

#    PulseAudio: the Pi's HDMI audio needs timer-based scheduling off (as
#    postinst/xfce.sh does for the same reason).
if [ -f /etc/pulse/default.pa ]; then
	sed -i 's/^load-module module-udev-detect$/& tsched=0/' /etc/pulse/default.pa
fi

# 3. The login screen. /etc/xlogin.conf is read by xlogin-launcher at boot;
#    xlogin itself rewrites single keys in it (the background picked in its
#    Options menu), so an existing file is left alone (except for the old
#    background name, below).
backgrounds=/usr/share/xlogin/backgrounds
install -d -m 0755 "${backgrounds}"
# The Pivuan backgrounds, picked in xlogin's Options menu; black is the default.
# xlogin only reads root-owned files that nobody else can write.
for image in /usr/share/backgrounds/pivuan/background-*.png; do
	[ -f "${image}" ] || continue
	install -m 0644 -o root -g root "${image}" "${backgrounds}/${image##*/}"
done
# The background before there were several (pivuan-background.png) is now black.
if [ -f /etc/xlogin.conf ]; then
	sed -i "s/^XLOGIN_BACKGROUND='pivuan-background\.png'$/XLOGIN_BACKGROUND='background-black.png'/" /etc/xlogin.conf
fi
if [ ! -f /etc/xlogin.conf ]; then
	cat > /etc/xlogin.conf << 'EOF'
# xlogin configuration.
#
# This file is sourced by /bin/sh (by xlogin-launcher, as root, at boot), so every
# line must be a plain KEY='value'. xlogin rewrites single keys here in place and
# leaves everything else alone, so anything you add by hand survives.

# Passed to the X server by xlogin-launcher. -seat seat0 -keeptty: X opens its
# devices through seatd (the Pi's open-source vc4/v3d drivers support this).
XSERVER_FLAGS="-seat seat0 -keeptty -nolisten tcp -ac"

# The VT the Options > Console entry switches to (a getty runs there).
XLOGIN_CONSOLE_VT='2'

# Background image: a file in /usr/share/xlogin/backgrounds, or empty for none.
XLOGIN_BACKGROUND='background-black.png'

# fill | fit | center | stretch | tile
XLOGIN_BG_MODE='fill'
EOF
	chmod 0644 /etc/xlogin.conf
fi

# 4. seatd gives the X server its devices; xlogin-launcher also starts it if
#    it is not running.
update-rc.d seatd defaults > /dev/null 2>&1

# 5. Realtime scheduling and locked memory for the audio group (JACK,
#    JackDAW's mlockall): jackd2 writes /etc/security/limits.d/audio.conf
#    when this debconf answer is yes. xlogin's PAM stack applies it
#    (pam_limits); users are in the audio group.
echo "jackd2 jackd/tweak_rt_limits boolean true" | debconf-set-selections
DEBIAN_FRONTEND=noninteractive dpkg-reconfigure -f noninteractive jackd2 > /dev/null 2>&1

# 6. tty1: xlogin-launcher instead of the text login. Last, and only if the
#    login screen starts on this machine: a tty1 respawning something that
#    cannot run leaves no login there (tty2-tty6 keep theirs). The original
#    inittab is kept in /etc/armbian/desktop/audio.inittab; removing Pivuan
#    Audio puts it back. The line has its own id (x1): init replaces a
#    running process only when its id goes away, so with the getty's id "1"
#    the text login on tty1 would stay until it exits. module_desktops
#    reloads init once this install has finished (telinit q). An empty
#    /etc/inittab.d keeps init from reporting that it has none.
#    If xlogin-launcher fails at boot, it runs a text login on tty1 itself.
launcher=/usr/bin/xlogin-launcher
if [ ! -x "${launcher}" ] || ! /usr/bin/xlogin --version > /dev/null 2>&1; then
	echo "Warning: xlogin does not run here; tty1 keeps its text login." >&2
	exit 0
fi
if ! command -v Xlibre > /dev/null 2>&1 && ! command -v Xorg > /dev/null 2>&1; then
	echo "Warning: no X server installed; tty1 keeps its text login." >&2
	exit 0
fi
if [ -f /etc/inittab ]; then
	install -d -m 0755 /etc/inittab.d
	if ! grep -q '^[^#]*xlogin-launcher' /etc/inittab; then
		mkdir -p /etc/armbian/desktop
		[ -f /etc/armbian/desktop/audio.inittab ] || cp -p /etc/inittab /etc/armbian/desktop/audio.inittab
		sed -i -E '/^1:[0-9]*:respawn:.*[ag]etty/s/^/#/' /etc/inittab
		echo "x1:2345:respawn:${launcher}" >> /etc/inittab
	else
		# Installed by an earlier Pivuan Audio with the getty's id.
		sed -i -E 's|^1:([0-9]*:respawn:.*xlogin-launcher)|x1:\1|' /etc/inittab
	fi
fi
exit 0
