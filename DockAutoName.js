.pragma library

// DockAutoName.js — Semantic folder auto-naming for Omarchy Dock

var SEMANTIC_CATEGORY_MAP = [
    { match: ["WebBrowser", "Browser"], name: "Browsers" },
    { match: ["InstantMessaging", "Chat", "IRCClient", "Telephony", "VideoConference"], name: "Messaging" },
    { match: ["Email", "Mail", "News", "Feed"], name: "Communication" },
    { match: ["IDE", "Development", "Debugger", "RevisionControl", "WebDevelopment"], name: "Development" },
    { match: ["TerminalEmulator", "ConsoleOnly"], name: "Terminals" },
    { match: ["TextEditor"], name: "Editors" },
    { match: ["VectorGraphics", "RasterGraphics", "2DGraphics", "3DGraphics", "Photography", "Scanning", "Graphics"], name: "Graphics" },
    { match: ["AudioVideoEditing", "Midi", "Music", "Audio", "Player", "AudioVideo", "Recorder"], name: "Media" },
    { match: ["Spreadsheet", "WordProcessor", "Presentation", "Office", "Finance", "FlowChart"], name: "Productivity" },
    { match: ["Game", "Emulator", "ArcadeGame", "ActionGame", "AdventureGame", "BlocksGame", "BoardGame", "CardGame", "LogicGame"], name: "Games" },
    { match: ["FileManager", "Archiving", "Compression", "FileTools"], name: "Files" },
    { match: ["Security", "PackageManager", "Settings", "System", "Monitor"], name: "System" },
    { match: ["Calculator", "Clock", "Utility"], name: "Utilities" }
];

var SEMANTIC_KEYWORD_MAP = [
    { match: ["chrome", "firefox", "brave", "edge", "browser", "zen", "chromium", "safari", "vivaldi", "tor"], name: "Browsers" },
    { match: ["telegram", "discord", "slack", "signal", "whatsapp", "viber", "element", "matrix", "messenger", "wechat", "messages", "zoom", "meet", "teams", "skype"], name: "Messaging" },
    { match: ["mail", "email", "gmail", "outlook", "thunderbird", "proton", "protonmail", "hey", "почта"], name: "Email" },
    { match: ["code", "vscode", "vscodium", "sublime", "zed", "nvim", "neovim", "helix", "fleet", "pycharm", "clion", "intellij", "idea", "cursor", "antigravity", "dev"], name: "Development" },
    { match: ["ghostty", "kitty", "alacritty", "foot", "wezterm", "terminal", "console"], name: "Terminals" },
    { match: ["spotify", "youtube", "music", "vlc", "mpv", "audacity", "reaper", "tidal", "deezer", "sound", "player"], name: "Media" },
    { match: ["figma", "gimp", "inkscape", "blender", "krita", "photoshop", "illustrator", "canva", "draw", "pinta", "adobe"], name: "Graphics" },
    { match: ["photos", "gallery", "shotwell", "digikam", "photo", "фото"], name: "Photos" },
    { match: ["obsidian", "notion", "logseq", "typora", "notes", "keep", "docs", "sheets", "word", "excel", "office", "paper", "xournal"], name: "Notes & Docs" },
    { match: ["steam", "heroic", "lutris", "retroarch", "prism", "minecraft", "game", "gaming", "portproton"], name: "Games" },
    { match: ["chatgpt", "claude", "grok", "gemini", "copilot", "ollama", "deepseek", "perplexity", "ai"], name: "AI Tools" },
    { match: ["maps", "map", "osm", "карты", "навигатор"], name: "Maps" },
    { match: ["dolphin", "thunar", "nautilus", "nemo", "yazi", "ranger", "files", "caja", "pcmanfm", "drive", "dropbox"], name: "Files" }
];

var CROSS_DOMAIN_RULES = [
    { cats1: ["TerminalEmulator", "ConsoleOnly"], cats2: ["IDE", "Development", "TextEditor", "Debugger", "RevisionControl"], name: "Development" },
    { cats1: ["AudioVideoEditing", "Recorder"], cats2: ["Player", "Music", "Audio", "AudioVideo"], name: "Media" },
    { cats1: ["Graphics", "2DGraphics", "Viewer"], cats2: ["AudioVideo", "Player", "Video"], name: "Media" }
];

