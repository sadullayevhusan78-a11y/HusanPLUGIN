const { entrypoints } = require("uxp");
const app = require("aftereffects");

const $ = (id) => document.getElementById(id);
const status = $("status");

function setStatus(message) {
  status.textContent = message;
}

function activeComp() {
  const item = app.project && app.project.activeItem;
  if (!item || item.typeName !== "Composition") {
    throw new Error("Open or select a composition first.");
  }
  return item;
}

function selectedLayers(comp) {
  const layers = comp.selectedLayers;
  if (!layers || layers.length === 0) {
    throw new Error("Select at least one layer.");
  }
  return layers;
}

function centerLayer(layer, comp) {
  const pos = layer.property("Transform").property("Position");
  if (pos) pos.setValue([comp.width / 2, comp.height / 2]);
}

function createReels() {
  app.beginUndoGroup("Husan - Create Reels Comp");
  try {
    const comp = app.project.items.addComp(
      "REELS_1080x1920",
      1080,
      1920,
      1,
      30,
      30
    );
    comp.openInViewer();
    setStatus("Created 1080 × 1920 Reels comp.");
  } finally {
    app.endUndoGroup();
  }
}

function centerSelected() {
  const comp = activeComp();
  const layers = selectedLayers(comp);
  app.beginUndoGroup("Husan - Center Selected");
  try {
    layers.forEach(layer => centerLayer(layer, comp));
    setStatus(`Centered ${layers.length} layer(s).`);
  } finally {
    app.endUndoGroup();
  }
}

function addText() {
  const comp = activeComp();
  app.beginUndoGroup("Husan - Add Subtitle");
  try {
    const layer = comp.layers.addText("YOUR TEXT");
    layer.name = "HUSAN_SUBTITLE";
    centerLayer(layer, comp);
    setStatus("Clean subtitle layer added.");
  } finally {
    app.endUndoGroup();
  }
}

function centerText() {
  const comp = activeComp();
  const layers = selectedLayers(comp);
  const textLayers = layers.filter(layer => layer.typeName === "TextLayer");
  if (!textLayers.length) throw new Error("Select a text layer.");
  app.beginUndoGroup("Husan - Center Text");
  try {
    textLayers.forEach(layer => centerLayer(layer, comp));
    setStatus(`Centered ${textLayers.length} text layer(s).`);
  } finally {
    app.endUndoGroup();
  }
}

function styleText() {
  const comp = activeComp();
  const layers = selectedLayers(comp);
  const textLayers = layers.filter(layer => layer.typeName === "TextLayer");
  if (!textLayers.length) throw new Error("Select a text layer.");
  app.beginUndoGroup("Husan - Minimal Text Style");
  try {
    textLayers.forEach(layer => {
      const prop = layer.property("Source Text");
      const doc = prop.value;
      doc.fontSize = Math.round(Math.min(comp.width, comp.height) * 0.055);
      doc.fillColor = [1, 1, 1];
      doc.applyFill = true;
      doc.applyStroke = false;
      doc.justification = 2;
      prop.setValue(doc);
      centerLayer(layer, comp);
    });
    setStatus("Minimal text style applied.");
  } finally {
    app.endUndoGroup();
  }
}

function fitSelected() {
  const comp = activeComp();
  const layers = selectedLayers(comp);
  app.beginUndoGroup("Husan - Fit Selected");
  try {
    layers.forEach(layer => {
      if (!layer.width || !layer.height) return;
      const scale = Math.min(
        (comp.width * 0.92 / layer.width) * 100,
        (comp.height * 0.92 / layer.height) * 100
      );
      const s = layer.property("Transform").property("Scale");
      if (s) s.setValue([scale, scale]);
      centerLayer(layer, comp);
    });
    setStatus("Selected layers fitted to frame.");
  } finally {
    app.endUndoGroup();
  }
}

function stagger() {
  const comp = activeComp();
  const layers = selectedLayers(comp).slice().sort((a,b) => a.index - b.index);
  const offset = 0.08;
  app.beginUndoGroup("Husan - Stagger Layers");
  try {
    layers.forEach((layer, i) => { layer.startTime += i * offset; });
    setStatus(`Staggered ${layers.length} layers by 0.08s.`);
  } finally {
    app.endUndoGroup();
  }
}

function quickFade() {
  const comp = activeComp();
  const layers = selectedLayers(comp);
  app.beginUndoGroup("Husan - Quick Fade");
  try {
    layers.forEach(layer => {
      const opacity = layer.property("Transform").property("Opacity");
      if (!opacity) return;
      const start = layer.inPoint;
      const end = Math.min(start + 0.18, layer.outPoint);
      opacity.setValueAtTime(start, 0);
      opacity.setValueAtTime(end, 100);
    });
    setStatus("Quick fade applied.");
  } finally {
    app.endUndoGroup();
  }
}

function safe(fn) {
  return () => {
    try { fn(); }
    catch (err) {
      setStatus(err && err.message ? err.message : String(err));
    }
  };
}

$("createReels").addEventListener("click", safe(createReels));
$("centerSelected").addEventListener("click", safe(centerSelected));
$("fitSelected").addEventListener("click", safe(fitSelected));
$("addText").addEventListener("click", safe(addText));
$("centerText").addEventListener("click", safe(centerText));
$("styleText").addEventListener("click", safe(styleText));
$("stagger").addEventListener("click", safe(stagger));
$("fade").addEventListener("click", safe(quickFade));

entrypoints.setup({
  panels: {
    reelsMasterPanel: {
      create() { setStatus("Ready."); },
      show() { setStatus("Ready."); }
    }
  }
});