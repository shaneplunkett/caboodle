// minirack ✿ — a cute little 10" rack planner.
// State is a plain object persisted to rack.json via the server; everything
// else (selection, zoom, wiring mode) is UI-only and never saved to the file.

// ---------- constants ----------

const U_MM = 44.45;
const BAY_MM = 222; // a 10" rack's opening
const BAY_RATIO = BAY_MM / U_MM;
const RAIL_RATIO = 16 / U_MM;
const SVGNS = "http://www.w3.org/2000/svg";
const SVG_TAGS = new Set(["svg", "path", "g", "circle", "rect", "text", "title"]);

const COLORS = {
  device: ["#f6b8d0", "#cdb8f2", "#b5e6cf", "#b6d8f5", "#f7e3a1", "#f9c8a8", "#eef0f4", "#4a4458"],
  cable: ["#ff8fb8", "#a98bf0", "#4fc794", "#5fa8ec", "#f2c94c", "#f5925c", "#f4f1ec", "#7a6d8e"],
  filament: ["#f6b8d0", "#cdb8f2", "#b5e6cf", "#b6d8f5", "#f7e3a1", "#f4f1ec", "#4a4458"],
  sticky: ["#fff1a8", "#ffd6e7", "#d9f5e5", "#dcebff", "#eadcff"],
};

const PORT_KINDS = {
  rj45: { label: "Port", short: "RJ45" },
  sfp: { label: "SFP", short: "SFP" },
  usba: { label: "USB-A", short: "USB-A" },
  usb: { label: "USB-C", short: "USB-C" },
  hdmi: { label: "HDMI", short: "HDMI" },
  power: { label: "Power", short: "PWR" },
};

// A port's face is "front", "rear", or "both" (a keystone passes straight
// through, so it can take one cable on each side).

// Template ports. Extras: label; pos ("left"/"right") pins a port to that
// edge of the faceplate; unit groups ports per device in a multi-bay mount.
const port = (face, kind, n = 1, extra = {}) => ({ face, kind, n, ...extra });

const perUnit = (count, name, ports) =>
  Array.from({ length: count }, (_, i) =>
    ports.map(([face, kind, n, label]) => port(face, kind, n, { unit: i + 1, label: `${name} ${i + 1} ${label}` })),
  ).flat();

const jetkvmPorts = (n) =>
  perUnit(n, "KVM", [
    ["rear", "hdmi", 1, "HDMI"],
    ["rear", "usb", 1, "USB-C"],
    ["rear", "rj45", 1, "LAN"],
  ]);
const oldPiPorts = (n) =>
  perUnit(n, "Pi", [
    ["front", "rj45", 1, "LAN"],
    ["front", "usba", 2, "USB-A"],
    ["rear", "power", 1, "micro-USB power"],
  ]);

const TEMPLATE_GROUPS = [
  {
    name: "Networking",
    emoji: "🌐",
    items: [
      {
        key: "patch-12",
        name: "Patch panel · 12",
        heightU: 1,
        width: "full",
        color: "#cdb8f2",
        style: "patch",
        align: "center",
        ports: [port("both", "rj45", 12)],
      },
      {
        key: "patch-6",
        name: "Patch panel · 6",
        heightU: 1,
        width: "half",
        color: "#cdb8f2",
        style: "patch",
        align: "center",
        ports: [port("both", "rj45", 6)],
      },
      {
        key: "ucg-max",
        name: "Cloud Gateway Max",
        heightU: 1,
        width: "full",
        color: "#eef0f4",
        style: "unifi",
        align: "center",
        screens: 1,
        ports: [
          port("both", "rj45", 1, { label: "Left keystone", pos: "left" }),
          port("both", "rj45", 1, { label: "Right keystone", pos: "right" }),
          port("rear", "rj45", 5),
          port("rear", "power"),
        ],
      },
      {
        key: "usw-lite-8",
        name: "USW Lite 8 PoE",
        heightU: 1,
        width: "full",
        color: "#eef0f4",
        style: "unifi",
        align: "center",
        ports: [port("front", "rj45", 8), port("rear", "power")],
      },
      {
        key: "flex-mini",
        name: "USW Flex Mini",
        heightU: 1,
        width: "full",
        color: "#eef0f4",
        style: "unifi",
        align: "center",
        ports: [port("front", "rj45", 5), port("rear", "usb", 1, { label: "USB-C power" })],
      },
      {
        key: "switch",
        name: "Switch",
        heightU: 1,
        width: "full",
        color: "#b6d8f5",
        style: "plain",
        ports: [port("front", "rj45", 8), port("rear", "power")],
      },
    ],
  },
  {
    name: "Compute",
    emoji: "🍓",
    items: [
      {
        key: "pi",
        name: "Raspberry Pi",
        heightU: 1,
        width: "half",
        color: "#b5e6cf",
        style: "pi",
        align: "center",
        ports: [
          port("front", "rj45"),
          port("front", "usba", 2),
          port("rear", "power", 1, { label: "micro-USB power" }),
        ],
      },
      {
        key: "pi-x2",
        name: "Pi mount · 2 bays",
        heightU: 1,
        width: "full",
        color: "#b5e6cf",
        style: "pi",
        align: "center",
        ports: oldPiPorts(2),
      },
      {
        key: "pi-x4",
        name: "Pi mount · 4 bays",
        heightU: 1,
        width: "full",
        color: "#b5e6cf",
        style: "pi",
        align: "center",
        ports: perUnit(4, "Pi", [
          ["front", "rj45", 1, "LAN"],
          ["rear", "usb", 1, "power"],
        ]),
      },
      {
        key: "mini-pc",
        name: "Mini PC",
        heightU: 2,
        width: "full",
        color: "#b6d8f5",
        style: "plain",
        fullDepth: true,
        ports: [port("front", "usba", 2), port("rear", "rj45", 2), port("rear", "power")],
      },
      {
        key: "itx-4u",
        name: "Mini ITX case · 4U",
        heightU: 4,
        width: "full",
        color: "#4a4458",
        style: "circuit",
        fullDepth: true,
        ports: [
          port("rear", "rj45", 1, { label: "LAN" }),
          port("rear", "usba", 4),
          port("rear", "usb", 1),
          port("rear", "hdmi", 1, { label: "Board HDMI" }),
          port("rear", "hdmi", 1, { label: "GPU HDMI" }),
          port("rear", "power"),
        ],
      },
      {
        key: "jetkvm-1",
        name: "JetKVM",
        heightU: 1,
        width: "full",
        color: "#f6b8d0",
        style: "jetkvm",
        align: "center",
        screens: 1,
        ports: jetkvmPorts(1),
      },
      {
        key: "jetkvm-2",
        name: "JetKVM · 2 bays",
        heightU: 1,
        width: "full",
        color: "#f6b8d0",
        style: "jetkvm",
        align: "center",
        screens: 2,
        ports: jetkvmPorts(2),
      },
      {
        key: "mac-mini-kvm",
        name: "Mac mini + JetKVM",
        heightU: 2,
        width: "full",
        color: "#4a4458",
        style: "mac-kvm",
        fullDepth: true,
        align: "center",
        bays: ["kvm", "mac-mini"],
        ports: [
          port("rear", "hdmi", 1, { unit: 1, label: "KVM HDMI" }),
          port("rear", "usb", 1, { unit: 1, label: "KVM USB-C" }),
          port("rear", "rj45", 1, { unit: 1, label: "KVM LAN" }),
          port("front", "usb", 2, { unit: 2, label: "Mac USB-C" }),
          port("rear", "usb", 3, { unit: 2, label: "Mac Thunderbolt" }),
          port("rear", "hdmi", 1, { unit: 2, label: "Mac HDMI" }),
          port("rear", "rj45", 1, { unit: 2, label: "Mac Ethernet" }),
          port("rear", "power", 1, { unit: 2, label: "Mac power" }),
        ],
      },
    ],
  },
  {
    name: "Smart home",
    emoji: "🏡",
    items: [
      {
        key: "hub",
        name: "Smart home hub",
        heightU: 1,
        width: "half",
        color: "#f7e3a1",
        style: "plain",
        ports: [port("rear", "rj45"), port("rear", "power")],
      },
      {
        key: "zigbee",
        name: "Zigbee / Thread stick",
        heightU: 1,
        width: "half",
        color: "#f9c8a8",
        style: "plain",
        ports: [port("front", "usba")],
      },
      {
        key: "bridge",
        name: "Bridge",
        heightU: 1,
        width: "half",
        color: "#f7e3a1",
        style: "plain",
        ports: [port("rear", "rj45"), port("rear", "power")],
      },
    ],
  },
  {
    name: "Power",
    emoji: "⚡",
    items: [
      {
        key: "power-strip",
        name: "Power strip",
        heightU: 1,
        width: "full",
        color: "#4a4458",
        style: "plain",
        ports: [port("rear", "power", 6)],
      },
      {
        key: "usb-hub",
        name: "USB-C power hub",
        heightU: 1,
        width: "half",
        color: "#f9c8a8",
        style: "plain",
        ports: [port("rear", "usb", 4)],
      },
    ],
  },
  {
    name: "Tidy bits",
    emoji: "🧺",
    items: [
      { key: "brush", name: "Brush panel", heightU: 1, width: "full", color: "#4a4458", style: "brush", ports: [] },
      { key: "rings", name: "Cable ring bar", heightU: 1, width: "full", color: "#f6b8d0", style: "rings", ports: [] },
      {
        key: "shelf",
        name: "Shelf",
        heightU: 2,
        width: "full",
        color: "#eef0f4",
        style: "shelf",
        fullDepth: true,
        ports: [],
      },
      { key: "vent", name: "Vent panel", heightU: 1, width: "full", color: "#f6b8d0", style: "vent", ports: [] },
      { key: "blank", name: "Blank", heightU: 1, width: "full", color: "#f6b8d0", style: "blank", ports: [] },
    ],
  },
  {
    name: "Make your own",
    emoji: "✨",
    items: [
      { key: "custom", name: "Custom thing", heightU: 1, width: "full", color: "#cdb8f2", style: "plain", ports: [] },
    ],
  },
];

const TEMPLATES = Object.fromEntries(TEMPLATE_GROUPS.flatMap((g) => g.items).map((t) => [t.key, t]));

