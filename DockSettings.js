.pragma library

var VISIBILITY_ALWAYS = "always"
var VISIBILITY_HOVER = "hover"
var VISIBILITY_KEYBIND = "keybind"
var VISIBILITY_HYBRID = "hybrid"

var VISIBILITY_OVERRIDE_HIDDEN = -1
var VISIBILITY_OVERRIDE_FOLLOW = 0
var VISIBILITY_OVERRIDE_SHOWN = 1

function normalizeVisibilityMode(value, legacyAutohide) {
    var mode = String(value === undefined || value === null ? "" : value).trim().toLowerCase()
    if (mode === VISIBILITY_ALWAYS || mode === VISIBILITY_HOVER || mode === VISIBILITY_KEYBIND || mode === VISIBILITY_HYBRID) {
        return mode
    }
    return legacyAutohide === true ? VISIBILITY_HOVER : VISIBILITY_ALWAYS
}

function hasHover(visibilityMode) {
    var mode = normalizeVisibilityMode(visibilityMode, false)
    return mode === VISIBILITY_HOVER || mode === VISIBILITY_HYBRID
}

function hasKeybind(visibilityMode) {
    var mode = normalizeVisibilityMode(visibilityMode, false)
    return mode === VISIBILITY_KEYBIND || mode === VISIBILITY_HYBRID
}

function normalizeOverlayMode(value, legacySpaceMode) {
    if (value === true || value === "true") return true
    if (value === false || value === "false") return false
    var mode = String(legacySpaceMode === undefined || legacySpaceMode === null ? "" : legacySpaceMode).trim().toLowerCase()
    return mode === "overlay"
}

function normalizeVisibleWorkspace(value) {
    if (value === undefined || value === null) return "all"
    var workspace = String(value).trim()
    return workspace === "" || workspace.toLowerCase() === "all" ? "all" : workspace
}

function normalizeSuppressSystemDock(value) {
    if (value === false || value === "false" || value === 0 || value === "0") return false
    return true
}

var ICON_SCALE_MIN = 0.75
var ICON_SCALE_MAX = 2.0
var SURFACE_AUTO = "auto"
var SURFACE_POPUP = "popup"

// Multiplies the whole dock (slots, icons, glyphs) on top of the shell's font scale.
function normalizeIconScale(value) {
    var scale = Number(value)
    if (value === null || value === "" || !isFinite(scale)) return 1.0
    return Math.max(ICON_SCALE_MIN, Math.min(ICON_SCALE_MAX, scale))
}

// "auto" follows the bar (translucent and borderless over a transparent bar);
// "popup" always uses the surface and border of Omarchy's popups.
function normalizeSurface(value) {
    var surface = String(value === undefined || value === null ? "" : value).trim().toLowerCase()
    return surface === SURFACE_POPUP ? SURFACE_POPUP : SURFACE_AUTO
}

function normalizeHoverMagnify(value) {
    return value === true || value === "true"
}

// Scale of the icon under the pointer. Magnified icons still fit their slot (24 * 1.5 < 42).
function hoverScale(hoverMagnify) {
    return normalizeHoverMagnify(hoverMagnify) ? 1.5 : 1.10
}

function normalize(raw) {
    var settings = raw && typeof raw === "object" ? raw : {}
    return {
        visibilityMode: normalizeVisibilityMode(settings.visibilityMode, settings.autohide),
        overlayMode: normalizeOverlayMode(settings.overlayMode, settings.spaceMode),
        visibleWorkspace: normalizeVisibleWorkspace(settings.visibleWorkspace),
        suppressSystemDock: normalizeSuppressSystemDock(settings.suppressSystemDock),
        iconScale: normalizeIconScale(settings.iconScale),
        surface: normalizeSurface(settings.surface),
        hoverMagnify: normalizeHoverMagnify(settings.hoverMagnify)
    }
}

function legacyAutohide(visibilityMode) {
    return normalizeVisibilityMode(visibilityMode, false) !== VISIBILITY_ALWAYS
}

function workspaceMatches(selector, workspaceId, workspaceName) {
    var normalized = normalizeVisibleWorkspace(selector)
    if (normalized === "all") return true
    if (normalized === "0" && (String(workspaceId) === "10" || String(workspaceName) === "10")) return true
    if (normalized === "10" && (String(workspaceId) === "0" || String(workspaceName) === "0")) return true
    return String(workspaceId) === normalized || String(workspaceName) === normalized
}

