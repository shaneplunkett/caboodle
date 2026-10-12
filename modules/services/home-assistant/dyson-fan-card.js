const MIN = 5;
const MAX = 355;
const WIDTHS = [0, 45, 90, 180, 350];
const TIMERS = [0, 15, 30, 60, 120, 180, 240, 360, 480, 540];
const HOLD_MS = 4000;
const SIZE = 300;
const C = SIZE / 2;
const R = 130;

const clamp = (v, lo, hi) => Math.min(hi, Math.max(lo, v));
const mins = (m) => (m < 60 ? `${m}m` : m % 60 ? `${Math.floor(m / 60)}h ${m % 60}m` : `${m / 60}h`);

class DysonFanCard extends HTMLElement {
  setConfig(config) {
    if (!config.entity) throw new Error("Set an entity, like fan.bedroom");
    this._config = { offset: 0, reverse: false, ...config };
    this._built = false;
    this._sheet = null;
  }

  set hass(hass) {
    this._hass = hass;
    if (!this._built) this._build();
    if (!this._drag && Date.now() > (this._holdUntil || 0)) this._sync();
    this._render();
  }

  connectedCallback() {
    this._tick = setInterval(() => this._render(), 30000);
  }

  disconnectedCallback() {
    clearInterval(this._tick);
  }

  getCardSize() {
    return 7;
  }

  static getStubConfig(hass) {
    const fan = Object.keys(hass.states).find(
      (id) => id.startsWith("fan.") && "angle_low" in hass.states[id].attributes,
    );
    return { entity: fan || "fan.bedroom" };
  }

  get _stateObj() {
    return this._hass.states[this._config.entity];
  }

  get _nightMode() {
    if (this._config.night_mode) return this._config.night_mode;
    const entities = this._hass.entities || {};
    const device = entities[this._config.entity]?.device_id;
    if (!device) return null;
    return Object.values(entities).find(
      (e) => e.device_id === device && e.entity_id.startsWith("switch.") && e.entity_id.includes("night_mode"),
    )?.entity_id;
  }

  get _timerKey() {
    return `dyson-fan-card:${this._config.entity}:timer`;
  }

  get _timerLeft() {
    const end = Number(localStorage.getItem(this._timerKey) || 0);
    return Math.max(0, Math.ceil((end - Date.now()) / 60000));
  }

  _sync() {
    const s = this._stateObj;
    if (!s) return;
    this._lo = Number(s.attributes.angle_low ?? 180);
    this._hi = Number(s.attributes.angle_high ?? 180);
  }

  _call(domain, service, data = {}) {
    this._hass.callService(domain, service, { entity_id: this._config.entity, ...data });
  }

  _toScreen(a) {
    const { offset, reverse } = this._config;
    return (reverse ? -a : a) + offset;
  }

  _fromScreen(s) {
    const { offset, reverse } = this._config;
    return (((reverse ? offset - s : s - offset) % 360) + 360) % 360;
  }

  _point(a, r = R) {
    const rad = ((this._toScreen(a) - 90) * Math.PI) / 180;
    return [C + r * Math.cos(rad), C + r * Math.sin(rad)];
  }

  _sector(lo, hi, r = R) {
    const [x1, y1] = this._point(lo, r);
    const [x2, y2] = this._point(hi, r);
    const large = hi - lo > 180 ? 1 : 0;
    const sweep = this._config.reverse ? 0 : 1;
    return `M ${C} ${C} L ${x1} ${y1} A ${r} ${r} 0 ${large} ${sweep} ${x2} ${y2} Z`;
  }

  _angleAt(ev) {
    const box = this._disc.getBoundingClientRect();
    const x = ((ev.clientX - box.left) / box.width) * SIZE - C;
    const y = ((ev.clientY - box.top) / box.height) * SIZE - C;
    const a = this._fromScreen((Math.atan2(y, x) * 180) / Math.PI + 90);
    if (a >= MIN && a <= MAX) return a;
    return a < 180 ? MIN : MAX;
  }

  _aim(centre, width) {
    if (width >= MAX - MIN) return [MIN, MAX];
    const lo = Math.round(clamp(centre - width / 2, MIN, MAX - width));
    return [lo, lo + width];
  }

