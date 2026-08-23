.pragma library

var VISIBILITY_ALWAYS = "always"
var VISIBILITY_HOVER = "hover"
var VISIBILITY_KEYBIND = "keybind"

var SPACE_EXCLUSIVE = "exclusive"
var SPACE_OVERLAY = "overlay"

var VISIBILITY_OVERRIDE_HIDDEN = -1
var VISIBILITY_OVERRIDE_FOLLOW = 0
var VISIBILITY_OVERRIDE_SHOWN = 1

function normalizeVisibilityMode(value, legacyAutohide) {
    var mode = String(value === undefined || value === null ? "" : value).trim().toLowerCase()
    if (mode === VISIBILITY_ALWAYS || mode === VISIBILITY_HOVER || mode === VISIBILITY_KEYBIND) {
        return mode
    }
    return legacyAutohide === true ? VISIBILITY_HOVER : VISIBILITY_ALWAYS
}

function normalizeSpaceMode(value) {
    var mode = String(value === undefined || value === null ? "" : value).trim().toLowerCase()
    return mode === SPACE_OVERLAY ? SPACE_OVERLAY : SPACE_EXCLUSIVE
}

function normalizeVisibleWorkspace(value) {
    if (value === undefined || value === null) return "all"
    var workspace = String(value).trim()
    return workspace === "" || workspace.toLowerCase() === "all" ? "all" : workspace
}

function normalize(raw) {
    var settings = raw && typeof raw === "object" ? raw : {}
    return {
        visibilityMode: normalizeVisibilityMode(settings.visibilityMode, settings.autohide),
        spaceMode: normalizeSpaceMode(settings.spaceMode),
        visibleWorkspace: normalizeVisibleWorkspace(settings.visibleWorkspace)
    }
}

function legacyAutohide(visibilityMode) {
    return normalizeVisibilityMode(visibilityMode, false) !== VISIBILITY_ALWAYS
}

function workspaceMatches(selector, workspaceId, workspaceName) {
    var normalized = normalizeVisibleWorkspace(selector)
    if (normalized === "all") return true
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

function keyboardToggleAllowed(visibilityMode) {
    return normalizeVisibilityMode(visibilityMode, false) !== VISIBILITY_HOVER
}

function revealRequestAllowed(visibilityMode, source) {
    return source === "internal" || keyboardToggleAllowed(visibilityMode)
}

function shouldAutoDismissKeyboardReveal(visibilityMode, visibilityOverride) {
    return normalizeVisibilityMode(visibilityMode, false) === VISIBILITY_KEYBIND
        && normalizeVisibilityOverride(visibilityOverride) === VISIBILITY_OVERRIDE_SHOWN
}

function releaseInteractionVisibilityOverride(owned, previousOverride, currentOverride) {
    return owned === true
        ? normalizeVisibilityOverride(previousOverride)
        : normalizeVisibilityOverride(currentOverride)
}

function dockScreenTarget(visibleWorkspace, visibilityMode, visibilityOverride) {
    if (normalizeVisibleWorkspace(visibleWorkspace) !== "all") return "configured"
    if (normalizeVisibilityOverride(visibilityOverride) === VISIBILITY_OVERRIDE_SHOWN) return "captured"
    if (normalizeVisibilityMode(visibilityMode, false) === VISIBILITY_HOVER) return "focused"
    return "base"
}

function workspaceIdentity(workspace) {
    if (!workspace) return ""
    var name = workspace.name === undefined || workspace.name === null ? "" : String(workspace.name).trim()
    if (name !== "") return name
    if (workspace.id === undefined || workspace.id === null) return ""
    return String(workspace.id)
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
    if (workspace.active !== true) {
        return { action: "workspace-inactive", targetWorkspace: "" }
    }

    var identity = workspaceIdentity(workspace)
    if (identity === "") {
        return { action: "workspace-unavailable", targetWorkspace: "" }
    }
    return { action: "show", targetWorkspace: identity }
}