// ---------- state ----------

let state = null;
const ui = {
  layoutId: localStorage.getItem("minirack.layout"),
  selection: null, // { type: "item" | "cable" | "sticky", id }
  wiring: null, // { item, port, face } while plugging in a cable
  view: localStorage.getItem("minirack.view") === "rear" ? "rear" : "front",
  showLayout: false, // the floating layout-settings card, when nothing is selected
  palette: (localStorage.getItem("minirack.palette") ?? (window.innerWidth >= 1100 ? "open" : "closed")) === "open",
  cableColor: localStorage.getItem("minirack.cableColor") ?? COLORS.cable[0],
  cables: "on", // "on", "quiet" (runs through the rack fade back) or "off"
  zoom: Number(localStorage.getItem("minirack.zoom")) || 64,
};
const history = { past: [], future: [], lastKey: null, lastAt: 0 };
const sync = { revision: "0", timer: null, status: "saved", dirty: false };

const $ = (id) => document.getElementById(id);
const els = {
  tabs: $("tabs"),
  toolbar: $("toolbar"),
  palette: $("palette"),
  stage: $("stage"),
  inspector: $("inspector"),
  banner: $("banner"),
  toast: $("toast"),
};

const uid = (prefix) => `${prefix}-${Math.random().toString(36).slice(2, 8)}`;
const clamp = (n, lo, hi) => Math.max(lo, Math.min(hi, n));
const layout = () => state.layouts.find((l) => l.id === ui.layoutId) ?? state.layouts[0];
const templateOf = (item) => TEMPLATES[item.template] ?? { style: "plain" };

function h(tag, props, ...kids) {
  const svg = SVG_TAGS.has(tag);
  const el = svg ? document.createElementNS(SVGNS, tag) : document.createElement(tag);
  for (const [k, v] of Object.entries(props ?? {})) {
    if (v == null || v === false) continue;
    if (k === "class") el.setAttribute("class", v);
    else if (k === "style") {
      for (const [sk, sv] of Object.entries(v)) {
        if (sv == null) continue;
        if (sk.startsWith("--")) el.style.setProperty(sk, sv);
        else el.style[sk] = sv;
      }
    } else if (k.startsWith("on")) el.addEventListener(k.slice(2), v);
    else if (!svg && k in el) el[k] = v;
    else el.setAttribute(k, v === true ? "" : v);
  }
  for (const kid of kids.flat(Infinity)) {
    if (kid == null || kid === false) continue;
    el.append(kid instanceof Node ? kid : String(kid));
  }
  return el;
}

function isDark(hex) {
  const n = parseInt(hex.slice(1), 16);
  return 0.299 * (n >> 16) + 0.587 * ((n >> 8) & 255) + 0.114 * (n & 255) < 140;
}

// ---------- model helpers ----------

function newLayout(name) {
  return {
    id: uid("layout"),
    name,
    rackUnits: 8,
    filament: COLORS.filament[0],
    notes: "",
    items: [],
    cables: [],
    stickies: [],
  };
}

function makeItem(templateKey) {
  const t = TEMPLATES[templateKey];
  const ports = t.ports.flatMap(({ face, kind, n, label = "", pos, unit }) =>
    Array.from({ length: n }, (_, i) => ({
      id: uid("p"),
      kind,
      face,
      label: label && n > 1 ? `${label} ${i + 1}` : label,
      ...(pos && { pos }),
      ...(unit && { unit }),
    })),
  );
  return {
    id: uid("item"),
    template: t.key,
    name: t.name,
    color: t.color,
    heightU: t.heightU,
    width: t.width,
    side: t.width === "half" ? "left" : null,
    u: 1,
    parked: false,
    ports,
    notes: "",
  };
}

function seedState() {
  const L = newLayout("My minirack");
  for (const key of ["ucg-max", "usw-lite-8", "patch-12"]) {
    const item = makeItem(key);
    item.parked = true;
    L.items.push(item);
  }
  L.stickies.push({
    id: uid("note"),
    x: 520,
    y: 430,
    color: COLORS.sticky[0],
    text: "drag your gear into the rack ✿\n\nclick a port, then another port, to plug in a cable",
  });
  return { version: 1, layouts: [L] };
}

// Gear hangs off the front rails or the back ones. Things on opposite rails can
// share a U, unless one of them fills the rack front to back.
const mountOf = (item) => item.mount ?? "front";
const fullDepth = (item) => item.fullDepth ?? !!templateOf(item).fullDepth;
const showBackRails = (L) => !!L.backRails || L.items.some((i) => !i.parked && mountOf(i) === "rear");

function setMount(item, mount) {
  if (mount === "rear") item.mount = "rear";
  else delete item.mount;
}

const overlaps = (a, b) =>
  a.u < b.u + b.heightU &&
  b.u < a.u + a.heightU &&
  (a.width === "full" || b.width === "full" || a.side === b.side) &&
  (mountOf(a) === mountOf(b) || fullDepth(a) || fullDepth(b));

function fits(L, spot, ignoreId) {
  if (spot.u < 1 || spot.u + spot.heightU - 1 > L.rackUnits) return false;
  return !L.items.some((o) => !o.parked && o.id !== ignoreId && overlaps(o, spot));
}

function firstFreeSpot(L, item) {
  const sides = item.width === "half" ? ["left", "right"] : [null];
  for (let u = 1; u <= L.rackUnits - item.heightU + 1; u++) {
    for (const side of sides) {
      const spot = { ...item, u, side };
      if (fits(L, spot, item.id)) return spot;
    }
  }
  return null;
}

const findItem = (L, id) => L.items.find((i) => i.id === id);
const sameEnd = (end, itemId, portId, face) =>
  end.item === itemId && end.port === portId && (!face || end.face === face);
const touchesPort = (c, itemId, portId, face) =>
  sameEnd(c.from, itemId, portId, face) || sameEnd(c.to, itemId, portId, face);
const cableAt = (L, itemId, portId, face) => L.cables.find((c) => touchesPort(c, itemId, portId, face));
const otherEnd = (c, itemId, portId, face) => (sameEnd(c.from, itemId, portId, face) ? c.to : c.from);
const onFace = (port, view) => port.face === view || port.face === "both";

// Older rack.json files predate rear views, so their ports have no face. Borrow
// it from the template (the nth RJ45 gets the template's nth RJ45 face), and
// fall back to the front, which is where every old cable was drawn.
function normalize(s) {
  for (const L of s.layouts) {
    for (const item of L.items) {
      const faces = {};
      for (const { face, kind, n } of TEMPLATES[item.template]?.ports ?? [])
        for (let i = 0; i < n; i++) {
          faces[kind] ??= [];
          faces[kind].push(face);
        }
      const seen = {};
      for (const p of item.ports) {
        seen[p.kind] = (seen[p.kind] ?? -1) + 1;
        p.face ??= faces[p.kind]?.[seen[p.kind]] ?? "front";
      }
    }
    for (const c of L.cables) {
      for (const end of [c.from, c.to]) {
        const port = findItem(L, end.item)?.ports.find((p) => p.id === end.port);
        end.face ??= port?.face === "rear" ? "rear" : "front";
      }
    }
  }
  return s;
}

function portName(item, port) {
  if (port.label) return port.label;
  const n = item.ports.filter((p) => p.kind === port.kind).findIndex((p) => p.id === port.id) + 1;
  return `${PORT_KINDS[port.kind].label} ${n}`;
}

// On the back rails, the front of a keystone faces into the rack and its rear faces out.
const faceName = (item, face) => (mountOf(item) === "rear" ? { front: "inside", rear: "outside" }[face] : face);

function endName(L, end) {
  const item = findItem(L, end.item);
  const port = item?.ports.find((p) => p.id === end.port);
  if (!item || !port) return "somewhere mysterious";
  return `${item.name} · ${portName(item, port)}${port.face === "both" ? ` (${faceName(item, end.face)})` : ""}`;
}

function usedUnits(L) {
  const used = new Set();
  for (const i of L.items)
    if (!i.parked && (mountOf(i) === "front" || fullDepth(i))) for (let u = i.u; u < i.u + i.heightU; u++) used.add(u);
  return used.size;
}

// ---------- mutations, undo, save ----------

function mutate(fn, { coalesce = null, stage = true, inspector = true } = {}) {
  const now = Date.now();
  const continuing = coalesce && coalesce === history.lastKey && now - history.lastAt < 1500;
  if (!continuing) {
    history.past.push(JSON.stringify(state));
    if (history.past.length > 200) history.past.shift();
  }
  history.lastKey = coalesce;
  history.lastAt = now;
  history.future = [];
  fn(layout(), state);
  render({ stage, inspector });
  scheduleSave();
}

function travel(from, to) {
  if (!from.length) return;
  to.push(JSON.stringify(state));
  state = JSON.parse(from.pop());
  history.lastKey = null;
  if (!state.layouts.some((l) => l.id === ui.layoutId)) ui.layoutId = state.layouts[0].id;
  ui.selection = null;
  ui.wiring = null;
  render();
  scheduleSave();
}
const undo = () => travel(history.past, history.future);
const redo = () => travel(history.future, history.past);

function scheduleSave() {
  sync.dirty = true;
  setStatus("unsaved");
  clearTimeout(sync.timer);
  sync.timer = setTimeout(save, 450);
}

async function save({ force = false } = {}) {
  clearTimeout(sync.timer);
  setStatus("saving");
  const headers = { "content-type": "application/json" };
  if (!force) headers["x-base-revision"] = sync.revision;
  try {
    const res = await fetch("/api/state", { method: "PUT", headers, body: JSON.stringify(state) });
    if (res.status === 409) return showConflict();
    if (!res.ok) throw new Error(await res.text());
    sync.revision = (await res.json()).revision;
    sync.dirty = false;
    setStatus("saved");
  } catch (err) {
    console.error(err);
    setStatus("offline");
  }
}

async function load() {
  const res = await fetch("/api/state", { cache: "no-store" });
  sync.revision = res.headers.get("x-revision") ?? "0";
  state = normalize((await res.json()) ?? seedState());
  if (!state.layouts.some((l) => l.id === ui.layoutId)) ui.layoutId = state.layouts[0].id;
  ui.selection = null;
  ui.wiring = null;
  sync.dirty = false;
  setStatus("saved");
}