  _build() {
    this._built = true;
    const root = this.shadowRoot || this.attachShadow({ mode: "open" });
    const button = (action, icon, label, value = false) =>
      `<button class="ctl" data-a="${action}">
        <span class="btn ${value ? "tall" : ""}"><ha-icon icon="${icon}"></ha-icon>${value ? `<span class="val"></span>` : ""}</span>
        <span class="label">${label}</span>
      </button>`;
    const sheet = (name, title, body) =>
      `<div class="sheet" data-s="${name}"><div class="title">${title}</div>${body}<button class="done">Done</button></div>`;
    root.innerHTML = `
      <style>
        :host {
          --fan-color: var(--state-fan-active-color, var(--state-active-color, var(--primary-color)));
          --off-color: color-mix(in srgb, var(--primary-text-color) 6%, transparent);
          --on-color: color-mix(in srgb, var(--fan-color) 20%, transparent);
        }
        ha-card { position: relative; overflow: hidden; padding: 12px 12px 16px; }
        .head { display: flex; align-items: center; gap: 10px; cursor: pointer; padding: 0 4px 8px; }
        .badge { width: 36px; height: 36px; border-radius: 50%; display: grid; place-items: center;
          background: var(--off-color); color: var(--state-icon-color, var(--secondary-text-color)); flex: none; }
        .on .badge { background: var(--on-color); color: var(--fan-color); }
        .on .badge ha-icon { animation: spin var(--spin, 2s) linear infinite; }
        @keyframes spin { to { transform: rotate(360deg); } }
        .who { display: flex; flex-direction: column; min-width: 0; }
        .name { font-weight: 500; color: var(--primary-text-color); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
        .state { font-size: 0.85em; color: var(--secondary-text-color); }
        .controls { display: grid; grid-template-columns: repeat(3, 1fr); gap: 12px 4px; justify-items: center;
          max-width: 300px; margin: 4px auto 0; }
        .controls .ctl[data-a="power"] { grid-column: 1 / -1; }
        .ctl { display: flex; flex-direction: column; align-items: center; gap: 6px; background: none; border: 0;
          padding: 0; font: inherit; cursor: pointer; color: var(--secondary-text-color); }
        .label { font-size: 0.8em; text-align: center; }
        .btn { width: 56px; height: 56px; border-radius: 28px; background: var(--off-color);
          color: var(--state-icon-color, var(--secondary-text-color)); display: grid; place-items: center;
          transition: background 0.2s, color 0.2s; }
        .btn.tall { height: 88px; grid-template-rows: 1fr 1fr; }
        .val { font-size: 1.05em; color: var(--primary-text-color); font-variant-numeric: tabular-nums; }
        .ctl.on .btn { background: var(--on-color); color: var(--fan-color); }
        .ctl.on .label { color: var(--primary-text-color); }
        .ctl.na { opacity: 0.35; pointer-events: none; }
        .dim .ctl:not([data-a="power"]) { opacity: 0.5; }
        .sheet { position: absolute; inset: 0; display: flex; flex-direction: column; align-items: center;
          justify-content: space-between; gap: 12px; padding: 16px;
          background: var(--ha-card-background, var(--card-background-color, #fff));
          opacity: 0; pointer-events: none; transform: translateY(8px); transition: opacity 0.2s, transform 0.2s; }
        .sheet.open { opacity: 1; pointer-events: auto; transform: none; }
        .title { color: var(--primary-text-color); font-weight: 500; }
        .disc { width: 100%; max-width: 240px; touch-action: none; user-select: none; }
        .face { fill: var(--off-color); }
        .reach { fill: var(--on-color); transition: d 0.25s ease; }
        .notch { stroke: var(--divider-color); stroke-width: 2; }
        .head-top, .heading { transform-box: view-box; transform-origin: ${C}px ${C}px; }
        .head-top { transition: transform 0.6s ease; }
        .head-top.dance { transition: none; animation: dance var(--dur) ease-in-out infinite alternate; }
        @keyframes dance { from { transform: rotate(var(--from)); } to { transform: rotate(var(--to)); } }
        .shell { fill: var(--ha-card-background, var(--card-background-color, #fff));
          stroke: var(--secondary-text-color); stroke-width: 2; }
        .lens { fill: var(--secondary-text-color); }
        .dots { stroke: var(--fan-color); stroke-width: 3; stroke-dasharray: 3 4; }
        .handle { fill: var(--ha-card-background, var(--card-background-color, #fff)); stroke: var(--fan-color);
          stroke-width: 4; cursor: grab; }
        .chips { display: flex; flex-wrap: wrap; justify-content: center; gap: 6px; max-width: 320px; }
        .chips button { border: 0; border-radius: 999px; padding: 8px 12px; min-width: 48px; font: inherit;
          cursor: pointer; background: var(--off-color); color: var(--primary-text-color); }
        .chips button.on { background: var(--on-color); color: var(--fan-color); font-weight: 500; }
        .done { border: 0; border-radius: 999px; padding: 10px 0; width: 60%; max-width: 200px; font: inherit;
          font-weight: 500; cursor: pointer; background: var(--primary-color); color: var(--text-primary-color, #fff); }
        .warn { color: var(--warning-color); font-size: 0.85em; text-align: center; }
      </style>
      <ha-card>
        <div class="head">
          <div class="badge"><ha-icon icon="mdi:fan"></ha-icon></div>
          <div class="who"><span class="name"></span><span class="state"></span></div>
        </div>
        <div class="controls">
          ${button("power", "mdi:power", "On/Off")}
          ${button("speed", "mdi:fan", "Airflow speed", true)}
          ${button("osc", "mdi:arrow-left-right", "Oscillation", true)}
          ${button("timer", "mdi:timer-outline", "Timer", true)}
          ${button("auto", "mdi:fan-auto", "Auto mode")}
          ${button("night", "mdi:weather-night", "Night mode")}
          ${button("direction", "mdi:swap-horizontal", "Airflow direction")}
        </div>
        <div class="warn"></div>
        ${sheet(
          "osc",
          "Oscillation",
          `<svg class="disc" viewBox="0 0 ${SIZE} ${SIZE}">
            <path class="face" /><path class="reach" /><line class="notch" />
            <g class="heading">
              <line class="dots" x1="${C}" y1="${C - 50}" x2="${C}" y2="${C - R + 14}" />
              <circle class="handle" cx="${C}" cy="${C - R}" r="15" />
            </g>
            <g class="head-top">
              <rect class="shell" x="${C - 30}" y="${C - 16}" width="60" height="50" rx="18" />
              <path class="shell" d="M ${C - 26} ${C - 16} L ${C - 13} ${C - 40} H ${C + 13} L ${C + 26} ${C - 16} Z" />
              <circle class="lens" cx="${C}" cy="${C - 35}" r="3" />
            </g>
          </svg>
          <div class="chips">${WIDTHS.map((w) => `<button data-w="${w}">${w ? `${w}°` : "Off"}</button>`).join("")}</div>`,
        )}
        ${sheet(
          "speed",
          "Airflow speed",
          `<div class="chips">${Array.from({ length: 10 }, (_, i) => `<button data-v="${i + 1}">${i + 1}</button>`).join("")}</div>`,
        )}
        ${sheet(
          "timer",
          "Sleep timer",
          `<div class="chips">${TIMERS.map((m) => `<button data-t="${m}">${m ? mins(m) : "Off"}</button>`).join("")}</div>`,
        )}
      </ha-card>`;

    const $ = (q) => root.querySelector(q);
    const $$ = (q) => [...root.querySelectorAll(q)];
    this._disc = $(".disc");
    const ctl = Object.fromEntries($$(".ctl").map((b) => [b.dataset.a, b]));
    this._el = {
      card: $("ha-card"),
      name: $(".name"),
      state: $(".state"),
      badge: $(".badge"),
      controls: $(".controls"),
      ctl,
      speed: ctl.speed.querySelector(".val"),
      osc: ctl.osc.querySelector(".val"),
      timer: ctl.timer.querySelector(".val"),
      warn: $(".warn"),
      sheets: Object.fromEntries($$(".sheet").map((s) => [s.dataset.s, s])),
      reach: $(".reach"),
      heading: $(".heading"),
      head: $(".head-top"),
      widths: $$("[data-w]"),
      speeds: $$("[data-v]"),
      timers: $$("[data-t]"),
    };

    $(".face").setAttribute("d", this._sector(MIN + 2, MAX - 2));
    const [nx, ny] = this._point(0, R + 18);
    const notch = $(".notch");
    notch.setAttribute("x1", C);
    notch.setAttribute("y1", C);
    notch.setAttribute("x2", nx);
    notch.setAttribute("y2", ny);

    $(".head").addEventListener("click", () =>
      this.dispatchEvent(
        new CustomEvent("hass-more-info", { bubbles: true, composed: true, detail: { entityId: this._config.entity } }),
      ),
    );
    for (const [a, b] of Object.entries(ctl)) b.addEventListener("click", () => this._press(a));
    for (const b of $$(".done")) b.addEventListener("click", () => this._open(null));
    for (const b of this._el.widths) b.addEventListener("click", () => this._setWidth(Number(b.dataset.w)));
    for (const b of this._el.speeds)
      b.addEventListener("click", () => this._call("fan", "set_percentage", { percentage: Number(b.dataset.v) * 10 }));
    for (const b of this._el.timers) b.addEventListener("click", () => this._setTimer(Number(b.dataset.t)));

    this._disc.addEventListener("pointerdown", (ev) => {
      this._drag = true;
      this._disc.setPointerCapture(ev.pointerId);
      this._steer(ev);
    });
    this._disc.addEventListener("pointermove", (ev) => this._drag && this._steer(ev));
    const release = (ev) => {
      if (!this._drag) return;
      this._drag = false;
      this._disc.releasePointerCapture?.(ev.pointerId);
      this._sendAngles();
    };
    this._disc.addEventListener("pointerup", release);
    this._disc.addEventListener("pointercancel", release);
  }

