.pragma library
// Colour palettes for the Omarchy Store Screensaver.
// bg = two background colours (top, bottom); c = ribbon colours the shapes drift through.

var LIST = [
    { id: "aurora",  name: "Aurora",   bg: ["#07030f", "#140a2e"], c: ["#b44cff", "#7a5cff", "#22d3c5", "#5ef2e0"] },
    { id: "store",   name: "Omarchy Store", bg: ["#0b0818", "#1a1b26"], c: ["#9ece6a", "#7c3aed", "#bb9af7", "#5ef2a0"] },
    { id: "sunset",  name: "Sunset",   bg: ["#120408", "#2a0a18"], c: ["#ff5f6d", "#ff9a3c", "#ffd36b", "#ff6fb1"] },
    { id: "ocean",   name: "Ocean",    bg: ["#020b18", "#06203a"], c: ["#1e6bff", "#22b8ff", "#3ef0ff", "#7ad7ff"] },
    { id: "forest",  name: "Forest",   bg: ["#03100a", "#082318"], c: ["#2bd67b", "#9be15d", "#1fb6a0", "#d4ff6b"] },
    { id: "ember",   name: "Ember",    bg: ["#100503", "#260c06"], c: ["#ff3b1f", "#ff7a00", "#ffc04d", "#ff2e63"] },
    { id: "candy",   name: "Candy",    bg: ["#12051a", "#260a33"], c: ["#ff7ad9", "#b38cff", "#7af0ff", "#fff07a"] },
    { id: "classic", name: "Classic Mystify", bg: ["#000000", "#000000"], c: ["#ff2020", "#20ff20", "#2060ff", "#ffff20", "#ff20ff", "#20ffff"] },
    { id: "mono",    name: "Silver",   bg: ["#050507", "#111318"], c: ["#ffffff", "#c7cbd6", "#8b93a7", "#e9ecf2"] },
    { id: "theme",   name: "My Omarchy theme", bg: ["#101315", "#101315"], c: ["#cacccc", "#cacccc", "#cacccc", "#cacccc"] }
];

function get(id) {
    for (var i = 0; i < LIST.length; i++)
        if (LIST[i].id === id) return LIST[i];
    return LIST[0];
}

// Turns the current Omarchy theme's colors.toml into a palette.
function fromColorsToml(text) {
    var v = {};
    String(text || "").split("\n").forEach(function (line) {
        var m = line.match(/^\s*([a-z_0-9]+)\s*=\s*"(#[0-9a-fA-F]{6})/);
        if (m) v[m[1]] = m[2];
    });
    var bg = v.background || "#101315";
    var c = [v.accent, v.color4 || v.blue, v.color5 || v.magenta, v.color6 || v.cyan, v.color2 || v.green]
        .filter(function (x) { return !!x; });
    if (c.length < 2) c = ["#cacccc", "#8b93a7"];
    return { id: "theme", name: "My Omarchy theme", bg: [bg, v.darker_background || bg], c: c };
}
