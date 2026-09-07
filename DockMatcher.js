// DockMatcher.js — Window matching, icon resolution, and dock item builder for Omarchy Dock

.pragma library

function stripDesktop(id) {
    var value = String(id == null ? "" : id).trim();
    if (value.slice(-8).toLowerCase() === ".desktop") value = value.slice(0, -8);
    if (value.slice(-4).toLowerCase() === ".exe") value = value.slice(0, -4);
    return value;
}

function cleanWindowAppId(id) {
    var value = stripDesktop(id);
    if (!value) return "";
    value = value.replace(/\s*[-_–—]?\s*(?:xwayland|wayland|x11)\s*$/i, "")
                 .replace(/\s*\((?:xwayland|wayland|x11)\)\s*$/i, "")
                 .trim();
    value = value.replace(/\s+v?[0-9]+(?:\.[0-9]+)*[a-z]?\s*$/i, "").trim();
    return value;
}

function toArray(list) {
    if (Array.isArray(list)) return list;
    if (list && typeof list.length === "number") {
        var out = [];
        for (var i = 0; i < list.length; i++) out.push(list[i]);
        return out;
    }
    return [];
}

var KNOWN_APP_DEFAULTS = {
    "syncterm": { id: "syncterm", icon: "syncterm", rawIcon: "syncterm", name: "SyncTERM" },
    "claude": { id: "claude-desktop", icon: "claude-desktop", rawIcon: "claude-desktop", name: "Claude" },
    "claude-desktop": { id: "claude-desktop", icon: "claude-desktop", rawIcon: "claude-desktop", name: "Claude" },
    "claude desktop": { id: "claude-desktop", icon: "claude-desktop", rawIcon: "claude-desktop", name: "Claude" },
    "code": { id: "code", icon: "vscode", rawIcon: "vscode", name: "Visual Studio Code" },
    "vscode": { id: "code", icon: "vscode", rawIcon: "vscode", name: "Visual Studio Code" },
    "org.kde.kwrite": { id: "org.kde.kwrite", icon: "kwrite", rawIcon: "kwrite", name: "KWrite" },
    "kwrite": { id: "org.kde.kwrite", icon: "kwrite", rawIcon: "kwrite", name: "KWrite" },
    "org.kde.krita": { id: "org.kde.krita", icon: "krita", rawIcon: "krita", name: "Krita" },
    "krita": { id: "org.kde.krita", icon: "krita", rawIcon: "krita", name: "Krita" },
    "org.kde.dolphin": { id: "org.kde.dolphin", icon: "org.kde.dolphin", rawIcon: "org.kde.dolphin", name: "Dolphin" },
    "dolphin": { id: "org.kde.dolphin", icon: "org.kde.dolphin", rawIcon: "org.kde.dolphin", name: "Dolphin" },
    "com.mitchellh.ghostty": { id: "com.mitchellh.ghostty", icon: "com.mitchellh.ghostty", rawIcon: "com.mitchellh.ghostty", name: "Ghostty" },
    "ghostty": { id: "com.mitchellh.ghostty", icon: "com.mitchellh.ghostty", rawIcon: "com.mitchellh.ghostty", name: "Ghostty" },
    "google-chrome": { id: "google-chrome", icon: "google-chrome", rawIcon: "google-chrome", name: "Google Chrome" },
    "steam": { id: "steam", icon: "steam", rawIcon: "steam", name: "Steam" },
    "antigravity": { id: "antigravity", icon: "antigravity", rawIcon: "antigravity", name: "Antigravity" },
    "libreoffice-writer": { id: "libreoffice-writer", icon: "libreoffice-writer", rawIcon: "libreoffice-writer", name: "LibreOffice Writer" },
    "libreoffice-impress": { id: "libreoffice-impress", icon: "libreoffice-impress", rawIcon: "libreoffice-impress", name: "LibreOffice Impress" },
    "libreoffice-calc": { id: "libreoffice-calc", icon: "libreoffice-calc", rawIcon: "libreoffice-calc", name: "LibreOffice Calc" },
    "discord": { id: "discord", icon: "omarchy-discord", rawIcon: "omarchy-discord", name: "Discord" },
    "google-photos": { id: "Google Photos", icon: "google-photos", rawIcon: "google-photos", name: "Google Photos" },
    "photos.google.com": { id: "Google Photos", icon: "google-photos", rawIcon: "google-photos", name: "Google Photos" },
    "chrome-photos.google.com__-default": { id: "Google Photos", icon: "google-photos", rawIcon: "google-photos", name: "Google Photos" },
    "google-contacts": { id: "Google Contacts", icon: "google-contacts", rawIcon: "google-contacts", name: "Google Contacts" },
    "contacts.google.com": { id: "Google Contacts", icon: "google-contacts", rawIcon: "google-contacts", name: "Google Contacts" },
    "chrome-contacts.google.com__-default": { id: "Google Contacts", icon: "google-contacts", rawIcon: "google-contacts", name: "Google Contacts" },
    "google-messages": { id: "Google Messages", icon: "google-messages", rawIcon: "google-messages", name: "Google Messages" },
    "messages.google.com": { id: "Google Messages", icon: "google-messages", rawIcon: "google-messages", name: "Google Messages" },
    "chrome-messages.google.com__web_conversations-default": { id: "Google Messages", icon: "google-messages", rawIcon: "google-messages", name: "Google Messages" },
    "google-maps": { id: "Google Maps", icon: "google-maps", rawIcon: "google-maps", name: "Google Maps" },
    "maps.google.com": { id: "Google Maps", icon: "google-maps", rawIcon: "google-maps", name: "Google Maps" },
    "chrome-maps.google.com__-default": { id: "Google Maps", icon: "google-maps", rawIcon: "google-maps", name: "Google Maps" },
    "gmail": { id: "Gmail", icon: "gmail", rawIcon: "gmail", name: "Gmail" },
    "mail.google.com": { id: "Gmail", icon: "gmail", rawIcon: "gmail", name: "Gmail" },
    "google-calendar": { id: "Google Calendar", icon: "google-calendar", rawIcon: "google-calendar", name: "Google Calendar" },
    "calendar.google.com": { id: "Google Calendar", icon: "google-calendar", rawIcon: "google-calendar", name: "Google Calendar" },
    "google-drive": { id: "Google Drive", icon: "google-drive", rawIcon: "google-drive", name: "Google Drive" },
    "drive.google.com": { id: "Google Drive", icon: "google-drive", rawIcon: "google-drive", name: "Google Drive" },
    "google-keep": { id: "Google Keep", icon: "google-keep", rawIcon: "google-keep", name: "Google Keep" },
    "keep.google.com": { id: "Google Keep", icon: "google-keep", rawIcon: "google-keep", name: "Google Keep" },
    "youtube": { id: "YouTube", icon: "youtube", rawIcon: "youtube", name: "YouTube" },
    "youtube.com": { id: "YouTube", icon: "youtube", rawIcon: "youtube", name: "YouTube" },
    "youtube-music": { id: "YouTube Music", icon: "youtube-music", rawIcon: "youtube-music", name: "YouTube Music" },
    "music.youtube.com": { id: "YouTube Music", icon: "youtube-music", rawIcon: "youtube-music", name: "YouTube Music" },
    "yandex-mail": { id: "Яндекс Почта", icon: "yandex-mail", rawIcon: "yandex-mail", name: "Яндекс Почта" },
    "mail.yandex.ru": { id: "Яндекс Почта", icon: "yandex-mail", rawIcon: "yandex-mail", name: "Яндекс Почта" },
    "yandex-music": { id: "Яндекс Музыка", icon: "yandex-music", rawIcon: "yandex-music", name: "Яндекс Музыка" },
    "music.yandex.ru": { id: "Яндекс Музыка", icon: "yandex-music", rawIcon: "yandex-music", name: "Яндекс Музыка" },
    "photoshop": { id: "Photoshop 2017", icon: "Photoshop2017", rawIcon: "Photoshop2017", name: "Photoshop 2017" },
    "photoshop 2017": { id: "Photoshop 2017", icon: "Photoshop2017", rawIcon: "Photoshop2017", name: "Photoshop 2017" },
    "yazi": { id: "yazi", icon: "yazi", rawIcon: "yazi", name: "Yazi" },
    "nvim": { id: "nvim", icon: "nvim", rawIcon: "nvim", name: "Neovim" },
    "neovim": { id: "nvim", icon: "nvim", rawIcon: "nvim", name: "Neovim" },
    "vim": { id: "vim", icon: "vim", rawIcon: "vim", name: "Vim" },
    "nano": { id: "nano", icon: "nano", rawIcon: "nano", name: "GNU nano" },
    "micro": { id: "micro", icon: "micro", rawIcon: "micro", name: "Micro" },
    "helix": { id: "helix", icon: "helix", rawIcon: "helix", name: "Helix" },
    "hx": { id: "helix", icon: "helix", rawIcon: "helix", name: "Helix" },
    "btop": { id: "btop", icon: "btop", rawIcon: "btop", name: "btop" },
    "htop": { id: "htop", icon: "htop", rawIcon: "htop", name: "htop" },
    "ranger": { id: "ranger", icon: "ranger", rawIcon: "ranger", name: "Ranger" },
    "mc": { id: "mc", icon: "mc", rawIcon: "mc", name: "Midnight Commander" },
    "lazygit": { id: "lazygit", icon: "lazygit", rawIcon: "lazygit", name: "LazyGit" },
    "fastfetch": { id: "fastfetch", icon: "fastfetch", rawIcon: "fastfetch", name: "Fastfetch" },
    "brave": { id: "brave-browser", icon: "brave-desktop", rawIcon: "brave-desktop", name: "Brave" },
    "brave-browser": { id: "brave-browser", icon: "brave-desktop", rawIcon: "brave-desktop", name: "Brave" },
    "transmission": { id: "transmission-gtk", icon: "transmission-gtk", rawIcon: "transmission-gtk", name: "Transmission" },
    "transmission-gtk": { id: "transmission-gtk", icon: "transmission-gtk", rawIcon: "transmission-gtk", name: "Transmission" },
    "transmission-qt": { id: "transmission-qt", icon: "transmission-qt", rawIcon: "transmission-qt", name: "Transmission" },
    "com.transmissionbt.transmission": { id: "transmission-gtk", icon: "transmission-gtk", rawIcon: "transmission-gtk", name: "Transmission" },
    "yandex-browser": { id: "yandex-browser", icon: "yandex-browser", rawIcon: "yandex-browser", name: "Yandex Browser" },
    "yandex-browser-stable": { id: "yandex-browser", icon: "yandex-browser", rawIcon: "yandex-browser", name: "Yandex Browser" },
    "ru.yandex.desktop.browser": { id: "yandex-browser", icon: "yandex-browser", rawIcon: "yandex-browser", name: "Yandex Browser" },
    "x": { id: "X", icon: "x", rawIcon: "x", name: "X" },
    "x.com": { id: "X", icon: "x", rawIcon: "x", name: "X" },
    "chrome-x.com__-default": { id: "X", icon: "x", rawIcon: "x", name: "X" },
    "twitter": { id: "X", icon: "twitter-x", rawIcon: "twitter-x", name: "X" },
    "twitter.com": { id: "X", icon: "twitter-x", rawIcon: "twitter-x", name: "X" },
    "basecamp": { id: "Basecamp", icon: "basecamp", rawIcon: "basecamp", name: "Basecamp" },
    "launchpad.37signals.com": { id: "Basecamp", icon: "basecamp", rawIcon: "basecamp", name: "Basecamp" },
    "chrome-launchpad.37signals.com__-default": { id: "Basecamp", icon: "basecamp", rawIcon: "basecamp", name: "Basecamp" },
    "hey": { id: "HEY", icon: "hey", rawIcon: "hey", name: "HEY" },
    "whatsapp": { id: "WhatsApp", icon: "whatsapp", rawIcon: "whatsapp", name: "WhatsApp" },
    "web.whatsapp.com": { id: "WhatsApp", icon: "whatsapp", rawIcon: "whatsapp", name: "WhatsApp" },
    "chrome-web.whatsapp.com__-default": { id: "WhatsApp", icon: "whatsapp", rawIcon: "whatsapp", name: "WhatsApp" },
    "zoom": { id: "Zoom", icon: "zoom", rawIcon: "zoom", name: "Zoom" },
    "cursor": { id: "Cursor", icon: "cursor", rawIcon: "cursor", name: "Cursor" },
    "chrome-appgkjomdnhhdolojlpkjafpklojikld-default": { id: "Cursor", icon: "cursor", rawIcon: "cursor", name: "Cursor" },
    "xdg-desktop-portal-gtk": { id: "xdg-desktop-portal-gtk", icon: "document-open", rawIcon: "document-open", name: "File Chooser" },
    "org.freedesktop.impl.portal.desktop.gtk": { id: "org.freedesktop.impl.portal.desktop.gtk", icon: "document-open", rawIcon: "document-open", name: "File Chooser" },
    "xdg-desktop-portal-gnome": { id: "xdg-desktop-portal-gnome", icon: "document-open", rawIcon: "document-open", name: "File Chooser" },
    "org.freedesktop.impl.portal.desktop.gnome": { id: "org.freedesktop.impl.portal.desktop.gnome", icon: "document-open", rawIcon: "document-open", name: "File Chooser" },
    "xdg-desktop-portal-kde": { id: "xdg-desktop-portal-kde", icon: "document-open", rawIcon: "document-open", name: "File Chooser" },
    "org.freedesktop.impl.portal.desktop.kde": { id: "org.freedesktop.impl.portal.desktop.kde", icon: "document-open", rawIcon: "document-open", name: "File Chooser" },
    "xdg-desktop-portal-lxqt": { id: "xdg-desktop-portal-lxqt", icon: "document-open", rawIcon: "document-open", name: "File Chooser" },
    "org.freedesktop.impl.portal.desktop.lxqt": { id: "org.freedesktop.impl.portal.desktop.lxqt", icon: "document-open", rawIcon: "document-open", name: "File Chooser" },
    "xdg-desktop-portal-hyprland": { id: "xdg-desktop-portal-hyprland", icon: "document-open", rawIcon: "document-open", name: "File Chooser" },
    "org.freedesktop.impl.portal.desktop.hyprland": { id: "org.freedesktop.impl.portal.desktop.hyprland", icon: "document-open", rawIcon: "document-open", name: "File Chooser" },
    "xdg-desktop-portal-wlr": { id: "xdg-desktop-portal-wlr", icon: "document-open", rawIcon: "document-open", name: "File Chooser" },
    "org.freedesktop.impl.portal.desktop.wlr": { id: "org.freedesktop.impl.portal.desktop.wlr", icon: "document-open", rawIcon: "document-open", name: "File Chooser" },
    "xdg-desktop-portal": { id: "xdg-desktop-portal", icon: "document-open", rawIcon: "document-open", name: "File Chooser" },
    "org.freedesktop.portal": { id: "org.freedesktop.portal", icon: "document-open", rawIcon: "document-open", name: "File Chooser" },
    "zenity": { id: "zenity", icon: "dialog-information", rawIcon: "dialog-information", name: "Dialog" },
    "kdialog": { id: "kdialog", icon: "dialog-information", rawIcon: "dialog-information", name: "Dialog" },
    "hyprpolkitagent": { id: "hyprpolkitagent", icon: "dialog-password", rawIcon: "dialog-password", name: "Authentication" },
    "polkit-gnome-authentication-agent-1": { id: "polkit-gnome-authentication-agent-1", icon: "dialog-password", rawIcon: "dialog-password", name: "Authentication" },
    "org.kde.polkit-kde-authentication-agent-1": { id: "org.kde.polkit-kde-authentication-agent-1", icon: "dialog-password", rawIcon: "dialog-password", name: "Authentication" },
    "pavucontrol": { id: "pavucontrol", icon: "multimedia-volume-control", rawIcon: "multimedia-volume-control", name: "Volume Control" },
    "org.pulseaudio.pavucontrol": { id: "pavucontrol", icon: "multimedia-volume-control", rawIcon: "multimedia-volume-control", name: "Volume Control" },
    "pwvucontrol": { id: "pwvucontrol", icon: "multimedia-volume-control", rawIcon: "multimedia-volume-control", name: "PipeWire Volume Control" },
    "com.saivert.pwvucontrol": { id: "pwvucontrol", icon: "multimedia-volume-control", rawIcon: "multimedia-volume-control", name: "PipeWire Volume Control" },
    "satty": { id: "satty", icon: "accessories-screenshot", rawIcon: "accessories-screenshot", name: "Satty" },
    "com.gabm.satty": { id: "satty", icon: "accessories-screenshot", rawIcon: "accessories-screenshot", name: "Satty" },
    "flameshot": { id: "flameshot", icon: "flameshot", rawIcon: "flameshot", name: "Flameshot" },
    "org.flameshot.Flameshot": { id: "flameshot", icon: "flameshot", rawIcon: "flameshot", name: "Flameshot" },
    "file-roller": { id: "file-roller", icon: "utilities-file-archiver", rawIcon: "utilities-file-archiver", name: "Archive Manager" },
    "org.gnome.FileRoller": { id: "file-roller", icon: "utilities-file-archiver", rawIcon: "utilities-file-archiver", name: "Archive Manager" },
    "ark": { id: "ark", icon: "utilities-file-archiver", rawIcon: "utilities-file-archiver", name: "Ark" },
    "org.kde.ark": { id: "ark", icon: "utilities-file-archiver", rawIcon: "utilities-file-archiver", name: "Ark" },
    "imv": { id: "imv", icon: "image-viewer", rawIcon: "image-viewer", name: "Image Viewer" },
    "swayimg": { id: "swayimg", icon: "image-viewer", rawIcon: "image-viewer", name: "Image Viewer" },
    "feh": { id: "feh", icon: "image-viewer", rawIcon: "image-viewer", name: "feh" },
    "zathura": { id: "zathura", icon: "document-viewer", rawIcon: "document-viewer", name: "Zathura" },
    "org.pwmt.zathura": { id: "zathura", icon: "document-viewer", rawIcon: "document-viewer", name: "Zathura" },
    "galculator": { id: "galculator", icon: "accessories-calculator", rawIcon: "accessories-calculator", name: "Calculator" },
    "gnome-calculator": { id: "gnome-calculator", icon: "accessories-calculator", rawIcon: "accessories-calculator", name: "Calculator" },
    "org.gnome.Calculator": { id: "gnome-calculator", icon: "accessories-calculator", rawIcon: "accessories-calculator", name: "Calculator" },
    "cliamp": { id: "cliamp", icon: "cliamp", rawIcon: "cliamp", name: "cliamp" },
    "org.omarchy.cliamp": { id: "cliamp", icon: "cliamp", rawIcon: "cliamp", name: "cliamp" }
};

