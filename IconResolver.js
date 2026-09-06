// IconResolver.js — Advanced Icon Resolution for Omarchy Dock

.pragma library

var iconCache = {};

var FALLBACK_MAP = {
    "kitty": "kitty",
    "alacritty": "Alacritty",
    "foot": "foot",
    "ghostty": "com.mitchellh.ghostty",
    "google-chrome": "google-chrome",
    "chrome": "google-chrome",
    "chromium": "chromium",
    "yandex-browser": "yandex-browser",
    "firefox": "firefox",
    "code": "com.visualstudio.code",
    "vscode": "com.visualstudio.code",
    "nautilus": "org.gnome.Nautilus",
    "files": "org.gnome.Nautilus",
    "dolphin": "org.kde.dolphin",
    "thunar": "org.xfce.thunar",
    "telegram": "telegram",
    "telegramdesktop": "telegram",
    "discord": "discord",
    "obsidian": "obsidian",
    "spotify": "spotify",
    "x": "twitter-x",
    "x.com": "twitter-x",
    "twitter": "twitter-x",
    "whatsapp": "whatsapp",
    "web.whatsapp.com": "whatsapp",
    "zoom": "zoom",
    "basecamp": "basecamp",
    "launchpad.37signals.com": "basecamp",
    "hey": "hey",
    "cursor": "cursor",
    "google-contacts": "google-contacts",
    "google-maps": "google-maps",
    "google-messages": "google-messages",
    "google-photos": "google-photos",
    "transmission": "transmission-gtk",
    "transmission-gtk": "transmission-gtk",
    "com.transmissionbt.transmission": "transmission-gtk",
    "youtube": "youtube"
};

function sanitizeName(name) {
    if (!name) return "";
    return String(name).toLowerCase().trim()
        .replace(/^org\./, "")
        .replace(/^com\./, "")
        .replace(/^io\./, "")
        .replace(/^dev\./, "")
        .replace(/\.desktop$/, "");
}

function resolveIcon(appClass, appName) {
    var raw = String(appClass || appName || "").trim();
    if (!raw) return "application-x-executable";

    var key = raw.toLowerCase();
    if (iconCache[key]) return iconCache[key];

    var clean = sanitizeName(raw);
    if (FALLBACK_MAP[clean]) {
        iconCache[key] = FALLBACK_MAP[clean];
        return iconCache[key];
    }

    if (FALLBACK_MAP[key]) {
        iconCache[key] = FALLBACK_MAP[key];
        return iconCache[key];
    }

    iconCache[key] = raw;
    return raw;
}
