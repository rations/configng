#!/bin/bash
set +e
# SonicDE removed (module_desktops remove, after its packages are purged): take away what
# postinst/sonicde.sh put outside them. Only one desktop is installed at a time, so the files it
# shares with Pivuan Audio (the on-screen keyboard's) are no one else's by now.
desktops_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Configuration files with names other programs could use too: only while they are still
# Pivuan's (unchanged).
remove_if_ours() {
	cmp -s "$1" "$2" && rm -f "$2"
}
remove_if_ours "${desktops_dir}/branding/sonicde/kdeglobals" /etc/xdg/kdeglobals
remove_if_ours "${desktops_dir}/branding/sonicde/kscreenlockerrc" /etc/xdg/kscreenlockerrc
remove_if_ours "${desktops_dir}/branding/sonicde/kde-mimeapps.list" /etc/xdg/kde-mimeapps.list
remove_if_ours "${desktops_dir}/branding/onboard/onboard-defaults.conf" /etc/onboard/onboard-defaults.conf
rmdir /etc/onboard 2> /dev/null

# Pivuan's own files
updates=/usr/share/plasma/shells/org.kde.plasma.desktop/contents/updates
rm -f "${updates}/pivuan-layout.js" "${updates}/pivuan-background.js"
rmdir -p "${updates}" 2> /dev/null
rm -f /etc/xdg/autostart/pivuan-onboard.desktop /usr/lib/pivuan/keyboard
rmdir /usr/lib/pivuan 2> /dev/null

# GTK's accessibility setting for Onboard, and the schemas compiled again without it
if [ -f /usr/share/glib-2.0/schemas/90_pivuan-onboard.gschema.override ]; then
	rm -f /usr/share/glib-2.0/schemas/90_pivuan-onboard.gschema.override
	for compile in /usr/lib/*/glib-2.0/glib-compile-schemas /usr/bin/glib-compile-schemas; do
		[ -x "${compile}" ] && "${compile}" /usr/share/glib-2.0/schemas && break
	done
fi
