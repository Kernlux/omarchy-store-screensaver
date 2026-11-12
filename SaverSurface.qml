import QtQuick
import Quickshell
import Quickshell.Wayland
import "Palettes.js" as Palettes

// One full-screen screensaver per monitor, above every window.
// Any key, click or real mouse movement wakes it (a short grace period ignores the
// jitter of it appearing). Keys are captured so the wake press isn't typed into an app.
PanelWindow {
    id: surface

    required property var modelData
    property var owner: null
    property bool active: false

    screen: modelData
    visible: active
    color: "black"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "omarchy-store-screensaver"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: active ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    property real shownAt: 0
    property point firstPos: Qt.point(-1, -1)
    onActiveChanged: if (active) { shownAt = Date.now(); firstPos = Qt.point(-1, -1); keys.forceActiveFocus(); }

    function wake(reason) {
        if (!active || Date.now() - shownAt < 1200) return;
        if (owner) owner.dismiss(reason);
    }

    readonly property real fps: view.fps
    SaverView {
        id: view
        anchors.fill: parent
        running: surface.active
        colours: surface.owner ? surface.owner.paletteObj : Palettes.get("aurora")
        speed: surface.owner ? surface.owner.cfg.speed : 1
        shapes: surface.owner ? surface.owner.cfg.shapes : 2
        showClock: surface.owner ? surface.owner.cfg.clock : true
        opacity: surface.active ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 900; easing.type: Easing.OutCubic } }
    }

    Item {
        id: keys
        anchors.fill: parent
        focus: true
        Keys.onPressed: function (e) { e.accepted = true; surface.wake("key"); }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.BlankCursor
        onPressed: surface.wake("click")
        onWheel: surface.wake("wheel")
        onPositionChanged: function (m) {
            if (surface.firstPos.x < 0) { surface.firstPos = Qt.point(m.x, m.y); return; }
            if (Math.abs(m.x - surface.firstPos.x) + Math.abs(m.y - surface.firstPos.y) > 24) surface.wake("mouse");
        }
    }
}
