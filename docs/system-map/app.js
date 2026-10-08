/* app.js — turns the authored grid in data.js into two clickable SVG models.
   No libraries. Layout is not computed: every node already carries its cell. */

const SVGNS = "http://www.w3.org/2000/svg";
const el = (n, a) => { const e = document.createElementNS(SVGNS, n); for (const k in a) e.setAttribute(k, a[k]); return e; };

const TOP = 54;            // space above row 1, for the first band label
const LINE = 15;           // text line height
const PAD_X = 11;

/* ---- text wrapping. Break on spaces and on - _ · / so a long slug still fits. */
function tokens(s) {
  const out = []; let cur = "";
  for (const ch of s) {
    cur += ch;
    if (ch === " " || ch === "-" || ch === "_" || ch === "·" || ch === "/") { out.push(cur); cur = ""; }
  }
  if (cur) out.push(cur);
  return out;
}
function wrap(s, maxPx, px) {
  const per = px * 0.545;                       // measured against Plus Jakarta Sans
  const max = Math.max(6, Math.floor(maxPx / per));
  const lines = []; let line = "";
  for (const t of tokens(s)) {
    if ((line + t).trimEnd().length > max && line) { lines.push(line.trimEnd()); line = t; }
    else line += t;
  }
  if (line.trim()) lines.push(line.trimEnd());
  return lines;
}

/* ---- geometry ---- */
function geom(model) {
  const g = new Map();
  const rowH = model.rowH;
  for (const n of model.nodes) {
    const col = model.cols[n.c];
    const span = n.h || 1;
    const x = col.x, w = col.w;
    const y = TOP + (n.r - 1) * rowH;
    const h = span === 1 ? rowH - 30 : span * rowH - 30;
    g.set(n.id, { x, y, w, h, x2: x + w, y2: y + h, cy: y + h / 2, node: n });
  }
  return g;
}

/* ---- edge routing. Edges draw first, so a crossing passes behind a box. ---- */
function route(a, b, i) {
  const j = (i % 4) * 7 - 10;
  if (a.node.c === b.node.c) {                                  // same column: a bracket on the left
    const x = a.x - 24 - (i % 3) * 6;
    return [[a.x, a.cy], [x, a.cy], [x, b.cy], [b.x, b.cy]];
  }
  if (b.x > a.x2) {                                             // forward
    const mid = Math.min(b.x - 22 - j, a.x2 + (b.x - a.x2) * 0.72);
    return a.cy === b.cy ? [[a.x2, a.cy], [b.x, b.cy]]
                         : [[a.x2, a.cy], [mid, a.cy], [mid, b.cy], [b.x, b.cy]];
  }
  const mid = b.x2 + 26 + (i % 3) * 7;                          // backward: enter from the right
  return a.cy === b.cy ? [[a.x, a.cy], [b.x2, b.cy]]
                       : [[a.x, a.cy], [mid, a.cy], [mid, b.cy], [b.x2, b.cy]];
}