var FALLBACK_ICON_CANDIDATES = {
    "syncterm": ["syncterm", "utilities-terminal", "terminal"],
    "claude": ["claude-desktop", "claude", "anthropic", "chat-claude"],
    "claude-desktop": ["claude-desktop", "claude", "anthropic", "chat-claude"],
    "claude desktop": ["claude-desktop", "claude", "anthropic", "chat-claude"],
    "brave": ["brave-desktop", "brave-browser", "brave"],
    "brave-browser": ["brave-desktop", "brave-browser", "brave"],
    "transmission": ["transmission-gtk", "transmission", "com.transmissionbt.Transmission", "transmission-qt"],
    "transmission-gtk": ["transmission-gtk", "transmission", "com.transmissionbt.Transmission", "transmission-qt"],
    "transmission-qt": ["transmission-qt", "transmission", "com.transmissionbt.Transmission", "transmission-gtk"],
    "com.transmissionbt.transmission": ["transmission-gtk", "transmission", "com.transmissionbt.Transmission", "transmission-qt"],
    "yandex-browser": ["yandex-browser", "yandex-browser-stable", "ru.yandex.desktop.browser", "yandex"],
    "yandex-browser-stable": ["yandex-browser", "yandex-browser-stable", "ru.yandex.desktop.browser", "yandex"],
    "ru.yandex.desktop.browser": ["yandex-browser", "yandex-browser-stable", "ru.yandex.desktop.browser", "yandex"],
    "x": ["x", "twitter-x", "twitter", "solstice-twitter-twitter", "unity-webapps-twitter"],
    "x.com": ["x", "twitter-x", "twitter", "solstice-twitter-twitter", "unity-webapps-twitter"],
    "chrome-x.com__-default": ["x", "twitter-x", "twitter"],
    "twitter": ["twitter-x", "twitter", "x", "solstice-twitter-twitter", "unity-webapps-twitter"],
    "twitter.com": ["twitter-x", "twitter", "x"],
    "basecamp": ["basecamp"],
    "launchpad.37signals.com": ["basecamp"],
    "chrome-launchpad.37signals.com__-default": ["basecamp"],
    "hey": ["hey", "mail-client", "internet-mail"],
    "whatsapp": ["whatsapp", "whatsapp-for-linux", "com.whatsapp.WhatsApp"],
    "web.whatsapp.com": ["whatsapp", "whatsapp-for-linux", "com.whatsapp.WhatsApp"],
    "chrome-web.whatsapp.com__-default": ["whatsapp", "whatsapp-for-linux", "com.whatsapp.WhatsApp"],
    "zoom": ["zoom", "Zoom", "us.zoom.Zoom"],
    "cursor": ["cursor", "cursor-editor", "code", "com.visualstudio.code"],
    "chrome-appgkjomdnhhdolojlpkjafpklojikld-default": ["cursor", "cursor-editor", "code", "com.visualstudio.code"],
    "ghostty": ["com.mitchellh.ghostty", "ghostty"],
    "com.mitchellh.ghostty": ["com.mitchellh.ghostty", "ghostty"],
    "yazi": ["yazi", "system-file-manager"],
    "nvim": ["nvim", "neovim", "text-editor"],
    "neovim": ["nvim", "neovim", "text-editor"],
    "vim": ["vim", "text-editor"],
    "nano": ["nano", "text-editor"],
    "micro": ["micro", "text-editor"],
    "helix": ["helix", "text-editor"],
    "btop": ["btop", "utilities-system-monitor"],
    "htop": ["htop", "utilities-system-monitor"],
    "ranger": ["ranger", "system-file-manager"],
    "mc": ["mc", "MidnightCommander", "system-file-manager"],
    "lazygit": ["lazygit", "git"],
    "lazydocker": ["lazydocker", "docker"],
    "ncmpcpp": ["ncmpcpp", "audio-player", "multimedia-audio-player"],
    "cmus": ["cmus", "audio-player", "multimedia-audio-player"],
    "code": ["com.visualstudio.code", "visual-studio-code", "visualstudiocode", "code-oss", "vscode", "code"],
    "vscode": ["com.visualstudio.code", "visual-studio-code", "visualstudiocode", "code-oss", "vscode", "code"],
    "com.visualstudio.code": ["com.visualstudio.code", "visual-studio-code", "visualstudiocode", "code-oss", "vscode", "code"],
    "dolphin": ["org.kde.dolphin", "dolphin", "system-file-manager"],
    "org.kde.dolphin": ["org.kde.dolphin", "dolphin", "system-file-manager"],
    "nautilus": ["org.gnome.Nautilus", "org.gnome.nautilus", "nautilus", "system-file-manager", "file-manager"],
    "org.gnome.nautilus": ["org.gnome.Nautilus", "org.gnome.nautilus", "nautilus", "system-file-manager", "file-manager"],
    "org.gnome.Nautilus": ["org.gnome.Nautilus", "org.gnome.nautilus", "nautilus", "system-file-manager", "file-manager"],
    "files": ["org.gnome.Nautilus", "org.gnome.nautilus", "nautilus", "system-file-manager", "file-manager"],
    "kwrite": ["org.kde.kwrite", "kwrite"],
    "org.kde.kwrite": ["org.kde.kwrite", "kwrite"],
    "krita": ["org.kde.krita", "krita"],
    "org.kde.krita": ["org.kde.krita", "krita"],
    "google-chrome": ["google-chrome", "chrome", "google-chrome-stable"],
    "steam": ["steam", "steam-launcher"],
    "antigravity": ["antigravity"],
    "libreoffice-writer": ["libreoffice-writer", "libreoffice-oasis-writer"],
    "libreoffice-calc": ["libreoffice-calc", "libreoffice-oasis-calc"],
    "libreoffice-impress": ["libreoffice-impress", "libreoffice-oasis-impress"],
    "discord": ["omarchy-discord", "discord", "com.discordapp.Discord"],
    "telegram": ["org.telegram.desktop", "telegram", "telegramdesktop", "org.telegram"],
    "org.telegram": ["org.telegram.desktop", "telegram", "telegramdesktop", "org.telegram"],
    "telegramdesktop": ["org.telegram.desktop", "telegram", "telegramdesktop", "org.telegram"],
    "obsidian": ["obsidian", "md.obsidian.Obsidian"],
    "spotify": ["spotify", "spotify-client"],
    "google-photos": ["google-photos", "photos", "googlephotos"],
    "photos": ["google-photos", "photos"],
    "photos.google.com": ["google-photos", "photos"],
    "chrome-photos.google.com__-default": ["google-photos", "photos"],
    "google-contacts": ["google-contacts", "contacts", "googlecontacts"],
    "contacts": ["google-contacts", "contacts"],
    "contacts.google.com": ["google-contacts", "contacts"],
    "chrome-contacts.google.com__-default": ["google-contacts", "contacts"],
    "google-messages": ["google-messages", "messages", "googlemessages"],
    "messages": ["google-messages", "messages"],
    "messages.google.com": ["google-messages", "messages"],
    "chrome-messages.google.com__web_conversations-default": ["google-messages", "messages"],
    "google-maps": ["google-maps", "maps", "googlemaps"],
    "maps.google.com": ["google-maps", "maps"],
    "chrome-maps.google.com__-default": ["google-maps", "maps"],
    "gmail": ["gmail", "google-gmail", "mail-google"],
    "mail.google.com": ["gmail", "google-gmail"],
    "google-calendar": ["google-calendar", "calendar-google"],
    "calendar.google.com": ["google-calendar", "calendar-google"],
    "google-drive": ["google-drive", "drive-google"],
    "drive.google.com": ["google-drive", "drive-google"],
    "google-keep": ["google-keep", "keep-google"],
    "keep.google.com": ["google-keep", "keep-google"],
    "youtube": ["youtube", "youtube-browser"],
    "youtube.com": ["youtube", "youtube-browser"],
    "youtube-music": ["youtube-music", "music-youtube"],
    "music.youtube.com": ["youtube-music", "music-youtube"],
    "yandex-mail": ["yandex-mail", "mail-yandex", "yandex-browser-mail"],
    "mail.yandex.ru": ["yandex-mail", "mail-yandex"],
    "yandex-music": ["yandex-music", "music-yandex"],
    "music.yandex.ru": ["yandex-music", "music-yandex"],
    "photoshop": ["Photoshop2017", "photoshop", "adobe-photoshop"],
    "photoshop 2017": ["Photoshop2017", "photoshop", "adobe-photoshop"],
    "xdg-desktop-portal-gtk": ["document-open", "document-save-as", "document-save", "system-file-manager", "org.gnome.Nautilus", "file-manager", "folder"],
    "org.freedesktop.impl.portal.desktop.gtk": ["document-open", "document-save-as", "document-save", "system-file-manager", "org.gnome.Nautilus", "file-manager", "folder"],
    "xdg-desktop-portal-gnome": ["document-open", "document-save-as", "document-save", "system-file-manager", "org.gnome.Nautilus", "file-manager", "folder"],
    "org.freedesktop.impl.portal.desktop.gnome": ["document-open", "document-save-as", "document-save", "system-file-manager", "org.gnome.Nautilus", "file-manager", "folder"],
    "xdg-desktop-portal-kde": ["document-open", "document-save-as", "document-save", "system-file-manager", "org.kde.dolphin", "dolphin", "file-manager", "folder"],
    "org.freedesktop.impl.portal.desktop.kde": ["document-open", "document-save-as", "document-save", "system-file-manager", "org.kde.dolphin", "dolphin", "file-manager", "folder"],
    "xdg-desktop-portal-lxqt": ["document-open", "document-save-as", "document-save", "system-file-manager", "file-manager", "folder"],
    "org.freedesktop.impl.portal.desktop.lxqt": ["document-open", "document-save-as", "document-save", "system-file-manager", "file-manager", "folder"],
    "xdg-desktop-portal-hyprland": ["document-open", "document-save-as", "document-save", "system-file-manager", "file-manager", "folder"],
    "org.freedesktop.impl.portal.desktop.hyprland": ["document-open", "document-save-as", "document-save", "system-file-manager", "file-manager", "folder"],
    "xdg-desktop-portal-wlr": ["document-open", "document-save-as", "document-save", "system-file-manager", "file-manager", "folder"],
    "org.freedesktop.impl.portal.desktop.wlr": ["document-open", "document-save-as", "document-save", "system-file-manager", "file-manager", "folder"],
    "xdg-desktop-portal": ["document-open", "document-save-as", "document-save", "system-file-manager", "file-manager", "folder"],
    "org.freedesktop.portal": ["document-open", "document-save-as", "document-save", "system-file-manager", "file-manager", "folder"],
    "zenity": ["dialog-information", "dialog-question", "dialog-warning", "utilities-terminal"],
    "kdialog": ["dialog-information", "dialog-question", "dialog-warning", "utilities-terminal"],
    "hyprpolkitagent": ["dialog-password", "security-high", "system-lock-screen", "preferences-system"],
    "polkit-gnome-authentication-agent-1": ["dialog-password", "security-high", "system-lock-screen", "preferences-system"],
    "org.kde.polkit-kde-authentication-agent-1": ["dialog-password", "security-high", "system-lock-screen", "preferences-system"],
    "pavucontrol": ["multimedia-volume-control", "audio-card", "pavucontrol", "audio-volume-high"],
    "org.pulseaudio.pavucontrol": ["multimedia-volume-control", "audio-card", "pavucontrol", "audio-volume-high"],
    "pwvucontrol": ["multimedia-volume-control", "audio-card", "pwvucontrol", "audio-volume-high"],
    "com.saivert.pwvucontrol": ["multimedia-volume-control", "audio-card", "pwvucontrol", "audio-volume-high"],
    "satty": ["accessories-screenshot", "applets-screenshooter", "accessories-image-viewer"],
    "com.gabm.satty": ["accessories-screenshot", "applets-screenshooter", "accessories-image-viewer"],
    "flameshot": ["flameshot", "accessories-screenshot", "applets-screenshooter"],
    "org.flameshot.Flameshot": ["flameshot", "accessories-screenshot", "applets-screenshooter"],
    "file-roller": ["utilities-file-archiver", "archive-manager", "file-roller", "org.gnome.FileRoller"],
    "org.gnome.FileRoller": ["utilities-file-archiver", "archive-manager", "file-roller", "org.gnome.FileRoller"],
    "ark": ["utilities-file-archiver", "archive-manager", "ark", "org.kde.ark"],
    "org.kde.ark": ["utilities-file-archiver", "archive-manager", "ark", "org.kde.ark"],
    "imv": ["image-viewer", "accessories-image-viewer", "multimedia-photo-viewer"],
    "swayimg": ["image-viewer", "accessories-image-viewer", "multimedia-photo-viewer"],
    "feh": ["image-viewer", "accessories-image-viewer", "feh"],
    "zathura": ["document-viewer", "application-pdf", "org.pwmt.zathura"],
    "org.pwmt.zathura": ["document-viewer", "application-pdf", "org.pwmt.zathura"],
    "galculator": ["accessories-calculator", "calc", "calculator"],
    "gnome-calculator": ["accessories-calculator", "calc", "calculator", "org.gnome.Calculator"],
    "org.gnome.Calculator": ["accessories-calculator", "calc", "calculator", "org.gnome.Calculator"],
    "cliamp": ["cliamp", "audio-player", "multimedia-audio-player", "music"],
    "org.omarchy.cliamp": ["cliamp", "audio-player", "multimedia-audio-player", "music"],
    "soffice": ["libreoffice-startcenter", "libreoffice-main", "document-viewer", "accessories-text-editor"],
    "spotify": ["spotify-client", "spotify", "audio-player", "multimedia-audio-player"],
    "com.spotify.client": ["spotify-client", "spotify", "audio-player"],
    "obsidian": ["md.obsidian.Obsidian", "obsidian", "accessories-text-editor"],
    "md.obsidian.obsidian": ["obsidian", "md.obsidian.Obsidian", "accessories-text-editor"],
    "lite_xl": ["lite-xl", "lite_xl", "text-editor", "accessories-text-editor"],
    "lite-xl": ["lite-xl", "lite_xl", "text-editor", "accessories-text-editor"],
    "com.lite_xl.litexl": ["lite-xl", "lite_xl", "text-editor", "accessories-text-editor"],
    "xdg-desktop-portal-gtk": ["document-open", "file-manager", "preferences-desktop"]
};

