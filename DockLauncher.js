// DockLauncher.js — Application launcher module for Omarchy Dock

.pragma library

function escapeShellArg(arg) {
    return "'" + String(arg == null ? "" : arg).replace(/'/g, "'\\''") + "'";
}

function parseDesktopExec(execStr) {
    if (!execStr || typeof execStr !== "string") return [];
    // Remove desktop field codes (%f, %u, %F, %U, etc.) according to FreeDesktop spec
    var raw = execStr.replace(/%%/g, "\x00")
                     .replace(/%[a-zA-Z]/g, "")
                     .replace(/\x00/g, "%")
                     .trim();
    if (!raw) return [];

    var args = [];
    var current = "";
    var inQuotes = false;
    var escape = false;

    for (var i = 0; i < raw.length; i++) {
        var ch = raw[i];

        if (escape) {
            current += ch;
            escape = false;
            continue;
        }

        if (ch === "\\") {
            escape = true;
            continue;
        }

        if (ch === '"') {
            inQuotes = !inQuotes;
            continue;
        }

        if (!inQuotes && (ch === " " || ch === "\t")) {
            if (current.length > 0) {
                args.push(current);
                current = "";
            }
            continue;
        }

        current += ch;
    }

    if (current.length > 0) {
        args.push(current);
    }

    return args;
}

function stripDesktop(id) {
    var value = String(id == null ? "" : id).trim();
    if (value.slice(-8).toLowerCase() === ".desktop") value = value.slice(0, -8);
    if (value.slice(-4).toLowerCase() === ".exe") value = value.slice(0, -4);
    return value;
}

function launchApp(shell, itemData, util) {
    if (!itemData) return;
    var rawLaunchId = itemData.desktopId || itemData.appId || "";
    var appName = itemData.name || "";
    var canonicalId = stripDesktop(rawLaunchId);
    var cleanId = canonicalId.toLowerCase();

    // Fast-path for cliamp & popular CLI utilities: sets dedicated Wayland app-id on foot
    var cliFastApps = ["cliamp", "org.omarchy.cliamp", "yazi", "btop", "nvim", "helix", "micro", "lazygit", "fastfetch"];
    if (cliFastApps.indexOf(cleanId) !== -1 && util && typeof util.execArgv === "function") {
        var baseCmd = (cleanId === "org.omarchy.cliamp" || cleanId === "cliamp") ? "cliamp" : cleanId;
        util.execArgv(["foot", "-a", baseCmd, "-T", baseCmd, "-e", baseCmd]);
        return;
    }

    // 1. Primary: Use Omarchy's official shell.appLibrary launcher
    // Note: Omarchy's AppLibrary.launch appends ".desktop" automatically, so pass canonicalId without extension
    if (shell && shell.appLibrary && typeof shell.appLibrary.launch === "function") {
        var libId = canonicalId || cleanId;
        shell.appLibrary.launch(libId, appName);
        return;
    }

    // 2. Fallback: Launch via gtk-launch or direct argv
    var target = canonicalId ? (canonicalId + ".desktop") : (cleanId ? (cleanId + ".desktop") : "");
    var argv = parseDesktopExec(itemData.exec);
    if (argv.length === 0 && cleanId) {
        argv = [cleanId];
    }

    if (util && typeof util.execArgv === "function") {
        if (target) {
            util.execArgv(["uwsm-app", "--", "gtk-launch", target]);
        } else if (argv.length > 0) {
            util.execArgv(["uwsm-app", "--"].concat(argv));
        }
        return;
    }

    var fallbackCmd = "";
    if (argv.length > 0) {
        var escapedArgs = [];
        for (var a = 0; a < argv.length; a++) {
            escapedArgs.push(escapeShellArg(argv[a]));
        }
        fallbackCmd = "uwsm-app -- " + escapedArgs.join(" ");
    } else if (cleanId) {
        fallbackCmd = "uwsm-app -- " + escapeShellArg(cleanId);
    }

    var cmd = "";
    if (target) {
        cmd = "uwsm-app -- gtk-launch " + escapeShellArg(target);
        if (fallbackCmd) {
            cmd += " || (" + fallbackCmd + ")";
        }
    } else if (fallbackCmd) {
        cmd = fallbackCmd;
    }

    if (cmd && util && typeof util.execDetached === "function") {
        util.execDetached(cmd);
    }
}