function render(key, model, host) {
  const G = geom(model);
  const maxRow = Math.max(...model.nodes.map(n => n.r + (n.h || 1) - 1));
  const W = model.cols[model.cols.length - 1].x + model.cols[model.cols.length - 1].w + 18;
  const H = TOP + maxRow * model.rowH + 24;

  const svg = el("svg", { viewBox: `0 0 ${W} ${H}`, width: W, height: H, role: "img",
    "aria-label": model.title + " — " + model.nodes.length + " parts of the GoalDigger system, each clickable for its explanation" });
  svg.classList.add("model");

  const defs = el("defs");
  for (const [id, cls] of [["ar", "a-flow"], ["ar-r", "a-read"], ["ar-d", "a-dead"], ["ar-t", "a-tree"]]) {
    const m = el("marker", { id: key + "-" + id, viewBox: "0 0 10 10", refX: "9", refY: "5",
      markerWidth: "6", markerHeight: "6", orient: "auto-start-reverse" });
    const p = el("path", { d: "M 0 1 L 9 5 L 0 9 z" }); p.setAttribute("class", cls);
    m.appendChild(p); defs.appendChild(m);
  }
  svg.appendChild(defs);

  /* bands */
  const gb = el("g", { class: "bands" });
  for (const b of model.bands) {
    const y = TOP + (b.from - 1) * model.rowH - 34;
    const y2 = TOP + (b.to) * model.rowH - 34;
    gb.appendChild(el("rect", { x: -8, y, width: W - 2, height: y2 - y, rx: 14, class: "band" }));
    const t = el("text", { x: 2, y: y + 21, class: "bandlabel" }); t.textContent = b.label;
    gb.appendChild(t);
  }
  svg.appendChild(gb);

  /* edges */
  const ge = el("g", { class: "edges" });

  /* Edge labels used to sit at the midpoint of the run leaving the source and
     stack upwards per source. Both parts were wrong: a midpoint lands on top of
     whatever box happens to be in the way ("7 national + per-club" printed
     straight across the RSS feeds box), and stacking moved a label off its own
     line and onto someone else's.
     So: find a span on the edge that is genuinely clear of every box AND of
     every label already placed, and put it there. If nothing fits, drop it —
     the panel carries the same words, and an unreadable label is worse than
     none. */
  const boxes = [...G.values()].map(g => ({ x1: g.x, x2: g.x2, y1: g.y, y2: g.y2 }));
  const placed = [];
  const LH = 11;                                  // half the vertical room a label needs

  /* A label is allowed to overhang its own run by up to OVER px, because the
     common case is a 60px gutter carrying a 170px label — searching only
     between the two boxes dropped a third of all labels. Among the spans that
     fit, take the one centred nearest the run, so the label stays next to the
     line it belongs to rather than wherever there happened to be room. */
  const OVER = 150;
  function freeSpan(y, from, to, needW) {
    const mid = (from + to) / 2;
    const lo = Math.max(0, Math.min(from, to) - OVER);
    const hi = Math.min(W, Math.max(from, to) + OVER);
    const blocked = [];
    for (const r of boxes.concat(placed))
      if (y + LH > r.y1 && y - LH < r.y2 && r.x2 > lo && r.x1 < hi)
        blocked.push([Math.max(r.x1 - 4, lo), Math.min(r.x2 + 4, hi)]);
    blocked.sort((p, q) => p[0] - q[0]);
    let cursor = lo, best = null, bestD = Infinity;
    for (const [bx1, bx2] of blocked.concat([[hi, hi]])) {
      if (bx1 - cursor >= needW) {
        // clamp the label's centre into this span, then score by distance to mid
        const c = Math.max(cursor + needW / 2, Math.min(bx1 - needW / 2, mid));
        const d = Math.abs(c - mid);
        if (d < bestD) { bestD = d; best = [c - needW / 2, c + needW / 2]; }
      }
      cursor = Math.max(cursor, bx2);
    }
    return best;
  }

  model.edges.forEach((e, i) => {
    const a = G.get(e.from), b = G.get(e.to);
    if (!a || !b) return;
    const pts = route(a, b, i);
    const cls = "e-" + e.kind;
    const mk = { flow: "ar", read: "ar-r", dead: "ar-d", tree: "ar-t" }[e.kind] || "ar";
    const pl = el("polyline", { points: pts.map(p => p.join(",")).join(" "), class: "edge " + cls,
      "marker-end": `url(#${key}-${mk})` });
    pl.dataset.from = e.from; pl.dataset.to = e.to;
    ge.appendChild(pl);
    if (!e.label) return;

    const needW = e.label.length * 5.8 + 10;
    let spot = null;
    outer:
    for (const [p0, p1] of pts.slice(0, -1).map((p, n) => [p, pts[n + 1]])) {
      if (p0[1] !== p1[1]) continue;              // horizontal runs only
      // Just above the line first, then the clear band between two rows —
      // boxes are rowH-30 tall, so there is always a gap of 30 there and it is
      // where a long label actually fits. Searching only near the line dropped
      // 26 of 67 labels.
      const gap = model.rowH / 2 + 2;
      for (const dy of [-10, -22, 10, 22, -34, -gap, gap, -gap - 11, gap + 11]) {
        const span = freeSpan(p0[1] + dy, p0[0], p1[0], needW);
        if (span) { spot = { x: (span[0] + span[1]) / 2, y: p0[1] + dy, w: needW }; break outer; }
      }
    }
    if (!spot) return;
    placed.push({ x1: spot.x - needW / 2, x2: spot.x + needW / 2, y1: spot.y - LH, y2: spot.y + LH });
    const t = el("text", { x: spot.x, y: spot.y, class: "elabel " + cls });
    t.textContent = e.label;
    ge.appendChild(t);
  });
  svg.appendChild(ge);

  /* nodes */
  const gn = el("g", { class: "nodes" });
  for (const n of model.nodes) {
    const b = G.get(n.id);
    const g = el("g", { class: "node k-" + n.k + " s-" + n.s, tabindex: "0", role: "button",
      "aria-label": n.l + ". " + (n.sub || "") });
    g.dataset.id = n.id; g.dataset.model = key;
    g.appendChild(el("rect", { x: b.x, y: b.y, width: b.w, height: b.h, rx: 10, class: "box" }));

    const inner = b.w - PAD_X * 2;
    const span = n.h || 1;
    const lab = wrap(n.l, inner, 12.5).slice(0, 2);
    const sub = n.sub ? wrap(n.sub, inner, 10.5).slice(0, 2) : [];
    const total = lab.length * LINE + (sub.length ? sub.length * 13 + 2 : 0);
    /* a spine taller than ~6 rows repeats its caption, so it never reads as two stray lines */
    const step = 760, reps = span > 6 ? Math.max(1, Math.floor(b.h / step)) : 1;
    const top = span > 2 ? b.y + 24 : b.y + (b.h - total) / 2 + 12;
    for (let k = 0; k < reps; k++) {
      let y = top + k * (b.h - total - 24) / Math.max(1, reps - 1 || 1);
      if (reps === 1) y = top;
      for (const l of lab) {
        const t = el("text", { x: b.x + PAD_X, y, class: "nl" }); t.textContent = l; g.appendChild(t); y += LINE;
      }
      y += 2;
      for (const s2 of sub) {
        const t = el("text", { x: b.x + PAD_X, y, class: "ns" }); t.textContent = s2; g.appendChild(t); y += 13;
      }
    }
    if (n.s !== "live" && n.s !== "external") {
      const t = el("text", { x: b.x + b.w - PAD_X, y: b.y + 15, class: "badge" , "text-anchor": "end" });
      t.textContent = n.s.toUpperCase(); g.appendChild(t);
    }
    gn.appendChild(g);
  }
  svg.appendChild(gn);
  host.appendChild(svg);
  return G;
}