function getCandidates(rawIcon, icon, appId) {
    var list = [];
    function add(c) {
        if (!c) return;
        var s = String(c).trim();
        if (s.length === 0) return;
        if (list.indexOf(s) === -1) list.push(s);
        var sLow = s.toLowerCase();
        if (list.indexOf(sLow) === -1) list.push(sLow);

        if (s.indexOf("_") !== -1) {
            var hyp = s.replace(/_/g, "-");
            if (list.indexOf(hyp) === -1) list.push(hyp);
            var hypLow = hyp.toLowerCase();
            if (list.indexOf(hypLow) === -1) list.push(hypLow);
        }
        if (s.indexOf("-") !== -1) {
            var und = s.replace(/-/g, "_");
            if (list.indexOf(und) === -1) list.push(und);
            var undLow = und.toLowerCase();
            if (list.indexOf(undLow) === -1) list.push(undLow);
        }
        if (s.indexOf(" ") !== -1) {
            var dash = s.replace(/\s+/g, "-");
            if (list.indexOf(dash) === -1) list.push(dash);
            var dashLow = dash.toLowerCase();
            if (list.indexOf(dashLow) === -1) list.push(dashLow);
        }

        var cleaned = cleanWindowAppId(s);
        if (cleaned && cleaned !== s) {
            if (list.indexOf(cleaned) === -1) list.push(cleaned);
            var cleanedLow = cleaned.toLowerCase();
            if (list.indexOf(cleanedLow) === -1) list.push(cleanedLow);
        }

        var firstToken = (cleaned || s).split(/[\s\-_]+/)[0];
        if (firstToken && firstToken.length >= 3 && firstToken !== s && firstToken !== cleaned) {
            if (list.indexOf(firstToken) === -1) list.push(firstToken);
            var firstLow = firstToken.toLowerCase();
            if (list.indexOf(firstLow) === -1) list.push(firstLow);
        }
    }
    add(rawIcon);
    add(icon);
    add(appId);
    var clean = String(appId || rawIcon || "").toLowerCase().replace(/\.desktop$/, "");
    add(clean);
    var cleanedAppId = cleanWindowAppId(appId);
    if (cleanedAppId) add(cleanedAppId);
    var withoutPrefix = clean.replace(/^(org|com|io|net|dev)\.[^.]+\./, "");
    add(withoutPrefix);
    var lastPart = clean.split(".").pop();
    add(lastPart);

    if (clean.indexOf("com.transmissionbt.transmission") === 0 || clean === "transmission" || clean === "transmission-gtk" || clean === "transmission-qt") {
        add("transmission-gtk");
        add("transmission");
        add("com.transmissionbt.Transmission");
        add("transmission-qt");
    }

    if (clean.indexOf("steam_app_") === 0) {
        var sGameId = clean.replace(/^steam_app_/, "");
        add("steam_icon_" + sGameId);
        add("steam_app_" + sGameId);
        add("steam");
    }

    if (FALLBACK_ICON_CANDIDATES[clean]) {
        var fb = FALLBACK_ICON_CANDIDATES[clean];
        for (var i = 0; i < fb.length; i++) add(fb[i]);
    }
    if (FALLBACK_ICON_CANDIDATES[lastPart]) {
        var fb2 = FALLBACK_ICON_CANDIDATES[lastPart];
        for (var j = 0; j < fb2.length; j++) add(fb2[j]);
    }

    if (clean.indexOf("portal") !== -1 || clean.indexOf("file-chooser") !== -1 || clean.indexOf("filechooser") !== -1 || clean.indexOf("file-picker") !== -1) {
        add("document-open");
        add("document-save-as");
        add("document-save");
        add("system-file-manager");
        add("org.gnome.Nautilus");
        add("org.kde.dolphin");
        add("file-manager");
        add("folder");
    }

    if (clean.indexOf("org.omarchy.") === 0 || clean.indexOf("omarchy-") === 0 || clean.indexOf("omarchy.") === 0) {
        if (clean.indexOf("update") !== -1) {
            add("system-software-update");
            add("software-update-available");
            add("update-manager");
            add("system-upgrade");
        }
        if (clean.indexOf("config") !== -1 || clean.indexOf("settings") !== -1 || clean.indexOf("edit") !== -1) {
            add("preferences-system");
            add("configuration-section");
            add("system-settings");
            add("preferences-desktop");
        }
        if (clean.indexOf("about") !== -1 || clean.indexOf("info") !== -1) {
            add("help-about");
            add("help");
            add("dialog-information");
        }
        add("omarchy");
        add("utilities-terminal");
        add("com.mitchellh.ghostty");
        add("ghostty");
    }

    var chromeDom = extractChromeDomain(clean);
    if (chromeDom) {
        add(chromeDom);
        if (FALLBACK_ICON_CANDIDATES[chromeDom]) {
            var fbc = FALLBACK_ICON_CANDIDATES[chromeDom];
            for (var fc = 0; fc < fbc.length; fc++) add(fbc[fc]);
        }
        var domParts = chromeDom.split(".");
        for (var dp = 0; dp < domParts.length; dp++) {
            var dpart = domParts[dp];
            if (dpart.length >= 3 && dpart !== "com" && dpart !== "org" && dpart !== "net") {
                add(dpart);
                if (FALLBACK_ICON_CANDIDATES[dpart]) {
                    var fbd = FALLBACK_ICON_CANDIDATES[dpart];
                    for (var fd = 0; fd < fbd.length; fd++) add(fbd[fd]);
                }
            }
        }
    }
    return list;
}

