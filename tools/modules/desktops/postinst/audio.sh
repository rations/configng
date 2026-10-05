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
cat > /etc/skel/.xinitrc << 'EOF'
#!/bin/sh
[ -x /usr/lib/pivuan/audio-session ] && /usr/lib/pivuan/audio-session
exec dbus-run-session jwm
EOF
chmod 0755 /etc/skel/.xinitrc

#    GTK programs (pcmanfm, Volume Control, file dialogs) use the Pivuan icons
#    (pivuan-icon-theme, Haiku's icons, with Numix for the ones it lacks). The theme
#    stays GTK's own; lxappearance changes both.
mkdir -p /etc/skel/.config/gtk-3.0 /etc/skel/.config/gtk-4.0
for gtk in gtk-3.0 gtk-4.0; do
	printf '[Settings]\ngtk-icon-theme-name=Pivuan\n' > "/etc/skel/.config/${gtk}/settings.ini"
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