function showConflict() {
  setStatus("conflict");
  els.banner.hidden = false;
  els.banner.replaceChildren(
    h("span", null, "🫣 rack.json changed on disk since this tab loaded it (a git pull, maybe, or another tab)."),
    h(
      "button",
      {
        class: "btn",
        onclick: async () => {
          els.banner.hidden = true;
          await load();
          history.past = [];
          history.future = [];
          render();
        },
      },
      "Load the file's version",
    ),
    h(
      "button",
      {
        class: "btn ghost",
        onclick: () => {
          els.banner.hidden = true;
          save({ force: true });
        },
      },
      "Keep mine & overwrite",
    ),
  );
}

function setStatus(status) {
  sync.status = status;
  const pill = document.querySelector(".status");
  if (pill) {
    pill.dataset.status = status;
    pill.textContent = {
      saved: "saved ✓",
      saving: "saving…",
      unsaved: "unsaved",
      offline: "can't save!",
      conflict: "conflict",
    }[status];
  }
}

let toastTimer;
function toast(msg) {
  els.toast.textContent = msg;
  els.toast.classList.add("show");
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => els.toast.classList.remove("show"), 2600);
}

function select(type, id) {
  ui.selection = type ? { type, id } : null;
  ui.showLayout = false;
  ui.wiring = null;
  render();
}

function toggleLayoutCard() {
  ui.selection = null;
  ui.wiring = null;
  ui.showLayout = !ui.showLayout;
  render();
}

function togglePalette(open = !ui.palette) {
  ui.palette = open;
  localStorage.setItem("minirack.palette", open ? "open" : "closed");
  render({ inspector: false });
}

// Right-click selects too, so the card is always one click away.
const contextSelect = (type, id) => (e) => {
  e.preventDefault();
  e.stopPropagation();
  select(type, id);
};

const isSelected = (type, id) => ui.selection?.type === type && ui.selection.id === id;

// ---------- rendering ----------

function render({ stage = true, inspector = true } = {}) {
  localStorage.setItem("minirack.layout", ui.layoutId);
  document.body.classList.toggle("wiring", !!ui.wiring);
  document.body.classList.toggle("palette-open", ui.palette);
  renderTabs();
  updateToolbar();
  if (stage) renderStage();
  if (inspector) renderInspector();
  placeInspector();
}

function renderTabs() {
  els.tabs.replaceChildren(
    ...state.layouts.map((L) =>
      h(
        "button",
        {
          class: `tab ${L.id === layout().id ? "active" : ""}`,
          onclick: () => {
            ui.layoutId = L.id;
            select(null);
          },
        },
        L.name || "untitled",
      ),
    ),
    h("button", { class: "tab add", title: "New layout", onclick: addLayout }, "+"),
  );
}

function addLayout() {
  mutate((_, s) => {
    const L = newLayout(`Layout ${s.layouts.length + 1}`);
    s.layouts.push(L);
    ui.layoutId = L.id;
    ui.selection = null;
  });
}

const toolbar = {};

function buildToolbar() {
  toolbar.swatches = COLORS.cable.map((c) =>
    h("button", {
      class: "swatch sm",
      style: { "--c": c },
      onclick: () => {
        ui.cableColor = c;
        localStorage.setItem("minirack.cableColor", c);
        updateToolbar();
      },
    }),
  );
  // On narrower windows the toolbar drops to icons; .lbl text is what gets hidden.
  const lbl = (text) => h("span", { class: "lbl" }, text);
  toolbar.cablesLabel = lbl("");
  toolbar.cables = h(
    "button",
    {
      class: "btn ghost",
      title: "Show all cables, fade the ones through the rack, or hide them",
      onclick: () => {
        ui.cables = { on: "quiet", quiet: "off", off: "on" }[ui.cables];
        render({ inspector: false });
      },
    },
    "〰",
    toolbar.cablesLabel,
  );
  toolbar.views = ["front", "rear"].map((v) => h("button", { onclick: () => setView(v) }, v));
  toolbar.gear = h(
    "button",
    { class: "btn ghost", title: "Gear drawer", onclick: () => togglePalette() },
    "🧺",
    lbl(" gear"),
  );
  toolbar.layout = h(
    "button",
    { class: "btn ghost", title: "Layout settings (or right-click the empty canvas)", onclick: toggleLayoutCard },
    "⚙",
    lbl(" layout"),
  );
  toolbar.undo = h("button", { class: "btn ghost icon", title: "Undo (Ctrl+Z)", onclick: undo }, "↶");
  toolbar.redo = h("button", { class: "btn ghost icon", title: "Redo (Ctrl+Shift+Z)", onclick: redo }, "↷");
  els.toolbar.replaceChildren(
    toolbar.gear,
    h("div", { class: "seg view-toggle", title: "Flip between the front and back of the rack (V)" }, toolbar.views),
    h(
      "div",
      { class: "cable-picker", title: "Colour for new cables" },
      h("span", { class: "label" }, "cable"),
      toolbar.swatches,
    ),
    toolbar.cables,
    h("button", { class: "btn ghost", title: "Add a sticky note", onclick: addSticky }, "✎", lbl(" note")),
    h(
      "label",
      { class: "zoom", title: "Zoom" },
      "🔍",
      h("input", {
        type: "range",
        min: 40,
        max: 110,
        value: ui.zoom,
        oninput: (e) => {
          ui.zoom = Number(e.target.value);
          localStorage.setItem("minirack.zoom", ui.zoom);
          render({ inspector: false });
        },
      }),
    ),
    toolbar.layout,
    toolbar.undo,
    toolbar.redo,
    h("span", { class: "status" }),
  );
}

function updateToolbar() {
  for (const [i, el] of toolbar.swatches.entries()) el.classList.toggle("on", COLORS.cable[i] === ui.cableColor);
  for (const el of toolbar.views) el.classList.toggle("on", el.textContent === ui.view);
  toolbar.gear.classList.toggle("on", ui.palette);
  toolbar.layout.classList.toggle("on", ui.showLayout);
  toolbar.cablesLabel.textContent = { on: " cables on", quiet: " back quiet", off: " cables off" }[ui.cables];
  toolbar.cables.classList.toggle("off", ui.cables === "off");
  toolbar.undo.disabled = !history.past.length;
  toolbar.redo.disabled = !history.future.length;
  setStatus(sync.status);
}

function setView(view) {
  ui.view = view;
  localStorage.setItem("minirack.view", view);
  render();
}

function renderPalette() {
  els.palette.replaceChildren(
    h(
      "div",
      { class: "palette-head" },
      h("span", null, "🧺 gear"),
      h("button", { class: "btn ghost icon sm", title: "Close the drawer", onclick: () => togglePalette(false) }, "×"),
    ),
    h("div", { class: "palette-intro" }, "drag things into the rack, or click to pop them in the first free spot"),
    ...TEMPLATE_GROUPS.map((g) =>
      h(
        "section",
        { class: "palette-group" },
        h("h3", null, h("span", null, g.emoji), " ", g.name),
        g.items.map((t) => {
          const portCount = t.ports.reduce((sum, { n }) => sum + n, 0);
          return h(
            "div",
            { class: "palette-card", onpointerdown: (e) => beginDrag(e, { template: t.key }) },
            h("span", { class: `chip ${t.width}`, style: { "--c": t.color, "--h": t.heightU } }),
            h(
              "span",
              { class: "palette-text" },
              h("span", { class: "palette-name" }, t.name),
              h(
                "span",
                { class: "palette-meta" },
                `${t.heightU}U · ${t.width}${portCount ? ` · ${portCount} ports` : ""}`,
              ),
            ),
          );
        }),
      ),
    ),
  );
}

// Which way the face you're looking at points. The back rails are drawn beside
// the rack, lined up with it: the front view shows their outside and the rear
// view their inside, so each view holds both ends of a cable through the rack.
const facing = (item) => (mountOf(item) === "front" ? ui.view : ui.view === "front" ? "rear" : "front");

// From behind, the rack is mirrored: a left-half item shows up on the right.
const shownSide = (side) => (ui.view === "rear" ? (side === "left" ? "right" : "left") : side);
const slotLeft = (item, bayW) => (item.width === "half" && shownSide(item.side) === "right" ? bayW / 2 : 0);

function visiblePorts(item) {
  // Ports are listed as seen from the front, except rear-only ones, which are listed as seen from behind.
  const mirrored = ui.view === "rear";
  const asSeen = (ports, fromBehind) => (fromBehind === mirrored ? ports : [...ports].reverse());
  if (facing(item) === "front")
    return asSeen(
      item.ports.filter((p) => onFace(p, "front")),
      false,
    );
  return [
    ...asSeen(
      item.ports.filter((p) => p.face === "rear"),
      true,
    ),
    ...asSeen(
      item.ports.filter((p) => p.face === "both"),
      false,
    ),
  ];
}

function geometry() {
  const U = ui.zoom;
  return { U, bayW: Math.round(U * BAY_RATIO), railW: Math.round(U * RAIL_RATIO) };
}

function renderStage() {
  hovered = null;
  const L = layout();
  const { U, bayW } = geometry();
  const scroll = { left: els.stage.scrollLeft, top: els.stage.scrollTop };

  const parked = L.items.filter((i) => i.parked);
  const inner = h(
    "div",
    {
      class: "stage-inner",
      onpointerdown: onStageDown,
      onpointermove: onStageMove,
      oncontextmenu: (e) => {
        e.preventDefault();
        ui.selection = null;
        ui.wiring = null;
        ui.showLayout = true;
        render();
      },
    },
    rackColumn(L, "front"),
    showBackRails(L) ? rackColumn(L, "rear") : null,
    h(
      "div",
      { class: "parking", style: { width: `${bayW + 36}px` } },
      h("div", { class: "parking-title" }, "🅿 parking bay", h("span", null, "things waiting for a home")),
      h(
        "div",
        { class: "parking-items" },
        parked.length
          ? parked.map((i) => itemEl(i, { U, bayW, parked: true }))
          : h("div", { class: "parking-empty" }, "all tucked away ✿"),
      ),
    ),
    L.stickies.map(stickyEl),
    h("svg", { class: `cables ${ui.cables}` }),
  );

  els.stage.replaceChildren(inner);
  els.stage.scrollLeft = scroll.left;
  els.stage.scrollTop = scroll.top;
  inner.querySelectorAll(".sticky textarea").forEach(autosize);
  drawCables();
}

