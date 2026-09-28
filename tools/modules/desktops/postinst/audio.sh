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

# 2. The session xlogin starts: ~/.xinitrc. dbus-run-session gives the
#    session a D-Bus bus (pcmanfm's trash and mounts, nm-applet, blueman).
cat > /etc/skel/.xinitrc << 'EOF'
#!/bin/sh
exec dbus-run-session jwm
EOF
chmod 0755 /etc/skel/.xinitrc

# 3. The login screen. /etc/xlogin.conf is read by xlogin-launcher at boot;
#    xlogin itself rewrites single keys in it (the background picked in its
#    Options menu), so an existing file is left alone.
backgrounds=/usr/share/xlogin/backgrounds
install -d -m 0755 "${backgrounds}"
if [ -f /usr/share/backgrounds/pivuan/pivuan-background.png ]; then
	# xlogin only reads root-owned files that nobody else can write.
	install -m 0644 -o root -g root /usr/share/backgrounds/pivuan/pivuan-background.png "${backgrounds}/pivuan-background.png"
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
XLOGIN_BACKGROUND='pivuan-background.png'

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
#    Audio puts it back. Not reloaded now (telinit q would end a login on
#    tty1, maybe the one running this); it takes effect at the next boot.
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
if [ -f /etc/inittab ] && ! grep -q '^[^#]*xlogin-launcher' /etc/inittab; then
	mkdir -p /etc/armbian/desktop
	[ -f /etc/armbian/desktop/audio.inittab ] || cp -p /etc/inittab /etc/armbian/desktop/audio.inittab
	sed -i -E '/^1:[0-9]*:respawn:.*[ag]etty/s/^/#/' /etc/inittab
	echo "1:2345:respawn:${launcher}" >> /etc/inittab
fi
exit 0