function normalizeKey(str) {
    if (!str) return "";
    return String(str).toLowerCase().replace(/[^a-z0-9]/g, "");
}

function extractChromeDomain(appClass) {
    if (!appClass) return "";
    var s = String(appClass).toLowerCase();
    if (s === "brave-browser" || s === "chromium-browser" || s === "chrome-browser" || s === "yandex-browser" || s === "yandex-browser-stable") {
        return "";
    }
    if (s.indexOf("chrome-") === 0 || s.indexOf("chromium-") === 0 || s.indexOf("brave-") === 0 || s.indexOf("edge-") === 0) {
        var dom = s.replace(/^(chrome|chromium|brave|edge)-/, "")
                   .replace(/__-.*$/, "")
                   .replace(/__.*$/, "")
                   .replace(/_\/.*$/, "")
                   .replace(/^-+/, "");
        if (dom === "browser") return "";
        return dom;
    }
    return "";
}

function unwrapEntry(e) {
    if (!e) return null;
    if (e.entry && typeof e.entry === "object") return e.entry;
    return e;
}

function findEntry(desktopEntries, appId) {
    var id = stripDesktop(appId);
    if (!id) return null;

    if (desktopEntries && desktopEntries.length > 0) {
        var list = toArray(desktopEntries);
        var target = id.toLowerCase();
        var targetNorm = normalizeKey(target);
        var chromeDom = extractChromeDomain(id);
        var cleaned = cleanWindowAppId(id);
        var cleanTarget = cleaned ? cleaned.toLowerCase() : "";
        var cleanNorm = cleanTarget ? normalizeKey(cleanTarget) : "";
        var firstToken = cleanTarget ? cleanTarget.split(/[\s\-_]+/)[0] : "";
        var hypTarget = (cleanTarget && cleanTarget.indexOf(" ") !== -1) ? cleanTarget.replace(/\s+/g, "-") : "";

        // Transmission GTK Wayland dynamic app ID resolution (e.g. com.transmissionbt.transmission_54_620133)
        if (target.indexOf("com.transmissionbt.transmission") === 0 || target === "transmission" || target === "transmission-gtk" || target === "transmission-qt") {
            for (var tr = 0; tr < list.length; tr++) {
                var tre = unwrapEntry(list[tr]);
                if (!tre) continue;
                var trId = stripDesktop(tre.id || "").toLowerCase();
                var trExec = String(tre.exec || "").toLowerCase().split(/\s+/)[0].split("/").pop();
                if (trId === "transmission-gtk" || trId === "transmission-qt" || trId === "transmission" || trId === "com.transmissionbt.transmission" ||
                    trExec === "transmission-gtk" || trExec === "transmission-qt" || trExec === "transmission") {
                    return tre;
                }
            }
        }

        // Steam game window resolution (e.g. steam_app_1700 matching steam://rungameid/1700 or steam_icon_1700)
        if (target.indexOf("steam_app_") === 0) {
            var gameId = target.replace(/^steam_app_/, "");
            for (var st = 0; st < list.length; st++) {
                var ste = unwrapEntry(list[st]);
                if (!ste) continue;
                var steExec = String(ste.exec || "").toLowerCase();
                var steIcon = String(ste.icon || "").toLowerCase();
                if (steExec.indexOf("rungameid/" + gameId) !== -1 || steIcon === "steam_icon_" + gameId || steIcon === "steam_app_" + gameId) {
                    return ste;
                }
            }
        }

        // Yandex Browser resolution (yandex-browser, yandex-browser-stable, ru.yandex.desktop.browser)
        if (target === "yandex-browser" || target === "yandex-browser-stable" || target === "ru.yandex.desktop.browser") {
            for (var yb = 0; yb < list.length; yb++) {
                var ybe = unwrapEntry(list[yb]);
                if (!ybe) continue;
                var ybeId = stripDesktop(ybe.id || "").toLowerCase();
                var ybeExec = String(ybe.exec || "").toLowerCase().split(/\s+/)[0].split("/").pop();
                if (ybeId === "yandex-browser" || ybeId === "ru.yandex.desktop.browser" || ybeExec === "yandex-browser-stable" || ybeExec === "yandex-browser") {
                    return ybe;
                }
            }
        }

        // 1. Exact match on entry.id (with and without .desktop / .exe)
        for (var i = 0; i < list.length; i++) {
            var entry = unwrapEntry(list[i]);
            if (!entry) continue;
            var entryId = stripDesktop(entry.id || "").toLowerCase();
            if (entryId === target || (cleanTarget && entryId === cleanTarget) || (hypTarget && entryId === hypTarget) || (firstToken.length >= 3 && entryId === firstToken)) return entry;
        }

        // 1b. Exact match on entry.name (case-insensitive)
        for (var m = 0; m < list.length; m++) {
            var em = unwrapEntry(list[m]);
            if (!em) continue;
            var emName = String(em.name || "").toLowerCase();
            if (emName === target || (cleanTarget && emName === cleanTarget) || (hypTarget && emName === hypTarget) || (firstToken.length >= 3 && emName === firstToken)) return em;
        }

        // 1c. Exact URL / Domain match in exec or entry.id for Chrome Web Apps
        if (chromeDom.length > 0) {
            for (var c = 0; c < list.length; c++) {
                var ce = unwrapEntry(list[c]);
                if (!ce) continue;
                var cExec = String(ce.exec || "").toLowerCase();
                var cId = stripDesktop(ce.id || "").toLowerCase();
                if (cExec.indexOf(chromeDom) !== -1 || cId.indexOf(chromeDom) !== -1) {
                    return ce;
                }
            }
        }

        // 2. Normalized key match on entry.id, name, or icon
        for (var j = 0; j < list.length; j++) {
            var e = unwrapEntry(list[j]);
            if (!e) continue;
            var eId = stripDesktop(e.id || "").toLowerCase();
            var eIdNorm = normalizeKey(eId);
            var eName = String(e.name || "").toLowerCase();
            var eNameNorm = normalizeKey(eName);
            var eIcon = String(e.icon || "").toLowerCase();
            var eIconNorm = normalizeKey(eIcon);

            if (targetNorm.length > 0 && (eIdNorm === targetNorm || eNameNorm === targetNorm || eIconNorm === targetNorm)) {
                return e;
            }
            if (cleanNorm.length > 0 && (eIdNorm === cleanNorm || eNameNorm === cleanNorm || eIconNorm === cleanNorm)) {
                return e;
            }
        }

        // 2b. Known App Default ID match (e.g. target "photoshop" matching "Photoshop 2017.desktop")
        var defKey = target;
        if (!KNOWN_APP_DEFAULTS[defKey] && cleanTarget && KNOWN_APP_DEFAULTS[cleanTarget]) defKey = cleanTarget;
        if (!KNOWN_APP_DEFAULTS[defKey] && firstToken && KNOWN_APP_DEFAULTS[firstToken]) defKey = firstToken;
        if (KNOWN_APP_DEFAULTS[defKey]) {
            var defId = stripDesktop(KNOWN_APP_DEFAULTS[defKey].id || "").toLowerCase();
            if (defId) {
                for (var kd = 0; kd < list.length; kd++) {
                    var kde = unwrapEntry(list[kd]);
                    if (!kde) continue;
                    var kdeId = stripDesktop(kde.id || "").toLowerCase();
                    if (kdeId === defId) return kde;
                }
            }
        }

        // 2c. Reverse-domain suffix match (e.g. org.omarchy.cliamp -> cliamp, io.github.yazi -> yazi)
        var strippedTarget = target.replace(/^(org|com|io|net|dev)\.[^.]+\./i, "").toLowerCase();
        var lastPartTarget = target.split(".").pop().toLowerCase();
        if (strippedTarget !== target || lastPartTarget !== target) {
            for (var sp = 0; sp < list.length; sp++) {
                var spe = unwrapEntry(list[sp]);
                if (!spe) continue;
                var speId = stripDesktop(spe.id || "").toLowerCase();
                var speName = String(spe.name || "").toLowerCase();
                var speExec = String(spe.exec || "").toLowerCase().split(/\s+/)[0].split("/").pop();
                if (speId === strippedTarget || speName === strippedTarget || speExec === strippedTarget ||
                    speId === lastPartTarget || speName === lastPartTarget || speExec === lastPartTarget) {
                    return spe;
                }
            }
        }

        // 3. Web App / Chrome domain token word matching (matching whole words, NOT substring like photos in photoshop)
        if (chromeDom.length > 0) {
            var domParts = chromeDom.split(".");
            var meaningfulParts = [];
            for (var p = 0; p < domParts.length; p++) {
                var part = domParts[p];
                if (part.length >= 1 && part !== "com" && part !== "org" && part !== "net" && part !== "web" && part !== "app" && part !== "google" && part !== "yandex" && part !== "microsoft" && part !== "apple") {
                    meaningfulParts.push(part);
                }
            }

            if (meaningfulParts.length > 0) {
                for (var c2 = 0; c2 < list.length; c2++) {
                    var ce2 = unwrapEntry(list[c2]);
                    if (!ce2) continue;
                    var cNameTokens = String(ce2.name || "").toLowerCase().split(/[\s\-_\.]+/);
                    var cIdTokens = stripDesktop(ce2.id || "").toLowerCase().split(/[\s\-_\.]+/);
                    var cIconTokens = String(ce2.icon || "").toLowerCase().split(/[\s\-_\.]+/);
                    var allTokens = cNameTokens.concat(cIdTokens).concat(cIconTokens);

                    var allMatched = true;
                    for (var mp = 0; mp < meaningfulParts.length; mp++) {
                        var mpart = meaningfulParts[mp];
                        var partFound = false;
                        for (var t = 0; t < allTokens.length; t++) {
                            var tok = allTokens[t];
                            if (tok === mpart || (mpart.endsWith("s") && tok === mpart.slice(0, -1)) || (tok.endsWith("s") && tok.slice(0, -1) === mpart)) {
                                partFound = true;
                                break;
                            }
                        }
                        if (!partFound) {
                            allMatched = false;
                            break;
                        }
                    }
                    if (allMatched) {
                        return ce2;
                    }
                }
            }
        }

        // 4. Substring / Exec binary match (exact binary name or exact name)
        for (var k = 0; k < list.length; k++) {
            var el = unwrapEntry(list[k]);
            if (!el) continue;
            var exec = String(el.exec || "").toLowerCase();
            var execBin = exec.split(/\s+/)[0].split("/").pop();
            var name = String(el.name || "").toLowerCase();
            if (execBin === target || name === target || (cleanTarget && (execBin === cleanTarget || name === cleanTarget)) || (firstToken.length >= 3 && (execBin === firstToken || name === firstToken))) return el;
        }
    }

    var cleanId = id.toLowerCase();
    if (KNOWN_APP_DEFAULTS[cleanId]) return KNOWN_APP_DEFAULTS[cleanId];
    var cleanedId = cleanWindowAppId(id).toLowerCase();
    if (cleanedId && KNOWN_APP_DEFAULTS[cleanedId]) return KNOWN_APP_DEFAULTS[cleanedId];
    var firstTokId = cleanedId ? cleanedId.split(/[\s\-_]+/)[0] : "";
    if (firstTokId && KNOWN_APP_DEFAULTS[firstTokId]) return KNOWN_APP_DEFAULTS[firstTokId];
    if (chromeDom && KNOWN_APP_DEFAULTS[chromeDom]) return KNOWN_APP_DEFAULTS[chromeDom];

    return null;
}