function rackColumn(L, mount) {
  const { U, bayW, railW } = geometry();
  const units = Array.from({ length: L.rackUnits }, (_, i) => i + 1);
  const placed = L.items.filter((i) => !i.parked);

  // Gear on the other rails that fills the rack front to back still takes up room here.
  const blocked = placed
    .filter((i) => mountOf(i) !== mount && fullDepth(i))
    .map((i) =>
      h(
        "div",
        {
          class: "depth-block",
          title: `${i.name} fills the rack front to back`,
          style: {
            top: `${(i.u - 1) * U}px`,
            left: `${slotLeft(i, bayW)}px`,
            width: `${i.width === "half" ? bayW / 2 : bayW}px`,
            height: `${i.heightU * U}px`,
          },
        },
        h("span", null, `↔ ${i.name}`),
      ),
    );

  const bay = h(
    "div",
    { class: "bay", "data-mount": mount, style: { width: `${bayW}px`, height: `${U * L.rackUnits}px` } },
    units.map((u) => h("div", { class: "slot", style: { top: `${(u - 1) * U}px`, height: `${U}px` } })),
    blocked,
    placed.filter((i) => mountOf(i) === mount).map((i) => itemEl(i, { U, bayW })),
  );
  const rail = (side) =>
    h(
      "div",
      { class: `rail ${side}`, style: { width: `${railW}px` } },
      units.map(() => h("div", { class: "rail-u", style: { height: `${U}px` } }, h("i"), h("i"), h("i"))),
    );

  const title =
    mount === "front"
      ? [
          h(
            "div",
            null,
            L.name,
            h("span", { class: `view-chip ${ui.view}` }, ui.view === "rear" ? "↻ rear view" : "front view"),
          ),
          h("span", null, `${usedUnits(L)}/${L.rackUnits}U used`),
        ]
      : [
          h(
            "div",
            null,
            "back rails",
            h("span", { class: `view-chip ${ui.view}` }, ui.view === "front" ? "outside" : "↻ inside"),
          ),
          h("span", null, ui.view === "front" ? "where the wall lines plug in" : "facing into the rack"),
        ];

  return h(
    "div",
    { class: `rack-column ${mount === "rear" ? "back-rails" : ""}` },
    h("div", { class: "rack-title" }, title),
    h(
      "div",
      { class: "rack-wrap" },
      h(
        "div",
        { class: "u-labels" },
        units.map((u) => h("div", { style: { height: `${U}px` } }, u)),
      ),
      h(
        "div",
        { class: "rack", style: { "--filament": L.filament } },
        h("div", { class: "rack-cap" }),
        h("div", { class: "rack-body" }, rail("left"), bay, rail("right")),
        h("div", { class: "rack-cap bottom" }, h("i"), h("i")),
      ),
    ),
  );
}

function itemEl(item, { U, bayW, parked = false, ghost = false }) {
  const t = templateOf(item);
  const L = layout();
  const width = item.width === "half" ? bayW / 2 : bayW;
  const style = {
    width: `${width}px`,
    height: `${item.heightU * U}px`,
    "--c": item.color,
    "--u": `${U}px`,
    top: parked || ghost ? null : `${(item.u - 1) * U}px`,
    left: parked || ghost ? null : `${slotLeft(item, bayW)}px`,
  };
  const cls = [
    "item",
    `face-${t.style}`,
    ui.view,
    item.width,
    t.align === "center" ? "centered" : "",
    isDark(item.color) ? "dark" : "",
    isSelected("item", item.id) ? "selected" : "",
    ghost ? "ghost" : "",
  ];
  const ports = visiblePorts(item);
  const portBtn = (p) => portEl(L, item, p, t.style === "patch" ? item.ports.indexOf(p) + 1 : null);
  const flank = (side) => {
    const pinned = ports.filter((p) => p.pos && shownSide(p.pos) === side);
    return pinned.length ? h("div", { class: `ports flank ${side}` }, pinned.map(portBtn)) : null;
  };
  // Ports in a multi-bay mount cluster per device; from behind, the bays run the other way.
  const units = [...new Set(ports.filter((p) => !p.pos).map((p) => p.unit ?? 0))];
  if (ui.view === "rear") units.reverse();
  const groups = units.map((u) => ports.filter((p) => !p.pos && (p.unit ?? 0) === u));
  // A mount holding different devices side by side draws each in its own bay, with that device's ports inside it.
  const bays = (t.bays ?? []).map((kind, i) => ({ kind, ports: ports.filter((p) => !p.pos && p.unit === i + 1) }));
  if (ui.view === "rear") bays.reverse();

  return h(
    "div",
    {
      class: cls.join(" "),
      "data-id": item.id,
      style,
      onpointerdown: ghost ? null : (e) => beginDrag(e, { item }),
      oncontextmenu: ghost ? null : contextSelect("item", item.id),
    },
    h(
      "div",
      { class: "item-top" },
      h("span", { class: "item-name" }, item.name),
      item.notes ? h("span", { class: "note-dot", title: item.notes }, "✎") : null,
      h("span", { class: "leds" }, h("i"), h("i")),
    ),
    h(
      "div",
      { class: "item-body" },
      flank("left"),
      h(
        "div",
        { class: "item-center" },
        bays.length
          ? h(
              "div",
              { class: "mount-bays" },
              bays.map(({ kind, ports }) =>
                h(
                  "div",
                  { class: `mount-bay bay-${kind}` },
                  kind === "kvm" && ui.view === "front"
                    ? h("div", { class: "kvm" }, h("div", { class: "kvm-screen" }, h("i"), h("i")))
                    : null,
                  ports.length ? h("div", { class: "ports" }, ports.map(portBtn)) : null,
                ),
              ),
            )
          : [
              decorEl(t),
              groups.length
                ? h(
                    "div",
                    { class: "ports" },
                    groups.map((g) => h("div", { class: "port-group" }, g.map(portBtn))),
                  )
                : null,
            ],
      ),
      flank("right"),
    ),
  );
}

function decorEl({ style, screens = 0 }) {
  if (screens) {
    if (ui.view === "rear") return null;
    return h(
      "div",
      { class: `decor screens screens-${style}` },
      Array.from({ length: screens }, () =>
        h("div", { class: "kvm" }, h("div", { class: "kvm-screen" }, h("i"), h("i"))),
      ),
    );
  }
  if (style === "brush") return h("div", { class: "decor brush" });
  if (style === "rings") return h("div", { class: "decor rings" }, h("i"), h("i"), h("i"));
  if (style === "vent") return h("div", { class: "decor vent" });
  if (style === "shelf") return h("div", { class: "decor shelf" });
  if (style === "circuit") return ui.view === "front" ? h("div", { class: "decor circuit" }, h("i")) : null;
  return null;
}

function portEl(L, item, port, number) {
  const face = facing(item);
  const cable = cableAt(L, item.id, port.id, face);
  const wiringHere = ui.wiring && sameEnd(ui.wiring, item.id, port.id, face);
  return h("button", {
    class: `port port-${port.kind} ${cable ? "linked" : ""} ${wiringHere ? "wiring-from" : ""}`,
    title: `${portName(item, port)}${cable ? ` → ${endName(L, otherEnd(cable, item.id, port.id, face))}` : ""}`,
    "data-item": item.id,
    "data-port": port.id,
    "data-n": number,
    style: cable ? { "--cable": cable.color } : null,
    onpointerdown: (e) => e.stopPropagation(),
    onpointerenter: () => hoverTrace(L.cables.find((c) => touchesPort(c, item.id, port.id)) ?? null),
    onpointerleave: () => hoverTrace(null),
    onclick: (e) => {
      e.stopPropagation();
      onPortClick(item, port);
    },
  });
}

function stickyEl(s) {
  return h(
    "div",
    {
      class: `sticky ${isSelected("sticky", s.id) ? "selected" : ""}`,
      "data-id": s.id,
      style: { left: `${s.x}px`, top: `${s.y}px`, "--c": s.color },
      onpointerdown: (e) => beginStickyDrag(e, s.id),
      oncontextmenu: contextSelect("sticky", s.id),
    },
    h("div", { class: "sticky-tape" }),
    h("textarea", {
      value: s.text,
      placeholder: "write a little note…",
      onpointerdown: (e) => e.stopPropagation(),
      oninput: (e) => {
        const text = e.target.value;
        autosize(e.target);
        mutate(
          (L) => {
            L.stickies.find((x) => x.id === s.id).text = text;
          },
          { coalesce: `sticky-${s.id}`, stage: false, inspector: false },
        );
      },
    }),
  );
}

function autosize(textarea) {
  textarea.style.height = "auto";
  textarea.style.height = `${textarea.scrollHeight}px`;
}

// ---------- cable lengths ----------

const DEPTH_CM = 16; // between the front and back rails
const PLUG_MM = 40; // a plug and its boot stick straight out before the cable can bend
const KEYSTONE_MM = 30; // how far a jack's back sits inside the rails
const STOCK_CM = [15, 25, 30, 50, 100, 150, 200, 300];

let measurer = null;

// Where a port sits in the rack, in mm: x across from the left as seen from the
// front, y down from the top, z back from the front rails. The x comes from
// drawing the item as it looks from that side, so it matches what's on screen.
function portSpot(L, end) {
  const item = findItem(L, end.item);
  if (!item || item.parked) return null;
  const { U, bayW } = geometry();
  const view = mountOf(item) === "front" ? end.face : end.face === "front" ? "rear" : "front";
  const shown = ui.view;
  ui.view = view;
  const el = itemEl(item, { U, bayW, parked: true });
  ui.view = shown;
  measurer ??= document.body.appendChild(h("div", { class: "measurer" }));
  measurer.replaceChildren(el);
  const port = el.querySelector(`.port[data-port="${end.port}"]`);
  if (!port) return null;
  const ir = el.getBoundingClientRect();
  const pr = port.getBoundingClientRect();
  const across = pr.left + pr.width / 2 - ir.left;
  const x =
    (item.width === "half" && item.side === "right" ? bayW / 2 : 0) + (view === "rear" ? ir.width - across : across);
  const y = (item.u - 1) * U + pr.top + pr.height / 2 - ir.top;
  const depth = (L.depthCm ?? DEPTH_CM) * 10;
  const front = mountOf(item) === "front";
  const z = front ? (end.face === "front" ? 0 : KEYSTONE_MM) : end.face === "front" ? depth - KEYSTONE_MM : depth;
  return { x: (x * U_MM) / U, y: (y * U_MM) / U, z, outside: z === 0 || z === depth };
}

