.pragma library

function switchDockWidgetInBar(shell, newWidgetId, prevWidgetIds, savedPositions, shellConfigFile) {
    if (!savedPositions) savedPositions = {};
    if (!Array.isArray(prevWidgetIds)) prevWidgetIds = [];

    var defaultRegions = {
        "omarchy.menu": "left",
        "omarchy.clock": "center",
        "omarchy.weather": "center",
        "omarchy.system-update": "center",
        "omarchy.indicators": "center",
        "omarchy.audio": "right",
        "omarchy.microphone": "right",
        "omarchy.media": "right",
        "omarchy.bluetooth": "right",
        "omarchy.network": "right",
        "omarchy.power": "right",
        "omarchy.monitor": "right",
        "omarchy.agents": "right",
        "omarchy.tailscale": "right",
        "omarchy.keyboard-layout": "right",
        "omarchy.clipboard": "right",
        "omarchy.emojis": "right",
        "omarchy.reminders": "right",
        "omarchy.tray": "right",
        "omarchy.dropbox": "right",
        "omarchy.speedtest": "right",
        "omarchy.disk-speedtest": "right",
        "omarchy.wifiqr": "right"
    };

    var canonicalSectionOrders = {
        "left": [
            "omarchy.menu",
            "omarchy.workspaces"
        ],
        "center": [
            "omarchy.indicators",
            "rosakodu.dock",
            "omarchy.system-update",
            "omarchy.clock",
            "omarchy.weather"
        ],
        "right": [
            "omarchy.agents",
            "omarchy.tray",
            "glafeara.languages",
            "omarchy.keyboard-layout",
            "omarchy.microphone",
            "silvaio.gamemode",
            "lgse.sandman",
            "omarchy.network",
            "omarchy.bluetooth",
            "omarchy.monitor",
            "omarchy.power",
            "omarchy.audio",
            "omarchy.media",
            "omarchy.tailscale",
            "omarchy.dropbox"
        ]
    };

    var mutator = function(config) {
        if (!config) config = {};
        if (!config.bar) config.bar = {};
        if (!config.bar.layout) config.bar.layout = {};
        var regions = ["left", "center", "right"];
        for (var r = 0; r < regions.length; r++) {
            if (!Array.isArray(config.bar.layout[regions[r]])) {
                config.bar.layout[regions[r]] = [];
            }
        }

        // 1. Return all previous widgets back to bar
        for (var p = 0; p < prevWidgetIds.length; p++) {
            var prevId = prevWidgetIds[p];
            if (!prevId || prevId === "omarchy.apps" || prevId === newWidgetId) continue;

            var savedInfo = savedPositions[prevId];
            var defReg = defaultRegions[prevId] || "right";
            var targetRegion = (savedInfo && savedInfo.region) ? savedInfo.region : defReg;
            var targetEntry = (savedInfo && savedInfo.entry) ? savedInfo.entry : { id: prevId };
            var fullSectionOrder = (savedInfo && Array.isArray(savedInfo.fullSectionOrder) && savedInfo.fullSectionOrder.length > 0)
                ? savedInfo.fullSectionOrder
                : (canonicalSectionOrders[targetRegion] || []);

            // Remove if already in layout anywhere
            for (var r1 = 0; r1 < regions.length; r1++) {
                var list1 = config.bar.layout[regions[r1]];
                for (var i1 = list1.length - 1; i1 >= 0; i1--) {
                    var id1 = (typeof list1[i1] === "string") ? list1[i1] : (list1[i1] && list1[i1].id);
                    if (id1 === prevId) {
                        list1.splice(i1, 1);
                    }
                }
            }

            // Insert into targetRegion
            var targetList = config.bar.layout[targetRegion];
            var insertAt = -1;

            if (fullSectionOrder.length > 0) {
                var selfOrderIdx = fullSectionOrder.indexOf(prevId);
                if (selfOrderIdx !== -1) {
                    for (var f = selfOrderIdx + 1; f < fullSectionOrder.length; f++) {
                        var fId = fullSectionOrder[f];
                        for (var m = 0; m < targetList.length; m++) {
                            var mId = (typeof targetList[m] === "string") ? targetList[m] : (targetList[m] && targetList[m].id);
                            if (mId === fId) {
                                insertAt = m;
                                break;
                            }
                        }
                        if (insertAt !== -1) break;
                    }
                    if (insertAt === -1) {
                        for (var b = selfOrderIdx - 1; b >= 0; b--) {
                            var bId = fullSectionOrder[b];
                            for (var n = 0; n < targetList.length; n++) {
                                var nId = (typeof targetList[n] === "string") ? targetList[n] : (targetList[n] && targetList[n].id);
                                if (nId === bId) {
                                    insertAt = n + 1;
                                    break;
                                }
                            }
                            if (insertAt !== -1) break;
                        }
                    }
                }
            }

            if (insertAt === -1 && savedInfo && savedInfo.index !== undefined) {
                insertAt = Math.min(Math.max(0, savedInfo.index), targetList.length);
            }
            if (insertAt === -1) {
                insertAt = targetList.length;
            }

            targetList.splice(insertAt, 0, targetEntry);
            if (savedInfo && savedInfo.addedToPlugins && Array.isArray(config.plugins)) {
                for (var ppi = config.plugins.length - 1; ppi >= 0; ppi--) {
                    var ppItem = config.plugins[ppi];
                    var ppId = (typeof ppItem === "string") ? ppItem : (ppItem && ppItem.id);
                    if (ppId === prevId) {
                        config.plugins.splice(ppi, 1);
                    }
                }
            }
            delete savedPositions[prevId];
        }

        // 2. If newWidgetId is provided and not omarchy.apps, remove it from bar and snapshot position
        if (newWidgetId && newWidgetId !== "omarchy.apps") {
            for (var r2 = 0; r2 < regions.length; r2++) {
                var regionName = regions[r2];
                var list2 = config.bar.layout[regionName];
                for (var i2 = list2.length - 1; i2 >= 0; i2--) {
                    var entry2 = list2[i2];
                    var id2 = (typeof entry2 === "string") ? entry2 : (entry2 && entry2.id);
                    if (id2 === newWidgetId) {
                        var fullSec = [];
                        for (var s2 = 0; s2 < list2.length; s2++) {
                            var sId2 = (typeof list2[s2] === "string") ? list2[s2] : (list2[s2] && list2[s2].id);
                            if (sId2) fullSec.push(sId2);
                        }
                        savedPositions[newWidgetId] = {
                            region: regionName,
                            index: i2,
                            fullSectionOrder: fullSec,
                            entry: JSON.parse(JSON.stringify(entry2))
                        };
                        list2.splice(i2, 1);
                    }
                }
            }

            // Keep plugin enabled in Omarchy shell while hosted in dock
            if (!Array.isArray(config.plugins)) config.plugins = [];
            var foundInPlugins = false;
            for (var pi = 0; pi < config.plugins.length; pi++) {
                var pItem = config.plugins[pi];
                var pId = (typeof pItem === "string") ? pItem : (pItem && pItem.id);
                if (pId === newWidgetId) { foundInPlugins = true; break; }
            }
            if (!foundInPlugins) {
                config.plugins.push({ id: newWidgetId });
                if (!savedPositions[newWidgetId]) savedPositions[newWidgetId] = {};
                savedPositions[newWidgetId].addedToPlugins = true;
            }
        }
    };

    if (shell && typeof shell.mutateShellConfig === "function") {
        shell.mutateShellConfig(mutator);
    }
    if (shellConfigFile && typeof shellConfigFile.text === "function" && typeof shellConfigFile.setText === "function") {
        try {
            var raw = shellConfigFile.text();
            if (raw) {
                var config = JSON.parse(raw);
                mutator(config);
                shellConfigFile.setText(JSON.stringify(config, null, 2) + "\n");
            }
        } catch(e) {}
    }

    return savedPositions;
}

