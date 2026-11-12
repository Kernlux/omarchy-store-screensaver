import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "Palettes.js" as Palettes

// Omarchy Store Screensaver: background service.
// - Waits the time you chose (Settings), then shows the screensaver on every monitor.
// - Any key / click / mouse movement wakes it. If "Ask for my password" is on, waking locks
//   the computer so you sign back in with your password (like Windows' "On resume, display logon screen").
// - Takes over from Omarchy's text screensaver while it's turned on, and hands it back when turned off.
// - Respects Stay Awake and anything that blocks sleep (videos, presentations).
Item {
    id: root

    // Injected by omarchy-shell.
    property var shell: null
    property var manifest: null
    property var pluginRegistry: null

    readonly property string pluginId: "omarchy-store-screensaver"
    readonly property string home: Quickshell.env("HOME")
    readonly property string cfgDir: home + "/.config/omarchy-store-screensaver"
    readonly property string cfgPath: cfgDir + "/settings.json"
    readonly property string stateDir: home + "/.local/state/omarchy-store-screensaver"
    readonly property string pluginDir: Qt.resolvedUrl(".").toString().replace(/^file:\/\//, "").replace(/\/$/, "")

    readonly property var defaults: ({ enabled: true, palette: "aurora", waitMinutes: 3, password: false, clock: true, speed: 1.0, shapes: 2 })
    property var cfg: defaults
    property var themePalette: null
    readonly property var paletteObj: cfg.palette === "theme" && themePalette ? themePalette : Palettes.get(cfg.palette)

    property bool showing: false
    property bool locked: false
    // Started from SnapDock's dock button: waking up always locks, whatever the setting.
    property bool lockOnWake: false
    property bool stayAwake: false

    function merged(o) {
        var out = {};
        for (var k in defaults) out[k] = (o && o[k] !== undefined && o[k] !== null) ? o[k] : defaults[k];
        out.waitMinutes = Math.max(1, Math.min(120, Number(out.waitMinutes) || defaults.waitMinutes));
        out.speed = Math.max(0.3, Math.min(2.5, Number(out.speed) || 1));
        out.shapes = Math.max(1, Math.min(4, Math.round(Number(out.shapes) || 2)));
        return out;
    }

    // ---- settings file (written by the Settings window, watched here) ----
    FileView {
        id: cfgFile
        path: root.cfgPath
        watchChanges: true
        printErrors: false
        onLoaded: { try { root.cfg = root.merged(JSON.parse(text())); } catch (e) { root.cfg = root.merged({}); } root.syncStock(); }
        onLoadFailed: { root.cfg = root.merged({}); root.syncStock(); }
        onFileChanged: reload()
    }

    // ---- current Omarchy theme colours, for the "My Omarchy theme" palette ----
    FileView {
        path: root.home + "/.local/state/omarchy/current/theme/colors.toml"
        watchChanges: true
        printErrors: false
        onLoaded: root.themePalette = Palettes.fromColorsToml(text())
        onFileChanged: reload()
    }

    // ---- Stay Awake indicator ----
    FileView {
        path: root.home + "/.local/state/omarchy/indicators/stay-awake"
        watchChanges: true
        printErrors: false
        onLoaded: root.stayAwake = true
        onLoadFailed: root.stayAwake = false
        onFileChanged: reload()
    }

    // ---- idle detection ----
    IdleMonitor {
        id: idle
        enabled: root.cfg.enabled && !root.stayAwake
        timeout: root.cfg.waitMinutes * 60
        respectInhibitors: true
        onIsIdleChanged: if (isIdle) root.show("idle")
    }

    // ---- show / hide ----
    function show(reason) {
        if (showing || locked) return;
        console.log("omarchy-store-screensaver: show (" + reason + ")");
        showing = true;
    }

    function dismiss(reason) {
        if (!showing) return;
        console.log("omarchy-store-screensaver: wake (" + reason + ")");
        if ((cfg.password || lockOnWake) && reason !== "test-end") {
            lockOnWake = false;
            // Lock first, then fade out, so the desktop is never visible without the password.
            run(["omarchy-system-lock"]);
            hideLater.restart();
        } else {
            showing = false;
        }
    }
    // Cursor visibility follows `showing`, however it gets cleared (wake, lock screen
    // taking over, shell restart), so the pointer can never be left hidden.
    function setCursorHidden(hidden) {
        var v = hidden ? "true" : "false";
        // fixed argv only (no shell): v is the literal "true"/"false" chosen above
        run(["hyprctl", "eval", "hl.config({ cursor = { invisible = " + v + " } })"]);
    }
    onShowingChanged: setCursorHidden(showing)
    Timer { id: hideLater; interval: 700; onTriggered: root.showing = false }

    // Hand Omarchy's own text screensaver back and forth. We only ever remove the
    // "screensaver-off" switch if we were the ones who set it.
    function syncStock() {
        var t = home + "/.local/state/omarchy/toggles/screensaver-off", mark = stateDir + "/took-over";
        // fixed argv only (no shell strings): paths are passed as separate arguments, never parsed by a shell
        if (cfg.enabled) {
            run(["mkdir", "-p", home + "/.local/state/omarchy/toggles", stateDir]);
            if (!stockOff) { run(["touch", t]); run(["touch", mark]); }
        } else if (tookOver) {
            run(["rm", "-f", "--", t, mark]);
        }
    }

    // does the stock-screensaver switch exist, and did WE set it? (read, never shelled)
    property bool stockOff: false
    property bool tookOver: false
    FileView { path: root.home + "/.local/state/omarchy/toggles/screensaver-off"; watchChanges: true; printErrors: false
        onLoaded: root.stockOff = true; onLoadFailed: root.stockOff = false; onFileChanged: reload() }
    FileView { path: root.stateDir + "/took-over"; watchChanges: true; printErrors: false
        onLoaded: root.tookOver = true; onLoadFailed: root.tookOver = false; onFileChanged: reload() }

    // ---- lock state: never draw over the lock screen ----
    Process {
        id: lockProc
        command: ["omarchy-shell", "lock", "isLocked"]
        stdout: StdioCollector { onStreamFinished: { root.locked = String(text).trim() === "true"; if (root.locked && root.showing && !hideLater.running) root.showing = false; } }
    }
    Timer { interval: 3000; repeat: true; running: true; onTriggered: if (!lockProc.running) lockProc.running = true }

    // ---- helpers ----
    property var _procs: []
    function run(argv) {
        var p = runner.createObject(root, { command: argv });
        p.running = true;
    }
    Component {
        id: runner
        Process { onExited: destroy() }
    }

    // App-launcher entry ("Screensaver Settings") so it's easy to find from Super+Space or the dock.
    function writeLauncher() {
        var d = home + "/.local/share/applications/omarchy-store-screensaver.desktop";
        // a .desktop entry is line-based: a path holding a newline could add an Exec= line, so refuse one
        if (/[\n\r]/.test(pluginDir)) return;
        var body = ["[Desktop Entry]", "Type=Application", "Name=Screensaver Settings", "GenericName=Omarchy Store Screensaver",
                    "Comment=Colours, wait time and password for the Omarchy Store screensaver",
                    "Exec=omarchy-shell shell summon omarchy-store-screensaver", "Icon=" + pluginDir + "/assets/icon.png",
                    "Categories=Settings;DesktopSettings;", "Keywords=screensaver;screen saver;mystify;idle;", ""].join("\n");
        run(["mkdir", "-p", home + "/.local/share/applications"]);
        launcherFile.setText(body);   // written by FileView: no shell, no printf format string
    }

    FileView { id: launcherFile; path: root.home + "/.local/share/applications/omarchy-store-screensaver.desktop"; printErrors: false }
    Component.onCompleted: { setCursorHidden(false); writeLauncher(); }

    Variants {
        id: surfaces
        model: Quickshell.screens
        SaverSurface {
            owner: root
            active: root.showing
        }
    }

    // omarchy-shell omarchy-store-screensaver test|hide|status
    IpcHandler {
        target: "omarchy-store-screensaver"
        function test(): void { root.show("test") }
        // Show it now; touching anything locks the computer (SnapDock's screensaver button).
        function lockNow(): void { root.lockOnWake = true; root.show("button") }
        function hide(): void { root.dismiss("test-end") }
        function status(): string { return JSON.stringify({ showing: root.showing, locked: root.locked, stayAwake: root.stayAwake, fps: surfaces.instances.map(function (s) { return s.fps; }), cfg: root.cfg }) }
    }
}
