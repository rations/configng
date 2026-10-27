#!/bin/bash
set +e
# SonicDE (the sonicde package from the Pivuan SonicDE apt repository, installed in /opt/sonicde).
desktops_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# The login screen starts SonicDE (/usr/share/xsessions/sonicde.desktop, from the sonicde
# package): the shared greeter configuration names XFCE's session.
if [ -d /etc/armbian/lightdm ]; then cp -R /etc/armbian/lightdm /etc/; fi
if [ -f /etc/lightdm/lightdm.conf.d/11-armbian.conf ]; then sed -i 's/^user-session=.*/user-session=sonicde/' /etc/lightdm/lightdm.conf.d/11-armbian.conf; fi

# Pivuan's first desktop: Silver Dark with the bottom panel (kdeglobals), then, once per user
# after Plasma has made that layout, the SonicBallLightning background and the panel's launchers
# (pivuan-layout.js, which replaced pivuan-background.js: the black background). The black
# Pivuan background stays behind the lock screen, as on the login screen.
install -Dm 0644 "${desktops_dir}/branding/sonicde/kdeglobals" /etc/xdg/kdeglobals
updates=/usr/share/plasma/shells/org.kde.plasma.desktop/contents/updates
rm -f "${updates}/pivuan-background.js"
install -Dm 0644 "${desktops_dir}/branding/sonicde/pivuan-layout.js" "${updates}/pivuan-layout.js"
install -Dm 0644 "${desktops_dir}/branding/sonicde/kscreenlockerrc" /etc/xdg/kscreenlockerrc
# Default applications in SonicDE only (KDE sessions): PDFs and images in qpdfview and LXImage,
# not Brave.
install -Dm 0644 "${desktops_dir}/branding/sonicde/kde-mimeapps.list" /etc/xdg/kde-mimeapps.list

# Earlier pivuan-config put a Plasma layout with only the desktop's background in /etc/skel, and
# so in each home. Plasma makes its default layout (the panel too) only when there is none, so
# SonicDE would start without a panel: remove it where Plasma has never run and it has no panel.
for home in /etc/skel /home/*; do
	layout="${home}/.config/plasma-org.kde.plasma.desktop-appletsrc"
	[ -f "${layout}" ] || continue
	[ -e "${home}/.config/plasmashellrc" ] && continue
	grep -q '^plugin=org.kde.panel$' "${layout}" && continue
	rm -f "${layout}"
done

# The on-screen keyboard for touchscreens, as on Pivuan Audio: /usr/lib/pivuan/keyboard starts
# Onboard hidden at login when a touchscreen is attached (pivuan-onboard.desktop, SonicDE's
# sessions only), and it comes up when a text box is tapped in GTK and Qt programs. Its first
# settings (/etc/onboard/onboard-defaults.conf) dock it along the bottom, above the panel.
# Accessibility > Onboard in the menu shows it in other programs.
install -Dm 0755 "${desktops_dir}/branding/jwm/pivuan-keyboard" /usr/lib/pivuan/keyboard
install -Dm 0644 "${desktops_dir}/branding/onboard/onboard-defaults.conf" /etc/onboard/onboard-defaults.conf
install -Dm 0644 "${desktops_dir}/branding/sonicde/pivuan-onboard.desktop" /etc/xdg/autostart/pivuan-onboard.desktop
# GTK's accessibility on, so Onboard comes up in GTK programs without asking first; the schemas
# are compiled again for it (no dpkg trigger sees this file).
install -Dm 0644 "${desktops_dir}/branding/onboard/90_pivuan-onboard.gschema.override" \
	/usr/share/glib-2.0/schemas/90_pivuan-onboard.gschema.override
for compile in /usr/lib/*/glib-2.0/glib-compile-schemas /usr/bin/glib-compile-schemas; do
	[ -x "${compile}" ] && "${compile}" /usr/share/glib-2.0/schemas && break
done