function removeWidgetFromBar(shell, widgetId, savedPositions, shellConfigFile) {
    if (!savedPositions) savedPositions = {};
    
    var mutator = function(config) {
        if (!config || !config.bar || !config.bar.layout) return;
        var regions = ["left", "center", "right"];
        for (var r = 0; r < regions.length; r++) {
            var regionName = regions[r];
            var list = config.bar.layout[regionName];
            if (Array.isArray(list)) {
                for (var i = list.length - 1; i >= 0; i--) {
                    var entry = list[i];
                    var id = (typeof entry === "string") ? entry : (entry && entry.id);
                    if (id === widgetId) {
                        var fullSectionOrder = [];
                        for (var s = 0; s < list.length; s++) {
                            var sid = (typeof list[s] === "string") ? list[s] : (list[s] && list[s].id);
                            if (sid) fullSectionOrder.push(sid);
                        }

                        var neighborsBefore = [];
                        for (var b = i - 1; b >= 0; b--) {
                            var bid = (typeof list[b] === "string") ? list[b] : (list[b] && list[b].id);
                            if (bid) neighborsBefore.push(bid);
                        }
                        var neighborsAfter = [];
                        for (var a = i + 1; a < list.length; a++) {
                            var aid = (typeof list[a] === "string") ? list[a] : (list[a] && list[a].id);
                            if (aid) neighborsAfter.push(aid);
                        }
                        savedPositions[widgetId] = {
                            region: regionName,
                            index: i,
                            fullSectionOrder: fullSectionOrder,
                            neighborsBefore: neighborsBefore,
                            neighborsAfter: neighborsAfter,
                            entry: JSON.parse(JSON.stringify(entry))
                        };
                        list.splice(i, 1);
                    }
                }
            }
        }

        if (widgetId && widgetId !== "omarchy.apps") {
            if (!Array.isArray(config.plugins)) config.plugins = [];
            var foundInPlugins = false;
            for (var pi = 0; pi < config.plugins.length; pi++) {
                var pItem = config.plugins[pi];
                var pId = (typeof pItem === "string") ? pItem : (pItem && pItem.id);
                if (pId === widgetId) { foundInPlugins = true; break; }
            }
            if (!foundInPlugins) {
                config.plugins.push({ id: widgetId });
                if (!savedPositions[widgetId]) savedPositions[widgetId] = {};
                savedPositions[widgetId].addedToPlugins = true;
            }
        }
    };

    if (shell && typeof shell.mutateShellConfig === "function") {
        shell.mutateShellConfig(mutator);
    }
    if (shellConfigFile && typeof shellConfigFile.text === "function" && typeof shellConfigFile.setText === "function") {
        try {
            var raw = shellConfigFile.text();
            if (raw) {
                var config = JSON.parse(raw);
                mutator(config);
                shellConfigFile.setText(JSON.stringify(config, null, 2) + "\n");
            }
        } catch(e) {}
    }
    return savedPositions;
}