function resolveIcon(entry, appId, appLibrary) {
    if (entry && entry.iconSource && entry.iconSource.length > 0 && entry.iconSource.indexOf("application-x-executable") === -1) {
        return entry.iconSource;
    }
    if (entry && entry.icon) {
        var iconVal = String(entry.icon).trim();
        if (iconVal.indexOf("file://") === 0 || iconVal.indexOf("image://") === 0) return iconVal;
        if (iconVal.charAt(0) === "/") return "file://" + iconVal;
        if (appLibrary && typeof appLibrary.iconSource === "function") {
            var src = appLibrary.iconSource(iconVal);
            if (src && src.length > 0 && src.indexOf("application-x-executable") === -1) return src;
        }
        return iconVal;
    }
    var id = stripDesktop(appId);
    if (appLibrary && typeof appLibrary.iconSource === "function") {
        var candidates = getCandidates(entry ? entry.icon : "", "", id);
        for (var i = 0; i < candidates.length; i++) {
            var cand = candidates[i];
            if (cand.indexOf("file://") === 0 || cand.indexOf("image://") === 0) return cand;
            if (cand.charAt(0) === "/") return "file://" + cand;
            var cSrc = appLibrary.iconSource(cand);
            if (cSrc && cSrc.length > 0 && cSrc.indexOf("application-x-executable") === -1) return cSrc;
        }

        // Try hyphenated/spaced variations (e.g. "Google Maps" -> "google-maps")
        var hyp = id.toLowerCase().replace(/\s+/g, "-");
        var src3 = appLibrary.iconSource(hyp);
        if (src3 && src3.length > 0 && src3.indexOf("application-x-executable") === -1) return src3;

        var spc = id.toLowerCase().replace(/[-_]+/g, " ");
        var src4 = appLibrary.iconSource(spc);
        if (src4 && src4.length > 0 && src4.indexOf("application-x-executable") === -1) return src4;
    }
    return id || "application-x-executable";
}

function isBrowserApp(id) {
    var s = String(id || "").toLowerCase();
    return s === "google-chrome" || s === "google-chrome-stable" || s === "chromium" || s === "brave" || s === "brave-browser" || s === "microsoft-edge" || s === "opera" || s === "vivaldi" || s === "yandex-browser" || s === "yandex-browser-stable" || s === "ru.yandex.desktop.browser";
}

var KNOWN_TERMINALS = [
    "ghostty", "com.mitchellh.ghostty", "kitty", "alacritty", "org.alacritty",
    "foot", "footclient", "wezterm", "org.wezfurlong.wezterm", "wezterm-gui",
    "xterm", "uxterm", "gnome-terminal", "org.gnome.terminal", "konsole",
    "org.kde.konsole", "xfce4-terminal", "tilix", "com.gexperts.tilix", "st",
    "simple-terminal", "urxvt", "rxvt", "rxvt-unicode", "terminator",
    "lxterminal", "contour", "rio", "blackbox", "com.raggesilver.blackbox",
    "ptyxis", "org.gnome.ptyxis", "tabby", "hyper", "warp", "warp-terminal"
];

function isTerminalApp(id, entry) {
    if (!id && !entry) return false;
    var s = String(id || "").toLowerCase().trim();
    if (s.slice(-8) === ".desktop") s = s.slice(0, -8);
    for (var i = 0; i < KNOWN_TERMINALS.length; i++) {
        if (s === KNOWN_TERMINALS[i]) return true;
    }
    if (entry) {
        if (Array.isArray(entry.categories) && entry.categories.indexOf("TerminalEmulator") !== -1) {
            return true;
        }
        if (typeof entry.categories === "string" && entry.categories.indexOf("TerminalEmulator") !== -1) {
            return true;
        }
        var gen = String(entry.genericName || "").toLowerCase();
        if (gen.indexOf("terminal emulator") !== -1 || gen === "terminal") {
            return true;
        }
    }
    return false;
}

var IGNORED_COMMAND_PREFIXES = [
    "sudo", "doas", "pkexec", "pacman", "yay", "paru", "apt", "dnf", "zypper",
    "cargo", "npm", "pnpm", "yarn", "bun", "git", "make", "ninja", "cmake",
    "pip", "python", "python3", "node", "go", "rustc", "gcc", "clang",
    "find", "grep", "cat", "less", "more", "tail", "journalctl", "systemctl",
    "sh", "bash", "zsh", "fish", "exec", "run", "echo", "rm", "cp", "mv",
    "which", "whereis", "man", "info", "curl", "wget", "tar", "unzip", "zip",
    "home", "user", "usr", "etc", "bin", "tmp", "var", "opt", "desktop", "documents", "downloads", "music", "pictures", "videos"
];

var KNOWN_CLI_COMMANDS = [
    "yazi", "nvim", "neovim", "vim", "nano", "micro", "helix", "hx", "emacs", "kakoune", "kak", "amp",
    "btop", "htop", "top", "bottom", "btm", "glances", "bashtop", "bpytop", "nvtop", "gotop",
    "ranger", "superfile", "broot", "vifm", "nnn", "lf", "fff", "mc", "midnight-commander", "clifm",
    "lazygit", "lazydocker", "tig", "gitui", "k9s", "ox", "bandwhich", "gping",
    "ncmpcpp", "cmus", "mocp", "cava", "cliamp", "rmpc", "spotify-tui", "spt", "mopidy", "musikcube",
    "weechat", "irssi", "profanity", "neomutt", "mutt", "aerc", "gomuks", "senpai",
    "tmux", "zellij", "cmatrix", "pipes.sh", "fastfetch", "neofetch", "cbonsai", "tty-clock", "peaclock", "termshark", "glow", "curseofwar"
];

function extractCliApp(title, desktopEntries) {
    if (!title) return "";
    var raw = String(title).toLowerCase().trim();
    var rawTokens = raw.split(/[\s:,\-_/\\()\[\]{}|]+/);
    var tokens = [];
    for (var k = 0; k < rawTokens.length; k++) {
        if (rawTokens[k].length > 0) tokens.push(rawTokens[k]);
    }
    if (tokens.length === 0) return "";

    var first = tokens[0];
    if (IGNORED_COMMAND_PREFIXES.indexOf(first) === -1 && KNOWN_CLI_COMMANDS.indexOf(first) !== -1) {
        if (first === "neovim" || first === "vim") return "nvim";
        if (first === "hx") return "helix";
        if (first === "btm") return "bottom";
        return first;
    }

    // Check all tokens in title for known CLI app names
    for (var t = 0; t < tokens.length; t++) {
        var tok = tokens[t];
        if (IGNORED_COMMAND_PREFIXES.indexOf(tok) !== -1) continue;
        if (KNOWN_CLI_COMMANDS.indexOf(tok) !== -1) {
            if (tok === "neovim" || tok === "vim") return "nvim";
            if (tok === "hx") return "helix";
            if (tok === "btm") return "bottom";
            return tok;
        }
    }

    // Dynamic scanning: check if any token in title matches an installed desktop entry
    if (desktopEntries) {
        var list = toArray(desktopEntries);
        var scanLimit = Math.min(tokens.length, 3);
        for (var i = 0; i < scanLimit; i++) {
            var token = tokens[i];
            if (token.length < 3 || IGNORED_COMMAND_PREFIXES.indexOf(token) !== -1 || isTerminalApp(token)) continue;
            for (var d = 0; d < list.length; d++) {
                var de = unwrapEntry(list[d]);
                if (!de) continue;
                var deId = stripDesktop(de.id || "").toLowerCase();
                var deExec = String(de.exec || "").toLowerCase().split(/\s+/)[0].split("/").pop();
                var deName = String(de.name || "").toLowerCase();
                if ((token === deId || token === deExec || token === deName) && !isTerminalApp(deId, de)) {
                    return deId || token;
                }
            }
        }
    }

    // Special title patterns like 'filename - NVIM' or '[No Name] - NVIM'
    if (raw.indexOf("nvim") !== -1 && tokens.indexOf("nvim") !== -1) {
        return "nvim";
    }

    // Special patterns for cliamp Winamp scrolling marquee ("really whips", "whips the terminal's ass", "cliamp", "it really", "really whip", "ass.")
    if (raw.indexOf("whips") !== -1 || raw.indexOf("terminal's ass") !== -1 || raw.indexOf("cliamp") !== -1 || raw.indexOf("really whip") !== -1 || raw.indexOf("it really") !== -1 || raw.indexOf("ass.") !== -1) {
        return "cliamp";
    }

    return "";
}

// =========================================================================
// Predictive Launch Hint — instant CLI app icon appearance
// When a CLI app is launched, we record the set of currently open windows
// (knownBefore). When a NEW terminal window opens that was NOT in knownBefore,
// it is immediately identified as the launched CLI app without waiting
// for the window title to update.
// =========================================================================
var _pendingCliHint = null; // { appId: string, timestamp: number, knownBefore: Array, appliedToTop: Object|null }

function setPendingCliHint(appId, knownWindowsList) {
    if (!appId) return;
    var clean = stripDesktop(appId).toLowerCase();
    var cleanNorm = normalizeKey(clean);
    var isCli = (KNOWN_CLI_COMMANDS.indexOf(clean) !== -1 || KNOWN_CLI_COMMANDS.indexOf(cleanNorm) !== -1 || clean === "cliamp" || cleanNorm === "cliamp");
    if (isCli) {
        var known = [];
        if (Array.isArray(knownWindowsList)) {
            for (var i = 0; i < knownWindowsList.length; i++) {
                if (knownWindowsList[i]) known.push(knownWindowsList[i]);
            }
        }
        var targetCmd = clean;
        for (var k = 0; k < KNOWN_CLI_COMMANDS.length; k++) {
            if (KNOWN_CLI_COMMANDS[k] === clean || KNOWN_CLI_COMMANDS[k] === cleanNorm) {
                targetCmd = KNOWN_CLI_COMMANDS[k];
                break;
            }
        }
        _pendingCliHint = {
            appId: targetCmd,
            timestamp: Date.now(),
            knownBefore: known,
            appliedToTop: null
        };
    }
}

function getPendingCliHint() {
    if (!_pendingCliHint) return null;
    if (Date.now() - _pendingCliHint.timestamp > 6000) {
        _pendingCliHint = null;
        return null;
    }
    return _pendingCliHint;
}

function clearPendingCliHint() {
    _pendingCliHint = null;
}

var _detectedCliApps = []; // array of detected CLI command strings from /proc, e.g. ["cliamp", "btop"]
var _detectedCliTimestamp = 0;

function setDetectedCliApps(apps) {
    if (Array.isArray(apps)) {
        _detectedCliApps = apps.slice();
        _detectedCliTimestamp = Date.now();
    }
}

function getDetectedCliApps() {
    if (Date.now() - _detectedCliTimestamp > 15000) {
        _detectedCliApps = [];
    }
    return _detectedCliApps;
}

var _stickyCliByTopId = {}; // topId -> cliApp
var _nextTopId = 1;

function hasRealDesktopEntry(entries, appId) {
    if (!entries || !appId) return false;
    var target = stripDesktop(appId).toLowerCase().trim();
    var list = toArray(entries);
    for (var i = 0; i < list.length; i++) {
        var e = unwrapEntry(list[i]);
        if (!e) continue;
        var eId = stripDesktop(e.id || "").toLowerCase();
        var eName = String(e.name || "").toLowerCase();
        var exec = String(e.exec || "").toLowerCase();
        var execBin = exec.split(/\s+/)[0].split("/").pop();
        if (eId === target || eName === target || execBin === target) {
            return true;
        }
    }
    return false;
}