// Cables run square to the rack rather than in a straight line, plus a plug's
// worth at each end, rounded up to a length you can buy.
function cableLength(L, c) {
  const a = portSpot(L, c.from);
  const b = portSpot(L, c.to);
  if (!a || !b) return null;
  // Nothing passes through a faceplate, so from the outside of one to anywhere else goes round the side.
  const around = (a.outside || b.outside) && a.z !== b.z;
  const dx = around ? Math.min(a.x + b.x, 2 * BAY_MM - a.x - b.x) : Math.abs(a.x - b.x);
  const mm = dx + Math.abs(a.y - b.y) + Math.abs(a.z - b.z) + 2 * PLUG_MM;
  return { mm, buyCm: STOCK_CM.find((cm) => cm * 10 >= mm) ?? null };
}

const cmText = (cm) => (cm == null ? "over 3 m" : cm < 100 ? `${cm} cm` : `${cm / 100} m`);

function cableKind(L, c) {
  const kind = findItem(L, c.from.item)?.ports.find((p) => p.id === c.from.port)?.kind;
  return kind === "rj45" ? "patch lead" : `${PORT_KINDS[kind]?.short ?? "mystery"} cable`;
}

function shoppingList(L) {
  const counts = new Map();
  let unmeasured = 0;
  for (const c of L.cables) {
    const len = cableLength(L, c);
    if (!len) {
      unmeasured++;
      continue;
    }
    const key = `${cableKind(L, c)}|${len.buyCm ?? Infinity}`;
    counts.set(key, (counts.get(key) ?? 0) + 1);
  }
  const lines = [...counts]
    .map(([key, n]) => {
      const [kind, cm] = key.split("|");
      return { kind, cm: Number(cm), n };
    })
    .sort((a, b) => a.kind.localeCompare(b.kind) || a.cm - b.cm);
  return { lines, unmeasured };
}

// ---------- cables ----------

function cablePath(a, b) {
  const sag = Math.min(140, 26 + Math.hypot(b.x - a.x, b.y - a.y) * 0.35);
  return {
    d: `M${a.x},${a.y} C${a.x},${a.y + sag} ${b.x},${b.y + sag} ${b.x},${b.y}`,
    mid: { x: (a.x + b.x) / 2, y: (a.y + b.y) / 2 + sag * 0.75 },
  };
}

function portCenter(inner, end) {
  const item = findItem(layout(), end.item);
  if (!item || end.face !== facing(item)) return null;
  const el = inner.querySelector(`.port[data-item="${end.item}"][data-port="${end.port}"]`);
  if (!el) return null;
  const r = el.getBoundingClientRect();
  const ir = inner.getBoundingClientRect();
  return { x: r.left + r.width / 2 - ir.left, y: r.top + r.height / 2 - ir.top, el };
}

// A cable whose other end is on the far side of the rack: draw it running
// off the nearest edge, finishing in a little ↻ badge.
function stubTo(inner, a) {
  const ir = inner.getBoundingClientRect();
  const r = a.el.closest(".item").getBoundingClientRect();
  const pad = a.el.closest(".bay") ? geometry().railW + 22 : 18;
  const right = a.x > r.left + r.width / 2 - ir.left;
  const b = { x: right ? r.right - ir.left + pad : r.left - ir.left - pad, y: a.y + 22 };
  const dir = right ? 1 : -1;
  return { b, d: `M${a.x},${a.y} C${a.x},${a.y + 34} ${b.x - dir * 34},${b.y} ${b.x},${b.y}` };
}

function drawCables() {
  const inner = els.stage.querySelector(".stage-inner");
  const svg = inner?.querySelector("svg.cables");
  if (!svg) return;
  svg.setAttribute("width", 0);
  svg.setAttribute("height", 0);
  svg.setAttribute("width", inner.scrollWidth);
  svg.setAttribute("height", inner.scrollHeight);

  const L = layout();
  const groups = L.cables.map((c) => {
    const pick = (e) => {
      e.stopPropagation();
      select("cable", c.id);
    };
    const through = [c.from, c.to].some((end) => mountOf(findItem(L, end.item) ?? {}) === "rear");
    const cls = `cable ${isSelected("cable", c.id) ? "selected" : ""} ${through ? "through" : ""}`;
    const hover = { onpointerenter: () => hoverTrace(c), onpointerleave: () => hoverTrace(null) };
    let a = portCenter(inner, c.from);
    const b = portCenter(inner, c.to);
    if (!a && !b) return null;
    if (!a || !b) {
      const away = a ? c.to : c.from;
      a ??= b;
      const stub = stubTo(inner, a);
      return h(
        "g",
        {
          class: `${cls} stub`,
          "data-id": c.id,
          style: { "--cable": c.color },
          oncontextmenu: contextSelect("cable", c.id),
          ...hover,
        },
        h("title", null, `${c.label ? `${c.label}: ` : ""}round the ${away.face} to ${endName(L, away)}`),
        h("path", { class: "cable-shadow", d: stub.d }),
        h("path", { class: "cable-line", d: stub.d }),
        h("path", { class: "cable-hit", d: stub.d, onpointerdown: (e) => e.stopPropagation(), onclick: pick }),
        h("circle", { class: "plug", cx: a.x, cy: a.y, r: 4 }),
        h(
          "g",
          { class: "stub-badge", onpointerdown: (e) => e.stopPropagation(), onclick: pick },
          h("circle", { cx: stub.b.x, cy: stub.b.y, r: 10 }),
          h("text", { x: stub.b.x, y: stub.b.y + 4 }, "↻"),
        ),
      );
    }
    const { d, mid } = cablePath(a, b);
    return h(
      "g",
      {
        class: cls,
        "data-id": c.id,
        style: { "--cable": c.color },
        oncontextmenu: contextSelect("cable", c.id),
        ...hover,
      },
      h("path", { class: "cable-shadow", d }),
      h("path", { class: "cable-line", d }),
      h("path", { class: "cable-hit", d, onpointerdown: (e) => e.stopPropagation(), onclick: pick }),
      h("circle", { class: "plug", cx: a.x, cy: a.y, r: 4 }),
      h("circle", { class: "plug", cx: b.x, cy: b.y, r: 4 }),
      c.label
        ? h(
            "g",
            { class: "cable-label", onpointerdown: (e) => e.stopPropagation(), onclick: pick },
            h("rect", {
              x: mid.x - (c.label.length * 6.4 + 16) / 2,
              y: mid.y - 10,
              width: c.label.length * 6.4 + 16,
              height: 20,
              rx: 10,
            }),
            h("text", { x: mid.x, y: mid.y + 4 }, c.label),
          )
        : null,
    );
  });
  svg.replaceChildren(...groups.filter(Boolean), h("path", { class: "wire-preview" }));
  applyTrace();
}

// ---------- tracing ----------

// A keystone passes straight through, so a run carries on out its other side.
function throughSide(L, end) {
  const port = findItem(L, end.item)?.ports.find((p) => p.id === end.port);
  return port?.face === "both" ? { ...end, face: end.face === "front" ? "rear" : "front" } : null;
}

// The whole run a cable is part of, from the wall to the device, as stops with a cable between each.
function traceRun(L, cable) {
  const seen = new Set([cable.id]);
  const extend = (end) => {
    const cables = [];
    const stops = [];
    for (let at = end; ; ) {
      const through = throughSide(L, at);
      const next =
        through && L.cables.find((c) => !seen.has(c.id) && touchesPort(c, through.item, through.port, through.face));
      if (!next) return { cables, stops };
      seen.add(next.id);
      at = otherEnd(next, through.item, through.port, through.face);
      cables.push(next);
      stops.push(at);
    }
  };
  const before = extend(cable.from);
  const after = extend(cable.to);
  const run = {
    stops: [...before.stops.reverse(), cable.from, cable.to, ...after.stops],
    cables: [...before.cables.reverse(), cable, ...after.cables],
  };
  // Read it from the open keystone a wall line plugs into, through to the device.
  const open = (end) => !!throughSide(L, end);
  if (open(run.stops.at(-1)) && !open(run.stops[0])) {
    run.stops.reverse();
    run.cables.reverse();
  }
  return run;
}

let hovered = null;

function hoverTrace(cable) {
  hovered = cable;
  applyTrace();
}

// Light up the run under the pointer, or the selected cable's, and fade everything else.
function applyTrace() {
  const L = layout();
  const selected = ui.selection?.type === "cable" && L.cables.find((c) => c.id === ui.selection.id);
  const live = hovered && L.cables.includes(hovered) ? hovered : selected;
  const run = live ? traceRun(L, live) : null;
  const cables = new Set(run?.cables.map((c) => c.id));
  const ports = new Set(run?.cables.flatMap((c) => [c.from, c.to]).map((e) => `${e.item}:${e.port}`));
  document.body.classList.toggle("tracing", !!run);
  for (const g of els.stage.querySelectorAll("svg.cables .cable"))
    g.classList.toggle("traced", cables.has(g.dataset.id));
  for (const el of els.stage.querySelectorAll(".port"))
    el.classList.toggle("traced", ports.has(`${el.dataset.item}:${el.dataset.port}`));
}

function onPortClick(item, port) {
  const L = layout();
  const face = facing(item);
  const existing = cableAt(L, item.id, port.id, face);
  if (!ui.wiring) {
    if (existing) return select("cable", existing.id);
    ui.selection = null;
    ui.wiring = { item: item.id, port: port.id, face };
    render();
    toast("now click another port to plug in the other end · V flips front/rear · Esc cancels");
    return;
  }
  if (sameEnd(ui.wiring, item.id, port.id, face)) {
    ui.wiring = null;
    return render();
  }
  if (existing) return toast("that port's already got a cable in it 🙈");
  const from = ui.wiring;
  ui.wiring = null;
  els.toast.classList.remove("show");
  mutate((L) => {
    const cable = {
      id: uid("cable"),
      from,
      to: { item: item.id, port: port.id, face },
      color: ui.cableColor,
      label: "",
      notes: "",
    };
    L.cables.push(cable);
    ui.selection = { type: "cable", id: cable.id };
  });
}