function stripDesktop(id) {
    var value = String(id == null ? "" : id).trim();
    if (value.slice(-8).toLowerCase() === ".desktop") value = value.slice(0, -8);
    if (value.slice(-4).toLowerCase() === ".exe") value = value.slice(0, -4);
    return value;
}

function normalizeAppKey(id) {
    if (!id) return "";
    return String(id).replace(/\.desktop$/i, "").replace(/^pin_/, "").replace(/^com\./i, "").replace(/^org\./i, "").trim().toLowerCase();
}

function getAppMetadata(appId, allEntries) {
    var cleanId = normalizeAppKey(appId);
    var categories = [];
    var genericName = "";
    var name = "";
    var comment = "";

    if (Array.isArray(allEntries) && cleanId.length > 0) {
        for (var i = 0; i < allEntries.length; i++) {
            var e = allEntries[i];
            if (!e) continue;
            var entryId = normalizeAppKey(e.id || e.desktopId || "");
            var entryExec = normalizeAppKey(e.execString || e.exec || "");
            var entryName = normalizeAppKey(e.name || "");
            var entryClass = normalizeAppKey(e.appClass || "");

            if (entryId === cleanId || entryExec === cleanId || entryClass === cleanId || entryName === cleanId) {
                if (Array.isArray(e.categories)) {
                    categories = e.categories.slice();
                }
                genericName = String(e.genericName || "").trim();
                name = String(e.name || "").trim();
                comment = String(e.comment || "").trim();
                break;
            }
        }
    }

    var fullText = (cleanId + " " + name + " " + genericName + " " + comment).toLowerCase();
    var rawTokens = fullText.split(/[\s\-_.;,:\/\\]+/);
    var tokens = [];
    for (var t = 0; t < rawTokens.length; t++) {
        var tok = rawTokens[t].trim();
        if (tok.length > 1) tokens.push(tok);
    }

    return {
        id: cleanId,
        name: name,
        genericName: genericName,
        categories: categories,
        tokens: tokens
    };
}

function hasTokenMatch(meta, keyword) {
    if (!meta || !meta.tokens || !keyword) return false;
    var k = keyword.toLowerCase();
    for (var i = 0; i < meta.tokens.length; i++) {
        var t = meta.tokens[i];
        if (t === k) return true;
        if (k.length >= 4 && (t.indexOf(k) === 0 || k.indexOf(t) === 0)) return true;
    }
    return false;
}

var BRAND_ECOSYSTEM_MAP = [
    { match: ["google", "gmail"], name: "Google" },
    { match: ["яндекс", "yandex"], name: "Яндекс" },
    { match: ["adobe", "photoshop", "illustrator", "premiere", "aftereffects", "acrobat", "lightroom", "indesign"], name: "Adobe" },
    { match: ["microsoft", "msoffice", "word", "excel", "powerpoint", "onenote", "teams", "onedrive"], name: "Microsoft" },
    { match: ["libreoffice", "soffice"], name: "LibreOffice" },
    { match: ["jetbrains", "pycharm", "clion", "intellij", "idea", "webstorm", "phpstorm", "goland", "rider", "rubymine", "rustrover", "datagrip", "fleet"], name: "JetBrains" },
    { match: ["apple", "icloud", "itunes"], name: "Apple" },
    { match: ["steam"], name: "Steam" },
    { match: ["proton", "protonmail", "protonvpn", "protonpass", "protondrive"], name: "Proton" },
    { match: ["kde", "kwrite", "dolphin", "kate", "konsole", "ark", "gwenview", "okular", "kcalc"], name: "KDE" },
    { match: ["gnome", "nautilus", "gedit", "evince", "eog", "totem", "epiphany"], name: "GNOME" },
    { match: ["mozilla", "firefox", "thunderbird"], name: "Mozilla" }
];