function returnWidgetToBar(shell, widgetId, savedPositions, defaultRegion, shellConfigFile) {
    if (!defaultRegion) defaultRegion = "right";
    if (!savedPositions) savedPositions = {};

    var defaultRegions = {
        "omarchy.menu": "left",
        "omarchy.clock": "center",
        "omarchy.weather": "center",
        "omarchy.system-update": "center",
        "omarchy.indicators": "center",
        "omarchy.audio": "right",
        "omarchy.microphone": "right",
        "omarchy.media": "right",
        "omarchy.bluetooth": "right",
        "omarchy.network": "right",
        "omarchy.power": "right",
        "omarchy.monitor": "right",
        "omarchy.agents": "right",
        "omarchy.tailscale": "right",
        "omarchy.keyboard-layout": "right",
        "omarchy.clipboard": "right",
        "omarchy.emojis": "right",
        "omarchy.reminders": "right",
        "omarchy.tray": "right",
        "omarchy.dropbox": "right",
        "omarchy.speedtest": "right",
        "omarchy.disk-speedtest": "right",
        "omarchy.wifiqr": "right"
    };

    var canonicalSectionOrders = {
        "left": [
            "omarchy.menu",
            "omarchy.workspaces"
        ],
        "center": [
            "omarchy.indicators",
            "rosakodu.dock",
            "omarchy.system-update",
            "omarchy.clock",
            "omarchy.weather"
        ],
        "right": [
            "omarchy.agents",
            "omarchy.tray",
            "glafeara.languages",
            "omarchy.keyboard-layout",
            "omarchy.microphone",
            "silvaio.gamemode",
            "lgse.sandman",
            "omarchy.network",
            "omarchy.bluetooth",
            "omarchy.monitor",
            "omarchy.power",
            "omarchy.audio",
            "omarchy.media",
            "omarchy.tailscale",
            "omarchy.dropbox"
        ]
    };

    var savedInfo = savedPositions[widgetId];
    var targetRegion = (savedInfo && savedInfo.region) ? savedInfo.region : (defaultRegions[widgetId] || defaultRegion);
    var targetIndex = (savedInfo && savedInfo.index !== undefined) ? savedInfo.index : 999;
    var targetEntry = (savedInfo && savedInfo.entry) ? savedInfo.entry : { id: widgetId };
    var fullSectionOrder = (savedInfo && Array.isArray(savedInfo.fullSectionOrder) && savedInfo.fullSectionOrder.length > 0)
        ? savedInfo.fullSectionOrder
        : (canonicalSectionOrders[targetRegion] || []);
    var nBeforeList = (savedInfo && Array.isArray(savedInfo.neighborsBefore))
        ? savedInfo.neighborsBefore
        : (savedInfo && savedInfo.neighborBefore ? [savedInfo.neighborBefore] : []);
    var nAfterList = (savedInfo && Array.isArray(savedInfo.neighborsAfter))
        ? savedInfo.neighborsAfter
        : (savedInfo && savedInfo.neighborAfter ? [savedInfo.neighborAfter] : []);

    var mutator = function(config) {
        if (!config) config = {};
        if (!config.bar) config.bar = {};
        if (!config.bar.layout) config.bar.layout = {};
        if (!Array.isArray(config.bar.layout[targetRegion])) config.bar.layout[targetRegion] = [];

        var regions = ["left", "center", "right"];

        // 1. Remove if already anywhere in layout so we can re-place it with 100% precision
        for (var r = 0; r < regions.length; r++) {
            var list = config.bar.layout[regions[r]];
            if (Array.isArray(list)) {
                for (var i = list.length - 1; i >= 0; i--) {
                    var id = (typeof list[i] === "string") ? list[i] : (list[i] && list[i].id);
                    if (id === widgetId) {
                        list.splice(i, 1);
                    }
                }
            }
        }

        var targetList = config.bar.layout[targetRegion];
        var insertAt = -1;

        // Snapshot-driven placement:
        if (fullSectionOrder.length > 0) {
            var selfOrderIdx = fullSectionOrder.indexOf(widgetId);
            if (selfOrderIdx !== -1) {
                // Check following items in snapshot order
                for (var f = selfOrderIdx + 1; f < fullSectionOrder.length; f++) {
                    var fId = fullSectionOrder[f];
                    for (var m = 0; m < targetList.length; m++) {
                        var mId = (typeof targetList[m] === "string") ? targetList[m] : (targetList[m] && targetList[m].id);
                        if (mId === fId) {
                            insertAt = m;
                            break;
                        }
                    }
                    if (insertAt !== -1) break;
                }

                // If not found after, check preceding items in snapshot order
                if (insertAt === -1) {
                    for (var p = selfOrderIdx - 1; p >= 0; p--) {
                        var pId = fullSectionOrder[p];
                        for (var n = 0; n < targetList.length; n++) {
                            var nId = (typeof targetList[n] === "string") ? targetList[n] : (targetList[n] && targetList[n].id);
                            if (nId === pId) {
                                insertAt = n + 1;
                                break;
                            }
                        }
                        if (insertAt !== -1) break;
                    }
                }
            }
        }

        // Fallback to neighbor arrays
        if (insertAt === -1) {
            for (var a = 0; a < nAfterList.length; a++) {
                var na = nAfterList[a];
                for (var k = 0; k < targetList.length; k++) {
                    var kid = (typeof targetList[k] === "string") ? targetList[k] : (targetList[k] && targetList[k].id);
                    if (kid === na) {
                        insertAt = k;
                        break;
                    }
                }
                if (insertAt !== -1) break;
            }
        }

        if (insertAt === -1) {
            for (var b = 0; b < nBeforeList.length; b++) {
                var nb = nBeforeList[b];
                for (var j = 0; j < targetList.length; j++) {
                    var jid = (typeof targetList[j] === "string") ? targetList[j] : (targetList[j] && targetList[j].id);
                    if (jid === nb) {
                        insertAt = j + 1;
                        break;
                    }
                }
                if (insertAt !== -1) break;
            }
        }

        if (insertAt === -1) {
            insertAt = Math.min(Math.max(0, targetIndex), targetList.length);
        }

        targetList.splice(insertAt, 0, targetEntry);
        if (savedInfo && savedInfo.addedToPlugins && Array.isArray(config.plugins)) {
            for (var pi = config.plugins.length - 1; pi >= 0; pi--) {
                var pItem = config.plugins[pi];
                var pId = (typeof pItem === "string") ? pItem : (pItem && pItem.id);
                if (pId === widgetId) {
                    config.plugins.splice(pi, 1);
                }
            }
        }
    };

    if (shell && typeof shell.mutateShellConfig === "function") {
        shell.mutateShellConfig(mutator);
    }
    if (shellConfigFile && typeof shellConfigFile.text === "function" && typeof shellConfigFile.setText === "function") {
        try {
            var raw = shellConfigFile.text();
            if (raw) {
                var config = JSON.parse(raw);
                mutator(config);
                shellConfigFile.setText(JSON.stringify(config, null, 2) + "\n");
            }
        } catch(e) {}
    }

    delete savedPositions[widgetId];
    return savedPositions;
}