function onStageMove(e) {
  if (!ui.wiring) return;
  const inner = e.currentTarget;
  const preview = inner.querySelector(".wire-preview");
  const a = portCenter(inner, ui.wiring);
  if (!preview || !a) return;
  const ir = inner.getBoundingClientRect();
  preview.setAttribute("d", cablePath(a, { x: e.clientX - ir.left, y: e.clientY - ir.top }).d);
  preview.style.setProperty("--cable", ui.cableColor);
}

function onStageDown(e) {
  if (e.target.closest(".item, .sticky, .port")) return;
  if (ui.wiring) {
    ui.wiring = null;
    return render();
  }
  if (ui.selection || ui.showLayout) select(null);
}

// ---------- dragging ----------

function beginDrag(e, spec) {
  if (e.button !== 0) return;
  e.preventDefault();
  const L = layout();
  const { U, bayW } = geometry();
  const proto = spec.item ?? makeItem(spec.template);
  const w = proto.width === "half" ? bayW / 2 : bayW;
  const hgt = proto.heightU * U;
  const start = { x: e.clientX, y: e.clientY };
  const r = e.currentTarget.getBoundingClientRect();
  const grab = spec.item ? { x: e.clientX - r.left, y: e.clientY - r.top } : { x: Math.min(36, w / 2), y: U / 2 };
  let ghost = null;
  let drop = null;

  const move = (ev) => {
    if (!ghost) {
      if (Math.hypot(ev.clientX - start.x, ev.clientY - start.y) < 4) return;
      ghost = itemEl(proto, { U, bayW, ghost: true });
      document.body.append(ghost);
      document.body.classList.add("dragging");
      if (spec.item) els.stage.querySelector(`.item[data-id="${proto.id}"]`)?.classList.add("lifted");
    }
    ghost.style.transform = `translate(${ev.clientX - grab.x}px, ${ev.clientY - grab.y}px)`;
    drop = computeDrop(L, ev, proto, grab, { U, w, hgt });
    showDropPreview(drop, proto, { U, bayW, w, hgt });
  };

  const finish = (cancelled) => {
    window.removeEventListener("pointermove", move);
    window.removeEventListener("pointerup", onUp);
    window.removeEventListener("pointercancel", onCancel);
    document.body.classList.remove("dragging");
    showDropPreview(null);
    if (!ghost) {
      if (cancelled) return;
      return spec.item ? select("item", proto.id) : placeAnywhere(proto);
    }
    ghost.remove();
    els.stage.querySelector(".item.lifted")?.classList.remove("lifted");
    if (!cancelled) applyDrop(drop, proto, !spec.item);
  };
  const onUp = () => finish(false);
  const onCancel = () => finish(true);
  window.addEventListener("pointermove", move);
  window.addEventListener("pointerup", onUp);
  window.addEventListener("pointercancel", onCancel);
}

function computeDrop(L, ev, proto, grab, { U, w, hgt }) {
  const park = els.stage.querySelector(".parking")?.getBoundingClientRect();
  if (
    park &&
    ev.clientX >= park.left &&
    ev.clientX <= park.right &&
    ev.clientY >= park.top &&
    ev.clientY <= park.bottom
  ) {
    return { type: "park" };
  }
  const left = ev.clientX - grab.x;
  const top = ev.clientY - grab.y;
  const cx = left + w / 2;
  const margin = U * 1.2;
  // With the back rails showing there are two bays, so drop into whichever is nearest.
  const near = [...els.stage.querySelectorAll(".bay")]
    .map((el) => ({ mount: el.dataset.mount, bay: el.getBoundingClientRect() }))
    .filter(({ bay }) => cx >= bay.left - margin && cx <= bay.right + margin)
    .filter(({ bay }) => top + hgt >= bay.top - margin && top <= bay.bottom + margin)
    .sort((a, b) => Math.abs(cx - (a.bay.left + a.bay.right) / 2) - Math.abs(cx - (b.bay.left + b.bay.right) / 2));
  if (!near.length) return null;
  const { mount, bay } = near[0];
  if (proto.heightU > L.rackUnits) return { type: "rack", valid: false, u: 1, side: null, mount };
  const u = clamp(Math.round((top - bay.top) / U) + 1, 1, L.rackUnits - proto.heightU + 1);
  const side = proto.width === "half" ? shownSide(cx < bay.left + bay.width / 2 ? "left" : "right") : null;
  return { type: "rack", u, side, mount, valid: fits(L, { ...proto, u, side, mount }, proto.id) };
}

function showDropPreview(drop, proto, geo) {
  els.stage.querySelector(".drop-preview")?.remove();
  els.stage.querySelector(".parking")?.classList.toggle("drop-target", drop?.type === "park");
  if (drop?.type !== "rack") return;
  const left = slotLeft({ width: proto.width, side: drop.side }, geo.bayW);
  els.stage.querySelector(`.bay[data-mount="${drop.mount}"]`).append(
    h("div", {
      class: `drop-preview ${drop.valid ? "ok" : "nope"}`,
      style: { top: `${(drop.u - 1) * geo.U}px`, left: `${left}px`, width: `${geo.w}px`, height: `${geo.hgt}px` },
    }),
  );
}

function applyDrop(drop, proto, isNew) {
  if (!drop) return;
  if (drop.type === "rack" && !drop.valid) return toast("no room there, lovely, something's in the way");
  mutate((L) => {
    const item = isNew ? proto : findItem(L, proto.id);
    if (drop.type === "park") item.parked = true;
    else {
      Object.assign(item, { parked: false, u: drop.u, side: drop.side });
      setMount(item, drop.mount);
    }
    if (isNew) L.items.push(item);
    ui.selection = { type: "item", id: item.id };
  });
}

function placeAnywhere(proto) {
  mutate((L) => {
    const spot = firstFreeSpot(L, proto);
    if (spot) Object.assign(proto, { u: spot.u, side: spot.side, parked: false });
    else {
      proto.parked = true;
      toast("rack's full! popped it in the parking bay for now");
    }
    L.items.push(proto);
    ui.selection = { type: "item", id: proto.id };
  });
}

function beginStickyDrag(e, id) {
  if (e.button !== 0) return;
  const el = e.currentTarget;
  const s = layout().stickies.find((x) => x.id === id);
  const start = { x: e.clientX, y: e.clientY, sx: s.x, sy: s.y };
  let moved = false;
  const move = (ev) => {
    const dx = ev.clientX - start.x;
    const dy = ev.clientY - start.y;
    if (!moved && Math.hypot(dx, dy) < 4) return;
    moved = true;
    el.style.left = `${Math.max(0, start.sx + dx)}px`;
    el.style.top = `${Math.max(0, start.sy + dy)}px`;
  };
  const up = (ev) => {
    window.removeEventListener("pointermove", move);
    window.removeEventListener("pointerup", up);
    if (!moved) return select("sticky", id);
    mutate((L) => {
      const note = L.stickies.find((x) => x.id === id);
      note.x = Math.max(0, start.sx + ev.clientX - start.x);
      note.y = Math.max(0, start.sy + ev.clientY - start.y);
      ui.selection = { type: "sticky", id };
    });
  };
  window.addEventListener("pointermove", move);
  window.addEventListener("pointerup", up);
}

function addSticky() {
  mutate((L) => {
    const note = {
      id: uid("note"),
      x: els.stage.scrollLeft + 60 + Math.round(Math.random() * 80),
      y: els.stage.scrollTop + 60 + Math.round(Math.random() * 80),
      color: COLORS.sticky[L.stickies.length % COLORS.sticky.length],
      text: "",
    };
    L.stickies.push(note);
    ui.selection = { type: "sticky", id: note.id };
  });
  els.stage.querySelector(`.sticky[data-id="${ui.selection.id}"] textarea`)?.focus();
}

// ---------- inspector ----------

const field = (label, ...control) =>
  h("div", { class: "field" }, h("span", { class: "field-label" }, label), ...control);

function swatches(colors, current, onPick) {
  return h(
    "div",
    { class: "swatches" },
    colors.map((c) =>
      h("button", {
        class: `swatch ${c === current ? "on" : ""}`,
        style: { "--c": c },
        title: c,
        onclick: (e) => {
          e.preventDefault();
          onPick(c);
        },
      }),
    ),
  );
}

function stepper(value, min, max, onChange, suffix = "") {
  return h(
    "div",
    { class: "stepper" },
    h(
      "button",
      {
        class: "btn ghost icon",
        disabled: value <= min,
        onclick: (e) => {
          e.preventDefault();
          onChange(value - 1);
        },
      },
      "−",
    ),
    h("span", null, `${value}${suffix}`),
    h(
      "button",
      {
        class: "btn ghost icon",
        disabled: value >= max,
        onclick: (e) => {
          e.preventDefault();
          onChange(value + 1);
        },
      },
      "+",
    ),
  );
}

function textInput(value, coalesce, apply, { multiline = false, placeholder = "", restage = true } = {}) {
  return h(multiline ? "textarea" : "input", {
    value,
    placeholder,
    rows: multiline ? 4 : null,
    oninput: (e) => {
      const v = e.target.value;
      mutate((L) => apply(L, v), { coalesce, inspector: false, stage: restage });
    },
  });
}

function renderInspector() {
  const L = layout();
  const sel = ui.selection;
  const item = sel?.type === "item" && findItem(L, sel.id);
  const cable = sel?.type === "cable" && L.cables.find((c) => c.id === sel.id);
  const sticky = sel?.type === "sticky" && L.stickies.find((s) => s.id === sel.id);
  const panel = item
    ? itemInspector(L, item)
    : cable
      ? cableInspector(L, cable)
      : sticky
        ? stickyInspector(sticky)
        : ui.showLayout
          ? layoutInspector(L)
          : null;
  els.inspector.hidden = !panel;
  if (panel) els.inspector.replaceChildren(panel);
}