function matchToplevel(toplevel, appId, entry, desktopEntries, cachedCliApp) {
    if (!toplevel) return false;
    var appClass = String(toplevel.appId || "").toLowerCase().trim();
    var title = String(toplevel.title || "").toLowerCase().trim();
    var cleanId = stripDesktop(appId).toLowerCase().trim();

    if (!cleanId && !entry) return false;
    if (!appClass) return false;

    var appClassClean = stripDesktop(appClass);
    var baseAppClass = cleanWindowAppId(appClassClean).toLowerCase();
    var firstClassToken = baseAppClass ? baseAppClass.split(/[\s\-_]+/)[0] : "";
    var hypClass = (baseAppClass && baseAppClass.indexOf(" ") !== -1) ? baseAppClass.replace(/\s+/g, "-") : "";

    var chromeDom = extractChromeDomain(appClass);
    var isWebAppWindow = (chromeDom.length > 0);

    // If this window is a Chrome Web App (e.g. chrome-maps.google.com__-Default):
    // Standard web browser dock items (Google Chrome, Chromium, Brave) should NOT swallow it!
    if (isWebAppWindow && isBrowserApp(cleanId)) {
        return false;
    }

    // Terminal CLI / TUI application matching:
    // If a window is running in a terminal emulator (e.g. foot, ghostty, kitty):
    if (isTerminalApp(appClass, null)) {
        var cliApp = (cachedCliApp !== undefined) ? cachedCliApp : extractCliApp(title, desktopEntries);
        // Case A: Dock item is a specific CLI app (e.g. yazi, nvim, btop):
        if (cliApp && !isTerminalApp(cleanId, entry)) {
            var normCliApp = normalizeKey(cliApp);
            var normTargetId = normalizeKey(cleanId);
            if (cleanId === cliApp || normTargetId === normCliApp) return true;
            if (entry) {
                var eId = stripDesktop(entry.id || "").toLowerCase();
                var eName = String(entry.name || "").toLowerCase();
                if (eId === cliApp || normalizeKey(eId) === normCliApp) return true;
                if (eName === cliApp || normalizeKey(eName) === normCliApp) return true;
            }
        }
        // Case B: Dock item is a generic terminal emulator, but window is running a dedicated CLI app:
        if (cliApp && isTerminalApp(cleanId, entry)) {
            return false;
        }
        // Case C: Dock item IS a terminal emulator, and window is a generic terminal session (no dedicated CLI app):
        if (!cliApp && isTerminalApp(cleanId, entry)) {
            return true;
        }
    }

    // Transmission GTK Wayland dynamic app ID matching (com.transmissionbt.transmission_<pid>_<random>)
    if (appClass.indexOf("com.transmissionbt.transmission") === 0 || cleanId.indexOf("com.transmissionbt.transmission") === 0) {
        var isTransDockItem = (cleanId === "transmission" || cleanId === "transmission-gtk" || cleanId === "transmission-qt" || cleanId.indexOf("com.transmissionbt.transmission") === 0);
        if (isTransDockItem) return true;
        if (entry) {
            var trEntryId = stripDesktop(entry.id || "").toLowerCase();
            var trEntryExec = String(entry.exec || "").toLowerCase().split(/\s+/)[0].split("/").pop();
            if (trEntryId === "transmission-gtk" || trEntryId === "transmission-qt" || trEntryId === "transmission" ||
                trEntryExec === "transmission-gtk" || trEntryExec === "transmission-qt" || trEntryExec === "transmission") {
                return true;
            }
        }
    }

    // Steam game matching (e.g. steam_app_1700)
    if (appClass.indexOf("steam_app_") === 0) {
        if (cleanId === "steam") return false;
        var steamGameId = appClass.replace(/^steam_app_/, "");
        if (cleanId === appClass || cleanId === ("steam_icon_" + steamGameId)) return true;
        if (entry) {
            var stExec = String(entry.exec || "").toLowerCase();
            var stIcon = String(entry.icon || "").toLowerCase();
            if (stExec.indexOf("rungameid/" + steamGameId) !== -1 || stIcon === "steam_icon_" + steamGameId || stIcon === "steam_app_" + steamGameId) {
                return true;
            }
        }
    }

    // Yandex Browser matching
    if (appClass === "yandex-browser" || appClass === "yandex-browser-stable") {
        if (cleanId === "yandex-browser" || cleanId === "yandex-browser-stable" || cleanId === "ru.yandex.desktop.browser") return true;
        if (entry) {
            var yId = stripDesktop(entry.id || "").toLowerCase();
            var yExec = String(entry.exec || "").toLowerCase().split(/\s+/)[0].split("/").pop();
            if (yId === "yandex-browser" || yId === "ru.yandex.desktop.browser" || yExec === "yandex-browser-stable" || yExec === "yandex-browser") return true;
        }
    }

    // 1. Direct class match (with and without .desktop / .exe)
    if (cleanId && (appClass === cleanId || appClassClean === cleanId || baseAppClass === cleanId || hypClass === cleanId || appClass === (cleanId + ".desktop") || appClass === (cleanId + ".exe"))) return true;

    // 2. Normalized match
    var normClass = normalizeKey(appClassClean);
    var normBaseClass = normalizeKey(baseAppClass);
    var normId = cleanId ? normalizeKey(cleanId) : "";
    if (normId.length > 0 && (normClass === normId || normBaseClass === normId)) return true;
    if (normId.length > 0 && firstClassToken.length >= 3 && normalizeKey(firstClassToken) === normId) return true;

    // 3. Entry ID, Name, Icon and Exec match
    if (entry) {
        var entryId = stripDesktop(entry.id || "").toLowerCase();
        var normEntryId = normalizeKey(entryId);
        if (entryId && (appClass === entryId || appClassClean === entryId || baseAppClass === entryId || hypClass === entryId || normClass === normEntryId || normBaseClass === normEntryId)) return true;
        if (entryId && firstClassToken.length >= 3 && (firstClassToken === entryId || normalizeKey(firstClassToken) === normEntryId)) return true;

        var entryName = String(entry.name || "").toLowerCase();
        if (entryName) {
            var normEntryName = normalizeKey(entryName);
            if (normClass === normEntryName || normBaseClass === normEntryName) return true;
            if (firstClassToken.length >= 3 && normalizeKey(firstClassToken) === normEntryName) return true;
            var nameTokens = entryName.split(/[\s\-_\.]+/);
            for (var nt = 0; nt < nameTokens.length; nt++) {
                if (nameTokens[nt] === appClassClean || nameTokens[nt] === baseAppClass || (nameTokens[nt].length >= 3 && nameTokens[nt] === firstClassToken)) return true;
            }
        }

        var entryIcon = String(entry.icon || "").toLowerCase();
        if (entryIcon && (normClass === normalizeKey(entryIcon) || normBaseClass === normalizeKey(entryIcon))) return true;

        if (entry.exec) {
            var execStr = String(entry.exec).trim().toLowerCase();
            var execBase = execStr.split(/\s+/)[0].split("/").pop();
            if (execBase && execBase !== "env" && execBase !== "sh" && execBase !== "bash" && execBase !== "flatpak" && execBase !== "bwrap" && execBase !== "wine" && execBase !== "uwsm-app" && !isWebAppWindow) {
                if (appClass === execBase || appClassClean === execBase || baseAppClass === execBase || (firstClassToken.length >= 3 && firstClassToken === execBase)) return true;
            }
        }
    }

    // 4. Chrome / Web App Matching
    if (isWebAppWindow) {
        if (entry && entry.exec && entry.exec.toLowerCase().indexOf(chromeDom) !== -1) return true;
        if (entry && entry.id && entry.id.toLowerCase().indexOf(chromeDom) !== -1) return true;
        if (cleanId && cleanId.indexOf(chromeDom) !== -1) return true;
        if (normId.length > 0 && normId.indexOf(normalizeKey(chromeDom)) !== -1) return true;

        // Check specific service keywords (e.g. "photos" in "photos.google.com") matching candidate dock item tokens
        var domParts = chromeDom.split(".");
        for (var p = 0; p < domParts.length; p++) {
            var part = domParts[p];
            if (part.length >= 3 && part !== "com" && part !== "org" && part !== "net" && part !== "web" && part !== "app" && part !== "google" && part !== "yandex" && part !== "microsoft" && part !== "apple") {
                var eNameTokens = entry && entry.name ? String(entry.name).toLowerCase().split(/[\s\-_\.]+/) : [];
                var eIdTokens = entry && entry.id ? stripDesktop(entry.id).toLowerCase().split(/[\s\-_\.]+/) : [];
                var eIconTokens = entry && entry.icon ? String(entry.icon).toLowerCase().split(/[\s\-_\.]+/) : [];
                var cleanIdTokens = cleanId ? cleanId.split(/[\s\-_\.]+/) : [];
                var allETokens = eNameTokens.concat(eIdTokens).concat(eIconTokens).concat(cleanIdTokens);

                for (var t = 0; t < allETokens.length; t++) {
                    var tok = allETokens[t];
                    if (tok === part || (part.endsWith("s") && tok === part.slice(0, -1)) || (tok.endsWith("s") && tok.slice(0, -1) === part)) {
                        return true;
                    }
                }
            }
        }
    }

    // 5. Window Title Match for web apps / webapp launchers
    if (entry && entry.exec && entry.exec.toLowerCase().indexOf("omarchy-launch-webapp") !== -1) {
        if (entry.name && title.length > 0) {
            var normName = normalizeKey(entry.name);
            var normTitle = normalizeKey(title);
            if (normTitle.indexOf(normName) !== -1 || normName.indexOf(normTitle) !== -1) return true;
        }
    }

    // 6. Normalized prefix matches (e.g., com.mitchellh.ghostty <-> ghostty, org.kde.dolphin <-> dolphin)
    if (!isWebAppWindow) {
        var appClassShort = appClass.replace(/^(org|com|io|net|dev)\.[^.]+\./, "").replace(/\.desktop$/, "");
        if (cleanId && appClassShort === cleanId) return true;

        var cleanIdShort = cleanId.replace(/^(org|com|io|net|dev)\.[^.]+\./, "");
        if (appClass === cleanIdShort || appClassShort === cleanIdShort) return true;
    }

    return false;
}

function toCanonical(str) {
    if (!str || typeof str !== "string") return "";
    var raw = str.trim().toLowerCase();
    if (!raw) return "";

    // 1. First-class desktop & Web App service aliases
    if (raw.indexOf("transmission") !== -1) return "transmission";
    if (raw.indexOf("yandex-browser") !== -1 || (raw.indexOf("yandex") !== -1 && raw.indexOf("mail") === -1 && raw.indexOf("music") === -1)) return "yandex-browser";
    if (raw.indexOf("telegram") !== -1) return "telegram";
    if (raw.indexOf("whatsapp") !== -1) return "whatsapp";
    if (raw.indexOf("chatgpt") !== -1 || raw.indexOf("openai") !== -1) return "chatgpt";
    if (raw.indexOf("claude") !== -1 || raw.indexOf("anthropic") !== -1) return "claude";
    if (raw.indexOf("gemini") !== -1) return "gemini";
    if (raw.indexOf("notion") !== -1) return "notion";
    if (raw.indexOf("figma") !== -1) return "figma";
    if (raw.indexOf("github") !== -1) return "github";
    if (raw.indexOf("gitlab") !== -1) return "gitlab";
    if (raw.indexOf("linear") !== -1) return "linear";
    if (raw.indexOf("trello") !== -1) return "trello";
    if (raw.indexOf("jira") !== -1) return "jira";
    if (raw.indexOf("slack") !== -1) return "slack";
    if (raw.indexOf("discord") !== -1 || raw.indexOf("vesktop") !== -1 || raw.indexOf("webcord") !== -1) return "discord";
    if (raw.indexOf("spotify") !== -1) return "spotify";
    if (raw.indexOf("gmail") !== -1 || raw.indexOf("mail.google.com") !== -1) return "gmail";
    if (raw.indexOf("outlook") !== -1) return "outlook";
    if (raw.indexOf("proton") !== -1 || raw.indexOf("protonmail") !== -1) return "protonmail";
    if (raw.indexOf("antigravity") !== -1) return "antigravity";
    if (raw.indexOf("code") !== -1 || raw.indexOf("vscodium") !== -1 || raw.indexOf("vscode") !== -1) return "code";
    if (raw.indexOf("nautilus") !== -1 || raw.indexOf("org.gnome.nautilus") !== -1 || raw.indexOf("thunar") !== -1 || raw.indexOf("dolphin") !== -1) return "nautilus";
    if (raw.indexOf("kitty") !== -1 || raw.indexOf("alacritty") !== -1 || raw.indexOf("ghostty") !== -1 || raw.indexOf("foot") !== -1 || raw.indexOf("terminal") !== -1) return "terminal";
    if (raw.indexOf("chrome") !== -1 || raw.indexOf("chromium") !== -1) return "chrome";
    if (raw.indexOf("firefox") !== -1 || raw.indexOf("zen-browser") !== -1) return "firefox";

    // 2. Extract domain core from Web App URLs
    var urlMatch = raw.match(/https?:\/\/(?:www\.|web\.|app\.|mail\.)?([a-zA-Z0-9-]+)\./i);
    if (urlMatch && urlMatch[1]) {
        var dom = urlMatch[1].toLowerCase();
        if (["com", "org", "net", "io", "app", "dev"].indexOf(dom) === -1) {
            return dom;
        }
    }

    // 3. Generic stripping
    var s = raw;
    s = s.replace(/\.desktop$/i, "");
    s = s.replace(/\.appimage$/i, "");
    s = s.replace(/-(?:bin|git|stable|nightly|electron|desktop)$/i, "");
    s = s.replace(/^(?:org|com|io|net|edu|dev)\.[a-z0-9_]+\./i, "");
    s = s.replace(/^(?:org|com|io|net|edu|dev)\./i, "");
    return s.replace(/[^a-z0-9]/g, "");
}

