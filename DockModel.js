// DockModel.js — Unified facade & API entry point for Omarchy Dock
// Modular architecture: delegates to specialized modules while preserving full backwards compatibility

.pragma library
.import "DockPinned.js" as Pinned
.import "DockAutoName.js" as AutoName
.import "DockMatcher.js" as Matcher
.import "DockWidgets.js" as Widgets
.import "DockLauncher.js" as Launcher

// =========================================================================
// 1. Pinned items & Folder/Stack management (DockPinned.js)
// =========================================================================
var DEFAULT_PINNED = Pinned.DEFAULT_PINNED;

function stripDesktop(id) {
    return Pinned.stripDesktop(id);
}

function hyprAddressFor(toplevel, hyprToplevels) {
    return Matcher.hyprAddressFor(toplevel, hyprToplevels);
}

function toArray(list) {
    return Pinned.toArray(list);
}

function parsePinned(raw) {
    return Pinned.parsePinned(raw);
}

function serializePinned(pinnedList) {
    return Pinned.serializePinned(pinnedList);
}

function togglePinned(pinnedList, appId, maxItems) {
    return Pinned.togglePinned(pinnedList, appId, maxItems);
}

function dissolveStack(pinnedList, stackId) {
    return Pinned.dissolveStack(pinnedList, stackId);
}

function setStackIcon(pinnedList, stackId, iconSymbol) {
    return Pinned.setStackIcon(pinnedList, stackId, iconSymbol);
}

function createStackFromTwo(pinnedList, targetAppId, sourceAppId, allEntries) {
    return Pinned.createStackFromTwo(pinnedList, targetAppId, sourceAppId, allEntries);
}

function addToStack(pinnedList, stackId, sourceAppId) {
    return Pinned.addToStack(pinnedList, stackId, sourceAppId);
}

function removeFromStack(pinnedList, stackId, appId) {
    return Pinned.removeFromStack(pinnedList, stackId, appId);
}

function renameStack(pinnedList, stackId, newName) {
    return Pinned.renameStack(pinnedList, stackId, newName);
}

function reorderInStack(pinnedList, stackId, fromIndex, toIndex) {
    return Pinned.reorderInStack(pinnedList, stackId, fromIndex, toIndex);
}

function extractFromStackToDock(pinnedList, stackId, appId, targetDockIndex) {
    return Pinned.extractFromStackToDock(pinnedList, stackId, appId, targetDockIndex);
}

function mergeIntoStack(pinnedList, dockItems, fromIndex, targetIndex, allEntries) {
    return Pinned.mergeIntoStack(pinnedList, dockItems, fromIndex, targetIndex, allEntries);
}

function reorderPinned(pinnedList, dockItems, fromIndex, toIndex) {
    return Pinned.reorderPinned(pinnedList, dockItems, fromIndex, toIndex);
}

// =========================================================================
// 2. Semantic Folder Auto-Naming (DockAutoName.js)
// =========================================================================
var SEMANTIC_CATEGORY_MAP = AutoName.SEMANTIC_CATEGORY_MAP;
var SEMANTIC_KEYWORD_MAP = AutoName.SEMANTIC_KEYWORD_MAP;
var BRAND_ECOSYSTEM_MAP = AutoName.BRAND_ECOSYSTEM_MAP;

function normalizeAppKey(id) {
    return AutoName.normalizeAppKey(id);
}

function getAppMetadata(appId, allEntries) {
    return AutoName.getAppMetadata(appId, allEntries);
}

function hasTokenMatch(meta, keyword) {
    return AutoName.hasTokenMatch(meta, keyword);
}

function inferFolderName(appId1, appId2, allEntries) {
    return AutoName.inferFolderName(appId1, appId2, allEntries);
}

// =========================================================================
// 3. Window Matching, Icon Resolution & Dock Item Builder (DockMatcher.js)
// =========================================================================
var KNOWN_APP_DEFAULTS = Matcher.KNOWN_APP_DEFAULTS;
var FALLBACK_ICON_CANDIDATES = Matcher.FALLBACK_ICON_CANDIDATES;

function getCandidates(rawIcon, icon, appId) {
    return Matcher.getCandidates(rawIcon, icon, appId);
}

function normalizeKey(str) {
    return Matcher.normalizeKey(str);
}

function extractChromeDomain(appClass) {
    return Matcher.extractChromeDomain(appClass);
}

function unwrapEntry(e) {
    return Matcher.unwrapEntry(e);
}

function findEntry(desktopEntries, appId) {
    return Matcher.findEntry(desktopEntries, appId);
}

function resolveIcon(entry, appId, appLibrary) {
    return Matcher.resolveIcon(entry, appId, appLibrary);
}

function isBrowserApp(id) {
    return Matcher.isBrowserApp(id);
}

function matchToplevel(toplevel, appId, entry, desktopEntries, cachedCliApp) {
    return Matcher.matchToplevel(toplevel, appId, entry, desktopEntries, cachedCliApp);
}

function toCanonical(str) {
    return Matcher.toCanonical(str);
}

function getBadgeInfo(badgeCounts, urgentCounts, appId, entry, name, desktopId) {
    return Matcher.getBadgeInfo(badgeCounts, urgentCounts, appId, entry, name, desktopId);
}

function buildDockItems(pinnedList, toplevelsList, activeToplevel, desktopEntries, appLibrary, badgeCounts, urgentCounts, maxItems, minimizedToplevels) {
    return Matcher.buildDockItems(pinnedList, toplevelsList, activeToplevel, desktopEntries, appLibrary, badgeCounts, urgentCounts, maxItems, minimizedToplevels);
}

function setPendingCliHint(appId, knownWindowsList) {
    return Matcher.setPendingCliHint(appId, knownWindowsList);
}

function setDetectedCliApps(apps) {
    return Matcher.setDetectedCliApps(apps);
}

// =========================================================================
// 4. Dock Widget Management (DockWidgets.js)
// =========================================================================
function switchDockWidgetInBar(shell, newWidgetId, prevWidgetIds, savedPositions, shellConfigFile) {
    return Widgets.switchDockWidgetInBar(shell, newWidgetId, prevWidgetIds, savedPositions, shellConfigFile);
}

function removeWidgetFromBar(shell, widgetId, savedPositions, shellConfigFile) {
    return Widgets.removeWidgetFromBar(shell, widgetId, savedPositions, shellConfigFile);
}

function returnWidgetToBar(shell, widgetId, savedPositions, defaultRegion, shellConfigFile) {
    return Widgets.returnWidgetToBar(shell, widgetId, savedPositions, defaultRegion, shellConfigFile);
}

function addWidgetToDockList(dockWidgetsList, widgetId) {
    return Widgets.addWidgetToDockList(dockWidgetsList, widgetId);
}

function removeWidgetFromDockList(dockWidgetsList, widgetId) {
    return Widgets.removeWidgetFromDockList(dockWidgetsList, widgetId);
}

function getDockWidgetLayout(showAppMenu, appMenuPosition, widgetsEnabled, dockWidgetsList, widgetPosition) {
    return Widgets.getDockWidgetLayout(showAppMenu, appMenuPosition, widgetsEnabled, dockWidgetsList, widgetPosition);
}

// =========================================================================
// 5. Application Launcher (DockLauncher.js)
// =========================================================================
function escapeShellArg(arg) {
    return Launcher.escapeShellArg(arg);
}

function parseDesktopExec(execStr) {
    return Launcher.parseDesktopExec(execStr);
}

function launchApp(shell, itemData, util) {
    return Launcher.launchApp(shell, itemData, util);
}
