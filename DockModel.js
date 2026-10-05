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
var stripDesktop = Pinned.stripDesktop;
var hyprAddressFor = Matcher.hyprAddressFor;
var toArray = Pinned.toArray;
var parsePinned = Pinned.parsePinned;
var serializePinned = Pinned.serializePinned;
var togglePinned = Pinned.togglePinned;
var dissolveStack = Pinned.dissolveStack;
var setStackIcon = Pinned.setStackIcon;
var createStackFromTwo = Pinned.createStackFromTwo;
var addToStack = Pinned.addToStack;
var removeFromStack = Pinned.removeFromStack;
var renameStack = Pinned.renameStack;
var reorderInStack = Pinned.reorderInStack;
var extractFromStackToDock = Pinned.extractFromStackToDock;
var mergeIntoStack = Pinned.mergeIntoStack;
var reorderPinned = Pinned.reorderPinned;

// =========================================================================
// 2. Semantic Folder Auto-Naming (DockAutoName.js)
// =========================================================================
var SEMANTIC_CATEGORY_MAP = AutoName.SEMANTIC_CATEGORY_MAP;
var SEMANTIC_KEYWORD_MAP = AutoName.SEMANTIC_KEYWORD_MAP;
var BRAND_ECOSYSTEM_MAP = AutoName.BRAND_ECOSYSTEM_MAP;
var normalizeAppKey = AutoName.normalizeAppKey;
var getAppMetadata = AutoName.getAppMetadata;
var hasTokenMatch = AutoName.hasTokenMatch;
var inferFolderName = AutoName.inferFolderName;

// =========================================================================
// 3. Window Matching, Icon Resolution & Dock Item Builder (DockMatcher.js)
// =========================================================================
var KNOWN_APP_DEFAULTS = Matcher.KNOWN_APP_DEFAULTS;
var FALLBACK_ICON_CANDIDATES = Matcher.FALLBACK_ICON_CANDIDATES;
var getCandidates = Matcher.getCandidates;
var normalizeKey = Matcher.normalizeKey;
var extractChromeDomain = Matcher.extractChromeDomain;
var unwrapEntry = Matcher.unwrapEntry;
var findEntry = Matcher.findEntry;
var resolveIcon = Matcher.resolveIcon;
var isBrowserApp = Matcher.isBrowserApp;
var matchToplevel = Matcher.matchToplevel;
var toCanonical = Matcher.toCanonical;
var getBadgeInfo = Matcher.getBadgeInfo;
var buildDockItems = Matcher.buildDockItems;
var setPendingCliHint = Matcher.setPendingCliHint;
var setDetectedCliApps = Matcher.setDetectedCliApps;
var setDefaultAgent = Matcher.setDefaultAgent;
var setDiskIcons = Matcher.setDiskIcons;
var getDiskIcon = Matcher.getDiskIcon;

// =========================================================================
// 4. Dock Widget Management (DockWidgets.js)
// =========================================================================
var switchDockWidgetInBar = Widgets.switchDockWidgetInBar;
var removeWidgetFromBar = Widgets.removeWidgetFromBar;
var returnWidgetToBar = Widgets.returnWidgetToBar;
var addWidgetToDockList = Widgets.addWidgetToDockList;
var removeWidgetFromDockList = Widgets.removeWidgetFromDockList;
var getDockWidgetLayout = Widgets.getDockWidgetLayout;

// =========================================================================
// 5. Application Launcher (DockLauncher.js)
// =========================================================================
var escapeShellArg = Launcher.escapeShellArg;
var parseDesktopExec = Launcher.parseDesktopExec;
var launchApp = Launcher.launchApp;
