const vars = JSON.parse(await Bun.file("/tmp/linear-re/slack-vars.json").text());
const M = {
  crust:[17,17,27], mantle:[24,24,37], base:[30,30,46], surface0:[49,50,68],
  surface1:[69,71,90], surface2:[88,91,112], overlay0:[108,112,134], overlay1:[127,132,156],
  overlay2:[147,153,178], subtext0:[166,173,200], subtext1:[186,194,222], text:[205,214,244],
  red:[243,139,168], peach:[250,179,135], yellow:[249,226,175], green:[166,227,161],
  teal:[148,226,213], sky:[137,220,235], sapphire:[116,199,236], blue:[137,180,250],
  lavender:[180,190,254], mauve:[203,166,247], pink:[245,194,231],
};
const rgb2hsl = (r,g,b) => {
  r/=255; g/=255; b/=255;
  const mx=Math.max(r,g,b), mn=Math.min(r,g,b), l=(mx+mn)/2;
  if (mx===mn) return [0,0,l];
  const d=mx-mn, s=l>0.5? d/(2-mx-mn) : d/(mx+mn);
  let h = mx===r ? (g-b)/d+(g<b?6:0) : mx===g ? (b-r)/d+2 : (r-g)/d+4;
  return [h*60, s, l];
};
const hsl2rgb = (h,s,l) => {
  h/=360;
  if (s===0) { const v=Math.round(l*255); return [v,v,v]; }
  const q = l<0.5 ? l*(1+s) : l+s-l*s, p = 2*l-q;
  const f = t => { t=(t%1+1)%1;
    if (t<1/6) return p+(q-p)*6*t;
    if (t<1/2) return q;
    if (t<2/3) return p+(q-p)*(2/3-t)*6;
    return p; };
  return [f(h+1/3), f(h), f(h-1/3)].map(x=>Math.round(x*255));
};
const neutralByL = l =>
  l<0.075?M.crust : l<0.11?M.mantle : l<0.16?M.base : l<0.24?M.surface0 : l<0.33?M.surface1 :
  l<0.43?M.surface2 : l<0.52?M.overlay0 : l<0.61?M.overlay1 : l<0.70?M.overlay2 :
  l<0.79?M.subtext0 : l<0.88?M.subtext1 : M.text;
const accentFor = h =>
  h<10||h>=345 ? M.red : h<40 ? M.peach : h<66 ? M.yellow : h<150 ? M.green :
  h<185 ? M.teal : h<205 ? M.sky : h<222 ? M.sapphire : h<252 ? M.blue :
  h<275 ? M.lavender : h<315 ? M.mauve : M.pink;
const mapRGB = (r,g,b) => {
  const [h,s,l] = rgb2hsl(r,g,b);
  if (s < 0.13) return neutralByL(l);
  const acc = accentFor(h);
  const [ah,as] = rgb2hsl(...acc);
  // Keep the accent's hue/saturation but the source's lightness, so dark
  // chrome stays dark and pastel accents stay pastel.
  return hsl2rgb(ah, as, l);
};
const out = [];
for (const [k, raw] of Object.entries(vars)) {
  if (k.startsWith("--dt_color-constants-")) continue;
  const v = raw.trim();
  let m;
  if ((m = v.match(/^(\d{1,3}),\s*(\d{1,3}),\s*(\d{1,3})$/))) {
    const [r,g,b] = mapRGB(+m[1],+m[2],+m[3]);
    out.push(`  ${k}: ${r}, ${g}, ${b} !important;`);
  } else if ((m = v.match(/^rgba?\((\d{1,3}),\s*(\d{1,3}),\s*(\d{1,3})(?:,\s*([\d.]+))?\)$/))) {
    const [r,g,b] = mapRGB(+m[1],+m[2],+m[3]);
    out.push(`  ${k}: rgba(${r}, ${g}, ${b}, ${m[4] !== undefined ? m[4] : "1"}) !important;`);
  } else if ((m = v.match(/^#([0-9a-f]{6})([0-9a-f]{2})?$/i))) {
    const n = parseInt(m[1],16);
    const [r,g,b] = mapRGB(n>>16, (n>>8)&255, n&255);
    out.push(`  ${k}: #${[r,g,b].map(x=>x.toString(16).padStart(2,"0")).join("")}${m[2]||""} !important;`);
  } else if ((m = v.match(/^#([0-9a-f]{3})$/i))) {
    const [r,g,b] = mapRGB(...m[1].split("").map(c=>parseInt(c+c,16)));
    out.push(`  ${k}: #${[r,g,b].map(x=>x.toString(16).padStart(2,"0")).join("")} !important;`);
  }
}
await Bun.write("/tmp/linear-re/slack-theme.css", `:root, body {\n${out.join("\n")}\n}\n`);
console.log("generated", out.length, "overrides");
