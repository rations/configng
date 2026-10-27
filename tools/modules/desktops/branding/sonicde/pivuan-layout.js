// SonicDE: Pivuan's first desktop, on top of Plasma's default layout (Silver Dark with the bottom
// panel, set in /etc/xdg/kdeglobals): the SonicBallLightning background on every desktop, and
// launchers in the panel's task manager for System Settings, the file manager, the terminal, the
// browser and VLC. Plasma runs each update script once per user, after the first login has made
// the default layout, so both can be changed afterwards as usual. Installed by pivuan-config
// (postinst/sonicde.sh) in /usr/share/plasma/shells/org.kde.plasma.desktop/contents/updates,
// where Plasma looks too.
const image = "file:///opt/sonicde/share/wallpapers/SonicBallLightning/";
desktops().forEach(function (desktop) {
    desktop.wallpaperPlugin = "org.kde.image";
    desktop.currentConfigGroup = ["Wallpaper", "org.kde.image", "General"];
    desktop.writeConfig("Image", image);
});

const launchers = [
    "applications:systemsettings.desktop",
    "preferred://filemanager",
    "applications:org.kde.konsole.desktop",
    "preferred://browser",
    "applications:vlc.desktop",
];
panels().forEach(function (panel) {
    panel.widgets("org.kde.plasma.taskmanager").forEach(function (tasks) {
        tasks.currentConfigGroup = ["General"];
        tasks.writeConfig("launchers", launchers.join(","));
        tasks.reloadConfig();
    });
});