function normalizeVisibilityOverride(value) {
    var override = Number(value)
    if (override < 0) return VISIBILITY_OVERRIDE_HIDDEN
    if (override > 0) return VISIBILITY_OVERRIDE_SHOWN
    return VISIBILITY_OVERRIDE_FOLLOW
}

function shouldSlideOut(visibilityMode, visibilityOverride, dockActive, workspaceEmpty) {
    var override = normalizeVisibilityOverride(visibilityOverride)
    if (override === VISIBILITY_OVERRIDE_HIDDEN) return true
    if (override === VISIBILITY_OVERRIDE_SHOWN) return false

    var mode = normalizeVisibilityMode(visibilityMode, false)
    if (mode === VISIBILITY_ALWAYS) return false
    if (mode === VISIBILITY_KEYBIND) return true
    return dockActive !== true && workspaceEmpty !== true
}

// Whether the keyboard shortcut may toggle the dock. Everything but "hover"
// accepts it; "hover" is the screen-edge trigger's alone, because a dock that
// reveals on approach has nothing for a keypress to add and the two would fight
// over visibilityOverride.
function keyboardToggleAllowed(visibilityMode) {
    return normalizeVisibilityMode(visibilityMode, false) !== VISIBILITY_HOVER
}

function revealRequestAllowed(visibilityMode, source) {
    return source === "internal" || keyboardToggleAllowed(visibilityMode)
}

// In "keybind" mode a dock summoned by the shortcut hides itself again once the
// inactivity timer runs out, the same way hover mode does. A dock the user
// asked to keep on screen in any other mode stays put.
function shouldAutoDismissKeyboardReveal(visibilityMode, visibilityOverride) {
    var mode = normalizeVisibilityMode(visibilityMode, false)
    var isDismissable = mode === VISIBILITY_KEYBIND || mode === VISIBILITY_HYBRID
    return isDismissable
        && normalizeVisibilityOverride(visibilityOverride) === VISIBILITY_OVERRIDE_SHOWN
}

function releaseInteractionVisibilityOverride(owned, previousOverride, currentOverride) {
    return owned === true
        ? normalizeVisibilityOverride(previousOverride)
        : normalizeVisibilityOverride(currentOverride)
}

function dockScreenTarget(visibleWorkspace, visibilityMode, visibilityOverride) {
    if (normalizeVisibleWorkspace(visibleWorkspace) !== "all") return "configured"
    return "all"
}

function screenShowsDock(target, screenName, configuredMonitorName, capturedMonitorName, focusedMonitorName) {
    var name = String(screenName || "")
    if (name === "") return false
    if (target === "configured") return name === String(configuredMonitorName || "")
    if (target === "captured") return name === String(capturedMonitorName || "")
    if (target === "focused") return name === String(focusedMonitorName || "")
    return true
}

function workspaceIdentity(workspace) {
    if (!workspace) return ""
    var name = workspace.name === undefined || workspace.name === null ? "" : String(workspace.name).trim()
    if (name !== "") return name
    if (workspace.id === undefined || workspace.id === null) return ""
    return String(workspace.id)
}

function keyboardToggleWorkspace(monitorWorkspace, focusedWorkspace, toplevelWorkspace) {
    if (monitorWorkspace) return monitorWorkspace
    if (focusedWorkspace) return focusedWorkspace
    if (toplevelWorkspace) return toplevelWorkspace
    return null
}

function keyboardToggleDecision(dockRevealed, configuredSelector, focusedWorkspace, configuredWorkspace) {
    if (dockRevealed === true) {
        return { action: "hide", targetWorkspace: "" }
    }

    var selector = normalizeVisibleWorkspace(configuredSelector)
    var workspace = selector === "all" ? focusedWorkspace : configuredWorkspace
    if (!workspace) {
        return { action: "workspace-unavailable", targetWorkspace: "" }
    }
    if (workspace.active === false) {
        return { action: "workspace-inactive", targetWorkspace: "" }
    }

    var identity = workspaceIdentity(workspace)
    return { action: "show", targetWorkspace: identity || "all" }
}