// The inspector floats beside whatever it's describing, nudged to stay on screen.
function placeInspector() {
  const card = els.inspector;
  if (card.hidden) return;
  const sel = ui.selection;
  const anchor = sel
    ? els.stage.querySelector(`.${sel.type}[data-id="${sel.id}"]`)?.getBoundingClientRect()
    : toolbar.layout.getBoundingClientRect();
  const m = 12;
  const w = card.offsetWidth;
  const ht = card.offsetHeight;
  let left = window.innerWidth - w - m;
  let top = 70;
  if (anchor && !sel) {
    left = anchor.right - w;
    top = anchor.bottom + 10;
  } else if (anchor) {
    left = anchor.right + 16;
    if (left + w > window.innerWidth - m) left = anchor.left - w - 16;
    top = anchor.top - 12;
  }
  card.style.left = `${clamp(left, m, window.innerWidth - w - m)}px`;
  card.style.top = `${clamp(top, 64, window.innerHeight - ht - m)}px`;
}

function itemInspector(L, item) {
  const id = item.id;
  const edit = (fn, opts) => mutate((L) => fn(findItem(L, id), L), opts);

  const resize = (patch) => {
    const next = { ...item, ...patch };
    if (next.width === "half" && !next.side) next.side = "left";
    if (!item.parked && !fits(L, next, id)) return toast("not enough room for that here, try moving it first");
    edit((it) => Object.assign(it, patch, { side: next.width === "half" ? next.side : null }));
  };

  const remount = (mount) => {
    if (!item.parked && !fits(L, { ...item, mount }, id))
      return toast(`something's already on the ${mount === "rear" ? "back" : "front"} rails there`);
    edit((it, L) => {
      setMount(it, mount);
      if (mount === "rear") L.backRails = true;
    });
  };

  const setDepth = (full) => {
    if (!item.parked && !fits(L, { ...item, fullDepth: full }, id))
      return toast("it'd bump into whatever's on the other rails there");
    edit((it) => {
      it.fullDepth = full;
    });
  };

  const seg = (options, current, onPick) =>
    h(
      "div",
      { class: "seg" },
      options.map(([value, label]) =>
        h(
          "button",
          {
            class: current === value ? "on" : "",
            onclick: (e) => {
              e.preventDefault();
              onPick(value);
            },
          },
          label,
        ),
      ),
    );

  const addPort = (kind) => edit((it) => it.ports.push({ id: uid("p"), kind, face: facing(it), label: "" }));
  const removePort = (portId) =>
    edit((it, L) => {
      it.ports = it.ports.filter((p) => p.id !== portId);
      L.cables = L.cables.filter((c) => !touchesPort(c, id, portId));
    });
  // front → rear → both; unplug any cable left on a side the port no longer has.
  const cycleFace = (portId) =>
    edit((it, L) => {
      const port = it.ports.find((p) => p.id === portId);
      port.face = { front: "rear", rear: "both", both: "front" }[port.face];
      L.cables = L.cables.filter((c) =>
        [c.from, c.to].every((end) => !sameEnd(end, id, portId) || onFace(port, end.face)),
      );
    });

  return h(
    "div",
    { class: "panel" },
    h(
      "div",
      { class: "panel-head" },
      h("span", { class: "panel-kicker" }, templateOf(item).name ?? "thing"),
      h("button", { class: "btn ghost icon", title: "Close", onclick: () => select(null) }, "×"),
    ),
    field(
      "Name",
      textInput(item.name, `name-${id}`, (L, v) => {
        findItem(L, id).name = v;
      }),
    ),
    field(
      "Colour",
      swatches(COLORS.device, item.color, (c) =>
        edit((it) => {
          it.color = c;
        }),
      ),
    ),
    h(
      "div",
      { class: "row" },
      field(
        "Height",
        stepper(item.heightU, 1, 8, (n) => resize({ heightU: n }), "U"),
      ),
      field(
        "Width",
        h(
          "div",
          { class: "seg" },
          ["full", "half"].map((w) =>
            h(
              "button",
              {
                class: item.width === w ? "on" : "",
                onclick: (e) => {
                  e.preventDefault();
                  resize({ width: w });
                },
              },
              w,
            ),
          ),
        ),
      ),
    ),
    h(
      "div",
      { class: "row" },
      field(
        "Rails",
        seg(
          [
            ["front", "front"],
            ["rear", "back"],
          ],
          mountOf(item),
          remount,
        ),
      ),
      field(
        "Depth",
        seg(
          [
            [false, "part"],
            [true, "full"],
          ],
          fullDepth(item),
          setDepth,
        ),
      ),
    ),
    field(
      "Notes",
      textInput(
        item.notes,
        `notes-${id}`,
        (L, v) => {
          findItem(L, id).notes = v;
        },
        { multiline: true, placeholder: "IPs, what it does, what's plugged in, reminders…" },
      ),
    ),
    h(
      "div",
      { class: "field" },
      h("span", { class: "field-label" }, `Ports (${item.ports.length})`),
      h(
        "div",
        { class: "port-list" },
        item.ports.length ? null : h("div", { class: "hint" }, "no ports yet, add some below"),
        item.ports.map((p) => {
          const linked = L.cables.filter((c) => touchesPort(c, id, p.id));
          return h(
            "div",
            { class: "port-row" },
            h("span", { class: `kind kind-${p.kind}` }, PORT_KINDS[p.kind].short),
            h(
              "button",
              {
                class: `face-chip face-${p.face}`,
                title: "Which side of the rack it's on (click to change)",
                onclick: () => cycleFace(p.id),
              },
              { front: "front", rear: "rear", both: "both" }[p.face],
            ),
            h(
              "div",
              { class: "port-row-main" },
              h("input", {
                value: p.label,
                placeholder: portName(item, { ...p, label: "" }),
                oninput: (e) => {
                  const v = e.target.value;
                  mutate(
                    (L) => {
                      findItem(L, id).ports.find((x) => x.id === p.id).label = v;
                    },
                    { coalesce: `port-${p.id}`, inspector: false },
                  );
                },
              }),
              linked.map((c) =>
                h(
                  "button",
                  { class: "linked-to", style: { "--cable": c.color }, onclick: () => select("cable", c.id) },
                  p.face === "both" ? `${faceName(item, (sameEnd(c.from, id, p.id) ? c.from : c.to).face)} ` : "",
                  "→ ",
                  endName(L, otherEnd(c, id, p.id)),
                ),
              ),
            ),
            h("button", { class: "btn ghost icon sm", title: "Remove port", onclick: () => removePort(p.id) }, "×"),
          );
        }),
      ),
      h(
        "div",
        { class: "add-ports" },
        Object.entries(PORT_KINDS).map(([kind, k]) =>
          h("button", { class: "btn ghost sm", onclick: () => addPort(kind) }, `+ ${k.short}`),
        ),
      ),
      h(
        "div",
        { class: "hint" },
        `new ports go on the ${faceName(item, facing(item))}, and the little side chip moves them`,
      ),
    ),
    h(
      "div",
      { class: "actions" },
      h(
        "button",
        {
          class: "btn ghost",
          onclick: () => {
            if (!item.parked)
              return edit((it) => {
                it.parked = true;
              });
            const spot = firstFreeSpot(L, item);
            if (!spot) return toast("no free spot that size in the rack right now");
            edit((it) => Object.assign(it, { parked: false, u: spot.u, side: spot.side }));
          },
        },
        item.parked ? "↥ put in rack" : "🅿 park it",
      ),
      h(
        "button",
        {
          class: "btn ghost",
          onclick: () =>
            mutate((L) => {
              const copy = JSON.parse(JSON.stringify(findItem(L, id)));
              copy.id = uid("item");
              copy.ports = copy.ports.map((p) => ({ ...p, id: uid("p") }));
              const spot = firstFreeSpot(L, copy);
              Object.assign(copy, spot ? { u: spot.u, side: spot.side, parked: false } : { parked: true });
              L.items.push(copy);
              ui.selection = { type: "item", id: copy.id };
            }),
        },
        "⧉ duplicate",
      ),
      TEMPLATES[item.template]
        ? h(
            "button",
            {
              class: "btn ghost",
              title: "Swap in the template's latest ports and size, keeping the name, colour, notes and spot",
              onclick: () => refreshFromTemplate(L, item),
            },
            "↺ refresh from template",
          )
        : null,
      h("button", { class: "btn danger", onclick: deleteSelection }, "delete"),
    ),
  );
}

function refreshFromTemplate(L, item) {
  const id = item.id;
  const fresh = makeItem(item.template);
  if (
    L.cables.some((c) => c.from.item === id || c.to.item === id) &&
    !confirm("Refreshing unplugs this item's cables. Carry on?")
  )
    return;
  const size = {
    heightU: fresh.heightU,
    width: fresh.width,
    side: fresh.width === "half" ? (item.side ?? "left") : null,
  };
  const roomy = item.parked || fits(L, { ...item, ...size }, id);
  mutate((L) => {
    const it = findItem(L, id);
    it.ports = fresh.ports;
    if (roomy) Object.assign(it, size);
    L.cables = L.cables.filter((c) => c.from.item !== id && c.to.item !== id);
  });
  toast(roomy ? "all fresh ✿" : "fresh ports! kept the old size though, there's no room to grow there");
}

function cableInspector(L, cable) {
  const id = cable.id;
  const edit = (fn, opts) => mutate((L) => fn(L.cables.find((c) => c.id === id)), opts);
  return h(
    "div",
    { class: "panel" },
    h(
      "div",
      { class: "panel-head" },
      h("span", { class: "panel-kicker" }, "cable"),
      h("button", { class: "btn ghost icon", title: "Close", onclick: () => select(null) }, "×"),
    ),
    h(
      "div",
      { class: "cable-ends", style: { "--cable": cable.color } },
      h("div", null, endName(L, cable.from)),
      h("div", { class: "cable-squiggle" }, "〰"),
      h("div", null, endName(L, cable.to)),
    ),
    routeEl(L, cable),
    field("Length", cableLengthEl(L, cable)),
    field(
      "Label",
      textInput(
        cable.label,
        `clabel-${id}`,
        (L, v) => {
          L.cables.find((c) => c.id === id).label = v;
        },
        { placeholder: "e.g. uplink, bedroom AP, pi-hole" },
      ),
    ),
    field(
      "Colour",
      swatches(COLORS.cable, cable.color, (c) =>
        edit((cb) => {
          cb.color = c;
        }),
      ),
    ),
    field(
      "Notes",
      textInput(
        cable.notes,
        `cnotes-${id}`,
        (L, v) => {
          L.cables.find((c) => c.id === id).notes = v;
        },
        { multiline: true, placeholder: "length, cat6 vs cat5e, needs replacing…", restage: false },
      ),
    ),
    h("div", { class: "actions" }, h("button", { class: "btn danger", onclick: deleteSelection }, "unplug")),
  );
}

