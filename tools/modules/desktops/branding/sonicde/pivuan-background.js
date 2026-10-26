// SonicDE: the black Pivuan background on every desktop. Plasma runs each update script once
// per user, after the first login has made the default layout (desktop and panel), so the
// background can be changed afterwards as usual. Installed by pivuan-config
// (postinst/sonicde.sh) in /usr/share/plasma/shells/org.kde.plasma.desktop/contents/updates,
// where Plasma looks too.
const image = "file:///usr/share/backgrounds/pivuan/background-black.png";
desktops().forEach(function (desktop) {
    desktop.wallpaperPlugin = "org.kde.image";
    desktop.currentConfigGroup = ["Wallpaper", "org.kde.image", "General"];
    desktop.writeConfig("Image", image);
});