/* ---- index of every node, for the panel and cross-links ---- */
const ALL = new Map();
for (const key of Object.keys(MODELS)) for (const n of MODELS[key].nodes) ALL.set(n.id, { n, model: key });

/* M1 -> M2: a shared file path is the link. M2 -> M1 is declared as x[]. */
function related(id) {
  const rec = ALL.get(id); if (!rec) return [];
  const out = new Set((rec.n.p.x || []).filter(i => ALL.has(i)));
  for (const key of Object.keys(MODELS)) {                  // anything that names me, in any model
    if (key === rec.model) continue;
    for (const m of MODELS[key].nodes) if ((m.p.x || []).includes(id)) out.add(m.id);
  }
  if (rec.model === "m1") {
    const mine = (rec.n.p.f || []).filter(f => f && f !== "— none");
    const loose = [];
    for (const m of MODELS.m2.nodes) {
      if ((m.p.f || []).some(f => mine.includes(f))) out.add(m.id);
      else if ((m.p.f || []).some(f => mine.some(x => x.startsWith(f) || f.startsWith(x)))) loose.push(m.id);
    }
    if (!out.size) loose.forEach(l => out.add(l));          // a directory match only when nothing exact hits
  }
  out.delete(id);
  return [...out];
}


/* ---- what breaks if this stops ----
   The edges are already a dependency graph, so the day-three question — "what
   goes if I touch this?" — is a traversal, not a new data structure. Downstream
   is what stops producing; upstream is what has to be working for this to run.
   Stores and surfaces are included on purpose: the honest answer to "what breaks"
   is usually a screen, not a function. */