// Every hop of the run this cable is part of, so you can see where it ends up without following lines.
function routeEl(L, cable) {
  const run = traceRun(L, cable);
  if (run.cables.length < 2) return null;
  const stop = (end) => {
    const item = findItem(L, end.item);
    const port = item?.ports.find((p) => p.id === end.port);
    if (!item || !port) return h("div", { class: "route-stop" }, "somewhere mysterious");
    const where = mountOf(item) === "rear" ? " (back rails)" : "";
    return h("div", { class: "route-stop" }, `${item.name}${where} · ${portName(item, port)}`);
  };
  const hop = (c) => {
    const len = cableLength(L, c);
    return h(
      "button",
      {
        class: `route-hop ${c.id === cable.id ? "here" : ""}`,
        style: { "--cable": c.color },
        title: "Select this cable",
        onclick: () => select("cable", c.id),
      },
      len ? cmText(len.buyCm) : "no length yet",
      c.label ? ` · ${c.label}` : "",
    );
  };
  return field(
    "Route",
    h(
      "div",
      { class: "route" },
      run.stops.map((end, i) => [stop(end), run.cables[i] ? hop(run.cables[i]) : null]),
    ),
  );
}

function cableLengthEl(L, cable) {
  const len = cableLength(L, cable);
  if (!len) return h("div", { class: "hint" }, "put both ends in the rack to measure it");
  return h(
    "div",
    { class: "cable-length" },
    h("b", null, `${cmText(len.buyCm)} ${cableKind(L, cable)}`),
    h("span", null, `about ${Math.round(len.mm / 10)} cm, plugs and all`),
  );
}

function stickyInspector(sticky) {
  const id = sticky.id;
  return h(
    "div",
    { class: "panel" },
    h(
      "div",
      { class: "panel-head" },
      h("span", { class: "panel-kicker" }, "sticky note"),
      h("button", { class: "btn ghost icon", title: "Close", onclick: () => select(null) }, "×"),
    ),
    h("p", { class: "hint" }, "type straight onto the note, and drag it around by its edges"),
    field(
      "Colour",
      swatches(COLORS.sticky, sticky.color, (c) =>
        mutate((L) => {
          L.stickies.find((s) => s.id === id).color = c;
        }),
      ),
    ),
    h("div", { class: "actions" }, h("button", { class: "btn danger", onclick: deleteSelection }, "peel it off")),
  );
}

function layoutInspector(L) {
  const id = L.id;
  const toggleBackRails = (on) =>
    mutate((L) => {
      L.backRails = on;
      if (on) return;
      const evicted = L.items.filter((i) => !i.parked && mountOf(i) === "rear");
      for (const i of evicted) i.parked = true;
      if (evicted.length)
        toast(`moved ${evicted.length} thing${evicted.length > 1 ? "s" : ""} off the back rails to parking`);
    });
  const resizeRack = (n) =>
    mutate((L) => {
      L.rackUnits = n;
      const evicted = L.items.filter((i) => !i.parked && i.u + i.heightU - 1 > n);
      for (const i of evicted) i.parked = true;
      if (evicted.length) toast(`moved ${evicted.length} thing${evicted.length > 1 ? "s" : ""} to the parking bay`);
    });

  return h(
    "div",
    { class: "panel" },
    h(
      "div",
      { class: "panel-head" },
      h("span", { class: "panel-kicker" }, "this layout"),
      h("button", { class: "btn ghost icon", title: "Close", onclick: () => select(null) }, "×"),
    ),
    field(
      "Name",
      textInput(L.name, `lname-${id}`, (L, v) => {
        L.name = v;
      }),
    ),
    h(
      "div",
      { class: "row" },
      field("Rack height", stepper(L.rackUnits, 2, 24, resizeRack, "U")),
      h(
        "div",
        { class: "stat" },
        h("b", null, L.rackUnits - usedUnits(L)),
        "U free",
        h("br"),
        h("b", null, L.cables.length),
        " cables",
      ),
    ),
    h(
      "div",
      { class: "row" },
      field(
        "Depth",
        stepper(
          L.depthCm ?? DEPTH_CM,
          5,
          60,
          (n) =>
            mutate((L) => {
              L.depthCm = n;
            }),
          " cm",
        ),
      ),
      field(
        "Back rails",
        h(
          "div",
          { class: "seg" },
          [
            [false, "off"],
            [true, "on"],
          ].map(([on, label]) =>
            h(
              "button",
              {
                class: showBackRails(L) === on ? "on" : "",
                onclick: (e) => {
                  e.preventDefault();
                  toggleBackRails(on);
                },
              },
              label,
            ),
          ),
        ),
      ),
    ),
    field(
      "Filament",
      swatches(COLORS.filament, L.filament, (c) =>
        mutate((L) => {
          L.filament = c;
        }),
      ),
    ),
    shoppingEl(L),
    field(
      "Layout notes",
      textInput(
        L.notes,
        `lnotes-${id}`,
        (L, v) => {
          L.notes = v;
        },
        { multiline: true, placeholder: "the plan, shopping list, things to print…", restage: false },
      ),
    ),
    h(
      "div",
      { class: "actions" },
      h(
        "button",
        {
          class: "btn ghost",
          onclick: () =>
            mutate((_, s) => {
              const copy = JSON.parse(JSON.stringify(L));
              copy.id = uid("layout");
              copy.name = `${L.name} (copy)`;
              s.layouts.splice(s.layouts.indexOf(layout()) + 1, 0, copy);
              ui.layoutId = copy.id;
            }),
        },
        "⧉ duplicate layout",
      ),
      state.layouts.length > 1
        ? h(
            "button",
            {
              class: "btn danger",
              onclick: () => {
                if (!confirm(`Delete "${L.name}"? (undo can bring it back)`)) return;
                mutate((_, s) => {
                  s.layouts = s.layouts.filter((x) => x.id !== id);
                  ui.layoutId = s.layouts[0].id;
                });
              },
            },
            "delete layout",
          )
        : null,
    ),
    h(
      "div",
      { class: "tips" },
      h("h4", null, "little tips ✿"),
      h(
        "ul",
        null,
        h(
          "li",
          null,
          "open the 🧺 gear drawer and drag things into the rack, or click one to drop it in the first free spot",
        ),
        h("li", null, "click a port, then another port, to plug in a cable"),
        h(
          "li",
          null,
          "flip to the rear view to cable up the back, and a ↻ shows a cable that goes round the other side",
        ),
        h(
          "li",
          null,
          "turn on back rails to mount a patch panel on the back: the front view shows its outside, the rear view its inside",
        ),
        h("li", null, "click (or right-click) anything to rename it, recolour it, or jot notes"),
        h("li", null, "duplicate a layout to plan the tidy version next to the current mess"),
        h(
          "li",
          null,
          h("kbd", null, "V"),
          " flip view · ",
          h("kbd", null, "Ctrl Z"),
          " undo · ",
          h("kbd", null, "Del"),
          " remove · ",
          h("kbd", null, "Esc"),
          " cancel",
        ),
      ),
    ),
  );
}

function shoppingEl(L) {
  const { lines, unmeasured } = shoppingList(L);
  return field(
    "Cable shopping list",
    lines.length
      ? h(
          "ul",
          { class: "shopping" },
          lines.map(({ kind, cm, n }) =>
            h("li", null, h("b", null, `${n} ×`), ` ${cmText(Number.isFinite(cm) ? cm : null)} ${kind}`),
          ),
        )
      : h("div", { class: "hint" }, "plug in some cables and their lengths add up here"),
    unmeasured
      ? h("div", { class: "hint" }, `plus ${unmeasured} with an end in the parking bay, so no length yet`)
      : null,
  );
}

function deleteSelection() {
  const sel = ui.selection;
  if (!sel) return;
  mutate((L) => {
    if (sel.type === "item") {
      L.items = L.items.filter((i) => i.id !== sel.id);
      L.cables = L.cables.filter((c) => c.from.item !== sel.id && c.to.item !== sel.id);
    }
    if (sel.type === "cable") L.cables = L.cables.filter((c) => c.id !== sel.id);
    if (sel.type === "sticky") L.stickies = L.stickies.filter((s) => s.id !== sel.id);
    ui.selection = null;
  });
}

// ---------- wiring it all up ----------

window.addEventListener("keydown", (e) => {
  const typing = e.target.closest?.("input, textarea");
  const mod = e.ctrlKey || e.metaKey;
  if (e.key === "Escape") {
    if (typing) return e.target.blur();
    if (ui.wiring) {
      ui.wiring = null;
      return render();
    }
    if (ui.selection || ui.showLayout) return select(null);
  }
  if (typing) return;
  if (mod && e.key.toLowerCase() === "z") {
    e.preventDefault();
    return e.shiftKey ? redo() : undo();
  }
  if (mod && e.key.toLowerCase() === "y") {
    e.preventDefault();
    return redo();
  }
  if (!mod && e.key.toLowerCase() === "v") return setView(ui.view === "front" ? "rear" : "front");
  if ((e.key === "Delete" || e.key === "Backspace") && ui.selection) {
    e.preventDefault();
    deleteSelection();
  }
});

window.addEventListener("resize", () => {
  drawCables();
  placeInspector();
});
els.stage.addEventListener("scroll", placeInspector);
window.addEventListener("beforeunload", (e) => {
  if (sync.dirty) e.preventDefault();
});

try {
  await load();
} catch (err) {
  console.error(err);
  state = seedState();
  ui.layoutId = state.layouts[0].id;
  setStatus("offline");
  toast("couldn't reach the server, changes won't save");
}
buildToolbar();
renderPalette();
render();
// Fonts can shift port positions after first paint, so redraw cables once they're in.
document.fonts?.ready.then(drawCables);
