// Rescue windows whose frame misses every output.
//
// X11 clients pick their own geometry and KWin honours the request, so a client
// that works out a position relative to the primary monitor's corner instead of
// the workspace origin lands in the dead space above/left of the monitors. KWin
// will not pull it back on its own: it clamps windows to the bounding box of the
// workspace, and the dead corner is inside that box.
//
// A window is only touched when its frame intersects NO output at all. A window
// deliberately dragged half off an edge still intersects, so it is left alone.
//
// Side benefit: unplugging a monitor or changing the layout leaves windows on the
// output that went away. Those miss every remaining output too, so they get
// rescued as well.

var VERBOSE = true;

// Set false to place the window exactly at the cursor even when that pushes its
// titlebar past the bottom-right edge of the screen.
var CLAMP_INTO_SCREEN = true;

// Placing a window moves it, which fires the geometry handler we connect
// ourselves. Without this the rescue would re-enter on its own result.
var placing = false;

function log(message) {
    if (!VERBOSE) {
        return;
    }
    if (typeof print === "function") {
        print("offscreen-rescue: " + message);
    } else if (typeof console !== "undefined" && console.log) {
        console.log("offscreen-rescue: " + message);
    }
}

function screenContaining(screens, point) {
    for (var i = 0; i < screens.length; i++) {
        var g = screens[i].geometry;
        if (point.x >= g.x && point.x < g.x + g.width &&
            point.y >= g.y && point.y < g.y + g.height) {
            return g;
        }
    }
    return null;
}

// Strict overlap test, so a window touching an edge with zero shared pixels does
// not count as visible.
function intersectsAny(screens, geo) {
    for (var i = 0; i < screens.length; i++) {
        var g = screens[i].geometry;
        if (geo.x < g.x + g.width && geo.x + geo.width > g.x &&
            geo.y < g.y + g.height && geo.y + geo.height > g.y) {
            return true;
        }
    }
    return false;
}

// Keep the top-left reachable. The inner Math.max covers a window larger than the
// screen: it falls back to the screen's own corner instead of a negative offset.
function clampInto(screen, x, y, width, height) {
    return {
        x: Math.max(screen.x, Math.min(x, screen.x + screen.width - width)),
        y: Math.max(screen.y, Math.min(y, screen.y + screen.height - height)),
        width: width,
        height: height
    };
}

function eligible(win) {
    if (!win || win.deleted || !win.moveable) {
        return false;
    }
    // Panels, the desktop/wallpaper surface and other shell surfaces position
    // themselves; moving them fights the compositor. moveable already excludes
    // them (plasmashell reports moveable=false) -- this is belt and braces.
    if (win.dock === true || win.desktopWindow === true) {
        return false;
    }
    if (win.hidden === true || win.specialWindow === true) {
        return false;
    }
    // Real user windows only. Transient menus/tooltips/popups are the app's own
    // business and are deliberately not rescued.
    if (!(win.normalWindow === true || win.dialog === true || win.utility === true)) {
        return false;
    }
    return true;
}

function place(win, x, y, width, height) {
    // frameGeometry is a writable property on the scripting wrapper -- verified by
    // writing it and reading it back through KWin's own JS engine.
    //
    // Do NOT look for move()/moveResize() here: neither exists. `win.move` is a
    // *boolean* on the scripting wrapper meaning "this window can be moved", not a
    // function, so a typeof check against it silently finds nothing.
    try {
        win.frameGeometry = { x: x, y: y, width: width, height: height };
        return "frameGeometry";
    } catch (e) {
        log("could not move: " + e);
        return null;
    }
}

function rescue(win) {
    if (placing || !eligible(win)) {
        return;
    }

    var screens = workspace.screens;
    if (!screens || screens.length === 0) {
        return;
    }

    var geo = win.frameGeometry;
    if (!geo || (geo.width === 0 && geo.height === 0)) {
        return;
    }
    if (intersectsAny(screens, geo)) {
        return;
    }

    var cursor = workspace.cursorPos;
    var target = screenContaining(screens, cursor);
    if (!target) {
        // Cursor is in the dead space too. Any screen beats none.
        target = workspace.activeScreen ? workspace.activeScreen.geometry : screens[0].geometry;
    }

    var spot = CLAMP_INTO_SCREEN
        ? clampInto(target, cursor.x, cursor.y, geo.width, geo.height)
        : { x: cursor.x, y: cursor.y, width: geo.width, height: geo.height };

    // Snapshot BEFORE moving. `geo` is a live wrapper over the window's geometry,
    // so reading it after place() reports the new position as if it were the old
    // one -- which makes the log lie in exactly the way that wastes an afternoon.
    var fromX = geo.x;
    var fromY = geo.y;
    var fromW = geo.width;
    var fromH = geo.height;

    placing = true;
    var via = place(win, spot.x, spot.y, spot.width, spot.height);
    placing = false;

    log((win.caption || win.resourceClass || win.windowId || "window") +
        " " + fromW + "x" + fromH + " at " + fromX + "," + fromY +
        " -> " + spot.x + "," + spot.y + (via ? " via " + via : " (no move call!)"));

    // Self-check: if it still misses every screen after the move, the placement
    // logic is wrong (usually the cursor is in dead space too) and saying so beats
    // silently leaving it where it was.
    if (!intersectsAny(workspace.screens, win.frameGeometry)) {
        log("WARNING: still off-screen after the move: " +
            win.frameGeometry.x + "," + win.frameGeometry.y);
    }
}

function watch(win) {
    // Connected before the first rescue: a window that has not finished being
    // placed when windowAdded fires gets caught on its next geometry change.
    win.frameGeometryChanged.connect(function () {
        rescue(win);
    });
    rescue(win);
}

workspace.windowAdded.connect(watch);

// Windows already misplaced when the script loads.
var existing = workspace.windowList();
for (var i = 0; i < existing.length; i++) {
    watch(existing[i]);
}

// Say what we think the world looks like. KWin script output lands in the system
// journal (kwin_wayland), and only if the kwin_scripting debug category is on.
(function () {
    var rects = [];
    var screens = workspace.screens;
    for (var i = 0; i < screens.length; i++) {
        var g = screens[i].geometry;
        rects.push(g.x + "," + g.y + " " + g.width + "x" + g.height);
    }
    log("loaded. screens: [" + rects.join(" | ") + "] cursor " +
        workspace.cursorPos.x + "," + workspace.cursorPos.y +
        " windows " + existing.length);
})();