function reach(id, dir) {
  const m = ALL.get(id); if (!m) return [];
  const edges = MODELS[m.model].edges;
  const seen = new Set([id]), order = [], queue = [id];
  while (queue.length) {
    const cur = queue.shift();
    for (const e of edges) {
      if (e.kind === "read") continue;                 // a read is not a dependency
      const [from, to] = dir === "down" ? [e.from, e.to] : [e.to, e.from];
      if (from !== cur || seen.has(to)) continue;
      seen.add(to); order.push(to); queue.push(to);
    }
  }
  return order;
}

function blastHtml(id) {
  // Only model 1 is a dependency graph. The others are tables with one arrow
  // per row, where "0 things stop with it" is noise rather than an answer.
  if (ALL.get(id)?.model !== "m1") return "";
  const down = reach(id, "down"), up = reach(id, "up");
  if (!down.length) return "";
  const chips = ids => ids.slice(0, 14).map(i =>
    `<button class="chip" data-go="${i}">${esc(ALL.get(i).n.l)}</button>`).join("") +
    (ids.length > 14 ? ` <span class="more">+${ids.length - 14} more</span>` : "");
  const surfaces = down.filter(i => ["surface", "device"].includes(ALL.get(i).n.k));
  return `<details class="blast"><summary>If this stops: ${down.length} things stop with it${
      surfaces.length ? `, including ${surfaces.length} she can see` : ""}</summary>
    ${down.length ? `<div class="prow"><div class="pk">Stops too</div><div class="pv chips">${chips(down)}</div></div>` : ""}
    ${up.length ? `<div class="prow"><div class="pk">Needs</div><div class="pv chips">${chips(up)}</div></div>` : ""}
  </details>`;
}

/* ---- the panel ---- */
const panel = document.getElementById("panel");
const pbody = document.getElementById("pbody");
let current = null;

const STATUS = { live:"live", dormant:"dormant — reachable by nothing", paused:"paused", stale:"stale",
                 unheard:"runs, and reaches nobody", external:"upstream, not ours" };

function row(label, value) {
  if (!value || value === "—") return "";
  return `<div class="prow"><div class="pk">${label}</div><div class="pv">${value}</div></div>`;
}
function esc(s) { return String(s).replace(/[&<>]/g, c => ({ "&":"&amp;","<":"&lt;",">":"&gt;" }[c])); }

function open(id, push) {
  const rec = ALL.get(id); if (!rec) return;
  const n = rec.n, p = n.p;
  document.querySelectorAll(".node.sel").forEach(e => e.classList.remove("sel"));
  document.querySelectorAll(`.node[data-id="${CSS.escape(id)}"]`).forEach(e => e.classList.add("sel"));
  document.querySelectorAll(".edge").forEach(e =>
    e.classList.toggle("lit", e.dataset.from === id || e.dataset.to === id));

  const rel = related(id).map(r =>
    `<button class="chip" data-go="${r}">${esc(ALL.get(r).n.l)}</button>`).join("");
  const files = (p.f || []).filter(f => f && f !== "— none")
    .map(f => `<code>${esc(f)}</code>`).join("<br>");

  const plain = (typeof PLAIN !== "undefined" && PLAIN[id]) || "";
  pbody.innerHTML = `
    <div class="ptags"><span class="tag k-${n.k}">${esc(KIND[n.k] || n.k)}</span>
      <span class="tag st-${n.s}">${esc(STATUS[n.s] || n.s)}</span></div>
    <h3>${esc(n.l)}</h3>
    ${n.sub ? `<p class="psub">${esc(n.sub)}</p>` : ""}
    <div class="plain"><b>In plain words</b><p>${esc(plain || p.w)}</p></div>
    ${plain ? `<p class="pwhat">${esc(p.w)}</p>` : ""}
    ${row("When", esc(p.t))}
    ${row("Reads", esc(p.rd))}
    ${row("Writes", esc(p.wr))}
    ${row("Files", files)}
    ${row("Watch out", esc(p.g))}
    ${rel ? `<div class="prow"><div class="pk">See also</div><div class="pv chips">${rel}</div></div>` : ""}
    ${blastHtml(id)}
  `;
  panel.classList.add("on");
  document.body.classList.add("panelled");
  current = id;
  if (push !== false) history.replaceState(null, "", "#node=" + id);
}