function addWidgetToDockList(dockWidgetsList, widgetId) {
    var arr = Array.isArray(dockWidgetsList) ? dockWidgetsList.slice() : [];
    if (!widgetId) return arr;

    // Remove duplicates of the same widgetId
    for (var i = arr.length - 1; i >= 0; i--) {
        if (arr[i] === widgetId) arr.splice(i, 1);
    }

    if (widgetId === "omarchy.apps") {
        // Add omarchy.apps at the front, keep other non-apps widgets (max 1)
        var others = arr.filter(function(id) { return id && id !== "omarchy.apps"; });
        return ["omarchy.apps"].concat(others.slice(0, 1));
    } else {
        // Add non-apps widget; preserve omarchy.apps if present, cap others at 1
        var hasApps = arr.indexOf("omarchy.apps") !== -1;
        var result = hasApps ? ["omarchy.apps", widgetId] : [widgetId];
        return result;
    }
}

function removeWidgetFromDockList(dockWidgetsList, widgetId) {
    var arr = Array.isArray(dockWidgetsList) ? dockWidgetsList.slice() : [];
    var res = [];
    for (var i = 0; i < arr.length; i++) {
        if (arr[i] !== widgetId) {
            res.push(arr[i]);
        }
    }
    return res;
}

function getDockWidgetLayout(showAppMenu, appMenuPosition, widgetsEnabled, dockWidgetsList, widgetPosition) {
    var leftWidgets = [];
    var rightWidgets = [];
    var appPos = (appMenuPosition === "right") ? "right" : "left";
    var otherPos = (widgetPosition === "left") ? "left" : "right";

    if (!widgetsEnabled) {
        return {
            leftWidgets: [],
            rightWidgets: []
        };
    }

    var hasApps = (showAppMenu === true) && Array.isArray(dockWidgetsList) && (dockWidgetsList.indexOf("omarchy.apps") !== -1);

    // Left side:
    if (hasApps && appPos === "left") {
        leftWidgets.push("omarchy.apps");
    }
    if (otherPos === "left") {
        var listL = Array.isArray(dockWidgetsList) ? dockWidgetsList : [];
        for (var i = 0; i < listL.length; i++) {
            if (listL[i] && listL[i] !== "omarchy.apps") {
                leftWidgets.push(listL[i]);
            }
        }
    }

    // Right side:
    if (otherPos === "right") {
        var listR = Array.isArray(dockWidgetsList) ? dockWidgetsList : [];
        for (var j = 0; j < listR.length; j++) {
            if (listR[j] && listR[j] !== "omarchy.apps") {
                rightWidgets.push(listR[j]);
            }
        }
    }
    if (hasApps && appPos === "right") {
        rightWidgets.push("omarchy.apps");
    }

    return {
        leftWidgets: leftWidgets,
        rightWidgets: rightWidgets
    };
}