function getCommonBrandToken(meta1, meta2) {
    if (meta1 && meta2 && meta1.name && meta2.name) {
        var word1 = meta1.name.split(/[\s\-_\.:]+/)[0].trim();
        var word2 = meta2.name.split(/[\s\-_\.:]+/)[0].trim();
        if (word1 && word2 && word1.toLowerCase() === word2.toLowerCase() && word1.length >= 3) {
            return word1.charAt(0).toUpperCase() + word1.slice(1);
        }
    }
    return "";
}

function inferFolderName(appId1, appId2, allEntries) {
    var meta1 = getAppMetadata(appId1, allEntries);
    var meta2 = getAppMetadata(appId2, allEntries);

    // 1. Semantic Category Intersection (both apps match the same category group)
    for (var c = 0; c < SEMANTIC_CATEGORY_MAP.length; c++) {
        var catRule = SEMANTIC_CATEGORY_MAP[c];
        var match1 = false;
        var match2 = false;

        for (var k = 0; k < catRule.match.length; k++) {
            var tag = catRule.match[k];
            if (meta1.categories.indexOf(tag) >= 0) match1 = true;
            if (meta2.categories.indexOf(tag) >= 0) match2 = true;
        }

        if (match1 && match2) {
            return catRule.name;
        }
    }

    // 2. Cross-Domain Rules (combinations of categories from related domains)
    for (var cd = 0; cd < CROSS_DOMAIN_RULES.length; cd++) {
        var rule = CROSS_DOMAIN_RULES[cd];
        var m1_c1 = false;
        var m1_c2 = false;
        var m2_c1 = false;
        var m2_c2 = false;

        for (var i = 0; i < rule.cats1.length; i++) {
            if (meta1.categories.indexOf(rule.cats1[i]) >= 0) m1_c1 = true;
            if (meta2.categories.indexOf(rule.cats1[i]) >= 0) m2_c1 = true;
        }
        for (var j = 0; j < rule.cats2.length; j++) {
            if (meta1.categories.indexOf(rule.cats2[j]) >= 0) m1_c2 = true;
            if (meta2.categories.indexOf(rule.cats2[j]) >= 0) m2_c2 = true;
        }

        if ((m1_c1 && m2_c2) || (m1_c2 && m2_c1)) {
            return rule.name;
        }
    }

    // 3. Brand / Ecosystem Matching (Google, Yandex, Adobe, JetBrains, KDE, GNOME, etc.)
    for (var b = 0; b < BRAND_ECOSYSTEM_MAP.length; b++) {
        var brandRule = BRAND_ECOSYSTEM_MAP[b];
        var bMatch1 = false;
        var bMatch2 = false;

        for (var bk = 0; bk < brandRule.match.length; bk++) {
            var bKey = brandRule.match[bk];
            if (hasTokenMatch(meta1, bKey)) bMatch1 = true;
            if (hasTokenMatch(meta2, bKey)) bMatch2 = true;
        }

        if (bMatch1 && bMatch2) {
            return brandRule.name;
        }
    }

    // 4. Common Brand Word Prefix (e.g. "Steam ..." + "Steam ...")
    var commonPrefix = getCommonBrandToken(meta1, meta2);
    if (commonPrefix) {
        return commonPrefix;
    }

    // 5. Semantic Keyword Match (both apps match the same keyword domain)
    for (var w = 0; w < SEMANTIC_KEYWORD_MAP.length; w++) {
        var keyRule = SEMANTIC_KEYWORD_MAP[w];
        var kwMatch1 = false;
        var kwMatch2 = false;

        for (var kw = 0; kw < keyRule.match.length; kw++) {
            var key = keyRule.match[kw];
            if (hasTokenMatch(meta1, key)) kwMatch1 = true;
            if (hasTokenMatch(meta2, key)) kwMatch2 = true;
        }

        if (kwMatch1 && kwMatch2) {
            return keyRule.name;
        }
    }

    // 6. Fallback: If both have identical non-empty genericName
    if (meta1.genericName && meta2.genericName && meta1.genericName.toLowerCase() === meta2.genericName.toLowerCase()) {
        return meta1.genericName;
    }

    // 7. Default Fallback
    return "Folder";
}