  _open(sheet) {
    this._sheet = sheet;
    this._render();
  }

  _press(action) {
    const s = this._stateObj;
    if (!s) return;
    const a = s.attributes;
    if (action === "power") this._call("fan", s.state === "on" ? "turn_off" : "turn_on");
    else if (action === "speed" || action === "osc" || action === "timer") this._open(action);
    else if (action === "auto")
      this._call("fan", "set_preset_mode", { preset_mode: a.preset_mode === "Auto" ? "Normal" : "Auto" });
    else if (action === "direction")
      this._call("fan", "set_direction", { direction: a.direction === "forward" ? "reverse" : "forward" });
    else if (action === "night" && this._nightMode)
      this._hass.callService("switch", "toggle", { entity_id: this._nightMode });
  }

  _steer(ev) {
    const centre = Math.round(this._angleAt(ev));
    [this._lo, this._hi] = this._aim(centre, this._hi - this._lo);
    this._render();
  }

  _setWidth(width) {
    [this._lo, this._hi] = this._aim((this._lo + this._hi) / 2, width);
    this._sendAngles();
    this._render();
  }

  _sendAngles() {
    this._holdUntil = Date.now() + HOLD_MS;
    this._call("dyson_local", "set_angle", { angle_low: this._lo, angle_high: this._hi });
  }

