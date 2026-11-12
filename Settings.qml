import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "Palettes.js" as Palettes

// Screensaver Settings: opened from the app launcher ("Screensaver Settings") or with
//   omarchy-shell shell summon omarchy-store-screensaver
// Changes save instantly; the background service picks them up right away.
Item {
    id: root

    property var shell: null
    property var manifest: null

    property bool opened: false
    readonly property string home: Quickshell.env("HOME")
    readonly property string cfgDir: home + "/.config/omarchy-store-screensaver"
    readonly property var defaults: ({ enabled: true, palette: "aurora", waitMinutes: 3, password: false, clock: true, speed: 1.0, shapes: 2 })
    property var cfg: defaults
    property var themePalette: null
    readonly property var waits: [1, 2, 3, 5, 10, 15, 20, 30, 45, 60]

    function open(payloadJson) { opened = true; mk.running = true; cfgFile.reload(); }
    function close() { opened = false; }
    function dismiss() {
        if (shell && typeof shell.hide === "function") shell.hide((manifest && manifest.id) || "omarchy-store-screensaver");
        else opened = false;
    }

    function set(k, v) {
        var o = {};
        for (var key in defaults) o[key] = cfg[key] !== undefined ? cfg[key] : defaults[key];
        o[k] = v;
        cfg = o;
        cfgFile.setText(JSON.stringify(o, null, 2) + "\n");
    }
    function pal(id) { return id === "theme" && themePalette ? themePalette : Palettes.get(id); }
    function grad(p) { return p.c; }

    Process { id: mk; command: ["mkdir", "-p", root.cfgDir] }
    Process { id: testProc; command: ["omarchy-shell", "omarchy-store-screensaver", "test"] }

    FileView {
        id: cfgFile
        path: root.cfgDir + "/settings.json"
        printErrors: false
        atomicWrites: true
        onLoaded: {
            try {
                var o = JSON.parse(text()), out = {};
                for (var k in root.defaults) out[k] = o[k] !== undefined ? o[k] : root.defaults[k];
                root.cfg = out;
            } catch (e) { root.cfg = root.defaults; }
        }
        onLoadFailed: root.cfg = root.defaults
    }
    FileView {
        path: root.home + "/.local/state/omarchy/current/theme/colors.toml"
        printErrors: false
        onLoaded: root.themePalette = Palettes.fromColorsToml(text())
    }

    PanelWindow {
        id: win
        visible: root.opened
        color: "transparent"
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "omarchy-store-screensaver-settings"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: root.opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        // dim backdrop; click outside the card to close
        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.45)
            MouseArea { anchors.fill: parent; onClicked: root.dismiss() }
        }

        Item {
            anchors.fill: parent
            focus: root.opened
            Keys.onEscapePressed: root.dismiss()
        }

        Rectangle {
            id: card
            width: Math.min(parent.width - 60, 880)
            height: Math.min(parent.height - 60, body.implicitHeight + 48)
            anchors.centerIn: parent
            radius: 22
            color: Qt.rgba(0.07, 0.06, 0.12, 0.92)
            border.color: Qt.rgba(1, 1, 1, 0.14)
            MouseArea { anchors.fill: parent }   // swallow clicks so the card doesn't close

            Flickable {
                anchors.fill: parent
                anchors.margins: 24
                contentHeight: body.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: body
                    width: parent.width
                    spacing: 18

                    // ---- header ----
                    Row {
                        width: parent.width
                        spacing: 14
                        Image { source: Qt.resolvedUrl("assets/icon.png"); width: 46; height: 46; sourceSize.width: 92; sourceSize.height: 92 }
                        Column {
                            width: parent.width - 46 - 14 - onSwitch.width - 14
                            anchors.verticalCenter: parent.verticalCenter
                            Text { text: "Screensaver"; color: "white"; font.pixelSize: 22; font.weight: Font.Bold }
                            Text { text: "Omarchy Store Screensaver"; color: Qt.rgba(1, 1, 1, 0.6); font.pixelSize: 13 }
                        }
                        Switch { id: onSwitch; anchors.verticalCenter: parent.verticalCenter; checked: root.cfg.enabled; label: root.cfg.enabled ? "On" : "Off"; onToggled: root.set("enabled", !root.cfg.enabled) }
                    }

                    // ---- live preview ----
                    Rectangle {
                        width: parent.width; height: width * 9 / 16 * 0.62
                        radius: 14; clip: true; color: "black"
                        border.color: Qt.rgba(1, 1, 1, 0.12)
                        SaverView {
                            anchors.fill: parent
                            running: root.opened
                            colours: root.pal(root.cfg.palette)
                            speed: root.cfg.speed
                            shapes: root.cfg.shapes
                            showClock: root.cfg.clock
                        }
                        Pill {
                            anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.margins: 12
                            text: "▶  Preview full screen"
                            onClicked: { root.dismiss(); testProc.running = true; }
                        }
                    }

                    // ---- colours ----
                    Text { text: "Colours"; color: "white"; font.pixelSize: 15; font.weight: Font.DemiBold }
                    Flow {
                        width: parent.width
                        spacing: 10
                        Repeater {
                            model: Palettes.LIST
                            delegate: Rectangle {
                                required property var modelData
                                readonly property var p: root.pal(modelData.id)
                                readonly property bool on: root.cfg.palette === modelData.id
                                width: (body.width - 40) / 5; height: 62
                                radius: 12
                                color: on ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.06)
                                border.color: on ? "#9ece6a" : Qt.rgba(1, 1, 1, 0.1)
                                border.width: on ? 2 : 1
                                Row {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    y: 12; spacing: 3
                                    Repeater {
                                        model: p.c.slice(0, 4)
                                        delegate: Rectangle { required property var modelData; width: 14; height: 14; radius: 7; color: modelData }
                                    }
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.bottom: parent.bottom; anchors.bottomMargin: 9
                                    width: parent.width - 10; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight
                                    text: modelData.name; color: "white"; font.pixelSize: 12
                                }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.set("palette", modelData.id) }
                            }
                        }
                    }

                    // ---- wait ----
                    Text { text: "Start after I've been away for"; color: "white"; font.pixelSize: 15; font.weight: Font.DemiBold }
                    Flow {
                        width: parent.width; spacing: 8
                        Repeater {
                            model: root.waits
                            delegate: Pill {
                                required property var modelData
                                text: modelData < 60 ? modelData + " min" : "1 hour"
                                selected: Number(root.cfg.waitMinutes) === modelData
                                onClicked: root.set("waitMinutes", modelData)
                            }
                        }
                    }

                    // ---- options ----
                    Column {
                        width: parent.width; spacing: 10
                        OptionRow { title: "Ask for my password when I come back"; hint: "Locks the computer when the screensaver ends, like Windows' \"On resume, display logon screen\"."; checked: root.cfg.password; onToggled: root.set("password", !root.cfg.password) }
                        OptionRow { title: "Show the clock"; hint: "Time and date, gently moving so nothing burns into the screen."; checked: root.cfg.clock; onToggled: root.set("clock", !root.cfg.clock) }
                    }

                    Text { text: "Speed"; color: "white"; font.pixelSize: 15; font.weight: Font.DemiBold }
                    Row {
                        spacing: 8
                        Repeater {
                            model: [["Calm", 0.55], ["Normal", 1.0], ["Lively", 1.6]]
                            delegate: Pill { required property var modelData; text: modelData[0]; selected: Math.abs(root.cfg.speed - modelData[1]) < 0.05; onClicked: root.set("speed", modelData[1]) }
                        }
                        Item { width: 20; height: 1 }
                        Text { text: "Shapes"; color: Qt.rgba(1, 1, 1, 0.7); font.pixelSize: 13; anchors.verticalCenter: parent.verticalCenter }
                        Repeater {
                            model: [1, 2, 3]
                            delegate: Pill { required property var modelData; text: String(modelData); selected: root.cfg.shapes === modelData; onClicked: root.set("shapes", modelData) }
                        }
                    }

                    Text {
                        width: parent.width; wrapMode: Text.WordWrap
                        color: Qt.rgba(1, 1, 1, 0.5); font.pixelSize: 12
                        text: "Press any key or move the mouse to wake it. Stay Awake (Omarchy menu › Toggle) pauses it. Turning it Off gives you back Omarchy's original screensaver. Esc closes this window."
                    }
                }
            }
        }
    }

    // ---- small controls ----
    component Pill: Rectangle {
        property string text: ""
        property bool selected: false
        signal clicked()
        implicitWidth: lbl.implicitWidth + 28; implicitHeight: 34
        width: implicitWidth; height: implicitHeight
        radius: 17
        color: selected ? "#9ece6a" : Qt.rgba(1, 1, 1, ma.containsMouse ? 0.16 : 0.09)
        Text { id: lbl; anchors.centerIn: parent; text: parent.text; color: parent.selected ? "#11131c" : "white"; font.pixelSize: 13; font.weight: Font.DemiBold }
        MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: parent.clicked() }
    }

    component Switch: Rectangle {
        property bool checked: false
        property string label: ""
        signal toggled()
        width: 52 + (lab.text ? lab.implicitWidth + 8 : 0); height: 30; color: "transparent"
        Rectangle {
            id: track
            width: 52; height: 30; radius: 15
            color: parent.checked ? "#9ece6a" : Qt.rgba(1, 1, 1, 0.18)
            Rectangle { width: 24; height: 24; radius: 12; y: 3; x: parent.parent.checked ? 25 : 3; color: "white"; Behavior on x { NumberAnimation { duration: 140 } } }
        }
        Text { id: lab; anchors.left: track.right; anchors.leftMargin: 8; anchors.verticalCenter: parent.verticalCenter; text: parent.label; color: "white"; font.pixelSize: 13 }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: parent.toggled() }
    }

    component OptionRow: Rectangle {
        property string title: ""
        property string hint: ""
        property bool checked: false
        signal toggled()
        width: parent ? parent.width : 400; height: 64; radius: 12
        color: Qt.rgba(1, 1, 1, 0.06)
        Column {
            anchors.left: parent.left; anchors.leftMargin: 16; anchors.right: sw.left; anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter; spacing: 3
            Text { text: title; color: "white"; font.pixelSize: 14; font.weight: Font.DemiBold; width: parent.width; elide: Text.ElideRight }
            Text { text: hint; color: Qt.rgba(1, 1, 1, 0.55); font.pixelSize: 12; width: parent.width; elide: Text.ElideRight }
        }
        Switch { id: sw; anchors.right: parent.right; anchors.rightMargin: 16; anchors.verticalCenter: parent.verticalCenter; checked: parent.checked; onToggled: parent.toggled() }
    }
}