function getBadgeInfo(badgeCounts, urgentCounts, appId, entry, name, desktopId) {
    if (!badgeCounts || typeof badgeCounts !== "object") return { count: 0, hasUrgent: false };
    var rawKeys = [
        appId,
        entry ? entry.id : "",
        entry ? stripDesktop(entry.id) : "",
        desktopId,
        desktopId ? stripDesktop(desktopId) : "",
        name,
        entry ? entry.name : "",
        entry ? entry.exec : ""
    ];
    var keys = [];
    for (var k = 0; k < rawKeys.length; k++) {
        var r = String(rawKeys[k] || "").trim();
        if (!r) continue;
        if (keys.indexOf(r) === -1) keys.push(r);
        var canon = toCanonical(r);
        if (canon && keys.indexOf(canon) === -1) keys.push(canon);
    }

    var count = 0;
    var isUrgent = false;
    for (var i = 0; i < keys.length; i++) {
        var raw = String(keys[i] || "").trim().toLowerCase();
        if (!raw) continue;
        if (badgeCounts[raw] != null && Number(badgeCounts[raw]) > count) {
            count = Number(badgeCounts[raw]);
        }
        if (urgentCounts && urgentCounts[raw] === true) {
            isUrgent = true;
        }
        var clean = raw.replace(/[^a-z0-9]/g, "");
        if (clean && badgeCounts[clean] != null && Number(badgeCounts[clean]) > count) {
            count = Number(badgeCounts[clean]);
        }
        if (clean && urgentCounts && urgentCounts[clean] === true) {
            isUrgent = true;
        }
    }
    return { count: count, hasUrgent: isUrgent };
}

function createDesktopEntryIndex(desktopEntries) {
    var list = toArray(desktopEntries);
    var byId = Object.create(null);
    var byName = Object.create(null);
    var byNorm = Object.create(null);
    var byExec = Object.create(null);

    for (var i = 0; i < list.length; i++) {
        var e = unwrapEntry(list[i]);
        if (!e) continue;

        var id = stripDesktop(e.id || "").toLowerCase();
        if (id && !byId[id]) byId[id] = e;

        var name = String(e.name || "").toLowerCase();
        if (name && !byName[name]) byName[name] = e;

        var cleanName = cleanWindowAppId(name).toLowerCase();
        if (cleanName && !byName[cleanName]) byName[cleanName] = e;

        var idNorm = normalizeKey(id);
        if (idNorm && !byNorm[idNorm]) byNorm[idNorm] = e;

        var nameNorm = normalizeKey(name);
        if (nameNorm && !byNorm[nameNorm]) byNorm[nameNorm] = e;

        if (cleanName) {
            var cleanNorm = normalizeKey(cleanName);
            if (cleanNorm && !byNorm[cleanNorm]) byNorm[cleanNorm] = e;
        }

        if (e.icon) {
            var icon = String(e.icon).toLowerCase();
            if (!byId[icon]) byId[icon] = e;
            var iconNorm = normalizeKey(icon);
            if (iconNorm && !byNorm[iconNorm]) byNorm[iconNorm] = e;
        }

        if (e.exec) {
            var execBase = String(e.exec).trim().split(/\s+/)[0].split("/").pop().toLowerCase();
            if (execBase && !byExec[execBase]) byExec[execBase] = e;
        }
    }

    return { list: list, byId: byId, byName: byName, byNorm: byNorm, byExec: byExec };
}

function findEntryFast(index, appId) {
    var id = stripDesktop(appId);
    if (!id || !index) return null;
    var target = id.toLowerCase();

    // 1. O(1) direct ID match
    if (index.byId[target]) return index.byId[target];

    // 2. O(1) direct Name match
    if (index.byName[target]) return index.byName[target];

    // 3. O(1) Exec binary match
    if (index.byExec[target]) return index.byExec[target];

    // 4. O(1) Normalized key match
    var targetNorm = normalizeKey(target);
    if (targetNorm && index.byNorm[targetNorm]) return index.byNorm[targetNorm];

    // 5a. Transmission dynamic app ID fast resolution
    if (target.indexOf("com.transmissionbt.transmission") === 0) {
        if (index.byId["transmission-gtk"]) return index.byId["transmission-gtk"];
        if (index.byId["transmission-qt"]) return index.byId["transmission-qt"];
        if (index.byId["transmission"]) return index.byId["transmission"];
        if (index.byExec["transmission-gtk"]) return index.byExec["transmission-gtk"];
        if (index.byExec["transmission-qt"]) return index.byExec["transmission-qt"];
        if (index.byExec["transmission"]) return index.byExec["transmission"];
    }

    // 5b. Steam game ID fast resolution
    var isSteamGame = (target.indexOf("steam_app_") === 0);
    if (isSteamGame) {
        var fastGameId = target.replace(/^steam_app_/, "");
        for (var s = 0; s < index.list.length; s++) {
            var se = index.list[s];
            if (!se) continue;
            var sExec = String(se.exec || "").toLowerCase();
            var sIcon = String(se.icon || "").toLowerCase();
            if (sExec.indexOf("rungameid/" + fastGameId) !== -1 || sIcon === "steam_icon_" + fastGameId || sIcon === "steam_app_" + fastGameId) {
                return se;
            }
        }
    }

    // 5c. Yandex Browser fast resolution
    if (target === "yandex-browser" || target === "yandex-browser-stable" || target === "ru.yandex.desktop.browser") {
        if (index.byId["yandex-browser"]) return index.byId["yandex-browser"];
        if (index.byId["ru.yandex.desktop.browser"]) return index.byId["ru.yandex.desktop.browser"];
        if (index.byExec["yandex-browser-stable"]) return index.byExec["yandex-browser-stable"];
        if (index.byExec["yandex-browser"]) return index.byExec["yandex-browser"];
    }

    // 6. Cleaned window appId match (e.g. "SyncTERM 1.8 - Wayland" -> "syncterm")
    var cleaned = cleanWindowAppId(id);
    var cleanTarget = cleaned ? cleaned.toLowerCase() : "";
    if (cleanTarget && cleanTarget !== target && (!isSteamGame || (cleanTarget !== "steam" && cleanTarget !== "steam_app"))) {
        if (index.byId[cleanTarget]) return index.byId[cleanTarget];
        if (index.byName[cleanTarget]) return index.byName[cleanTarget];
        if (index.byExec[cleanTarget]) return index.byExec[cleanTarget];
        var cleanNorm = normalizeKey(cleanTarget);
        if (cleanNorm && index.byNorm[cleanNorm]) return index.byNorm[cleanNorm];
    }

    // 6b. First token match (e.g. "syncterm" from "syncterm 1.8")
    var firstToken = cleanTarget ? cleanTarget.split(/[\s\-_]+/)[0] : "";
    if (!isSteamGame && firstToken && firstToken.length >= 3 && firstToken !== cleanTarget && firstToken !== target && firstToken !== "steam") {
        if (index.byId[firstToken]) return index.byId[firstToken];
        if (index.byName[firstToken]) return index.byName[firstToken];
        if (index.byExec[firstToken]) return index.byExec[firstToken];
        var firstNorm = normalizeKey(firstToken);
        if (firstNorm && index.byNorm[firstNorm]) return index.byNorm[firstNorm];
    }

    // 6c. Hyphenated match (e.g. "claude desktop" -> "claude-desktop")
    if (cleanTarget && cleanTarget.indexOf(" ") !== -1) {
        var hypTarget = cleanTarget.replace(/\s+/g, "-");
        if (index.byId[hypTarget]) return index.byId[hypTarget];
        if (index.byName[hypTarget]) return index.byName[hypTarget];
        if (index.byExec[hypTarget]) return index.byExec[hypTarget];
    }

    // 6d. O(1) Known default ID match
    if (!isSteamGame) {
        if (KNOWN_APP_DEFAULTS[target]) {
            var defId = stripDesktop(KNOWN_APP_DEFAULTS[target].id || "").toLowerCase();
            if (defId && index.byId[defId]) return index.byId[defId];
        }
        if (cleanTarget && KNOWN_APP_DEFAULTS[cleanTarget]) {
            var defCleanId = stripDesktop(KNOWN_APP_DEFAULTS[cleanTarget].id || "").toLowerCase();
            if (defCleanId && index.byId[defCleanId]) return index.byId[defCleanId];
        }
        if (firstToken && KNOWN_APP_DEFAULTS[firstToken]) {
            var defFirstId = stripDesktop(KNOWN_APP_DEFAULTS[firstToken].id || "").toLowerCase();
            if (defFirstId && index.byId[defFirstId]) return index.byId[defFirstId];
        }
    }

    // 6. Fallback to deep heuristic search on cache miss
    return findEntry(index.list, appId);
}

// The Hyprland address of one of a dock item's windows, empty when the window
// is not in Hyprland's list any more. A dock icon numbers its windows in its
// own sticky creation order, while the helper script resolves them against
// Hyprland's client list, and that list reorders on its own — a lock screen, a
// workspace move or a restore from the scratchpad is enough to swap two entries
// around. A position sent across that gap names whichever window happens to sit
// there; an address names the window itself.
function hyprAddressFor(toplevel, hyprToplevels) {
    if (!toplevel || !hyprToplevels || typeof hyprToplevels.length !== "number") return "";
    for (var i = 0; i < hyprToplevels.length; i++) {
        var ht = hyprToplevels[i];
        if (!ht) continue;
        if (ht === toplevel || ht.wayland === toplevel) {
            var addr = String(ht.address || "");
            if (!addr) return "";
            return addr.indexOf("0x") === 0 ? addr : ("0x" + addr);
        }
    }
    return "";
}

function collectMatchingToplevels(appId, entry, entries, toplevels, assignedTops, toplevelCliApps, activeToplevel, isTopMinimizedFn, getTopKeyFn) {
    var matching = [];
    var isAnyActive = false;
    var activeIdx = 0;
    var minCount = 0;

    for (var t = 0; t < toplevels.length; t++) {
        var top = toplevels[t];
        var tKey = getTopKeyFn ? getTopKeyFn(top, t) : (top ? (String(top.appId || "") + "___" + String(top.title || "") + "___" + t) : ("top_" + t));
        var cliApp = toplevelCliApps ? toplevelCliApps[tKey] : undefined;

        if (!assignedTops[tKey] && matchToplevel(top, appId, entry, entries, cliApp)) {
            matching.push(top);
            assignedTops[tKey] = true;

            var isMin = isTopMinimizedFn ? isTopMinimizedFn(top) : false;
            if (isMin) {
                minCount++;
            } else {
                try {
                    if (activeToplevel && top === activeToplevel) {
                        isAnyActive = true;
                        activeIdx = matching.length - 1;
                    }
                } catch (e) {}
            }
        }
    }

    var isAllMin = (matching.length > 0 && minCount === matching.length);
    if (isAllMin) isAnyActive = false;

    return {
        matching: matching,
        isActive: isAnyActive,
        isMinimized: isAllMin,
        activeTopIndex: activeIdx,
        windowCount: matching.length
    };
}

