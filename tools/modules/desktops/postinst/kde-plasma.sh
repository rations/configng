#!/bin/bash
set +e

# Armbian branding for KDE Plasma. System defaults only: users can
# still change everything.
# Pivuan: the Pivuan background (no blurred copy) and logo, as on the other desktops.
wallpaper=/usr/share/backgrounds/pivuan/background-black.png
wallpaper_blurred=${wallpaper}
logo=/usr/share/pixmaps/pivuan/pivuan.png

# SDDM: Breeze works with the Qt5 and the Qt6 greeter. Use the
# Armbian background.
if [ -d /usr/share/sddm/themes/breeze ]; then
	cat > /usr/share/sddm/themes/breeze/theme.conf.user <<- EOF
	[General]
	background=${wallpaper_blurred}
	EOF
fi

# Wallpaper and launcher logo. Plasma runs each update script once per
# user at login, so this also reaches existing users. It changes only
# values that are still at the Plasma default, so a user's own choice
# and the rest of the layout stay.
updates=/usr/share/plasma/shells/org.kde.plasma.desktop/contents/updates
mkdir -p "$updates"
cat > "$updates/armbian-branding.js" <<- EOF
	desktops().forEach(function (d) {
		d.currentConfigGroup = ["Wallpaper", "org.kde.image", "General"];
		var image = d.readConfig("Image");
		if (d.wallpaperPlugin == "org.kde.image" && (!image || image.indexOf("/wallpapers/Next") >= 0)) {
			d.writeConfig("Image", "file://${wallpaper}");
		}
	});
	panels().forEach(function (p) {
		p.widgets("org.kde.plasma.kickoff").forEach(function (w) {
			w.currentConfigGroup = ["General"];
			var icon = w.readConfig("icon");
			if (!icon || icon.indexOf("start-here") === 0) {
				w.writeConfig("icon", "${logo}");
			}
		});
	});
EOF

# Pin Armbian Imager to the panel. The package ships
# "Armbian Imager.desktop"; armbian-imager is only built for some arches.
for imager in armbian-imager.desktop "Armbian Imager.desktop"; do
	[ -f "/usr/share/applications/${imager}" ] || continue
	cat >> "$updates/armbian-branding.js" <<- EOF
	var imager = "applications:${imager}";
	panels().forEach(function (p) {
		p.widgets("org.kde.plasma.icontasks").forEach(function (w) {
			w.currentConfigGroup = ["General"];
			var l = w.readConfig("launchers");
			if (w.configKeys.indexOf("launchers") < 0) {
				// No key: the task manager default (Plasma main.xml).
				l = ["applications:systemsettings.desktop", "applications:org.kde.discover.desktop",
					"preferred://filemanager", "preferred://browser"];
			} else if (!l) {
				// The user removed all launchers.
				l = [];
			} else if (typeof l === "string") {
				l = l.split(",");
			}
			if (l.indexOf(imager) < 0) {
				l.push(imager);
				w.writeConfig("launchers", l);
			}
		});
	});
	EOF
	break
done

# Lock screen wallpaper.
cat > /etc/xdg/kscreenlockerrc <<- EOF
[Greeter][Wallpaper][org.kde.image][General]
Image=file://${wallpaper}
EOF

# System Settings > About this System.
cat > /etc/xdg/kcm-about-distrorc <<- EOF
[General]
LogoPath=${logo}
Website=https://github.com/rations/pivuan
EOF

# No KDE splash: Plymouth goes straight to the desktop.
cat > /etc/xdg/ksplashrc <<- EOF
[KSplash]
Engine=none
Theme=None
EOF

# An earlier version wrote a partial Plasma layout to /etc/skel. New
# users then got a desktop without a panel. Remove it.
skel_layout=/etc/skel/.config/plasma-org.kde.plasma.desktop-appletsrc
if [ -f "$skel_layout" ] && ! grep -q 'org.kde.panel' "$skel_layout"; then
	rm -f "$skel_layout"
fi