function close() {
  panel.classList.remove("on");
  document.body.classList.remove("panelled");
  document.querySelectorAll(".node.sel").forEach(e => e.classList.remove("sel"));
  document.querySelectorAll(".edge.lit").forEach(e => e.classList.remove("lit"));
  current = null;
  history.replaceState(null, "", location.pathname + location.search);
}

/* ---- boot ---- */
for (const key of Object.keys(MODELS)) {
  const host = document.getElementById("fig-" + key);
  if (host) render(key, MODELS[key], host);
}

document.addEventListener("click", ev => {
  const go = ev.target.closest("[data-go]");
  if (go) { const id = go.dataset.go; open(id);
    document.querySelector(`.node[data-id="${CSS.escape(id)}"]`)
      ?.scrollIntoView({ block: "center", inline: "center", behavior: "smooth" }); return; }
  const node = ev.target.closest(".node");
  if (node) { open(node.dataset.id); return; }
  if (ev.target.closest("#pclose")) close();
});
document.addEventListener("keydown", ev => {
  if (ev.key === "Escape") close();
  if (ev.key === "Enter" || ev.key === " ") {
    const n = document.activeElement?.closest?.(".node");
    if (n) { ev.preventDefault(); open(n.dataset.id); }
  }
});

/* A handover link can point straight at a box: #node=match-watcher. Also listen
   for later hash changes, because a same-page hash does not reload the script. */
function fromHash(scroll) {
  if (!location.hash.startsWith("#node=")) return;
  const id = decodeURIComponent(location.hash.slice(6));
  if (!ALL.has(id)) return;
  open(id, false);
  if (scroll) document.querySelector(`.node[data-id="${CSS.escape(id)}"]`)
    ?.scrollIntoView({ block: "center", inline: "center" });
}
fromHash(true);
addEventListener("hashchange", () => fromHash(true));


/* ---- the verifiable half, generated by scripts/arch-facts.sh ----
   Every number in the masthead is read from facts.json rather than typed here.
   scripts/verify-arch-map.sh fails when that file and the system disagree. */
fetch("facts.json").then(r => r.ok ? r.json() : null).then(f => {
  if (!f) return;
  window.__facts = f;
  for (const el of document.querySelectorAll("[data-fact]")) {
    const v = f.counts[el.dataset.fact];
    if (v !== undefined) el.textContent = v;
  }
  const bc = document.getElementById("boxcount");
  if (bc) bc.textContent = ALL.size;
  const stamp = document.getElementById("factstamp");
  if (stamp) stamp.textContent = "counts generated from the live system on " + f.generatedAt.slice(0, 10) +
    (f.db ? "" : " (without a database — the live half is missing)");
}).catch(() => {});

