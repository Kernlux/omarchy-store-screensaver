import QtQuick

// The screensaver picture: Mystify-style shapes whose corners bounce around the screen,
// drawn as glowing ribbons with fading echoes, over a slow aurora background.
// Everything is drawn on the graphics card (shaders/mystify.frag); the CPU only advances the clock.
// Used full screen by SaverSurface.qml and as the live preview in the settings window.
Item {
    id: view

    property var colours: ({ bg: ["#07030f", "#140a2e"], c: ["#b44cff", "#7a5cff", "#22d3c5", "#5ef2e0"] })
    property real speed: 1.0          // 0.55 calm, 1 normal, 1.6 lively
    property int shapes: 2
    property bool running: true
    property bool showClock: true
    property bool showBrand: true
    property real scaleUi: Math.max(0.35, Math.min(width / 1920, height / 1080))
    property string logo: Qt.resolvedUrl("assets/mark.png")
    property string wordmark: Qt.resolvedUrl("assets/wordmark.png")
    readonly property string timeFmt: Qt.locale().timeFormat(Locale.ShortFormat).toLowerCase().indexOf("ap") >= 0 ? "h:mm" : "HH:mm"

    // Draw at no more than ~800 pixels tall and scale up smoothly: the glow hides the difference
    // and it keeps big monitors and older laptops at full frame rate.
    readonly property real renderScale: Math.max(1, height / 800)
    property real t: 0
    property var corners: []

    function rnd(a, b) { return a + Math.random() * (b - a); }
    function reset() {
        var out = [];
        for (var i = 0; i < 12; i++)
            out.push(Qt.vector4d(Math.random() * 2, Math.random() * 2,
                                 rnd(0.05, 0.11) * (Math.random() < 0.5 ? -1 : 1), rnd(0.05, 0.11) * (Math.random() < 0.5 ? -1 : 1)));
        corners = out;
        t = rnd(5, 50);
    }
    function col(i) { var c = colours.c || ["#ffffff"]; return c[i % c.length]; }
    function cv(i) { return corners.length ? corners[i] : Qt.vector4d(0, 0, 0, 0); }
    Component.onCompleted: reset()

    property int frames: 0
    property real fps: 0
    FrameAnimation {
        running: view.running && view.visible && view.width > 0
        onTriggered: { view.t += Math.min(frameTime, 0.1) * view.speed; view.frames++; }
        onRunningChanged: if (running) { view.frames = 0; fpsTimer.restart(); }
    }
    // Measures the frame rate once, 5 seconds after starting (shows up in `status`).
    Timer { id: fpsTimer; interval: 5000; onTriggered: view.fps = view.frames / 5 }

    ShaderEffect {
        id: fx
        width: Math.ceil(view.width / view.renderScale)
        height: Math.ceil(view.height / view.renderScale)
        transformOrigin: Item.TopLeft
        scale: view.renderScale
        layer.enabled: view.renderScale > 1
        layer.smooth: true
        fragmentShader: "shaders/mystify.frag.qsb"

        property real t: view.t
        property real aspect: view.width / Math.max(1, view.height)
        property real shapes: view.shapes
        property real lw: Math.max(0.0011, 1.25 / Math.max(1, height))
        property real ncol: Math.min(6, Math.max(2, (view.colours.c || []).length))
        property color c0: view.col(0)
        property color c1: view.col(1)
        property color c2: view.col(2)
        property color c3: view.col(3)
        property color c4: view.col(4)
        property color c5: view.col(5)
        property color bg0: view.colours.bg ? view.colours.bg[0] : "#000000"
        property color bg1: view.colours.bg ? view.colours.bg[1] : "#000000"
        property vector4d p0: view.cv(0)
        property vector4d p1: view.cv(1)
        property vector4d p2: view.cv(2)
        property vector4d p3: view.cv(3)
        property vector4d p4: view.cv(4)
        property vector4d p5: view.cv(5)
        property vector4d p6: view.cv(6)
        property vector4d p7: view.cv(7)
        property vector4d p8: view.cv(8)
        property vector4d p9: view.cv(9)
        property vector4d p10: view.cv(10)
        property vector4d p11: view.cv(11)
    }

    // Clock: drifts a little every minute so nothing burns into the screen.
    Item {
        id: clockBox
        visible: view.showClock
        width: col.width; height: col.height
        x: (view.width - width) / 2
        y: view.height * 0.16
        transform: Translate { id: drift; Behavior on x { NumberAnimation { duration: 4000; easing.type: Easing.InOutSine } } Behavior on y { NumberAnimation { duration: 4000; easing.type: Easing.InOutSine } } }
        Column {
            id: col
            spacing: 6 * view.scaleUi
            Text {
                id: timeText
                anchors.horizontalCenter: parent.horizontalCenter
                color: "white"; opacity: 0.92
                font.pixelSize: 132 * view.scaleUi; font.weight: Font.Bold; font.letterSpacing: -4 * view.scaleUi
                text: Qt.formatTime(new Date(), view.timeFmt)
            }
            Text {
                id: dateText
                anchors.horizontalCenter: parent.horizontalCenter
                color: "white"; opacity: 0.72
                font.pixelSize: 28 * view.scaleUi; font.weight: Font.Medium
                text: Qt.formatDate(new Date(), "dddd, MMMM d")
            }
        }
        Timer {
            interval: 1000; repeat: true; running: view.running && view.showClock
            property int n: 0
            onTriggered: {
                var d = new Date();
                timeText.text = Qt.formatTime(d, view.timeFmt);
                dateText.text = Qt.formatDate(d, "dddd, MMMM d");
                if (++n % 60 === 0) { drift.x = (Math.random() - 0.5) * view.width * 0.3; drift.y = (Math.random() - 0.2) * view.height * 0.25; }
            }
        }
    }

    Row {
        visible: view.showBrand
        anchors.right: parent.right; anchors.bottom: parent.bottom
        anchors.margins: 28 * view.scaleUi
        spacing: 10 * view.scaleUi
        opacity: 0.6
        // official brand assets only (mark + wordmark PNG), never typeset
        Image { source: view.logo; width: 28 * view.scaleUi; height: width; sourceSize.width: 96; sourceSize.height: 96; smooth: true; mipmap: true; anchors.verticalCenter: parent.verticalCenter }
        Image { source: view.wordmark; height: 16 * view.scaleUi; fillMode: Image.PreserveAspectFit; smooth: true; mipmap: true; anchors.verticalCenter: parent.verticalCenter }
    }
}