function buildDockItems(pinnedList, toplevelsList, activeToplevel, desktopEntries, appLibrary, badgeCounts, urgentCounts, maxItems, minimizedToplevels) {
    var pinned = Array.isArray(pinnedList) ? pinnedList : [];
    var toplevels = toArray(toplevelsList);
    var entries = toArray(desktopEntries);
    var minList = Array.isArray(minimizedToplevels) ? minimizedToplevels : [];

    var items = [];
    var assignedTops = {};
    var entryIndex = createDesktopEntryIndex(entries);

    function isTopMinimized(top) {
        if (!top) return false;
        if (top.minimized === true) return true;
        for (var m = 0; m < minList.length; m++) {
            if (minList[m] === top) return true;
            try {
                if (minList[m] && minList[m].wayland === top) return true;
            } catch (e) {}
        }
        return false;
    }

    for (var init_t = 0; init_t < toplevels.length; init_t++) {
        var tObj = toplevels[init_t];
        if (tObj && typeof tObj === "object") {
            try {
                if (!tObj._dockTopId) {
                    tObj._dockTopId = (tObj.address ? String(tObj.address) : ("win_" + (_nextTopId++)));
                }
            } catch (e) {}
        }
    }

    function getTopKey(top, idx) {
        if (!top) return "top_" + idx;
        try {
            if (top._dockTopId) return top._dockTopId;
            if (top.address) return String(top.address);
        } catch (e) {}
        var app = "";
        try {
            app = String(top.appId || "");
        } catch (e) {}
        return app + "___" + idx;
    }

    function entryFor(id) {
        return findEntryFast(entryIndex, id);
    }

    // Precalculate CLI app recognition once per toplevel to avoid O(P * T * E) repeated loops
    // Predictive Launch Hint & Real-Time /proc Scanning:
    //   1. Detect CLI apps from window titles (extractCliApp)
    //   2. If not in title, apply predictive launch hint from dock click
    //   3. If not in title, apply background /proc scanner results (detects CLI apps launched from menu/CLI)
    //   4. When extractCliApp confirms the real title, clear the hint.
    var toplevelCliApps = {};
    var hint = getPendingCliHint();
    var detectedCliList = getDetectedCliApps();
    for (var tc = 0; tc < toplevels.length; tc++) {
        var topObj = toplevels[tc];
        if (topObj && isTerminalApp(topObj.appId || "")) {
            var tk = getTopKey(topObj, tc);
            var title = String(topObj.title || "");
            var detected = extractCliApp(title, entries);

            // Check sticky window cache for persistent player/app matching (vital for Winamp marquee!)
            if (!detected && _stickyCliByTopId[tk]) {
                detected = _stickyCliByTopId[tk];
            }

            if (!detected && hint) {
                var wasAlreadyOpen = false;
                if (hint.knownBefore && Array.isArray(hint.knownBefore)) {
                    for (var kb = 0; kb < hint.knownBefore.length; kb++) {
                        if (hint.knownBefore[kb] === topObj) {
                            wasAlreadyOpen = true;
                            break;
                        }
                    }
                }
                if (!wasAlreadyOpen && (!hint.appliedToTop || hint.appliedToTop === topObj)) {
                    detected = hint.appId;
                    hint.appliedToTop = topObj;
                }
            }
            if (!detected && detectedCliList.length > 0) {
                for (var d = 0; d < detectedCliList.length; d++) {
                    var candCli = detectedCliList[d];
                    if (candCli) {
                        detected = candCli;
                        break;
                    }
                }
            }

            if (detected) {
                _stickyCliByTopId[tk] = detected;
            }

            if (detected && hint && (hint.appliedToTop === topObj || detected === hint.appId)) {
                if (extractCliApp(topObj.title || "", entries)) {
                    clearPendingCliHint();
                    hint = null;
                }
            }
            toplevelCliApps[tk] = detected;
        }
    }

    // Purge closed windows from sticky cache
    var liveTopKeys = {};
    for (var ltk = 0; ltk < toplevels.length; ltk++) {
        if (toplevels[ltk]) liveTopKeys[getTopKey(toplevels[ltk], ltk)] = true;
    }
    for (var cachedKey in _stickyCliByTopId) {
        if (!liveTopKeys[cachedKey]) {
            delete _stickyCliByTopId[cachedKey];
        }
    }

    // 1. Process Pinned Items
    for (var i = 0; i < pinned.length; i++) {
        var p = pinned[i];
        if (p && typeof p === "object" && p.isStack) {
            var subApps = [];
            var isAnySubRunning = false;
            var isAnySubActive = false;

            for (var s = 0; s < p.apps.length; s++) {
                var sAppId = stripDesktop(p.apps[s]);
                var sEntry = entryFor(sAppId);
                var sRawIcon = (sEntry && sEntry.icon) ? sEntry.icon : sAppId;
                var sIcon = resolveIcon(sEntry, sAppId, appLibrary);
                var sName = sEntry && sEntry.name ? sEntry.name : sAppId;
                var sIconSource = (sEntry && sEntry.iconSource) ? sEntry.iconSource : "";
                var sDesktopId = (sEntry && sEntry.id) ? sEntry.id : (sAppId.indexOf(".desktop") !== -1 ? sAppId : (sAppId + ".desktop"));
                var sRes = collectMatchingToplevels(sAppId, sEntry, entries, toplevels, assignedTops, toplevelCliApps, activeToplevel, isTopMinimized, getTopKey);
                if (sRes.windowCount > 0) isAnySubRunning = true;
                if (sRes.isActive) isAnySubActive = true;

                var sInfo = getBadgeInfo(badgeCounts, urgentCounts, sAppId, sEntry, sName, sDesktopId);

                subApps.push({
                    appId: sAppId,
                    desktopId: sDesktopId,
                    exec: (sEntry && sEntry.exec) ? sEntry.exec : "",
                    name: sName,
                    icon: sIcon,
                    rawIcon: sRawIcon,
                    iconSource: sIconSource,
                    isPinned: true,
                    isRunning: sRes.windowCount > 0,
                    isActive: sRes.isActive,
                    isMinimized: sRes.isMinimized,
                    activeTopIndex: sRes.activeTopIndex,
                    windowCount: sRes.windowCount,
                    badgeCount: sInfo.count,
                    hasUrgent: sInfo.hasUrgent,
                    toplevels: sRes.matching
                });
            }

            var totalStackBadge = 0;
            var hasStackUrgent = false;
            for (var sb = 0; sb < subApps.length; sb++) {
                totalStackBadge += (subApps[sb].badgeCount || 0);
                if (subApps[sb].hasUrgent) hasStackUrgent = true;
            }

            items.push({
                id: p.id || ("stack_" + i),
                name: p.name || "Folder",
                icon: p.icon || "folder",
                isStack: true,
                isPinned: true,
                isDuplicate: false,
                isRunning: isAnySubRunning,
                isActive: isAnySubActive,
                subApps: subApps,
                badgeCount: totalStackBadge,
                hasUrgent: hasStackUrgent,
                activeTopIndex: 0,
                windowCount: 0
            });
        } else {
            var appId = stripDesktop(typeof p === "string" ? p : (p && p.id ? p.id : ""));
            if (!appId) continue;

            var entry = entryFor(appId);
            var rawIcon = (entry && entry.icon) ? entry.icon : appId;
            var icon = resolveIcon(entry, appId, appLibrary);
            var name = entry && entry.name ? entry.name : appId;
            var iconSource = (entry && entry.iconSource) ? entry.iconSource : "";
            var desktopId = (entry && entry.id) ? entry.id : (appId.indexOf(".desktop") !== -1 ? appId : (appId + ".desktop"));
            var exec = (entry && entry.exec) ? entry.exec : "";

            var pRes = collectMatchingToplevels(appId, entry, entries, toplevels, assignedTops, toplevelCliApps, activeToplevel, isTopMinimized, getTopKey);
            var itemInfo = getBadgeInfo(badgeCounts, urgentCounts, appId, entry, name, desktopId);

            items.push({
                id: appId,
                appId: appId,
                desktopId: desktopId,
                exec: exec,
                name: name,
                icon: icon,
                rawIcon: rawIcon,
                iconSource: iconSource,
                isStack: false,
                isPinned: true,
                isDuplicate: false,
                isRunning: pRes.windowCount > 0,
                isActive: pRes.isActive,
                isMinimized: pRes.isMinimized,
                activeTopIndex: pRes.activeTopIndex,
                windowCount: pRes.windowCount,
                badgeCount: itemInfo.count,
                hasUrgent: itemInfo.hasUrgent,
                toplevels: pRes.matching
            });
        }
    }

    // 2. Process Running Unpinned Toplevels (Stop if limit reached)
    for (var j = 0; j < toplevels.length; j++) {
        if (maxItems && maxItems > 0 && items.length >= maxItems) {
            break;
        }

        var topItem = toplevels[j];
        if (!topItem) continue;
        var topItemKey = getTopKey(topItem, j);
        if (assignedTops[topItemKey]) continue;

        var rAppId = "";
        var rTitle = "";
        try {
            rAppId = topItem.appId || "";
            rTitle = topItem.title || "";
        } catch (e) {}

        // If window is running inside a terminal emulator and executes a recognized CLI app with a valid installed desktop entry:
        if (isTerminalApp(rAppId)) {
            var rCliApp = (toplevelCliApps[topItemKey] !== undefined) ? toplevelCliApps[topItemKey] : extractCliApp(rTitle, entries);
            if (rCliApp && !isTerminalApp(rCliApp) && hasRealDesktopEntry(entries, rCliApp)) {
                rAppId = rCliApp;
            } else if (!rTitle || rTitle === rAppId || rTitle === "foot" || rTitle === "ghostty" || rTitle === "kitty" || rTitle === "alacritty" || rTitle === "terminal") {
                var isPinnedTerm = false;
                for (var pt = 0; pt < pinned.length; pt++) {
                    var pinnedId = (typeof pinned[pt] === "string") ? pinned[pt] : (pinned[pt] && pinned[pt].id ? pinned[pt].id : "");
                    if (isTerminalApp(stripDesktop(pinnedId))) {
                        isPinnedTerm = true;
                        break;
                    }
                }
                if (isPinnedTerm) {
                    continue;
                }
            }
        }

        var rEntry = entryFor(rAppId);
        if (rEntry && rEntry.id) {
            rAppId = stripDesktop(rEntry.id);
        }
        var rRawIcon = (rEntry && rEntry.icon) ? rEntry.icon : (rAppId || "application-x-executable");
        var rIcon = resolveIcon(rEntry, rAppId, appLibrary);
        var rName = (rEntry && rEntry.name) ? rEntry.name : (rTitle || rAppId || "App");
        var rIconSource = (rEntry && rEntry.iconSource) ? rEntry.iconSource : "";
        var rDesktopId = (rEntry && rEntry.id) ? rEntry.id : (rAppId ? (rAppId.indexOf(".desktop") !== -1 ? rAppId : (rAppId + ".desktop")) : "");
        var rExec = (rEntry && rEntry.exec) ? rEntry.exec : "";

        // Find all unassigned toplevels for this unpinned app
        var rRes = collectMatchingToplevels(rAppId, rEntry, entries, toplevels, assignedTops, toplevelCliApps, activeToplevel, isTopMinimized, getTopKey);
        if (rRes.windowCount === 0) continue;

        var rInfo = getBadgeInfo(badgeCounts, urgentCounts, rAppId, rEntry, rName, rDesktopId);

        items.push({
            id: rAppId,
            appId: rAppId,
            desktopId: rDesktopId,
            exec: rExec,
            name: rName,
            icon: rIcon,
            rawIcon: rRawIcon,
            iconSource: rIconSource,
            isStack: false,
            isPinned: false,
            isDuplicate: false,
            isRunning: true,
            isActive: rRes.isActive,
            isMinimized: rRes.isMinimized,
            activeTopIndex: rRes.activeTopIndex,
            windowCount: rRes.windowCount,
            badgeCount: rInfo.count,
            hasUrgent: rInfo.hasUrgent,
            toplevels: rRes.matching
        });
    }

    return items;
}