/* ---- the runnable check: ?check=1 ---- */
if (new URLSearchParams(location.search).get("check")) {
  const fail = [];
  const seen = new Set();
  for (const key of Object.keys(MODELS)) {
    const m = MODELS[key];
    const cells = new Map();
    for (const n of m.nodes) {
      if (seen.has(n.id)) fail.push(`duplicate id ${n.id}`); seen.add(n.id);
      if (!n.p || !n.p.w) fail.push(`${n.id}: no panel text`);
      if (typeof PLAIN !== "undefined" && !PLAIN[n.id] && !(n.p && n.p.w))
        fail.push(`${n.id}: nothing to show a non-technical reader`);
      if (!STATUS[n.s]) fail.push(`${n.id}: unknown status ${n.s}`);
      if (!KIND[n.k]) fail.push(`${n.id}: unknown kind ${n.k}`);
      for (let i = 0; i < (n.h || 1); i++) {
        const cell = n.c + ":" + (n.r + i);
        if (cells.has(cell)) fail.push(`${n.id} overlaps ${cells.get(cell)} at col ${n.c} row ${n.r + i}`);
        cells.set(cell, n.id);
      }
      const band = m.bands.find(b => n.r >= b.from && n.r <= b.to);
      if (!band) fail.push(`${n.id}: row ${n.r} is outside every band`);
      for (const x of (n.p.x || [])) if (!ALL.has(x)) fail.push(`${n.id}: cross-link ${x} does not exist`);
    }
    for (const e of m.edges) {
      if (!m.nodes.some(n => n.id === e.from)) fail.push(`edge from ${e.from} -> ${e.to}: no such source`);
      if (!m.nodes.some(n => n.id === e.to)) fail.push(`edge from ${e.from} -> ${e.to}: no such target`);
    }
  }
  for (const n of MODELS.m1.nodes) if (!related(n.id).length && n.k !== "surface" && n.k !== "device")
    fail.push(`NOTE ${n.id}: no link into model 2`);
  for (const n of MODELS.m1.nodes) if (typeof PLAIN !== "undefined" && !PLAIN[n.id])
    fail.push(`NOTE ${n.id}: no hand-written plain-English line`);
  for (const n of MODELS.m2.nodes) if (typeof PLAIN !== "undefined" && !PLAIN[n.id])
    fail.push(`NOTE ${n.id}: no hand-written plain-English line`);

  /* Edge labels printed over boxes once, and the only way to see it was to look.
     Measure it instead: every drawn label against every box, and against every
     other label. Also count what was dropped — a placer that silently hides
     half the labels passes an overlap test and fails the reader. */
  let drawn = 0, wanted = 0, collide = 0;
  for (const key of Object.keys(MODELS)) {
    wanted += MODELS[key].edges.filter(e => e.label).length;
    const svg = document.querySelector("#fig-" + key + " svg");
    if (!svg) continue;
    const rects = [...svg.querySelectorAll(".node .box")].map(r => ({
      x1: +r.getAttribute("x"), y1: +r.getAttribute("y"),
      x2: +r.getAttribute("x") + +r.getAttribute("width"),
      y2: +r.getAttribute("y") + +r.getAttribute("height") }));
    const labels = [...svg.querySelectorAll(".elabel")];
    drawn += labels.length;
    const hit = (a, b) => a.x + a.width > b.x1 + 2 && a.x < b.x2 - 2 && a.y + a.height > b.y1 + 2 && a.y < b.y2 - 2;
    labels.forEach((t, i) => {
      const b = t.getBBox();
      if (rects.some(r => hit(b, r))) { fail.push(`label "${t.textContent}" sits on a box in ${key}`); collide++; }
      for (let j = i + 1; j < labels.length; j++) {
        const o = labels[j].getBBox();
        if (b.x + b.width > o.x && b.x < o.x + o.width && b.y + b.height > o.y && b.y < o.y + o.height) {
          fail.push(`labels overlap in ${key}: "${t.textContent}" and "${labels[j].textContent}"`); collide++;
        }
      }
    });
  }
  if (!collide) fail.push(`NOTE all ${drawn} edge labels are clear of every box and of each other`);
  if (drawn < wanted) fail.push(`NOTE ${wanted - drawn} edge label(s) had nowhere clear to go and were dropped`);
  const hard = fail.filter(f => !f.startsWith("NOTE"));
  console.log(hard.length ? "CHECK FAILED\n" + fail.join("\n") : "CHECK OK — " + ALL.size + " nodes, " +
    (MODELS.m1.edges.length + MODELS.m2.edges.length) + " edges, all resolve." +
    (fail.length ? "\n" + fail.join("\n") : ""));
  window.__check = { ok: !hard.length, fail };
}