  _setTimer(minutes) {
    this._call("dyson_local", "set_timer", { timer: minutes });
    if (minutes) localStorage.setItem(this._timerKey, String(Date.now() + minutes * 60000));
    else localStorage.removeItem(this._timerKey);
    this._render();
  }

  _render() {
    if (!this._el || !this._hass) return;
    const s = this._stateObj;
    const el = this._el;
    el.name.textContent = this._config.name ?? s?.attributes.friendly_name ?? this._config.entity;
    if (!s || s.state === "unavailable") {
      el.state.textContent = "Unavailable";
      el.warn.textContent = "Can't reach the fan";
      el.controls.classList.add("dim");
      return;
    }
    const a = s.attributes;
    const on = s.state === "on";
    const auto = a.preset_mode === "Auto";
    const speed = Math.round((a.percentage || 0) / 10);
    const width = this._hi - this._lo;
    const left = this._timerLeft;
    const night = this._nightMode && this._hass.states[this._nightMode];

    el.warn.textContent = "";
    el.card.classList.toggle("on", on);
    el.controls.classList.toggle("dim", !on);
    el.badge.style.setProperty("--spin", `${(3 - speed * 0.25).toFixed(2)}s`);
    el.state.textContent = on
      ? [auto ? "Auto" : `Speed ${speed}`, width ? `${width}°` : null].filter(Boolean).join(" · ")
      : "Off";

    el.speed.textContent = auto ? "A" : speed || "–";
    el.osc.textContent = width ? `${width}°` : "Off";
    el.timer.textContent = left ? mins(left) : "Off";
    el.ctl.power.classList.toggle("on", on);
    el.ctl.speed.classList.toggle("on", on);
    el.ctl.osc.classList.toggle("on", width > 0);
    el.ctl.timer.classList.toggle("on", left > 0);
    el.ctl.auto.classList.toggle("on", auto);
    el.ctl.night.classList.toggle("on", night?.state === "on");
    el.ctl.night.classList.toggle("na", !night);
    el.ctl.direction.classList.toggle("on", a.direction === "forward");

    for (const [name, sheet] of Object.entries(el.sheets)) sheet.classList.toggle("open", this._sheet === name);
    for (const b of el.widths) b.classList.toggle("on", Number(b.dataset.w) === width);
    for (const b of el.speeds) b.classList.toggle("on", !auto && Number(b.dataset.v) === speed);
    for (const b of el.timers) b.classList.toggle("on", Number(b.dataset.t) === 0 && !left);

    const centre = (this._lo + this._hi) / 2;
    el.reach.setAttribute("d", width ? this._sector(this._lo, this._hi, R - 2) : "");
    el.heading.style.transform = `rotate(${this._toScreen(centre)}deg)`;
    const dancing = width > 0 && on && !this._drag;
    el.head.classList.toggle("dance", dancing);
    if (dancing) {
      el.head.style.transform = "";
      el.head.style.setProperty("--from", `${this._toScreen(this._lo)}deg`);
      el.head.style.setProperty("--to", `${this._toScreen(this._hi)}deg`);
      el.head.style.setProperty("--dur", `${Math.max(1.5, width / 40)}s`);
    } else {
      el.head.style.transform = `rotate(${this._toScreen(centre)}deg)`;
    }
  }
}

customElements.define("dyson-fan-card", DysonFanCard);

window.customCards = window.customCards || [];
window.customCards.push({
  type: "dyson-fan-card",
  name: "Dyson fan",
  description: "The Dyson app's controls and oscillation dial, in your dashboard's theme.",
});
