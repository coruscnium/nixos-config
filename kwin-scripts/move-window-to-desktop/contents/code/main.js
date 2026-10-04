// Move the focused window to desktop N and follow it there.
//
// The move goes through KWin's own slotWindowToNextDesktop()/PreviousDesktop()
// actions, one desktop per step -- NOT by assigning window.desktops directly.
// Those slots are KWin's built-in "move window to the next/previous desktop"
// operations, so the desktop switch animates the way KWin intends and carries
// the window along with it. Assigning window.desktops by hand instead makes the
// window vanish from the old desktop and pop in on the target.
//
// Defaults use the shifted-symbol form (Meta+!, Meta+@, ...) rather than
// "Meta+Shift+1": KGlobalAccel canonicalises Shift+<digit> to its symbol, so a
// literal "Meta+Shift+1" is stored but never matches the key event.
registerShortcut("MoveWindowToDesktop1", "Move Window to Desktop 1", "Meta+!", function () { moveToDesktop(1); });
registerShortcut("MoveWindowToDesktop2", "Move Window to Desktop 2", "Meta+@", function () { moveToDesktop(2); });
registerShortcut("MoveWindowToDesktop3", "Move Window to Desktop 3", "Meta+#", function () { moveToDesktop(3); });
registerShortcut("MoveWindowToDesktop4", "Move Window to Desktop 4", "Meta+$", function () { moveToDesktop(4); });
registerShortcut("MoveWindowToDesktop5", "Move Window to Desktop 5", "Meta+%", function () { moveToDesktop(5); });

function moveToDesktop(n) {
    if (n < 1 || n > workspace.desktops.length) {
        return;
    }

    var win = workspace.activeWindow;
    if (!win || !win.moveable || win.onAllDesktops) {
        return;
    }

    var current = workspace.currentDesktop.x11DesktopNumber;
    while (current < n) {
        workspace.slotWindowToNextDesktop();
        current++;
    }
    while (current > n) {
        workspace.slotWindowToPreviousDesktop();
        current--;
    }
}
