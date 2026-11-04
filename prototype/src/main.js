import * as THREE from 'three';
import { SKILLS, STUDENTS, TEACHER, ENEMY_TYPES, ITEMS, RECIPES, CLUES } from './data.js';

const $ = (id) => document.getElementById(id);
const clamp = (v, a, b) => Math.max(a, Math.min(b, v));
const rand = (a, b) => a + Math.random() * (b - a);
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

function h(tag, props = {}, ...kids) {
  const el = document.createElement(tag);
  for (const [k, v] of Object.entries(props)) {
    if (k === 'class') el.className = v;
    else if (k.startsWith('on')) el.addEventListener(k.slice(2), v);
    else el.setAttribute(k, v);
  }
  for (const kid of kids.flat()) if (kid != null) el.append(kid);
  return el;
}

/* ------------------------------------------------------------------ state */
const MAX_PARTY = 3;
const BOUND_X = 29.5, BOUND_Z = 19.5;
const FENCE_X = 16;
const CLASSROOM_MAX_X = -15.5;

const game = {
  mode: 'ui', // ui | explore | combat
  inv: { scrap: 0, cloth: 0, bandage: 1, medkit: 0, energy: 0 },
  clues: [],
  crafted: {},
  fenceCleared: false,
  teacher: null,
  roster: [],
  party: [],
  finished: false,
};
window.__game = game;

function makeMember(def) {
  return { ...def, level: 1, xp: 0, maxHp: def.hp, skills: [...def.skills], cd: {}, buff: null, defending: false, mesh: null };
}
const defOf = (m) => m.def;
const atkOf = (m) => m.atk * (m.buff ? m.buff.mult : 1);

/* --------------------------------------------------------------- renderer */
const renderer = new THREE.WebGLRenderer({ antialias: true });
renderer.setPixelRatio(Math.min(devicePixelRatio, 2));
renderer.shadowMap.enabled = true;
$('game').appendChild(renderer.domElement);

const world = new THREE.Scene();
world.background = new THREE.Color(0x10151f);
world.fog = new THREE.Fog(0x10151f, 35, 75);
const topCam = new THREE.PerspectiveCamera(42, 1, 0.1, 200);

const cScene = new THREE.Scene();
cScene.background = new THREE.Color(0x05060a);
cScene.fog = new THREE.Fog(0x05060a, 5, 24);
const cCam = new THREE.PerspectiveCamera(70, 1, 0.1, 100);

function resize() {
  renderer.setSize(innerWidth, innerHeight);
  for (const c of [topCam, cCam]) { c.aspect = innerWidth / innerHeight; c.updateProjectionMatrix(); }
}
addEventListener('resize', resize);
resize();

/* ------------------------------------------------------------ world build */
const colliders = [];
const tables = [];
const itemNodes = [];
const exploreEnemies = [];

function addBox(x, z, w, d, hgt, color, { collide = true, y = 0, emissive = 0 } = {}) {
  const mesh = new THREE.Mesh(
    new THREE.BoxGeometry(w, hgt, d),
    new THREE.MeshStandardMaterial({ color, roughness: 0.9, emissive, emissiveIntensity: emissive ? 0.6 : 0 }),
  );
  mesh.position.set(x, y + hgt / 2, z);
  mesh.castShadow = mesh.receiveShadow = true;
  world.add(mesh);
  let col = null;
  if (collide) {
    col = { minX: x - w / 2, maxX: x + w / 2, minZ: z - d / 2, maxZ: z + d / 2 };
    colliders.push(col);
  }
  return { mesh, col };
}

function buildWorld() {
  world.add(new THREE.HemisphereLight(0x9bb4ff, 0x2a2118, 0.7));
  const sun = new THREE.DirectionalLight(0xfff0d0, 1.1);
  sun.position.set(-18, 40, 14);
  sun.castShadow = true;
  sun.shadow.mapSize.set(2048, 2048);
  Object.assign(sun.shadow.camera, { left: -45, right: 45, top: 30, bottom: -30, near: 1, far: 120 });
  world.add(sun);

  const ground = new THREE.Mesh(new THREE.PlaneGeometry(80, 56), new THREE.MeshStandardMaterial({ color: 0x2b3a2e, roughness: 1 }));
  ground.rotation.x = -Math.PI / 2;
  ground.receiveShadow = true;
  world.add(ground);
  const paths = new THREE.Mesh(new THREE.PlaneGeometry(40, 5), new THREE.MeshStandardMaterial({ color: 0x4a4a50, roughness: 1 }));
  paths.rotation.x = -Math.PI / 2; paths.position.set(-2, 0.02, 0); paths.receiveShadow = true;
  world.add(paths);

  // Classroom (home base)
  const floor = new THREE.Mesh(new THREE.PlaneGeometry(12, 16), new THREE.MeshStandardMaterial({ color: 0x8a7a5a, roughness: 1 }));
  floor.rotation.x = -Math.PI / 2; floor.position.set(-22, 0.03, 0); floor.receiveShadow = true;
  world.add(floor);
  const wallC = 0xc9c2b0;
  addBox(-22, -8, 12.6, 0.6, 3, wallC);
  addBox(-22, 8, 12.6, 0.6, 3, wallC);
  addBox(-28, 0, 0.6, 16.6, 3, wallC);
  addBox(-16, -5, 0.6, 6, 3, wallC);
  addBox(-16, 5, 0.6, 6, 3, wallC);
  for (const [x, z] of [[-26, 3.5], [-23, 3.5], [-20, 3.5], [-26, 6], [-23, 6], [-20, 6]]) addBox(x, z, 2, 1, 0.8, 0x7a5a3a);
  addBox(-20, -7.5, 4, 0.3, 2, 0xf4f4f4, { collide: false, y: 0.6, emissive: 0x333333 }); // roster board
  tables.push(makeTable(-26, -5.5));

  // Campus
  addBox(-4, -12, 10, 6, 4, 0x6d6a78); // lecture hall
  addBox(6, 10, 9, 7, 4, 0x7a6a5a);    // library
  addBox(-9, 12, 3, 2, 1.2, 0x555b66); // wrecked car
  addBox(10, -4, 2, 2, 1.2, 0x555b66);
  for (const [x, z] of [[-12, 8], [-10, -4], [3, 4], [12, 5], [13, -14], [-2, 17], [8, -9], [22, 15], [27, -6], [19, -15]]) addTree(x, z);

  // The fence (needs the whole party to clear it)
  const fence = addBox(FENCE_X, 0, 0.7, 40, 2.4, 0xa85a2a);
  fence.mesh.material.map = stripeTexture();
  game.fence = fence;
  // East quad
  const quad = new THREE.Mesh(new THREE.PlaneGeometry(13, 40), new THREE.MeshStandardMaterial({ color: 0x33403a, roughness: 1 }));
  quad.rotation.x = -Math.PI / 2; quad.position.set(23, 0.01, 0); quad.receiveShadow = true;
  world.add(quad);
  tables.push(makeTable(24, -10));
  addBox(22, 10, 4, 3, 2.4, 0x4a3d5a);

  // Items
  const spots = [
    ['cloth', -10, 4], ['cloth', -12, -7], ['scrap', -8, -1], ['scrap', 2, -3], ['scrap', 5, 3], ['medkit', 0, 14],
    ['energy', 10, -12], ['clue', -6, -7.5], ['clue', 8, -7],
    ['scrap', 22, 6], ['cloth', 20, -4], ['cloth', 25, 4], ['medkit', 26, 13], ['energy', 21, 14], ['scrap', 28, -12],
    ['clue', 27, -15], ['clue', 28, 1],
  ];
  for (const [type, x, z] of spots) addItem(type, x, z);

  // Enemies
  for (const [type, count, x, z] of [
    ['shade', 1, -8, 9], ['shade', 2, 2, -6], ['shade', 1, 9, 0], ['shade', 2, 11, 14], ['shade', 1, -3, 16],
    ['hollow', 2, 22, -5], ['hollow', 3, 24, 9],
  ]) addExploreEnemy(type, count, x, z);
}

function stripeTexture() {
  const c = document.createElement('canvas'); c.width = c.height = 64;
  const g = c.getContext('2d');
  g.fillStyle = '#a85a2a'; g.fillRect(0, 0, 64, 64);
  g.fillStyle = '#2a2018'; for (let i = -64; i < 64; i += 16) { g.beginPath(); g.moveTo(i, 64); g.lineTo(i + 8, 64); g.lineTo(i + 72, 0); g.lineTo(i + 64, 0); g.fill(); }
  const t = new THREE.CanvasTexture(c); t.wrapS = t.wrapT = THREE.RepeatWrapping; t.repeat.set(30, 1);
  t.colorSpace = THREE.SRGBColorSpace;
  return t;
}

function addTree(x, z) {
  const g = new THREE.Group();
  const trunk = new THREE.Mesh(new THREE.CylinderGeometry(0.25, 0.35, 1.6, 8), new THREE.MeshStandardMaterial({ color: 0x4a3524 }));
  trunk.position.y = 0.8;
  const top = new THREE.Mesh(new THREE.ConeGeometry(1.4, 3.2, 8), new THREE.MeshStandardMaterial({ color: 0x1f4a34 }));
  top.position.y = 3;
  trunk.castShadow = top.castShadow = true;
  g.add(trunk, top); g.position.set(x, 0, z);
  world.add(g);
  colliders.push({ minX: x - 0.4, maxX: x + 0.4, minZ: z - 0.4, maxZ: z + 0.4 });
}

function makeTable(x, z) {
  const { mesh } = addBox(x, z, 2.4, 1.2, 1, 0x8a5a2a);
  const glow = new THREE.PointLight(0xffaa44, 6, 8, 2);
  glow.position.set(x, 2, z);
  world.add(glow);
  const top = new THREE.Mesh(new THREE.BoxGeometry(2.2, 0.1, 1.0), new THREE.MeshStandardMaterial({ color: 0xffb347, emissive: 0xff8a1a, emissiveIntensity: 0.8 }));
  top.position.set(x, 1.05, z);
  world.add(top);
  return { x, z, mesh, top };
}

function addItem(type, x, z) {
  const color = type === 'clue' ? 0xfff27a : ITEMS[type].color;
  const mesh = new THREE.Mesh(
    type === 'clue' ? new THREE.BoxGeometry(0.5, 0.65, 0.08) : new THREE.OctahedronGeometry(0.35),
    new THREE.MeshStandardMaterial({ color, emissive: color, emissiveIntensity: 0.5, roughness: 0.4 }),
  );
  mesh.position.set(x, 0.8, z);
  mesh.castShadow = true;
  world.add(mesh);
  itemNodes.push({ type, mesh, baseY: 0.8, phase: rand(0, 6) });
}

function makeChar(color, scale = 1) {
  const g = new THREE.Group();
  const mat = new THREE.MeshStandardMaterial({ color, roughness: 0.7 });
  const body = new THREE.Mesh(new THREE.CylinderGeometry(0.32, 0.38, 0.95, 12), mat);
  body.position.y = 0.55;
  const head = new THREE.Mesh(new THREE.SphereGeometry(0.28, 16, 12), new THREE.MeshStandardMaterial({ color: 0xf0d2b0, roughness: 0.8 }));
  head.position.y = 1.3;
  const nose = new THREE.Mesh(new THREE.BoxGeometry(0.1, 0.1, 0.12), mat);
  nose.position.set(0, 1.3, 0.28);
  body.castShadow = head.castShadow = true;
  g.add(body, head, nose);
  g.scale.setScalar(scale);
  return g;
}

function makeEnemyMesh(def, scale = 1) {
  const g = new THREE.Group();
  const mat = new THREE.MeshStandardMaterial({ color: def.color, roughness: 0.5, emissive: def.eye, emissiveIntensity: 0.08 });
  const body = new THREE.Mesh(new THREE.CapsuleGeometry(0.45, 1.0, 6, 12), mat);
  body.position.y = 0.95;
  const head = new THREE.Mesh(new THREE.SphereGeometry(0.4, 16, 12), mat);
  head.position.y = 1.95;
  const eyeMat = new THREE.MeshBasicMaterial({ color: def.eye });
  for (const s of [-1, 1]) {
    const e = new THREE.Mesh(new THREE.SphereGeometry(0.07, 8, 8), eyeMat);
    e.position.set(s * 0.15, 2.0, 0.34);
    g.add(e);
  }
  body.castShadow = head.castShadow = true;
  g.add(body, head);
  g.scale.setScalar(scale);
  return g;
}

function addExploreEnemy(type, count, x, z) {
  const mesh = makeEnemyMesh(ENEMY_TYPES[type], 0.85 + count * 0.12);
  mesh.position.set(x, 0, z);
  world.add(mesh);
  exploreEnemies.push({ type, count, mesh, home: new THREE.Vector3(x, 0, z), target: new THREE.Vector3(x, 0, z), wait: 0 });
}

/* ------------------------------------------------------------ party setup */
function buildParty() {
  game.teacher = makeMember(TEACHER);
  game.teacher.mesh = makeChar(TEACHER.color, 1.12);
  game.teacher.mesh.position.set(-20, 0, 0);
  world.add(game.teacher.mesh);
  game.roster = STUDENTS.map((s) => {
    const m = makeMember(s);
    m.mesh = makeChar(s.color);
    world.add(m.mesh);
    return m;
  });
  placeParty(true);
}

const IDLE_SPOTS = [[-26, -2.5], [-24.4, -2.5], [-22.8, -2.5], [-21.2, -2.5], [-19.6, -2.5], [-18, -2.5]];
function placeParty(initial = false) {
  const t = game.teacher.mesh.position;
  game.roster.forEach((m, i) => {
    const inParty = game.party.includes(m);
    if (inParty) {
      const k = game.party.indexOf(m);
      m.mesh.position.set(t.x - 1 - k * 0.2, 0, t.z + 0.8 + k * 0.8);
    } else {
      m.mesh.position.set(IDLE_SPOTS[i][0], 0, IDLE_SPOTS[i][1]);
    }
  });
  if (initial) game.teacher.mesh.position.set(-20, 0, 0);
}

const everyone = () => [game.teacher, ...game.party];

function learn(m, id) {
  if (id && !m.skills.includes(id)) { m.skills.push(id); return true; }
  return false;
}

function gainXp(m, amount) {
  const lines = [];
  m.xp += amount;
  while (m.xp >= m.level * 25) {
    m.xp -= m.level * 25;
    m.level++;
    m.maxHp += 5; m.hp = Math.min(m.maxHp, m.hp + 5);
    m.atk += 1; m.int += 1; if (m.level % 2 === 1) m.def += 1;
    lines.push(`${m.name} reached level ${m.level}!`);
    if (m.level === 2 && learn(m, m.unlock)) lines.push(`${m.name} learned ${SKILLS[m.unlock].name}!`);
  }
  return lines;
}

/* ------------------------------------------------------------------- HUD */
let toastTimer = 0;
function toast(msg, ms = 3200) {
  const t = $('toast');
  t.textContent = msg; t.classList.add('on');
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => t.classList.remove('on'), ms);
}

function memberCard(m, extra = '') {
  return h('div', { class: 'pm' + (m.hp <= 0 ? ' ko' : '') + extra },
    h('div', { class: 'row' }, h('span', { class: 'name' }, m.name), h('span', {}, `Lv${m.level} · ${m.hp <= 0 ? 'KO' : `${m.hp}/${m.maxHp}`}`)),
    h('div', { class: 'bar' }, Object.assign(h('i'), { style: `width:${(m.hp / m.maxHp) * 100}%` })),
    m.buff ? h('div', { class: 'tag' }, `ATK +${Math.round((m.buff.mult - 1) * 100)}% (${m.buff.turns})`) : null,
  );
}

function updateHud() {
  const p = $('party');
  p.replaceChildren(...everyone().map((m) => {
    const card = memberCard(m);
    card.append(h('div', { class: 'bar xp' }, Object.assign(h('i'), { style: `width:${(m.xp / (m.level * 25)) * 100}%` })));
    return card;
  }));
  const inv = Object.entries(game.inv).filter(([, n]) => n > 0).map(([k, n]) => `${ITEMS[k].name} ×${n}`);
  $('inv').replaceChildren(h('b', {}, 'Inventory'), h('div', {}, inv.length ? inv.join(' · ') : 'Empty'));
  const obj = game.fenceCleared ? 'The east quad is open.' : 'A fence blocks the east quad. Everyone must be able to clear it.';
  $('objective').replaceChildren(h('b', {}, `Clues ${game.clues.length}/${CLUES.length}`), h('div', {}, 'Scavenge the campus and piece together what happened.'), h('div', {}, obj));
  if (game.mode === 'combat') renderCombatParty();
}

/* --------------------------------------------------------------- overlays */
function openOverlay(content, closable = false) {
  $('panel').replaceChildren(...[content].flat());
  $('overlay').hidden = false;
  game.mode = 'ui';
  game.overlayClosable = closable;
}
function closeOverlay() {
  $('overlay').hidden = true;
  game.mode = 'explore';
  updateHud();
}

function openRoster(intro = false) {
  const sel = new Set(game.party.map((m) => m.id));
  const panel = [];
  const render = () => {
    const cards = game.roster.map((m) => h('div', {
      class: 'card' + (sel.has(m.id) ? ' sel' : ''),
      onclick: () => { if (sel.has(m.id)) sel.delete(m.id); else if (sel.size < MAX_PARTY) sel.add(m.id); render(); },
    },
    h('div', { class: 'cname' }, m.name),
    h('div', { class: 'cmeta' }, `${m.major} · ${m.clique} · Lv${m.level}`),
    h('div', { class: 'stats' }, h('span', {}, `ATK ${m.atk}`), h('span', {}, `HP ${m.maxHp}`), h('span', {}, `DEF ${m.def}`), h('span', {}, `INT ${m.int}`)),
    h('div', { class: 'cmeta' }, `Skills: ${m.skills.map((s) => SKILLS[s].name).join(', ')}`),
    h('div', { class: 'cmeta' }, `"${m.blurb}"`),
    m.canJump ? null : h('div', { class: 'warn' }, '⚠ Cannot jump obstacles'),
    m.trait === 'craftAnywhere' ? h('div', { class: 'tag' }, '★ Group can craft anywhere') : null));
    const go = h('button', { class: 'primary', onclick: confirm }, `Leave classroom with ${sel.size} student${sel.size === 1 ? '' : 's'}`);
    const rest = h('button', { onclick: () => { for (const m of [game.teacher, ...game.roster]) m.hp = m.maxHp; toast('Everyone rests and recovers.'); render(); } }, 'Rest (full heal)');
    $('panel').replaceChildren(
      h('h2', {}, intro ? 'Apocalypse 101' : 'Classroom'),
      h('p', {}, intro
        ? 'Everyone else has vanished. You are the teacher. Choose 0–3 students to bring along. No one gets left behind: the party moves as one.'
        : 'Choose 0–3 students to accompany you.'),
      h('div', { class: 'cards' }, cards),
      h('div', { class: 'actions' }, h('span', { class: 'spacer' }, `Party ${sel.size}/${MAX_PARTY}`), rest, go),
    );
  };
  const confirm = () => {
    game.party = game.roster.filter((m) => sel.has(m.id));
    placeParty();
    closeOverlay();
  };
  openOverlay(panel);
  render();
}

function craftRecipes() {
  const render = () => {
    const rows = RECIPES.map((r) => {
      const done = r.once && game.crafted[r.id];
      const can = !done && Object.entries(r.cost).every(([k, n]) => game.inv[k] >= n);
      return h('div', { class: 'recipe' },
        h('div', { class: 'info' }, h('b', {}, r.name), h('div', { class: 'cost' }, `${r.desc} — Cost: ${Object.entries(r.cost).map(([k, n]) => `${ITEMS[k].name} ×${n}`).join(', ')}`)),
        h('button', { ...(can ? {} : { disabled: '' }), onclick: () => { doCraft(r); render(); } }, done ? 'Crafted' : 'Craft'));
    });
    $('panel').replaceChildren(
      h('h2', {}, 'Crafting'),
      h('p', {}, `You have: ${Object.entries(game.inv).filter(([k, n]) => n > 0 && ITEMS[k].kind === 'material').map(([k, n]) => `${ITEMS[k].name} ×${n}`).join(', ') || 'no materials'}`),
      ...rows,
      h('div', { class: 'actions' }, h('button', { onclick: closeOverlay }, 'Close (Esc)')),
    );
  };
  openOverlay([], true);
  render();
}

function doCraft(r) {
  for (const [k, n] of Object.entries(r.cost)) game.inv[k] -= n;
  if (r.gives) for (const [k, n] of Object.entries(r.gives)) game.inv[k] = (game.inv[k] || 0) + n;
  if (r.id === 'bat') { game.teacher.atk += 4; learn(game.teacher, 'power_swing'); toast('Reinforced Bat crafted: ATK +4, learned Power Swing!'); }
  if (r.id === 'vest') { for (const m of [game.teacher, ...game.roster]) m.def += 2; toast('Riot Vest crafted: party DEF +2!'); }
  if (r.once) game.crafted[r.id] = true;
  updateHud();
}

function openJournal() {
  openOverlay([
    h('h2', {}, 'Journal'),
    game.clues.length ? h('ul', { class: 'clues' }, game.clues.map((c) => h('li', {}, c))) : h('p', {}, 'No clues yet.'),
    h('div', { class: 'actions' }, h('button', { onclick: closeOverlay }, 'Close (Esc)')),
  ], true);
}

/* ----------------------------------------------------------------- input */
const keys = new Set();
const pad = { prev: [] };
let mini = null;
let menuActive = false;

const DIRS = { ArrowUp: '↑', KeyW: '↑', ArrowDown: '↓', KeyS: '↓', ArrowLeft: '←', KeyA: '←', ArrowRight: '→', KeyD: '→' };

addEventListener('keydown', (e) => {
  if (['Space', 'ArrowUp', 'ArrowDown', 'ArrowLeft', 'ArrowRight'].includes(e.code)) e.preventDefault();
  keys.add(e.code);
  if (!e.repeat) onAction(e.code);
});
addEventListener('keyup', (e) => keys.delete(e.code));

function onAction(code) {
  if (mini) {
    if (code === 'Space' || code === 'Enter') mini.confirm?.();
    else if (DIRS[code]) mini.dir?.(DIRS[code]);
    return;
  }
  if (game.mode === 'combat') {
    const m = /^Digit([1-9])$/.exec(code);
    if (m && menuActive) {
      const btn = [...document.querySelectorAll('#cMenu .btn:not(.disabled)')][Number(m[1]) - 1];
      btn?.click();
    }
    return;
  }
  if (game.mode === 'ui') {
    if (code === 'Escape' && game.overlayClosable) closeOverlay();
    return;
  }
  if (game.mode !== 'explore') return;
  if (code === 'KeyE' || code === 'Space') interact();
  else if (code === 'KeyH') healLowest();
  else if (code === 'KeyC') craftAnywhere();
  else if (code === 'KeyJ') openJournal();
}

function pollGamepad() {
  const gp = [...(navigator.getGamepads?.() || [])].find(Boolean);
  const out = { x: 0, z: 0 };
  if (!gp) return out;
  const dz = (v) => (Math.abs(v) < 0.2 ? 0 : v);
  out.x = dz(gp.axes[0] || 0); out.z = dz(gp.axes[1] || 0);
  const pressed = gp.buttons.map((b) => b.pressed);
  const edge = (i) => pressed[i] && !pad.prev[i];
  if (mini) {
    if (edge(0)) mini.confirm?.();
    for (const [i, d] of [[12, '↑'], [13, '↓'], [14, '←'], [15, '→']]) if (edge(i)) mini.dir?.(d);
  } else if (game.mode === 'explore') {
    if (edge(0)) interact();
    if (edge(2)) healLowest();
    if (edge(3)) craftAnywhere();
    if (edge(9)) openJournal();
  }
  pad.prev = pressed;
  return out;
}

/* ------------------------------------------------------------ exploration */
const nearTable = (p, r = 2.6) => tables.find((t) => Math.hypot(t.x - p.x, t.z - p.z) < r);
const inClassroom = (p) => p.x < CLASSROOM_MAX_X;

function findInteract() {
  const p = game.teacher.mesh.position;
  if (nearTable(p)) return { label: 'E / Space: Craft', run: craftRecipes };
  if (Math.hypot(p.x + 20, p.z + 6.4) < 3) return { label: 'E / Space: Change party', run: () => openRoster() };
  if (!game.fenceCleared && Math.abs(p.x - FENCE_X) < 2.4) return { label: 'E / Space: Jump the fence', run: tryFence };
  return null;
}
function interact() { findInteract()?.run(); }

function tryFence() {
  const blockers = game.party.filter((m) => !m.canJump);
  if (blockers.length) {
    toast(`${blockers.map((m) => m.name).join(' and ')} can't clear the fence. No one gets left behind. Swap them out at the classroom board.`, 4500);
    return;
  }
  game.fenceCleared = true;
  colliders.splice(colliders.indexOf(game.fence.col), 1);
  game.fence.mesh.scale.y = 0.25;
  game.fence.mesh.position.y = 0.3;
  toast('The whole party vaults the fence together.');
  updateHud();
}

function craftAnywhere() {
  if (game.party.some((m) => m.trait === 'craftAnywhere')) craftRecipes();
  else toast('You need a table, or a crafter in the party (Priya).');
}

function healLowest() {
  const targets = everyone().filter((m) => m.hp < m.maxHp);
  if (!targets.length) return toast('Everyone is healthy.');
  const item = ['bandage', 'medkit'].find((k) => game.inv[k] > 0);
  if (!item) return toast('No healing items. Craft bandages from cloth.');
  const t = targets.sort((a, b) => a.hp / a.maxHp - b.hp / b.maxHp)[0];
  game.inv[item]--;
  t.hp = Math.min(t.maxHp, t.hp + ITEMS[item].heal);
  toast(`${t.name} used a ${ITEMS[item].name}.`);
  updateHud();
}

function pickup(node) {
  world.remove(node.mesh);
  itemNodes.splice(itemNodes.indexOf(node), 1);
  if (node.type === 'clue') {
    const text = CLUES[game.clues.length % CLUES.length];
    game.clues.push(text);
    toast(`Clue: ${text}`, 6000);
    if (game.clues.length === CLUES.length) setTimeout(finishDemo, 6200);
  } else {
    game.inv[node.type] = (game.inv[node.type] || 0) + 1;
    toast(`Picked up ${ITEMS[node.type].name}.`, 1600);
  }
  updateHud();
}

function finishDemo() {
  if (game.finished || game.mode === 'combat') return;
  game.finished = true;
  openOverlay([
    h('h2', {}, 'Prototype complete'),
    h('p', {}, 'You found every clue. The mystery of the disappearance continues in the full game.'),
    h('div', { class: 'actions' }, h('button', { class: 'primary', onclick: closeOverlay }, 'Keep exploring')),
  ], true);
}

let time = 0;
let lastTick = performance.now();

function moveTo(p, dx, dz, r) { p.x += dx; p.z += dz; resolve(p, r); }

function resolve(p, r) {
  for (const c of colliders) {
    const cx = clamp(p.x, c.minX, c.maxX), cz = clamp(p.z, c.minZ, c.maxZ);
    const dx = p.x - cx, dz = p.z - cz, d2 = dx * dx + dz * dz;
    if (d2 >= r * r) continue;
    if (d2 > 1e-8) { const d = Math.sqrt(d2); p.x = cx + (dx / d) * r; p.z = cz + (dz / d) * r; }
    else {
      const l = p.x - c.minX, rr = c.maxX - p.x, t = p.z - c.minZ, b = c.maxZ - p.z, m = Math.min(l, rr, t, b);
      if (m === l) p.x = c.minX - r; else if (m === rr) p.x = c.maxX + r; else if (m === t) p.z = c.minZ - r; else p.z = c.maxZ + r;
    }
  }
  p.x = clamp(p.x, -BOUND_X, BOUND_X);
  p.z = clamp(p.z, -BOUND_Z, BOUND_Z);
}

function updateExplore(dt, padAxes) {
  const tp = game.teacher.mesh.position;
  let ix = (keys.has('KeyD') || keys.has('ArrowRight') ? 1 : 0) - (keys.has('KeyA') || keys.has('ArrowLeft') ? 1 : 0) + padAxes.x;
  let iz = (keys.has('KeyS') || keys.has('ArrowDown') ? 1 : 0) - (keys.has('KeyW') || keys.has('ArrowUp') ? 1 : 0) + padAxes.z;
  const len = Math.hypot(ix, iz);
  const moving = len > 0.01;
  if (moving) {
    ix /= Math.max(1, len); iz /= Math.max(1, len);
    moveTo(tp, ix * 6.5 * dt, iz * 6.5 * dt, 0.5);
    game.teacher.mesh.rotation.y = Math.atan2(ix, iz);
  }
  const bob = (m, active) => { m.mesh.position.y = active ? Math.abs(Math.sin(time * 11)) * 0.08 : 0; };
  bob(game.teacher, moving);

  // Followers trail the leader; the party moves as one.
  game.party.forEach((m, i) => {
    const L = i === 0 ? tp : game.party[i - 1].mesh.position;
    const p = m.mesh.position;
    const dx = L.x - p.x, dz = L.z - p.z, d = Math.hypot(dx, dz);
    let active = false;
    if (d > 1.5) {
      const s = Math.min(d - 1.5, 8 * dt);
      moveTo(p, (dx / d) * s, (dz / d) * s, 0.4);
      m.mesh.rotation.y = Math.atan2(dx, dz);
      active = true;
    }
    bob(m, active);
  });

  if (game.fenceCleared) {
    for (const c of everyone()) {
      const dx = Math.abs(c.mesh.position.x - FENCE_X);
      if (dx < 1.8) c.mesh.position.y += 1.1 * (1 - dx / 1.8);
    }
  }

  const safe = inClassroom(tp);
  for (const e of exploreEnemies) {
    const p = e.mesh.position;
    const d = Math.hypot(tp.x - p.x, tp.z - p.z);
    let speed = 1.6;
    if (!safe && d < 7.5) { e.target.set(tp.x, 0, tp.z); speed = 3.3; }
    else {
      e.wait -= dt;
      if (e.wait <= 0 || Math.hypot(e.target.x - p.x, e.target.z - p.z) < 0.5) {
        e.target.set(e.home.x + rand(-4, 4), 0, e.home.z + rand(-4, 4));
        e.wait = rand(2, 5);
      }
    }
    const dx = e.target.x - p.x, dz = e.target.z - p.z, dd = Math.hypot(dx, dz);
    if (dd > 0.2) {
      moveTo(p, (dx / dd) * speed * dt, (dz / dd) * speed * dt, 0.5);
      if (p.x < CLASSROOM_MAX_X + 0.6) p.x = CLASSROOM_MAX_X + 0.6;
      e.mesh.rotation.y = Math.atan2(dx, dz);
    }
    e.mesh.position.y = Math.sin(time * 3 + e.home.x) * 0.1;
    if (!safe && d < 1.2 && game.mode === 'explore') { startCombat(e); return; }
  }

  for (const n of itemNodes.slice()) {
    n.mesh.rotation.y += dt * 2;
    n.mesh.position.y = n.baseY + Math.sin(time * 2 + n.phase) * 0.12;
    if (Math.hypot(n.mesh.position.x - tp.x, n.mesh.position.z - tp.z) < 1.1) pickup(n);
  }
  for (const t of tables) t.top.material.emissiveIntensity = 0.6 + Math.sin(time * 3) * 0.25;

  const act = findInteract();
  $('prompt').textContent = act ? act.label : '';

  topCam.position.lerp(new THREE.Vector3(tp.x, 21, tp.z + 14), 1 - Math.pow(0.001, dt));
  topCam.lookAt(tp.x, 0, tp.z + 1);
}

/* ---------------------------------------------------------------- combat */
const cState = { enemies: [], shake: 0, flicker: null, hallLight: null };

function buildCombatScene() {
  cScene.add(new THREE.AmbientLight(0x6a7a99, 0.9));
  const mat = (c) => new THREE.MeshStandardMaterial({ color: c, roughness: 0.9 });
  const floor = new THREE.Mesh(new THREE.BoxGeometry(9, 0.2, 40), mat(0x2a2d36)); floor.position.set(0, -0.1, -14);
  const ceil = new THREE.Mesh(new THREE.BoxGeometry(9, 0.2, 40), mat(0x1a1c22)); ceil.position.set(0, 3.6, -14);
  const back = new THREE.Mesh(new THREE.BoxGeometry(9, 4, 0.3), mat(0x14161c)); back.position.set(0, 1.8, -17);
  cScene.add(floor, ceil, back);
  for (const s of [-1, 1]) {
    const wall = new THREE.Mesh(new THREE.BoxGeometry(0.3, 4, 40), mat(0x2e3440)); wall.position.set(s * 4.5, 1.8, -14);
    cScene.add(wall);
    for (let z = 2; z > -16; z -= 1.3) {
      const locker = new THREE.Mesh(new THREE.BoxGeometry(0.7, 2.3, 1), mat(z % 2 ? 0x3a5068 : 0x35485e));
      locker.position.set(s * 4.0, 1.15, z);
      cScene.add(locker);
    }
  }
  const light = new THREE.PointLight(0xbcd0ff, 22, 22, 2);
  light.position.set(0, 3.2, -3);
  cScene.add(light);
  const red = new THREE.PointLight(0xff3050, 25, 18, 2);
  red.position.set(0, 2, -12);
  cScene.add(red);
  cState.hallLight = light;
  cCam.position.set(0, 1.6, 3);
  cCam.lookAt(0, 1.5, -8);
}

function renderCombatParty() {
  const act = cState.active;
  $('cParty').replaceChildren(...everyone().map((m) => memberCard(m, m === act ? ' active' : '')));
  $('cEnemies').replaceChildren(...cState.enemies.map((e) => h('div', { class: 'en' + (e.hp <= 0 ? ' dead' : '') + (e.stunned ? ' stun' : '') },
    h('div', {}, `${e.name}${e.stunned ? ' (stunned)' : ''}`),
    h('div', { class: 'bar foe' }, Object.assign(h('i'), { style: `width:${(Math.max(0, e.hp) / e.maxHp) * 100}%` })))));
}

function log(msg) { $('cLog').textContent = msg; }

function choose(title, options) {
  return new Promise((resolve) => {
    const menu = $('cMenu');
    menuActive = true;
    let n = 0;
    menu.replaceChildren(h('div', { class: 'title' }, title), ...options.map((o) => {
      const idx = o.disabled ? '' : `${++n}. `;
      return h('div', { class: 'btn' + (o.disabled ? ' disabled' : ''), onclick: () => {
        if (o.disabled) return;
        menuActive = false; menu.replaceChildren(); resolve(o.value);
      } }, `${idx}${o.label}`, o.sub ? h('small', {}, o.sub) : null);
    }));
  });
}

function popup(text, worldPos, cls = '') {
  const v = worldPos.clone().project(cCam);
  const el = h('div', { class: `popup ${cls}` }, text);
  el.style.left = `${(v.x * 0.5 + 0.5) * innerWidth}px`;
  el.style.top = `${(-v.y * 0.5 + 0.5) * innerHeight}px`;
  $('combat').append(el);
  setTimeout(() => el.remove(), 1000);
}

function runMini(type, label) {
  const el = $('cMini');
  el.hidden = false;
  return new Promise((resolve) => {
    let done = false;
    const finish = async (q, text) => {
      if (done) return; done = true;
      cancelAnimationFrame(raf); mini = null;
      el.replaceChildren(h('div', { class: 'mash' }, text));
      await sleep(550);
      el.hidden = true; resolve(q);
    };
    let raf = 0;
    if (type === 'timing') {
      const marker = h('div', { class: 'marker' });
      el.replaceChildren(h('b', {}, label), h('div', {}, 'Press Space / click / A when the marker is in the green'), h('div', { class: 'mbar' }, h('div', { class: 'sweet' }), marker));
      let pos = 1, t = 0, last = performance.now();
      const tick = (now) => { t += (now - last) / 1000; last = now; pos = Math.abs(((t * 0.95) % 2) - 1); marker.style.left = `${pos * 100}%`; raf = requestAnimationFrame(tick); };
      raf = requestAnimationFrame(tick);
      const stop = () => {
        const d = Math.abs(pos - 0.5);
        const q = d < 0.06 ? 1 : clamp(1 - (d - 0.06) * 2.2, 0, 1);
        finish(q, q >= 0.95 ? 'Perfect!' : q >= 0.5 ? 'Good' : 'Weak');
      };
      mini = { confirm: stop };
      el.onclick = stop;
    } else if (type === 'mash') {
      let count = 0, left = 2;
      const num = h('div', { class: 'mash' }, '0');
      const timer = h('div', {}, '2.0s');
      el.replaceChildren(h('b', {}, label), h('div', {}, 'Mash Space / click / A!'), num, timer);
      const hit = () => { count++; num.textContent = String(count); };
      mini = { confirm: hit };
      el.onclick = hit;
      let last = performance.now();
      const tick = (now) => {
        left -= (now - last) / 1000; last = now;
        timer.textContent = `${Math.max(0, left).toFixed(1)}s`;
        if (left <= 0) { const q = Math.min(1, count / 14); finish(q, q >= 0.95 ? 'Maximum power!' : `${count} hits`); return; }
        raf = requestAnimationFrame(tick);
      };
      raf = requestAnimationFrame(tick);
    } else if (type === 'memory') {
      const seq = Array.from({ length: 3 }, () => ['↑', '↓', '←', '→'][Math.floor(Math.random() * 4)]);
      const input = [];
      const display = h('div', { class: 'seq' }, seq.join(' '));
      const dirs = h('div', { class: 'dirs' }, ['←', '↑', '↓', '→'].map((d) => h('button', { onclick: () => mini?.dir?.(d) }, d)));
      el.replaceChildren(h('b', {}, label), h('div', {}, 'Memorize the sequence…'), display, dirs);
      mini = { confirm: null, dir: null };
      el.onclick = null;
      setTimeout(() => {
        if (done) return;
        display.textContent = '? ? ?';
        el.firstChild.nextSibling.textContent = 'Enter it with arrows / WASD';
        mini.dir = (d) => {
          input.push(d);
          display.textContent = input.join(' ') + ' ' + '?'.repeat(3 - input.length);
          if (input.length === 3) {
            const ok = input.filter((v, i) => v === seq[i]).length;
            finish(ok / 3, ok === 3 ? 'Perfect recall!' : `${ok}/3 correct`);
          }
        };
      }, 1500);
    }
  });
}

function enemyScreenPos(e) { return e.mesh.position.clone().add(new THREE.Vector3(0, 2.2 * e.mesh.scale.y, 0)); }

async function startCombat(group) {
  game.mode = 'combat';
  $('prompt').textContent = '';
  $('hud').hidden = true;
  $('combat').hidden = false;
  cState.enemies = [];
  const n = group.count;
  for (let i = 0; i < n; i++) {
    const t = ENEMY_TYPES[group.type];
    const mesh = makeEnemyMesh(t, 1.5);
    mesh.position.set((i - (n - 1) / 2) * 2.6, 0, -7 - (i % 2));
    cScene.add(mesh);
    cState.enemies.push({ ...t, maxHp: t.hp, stunned: false, mesh, home: mesh.position.clone(), hitT: 0 });
  }
  log(`${n > 1 ? `${n} ${ENEMY_TYPES[group.type].name}s appear` : `A ${ENEMY_TYPES[group.type].name} appears`}!`);
  await sleep(900);
  const result = await combatLoop();
  await endCombat(result, group);
}

const aliveEnemies = () => cState.enemies.filter((e) => e.hp > 0);
const aliveParty = () => everyone().filter((m) => m.hp > 0);

async function combatLoop() {
  while (true) {
    for (const m of everyone()) {
      if (m.hp <= 0) continue;
      if (!aliveEnemies().length) return 'win';
      cState.active = m;
      renderCombatParty();
      await playerTurn(m);
    }
    cState.active = null;
    if (!aliveEnemies().length) return 'win';
    await enemyPhase();
    if (!aliveParty().length) return 'lose';
    for (const m of everyone()) {
      for (const k of Object.keys(m.cd)) m.cd[k] = Math.max(0, m.cd[k] - 1);
      m.defending = false;
      if (m.buff && --m.buff.turns <= 0) m.buff = null;
    }
    renderCombatParty();
  }
}

async function playerTurn(m) {
  log(`${m.name}'s turn`);
  while (true) {
    const hasItems = ['bandage', 'medkit', 'energy'].some((k) => game.inv[k] > 0);
    const opts = [{ label: 'Attack', value: 'strike' }];
    for (const id of m.skills) {
      const sk = SKILLS[id], cd = m.cd[id] || 0;
      opts.push({ label: sk.name, value: id, disabled: cd > 0, sub: cd > 0 ? `Recharging (${cd})` : sk.desc });
    }
    opts.push({ label: 'Item', value: 'item', disabled: !hasItems }, { label: 'Defend', value: 'defend' });
    const c = await choose(`${m.name}: choose action`, opts);
    if (c === 'defend') { m.defending = true; log(`${m.name} braces for impact.`); await sleep(500); return; }
    if (c === 'item') { if (await itemFlow(m)) return; continue; }
    if (await skillFlow(m, c)) return;
  }
}

async function pickTarget(kind) {
  if (kind === 'party') return 'party';
  const list = kind === 'enemy' ? aliveEnemies() : everyone();
  const opts = list.map((t) => ({ label: t.name, value: t, sub: kind === 'enemy' ? `HP ${t.hp}/${t.maxHp}` : `HP ${t.hp}/${t.maxHp}${t.hp <= 0 ? ' (KO)' : ''}` }));
  opts.push({ label: 'Back', value: null });
  return choose(kind === 'enemy' ? 'Select target' : 'Select ally', opts);
}

async function skillFlow(m, id) {
  const sk = SKILLS[id];
  const target = await pickTarget(sk.target);
  if (!target) return false;
  const q = sk.minigame ? await runMini(sk.minigame, sk.name) : 0.5;
  const power = (sk.stat === 'int' ? m.int : atkOf(m)) * sk.mult * (0.5 + q) * rand(0.92, 1.08);
  if (sk.type === 'attack' || sk.type === 'status') {
    const dmg = Math.max(1, Math.round(power - target.def));
    await hitEnemy(target, dmg, q >= 0.95);
    if (sk.status === 'stun' && target.hp > 0) {
      if (q >= 0.3) { target.stunned = true; log(`${m.name} stuns ${target.name}!`); } else log('The flash fizzles.');
    } else log(`${m.name} uses ${sk.name}: ${dmg} damage!`);
  } else if (sk.type === 'heal') {
    const amt = Math.round(power) + 5;
    target.hp = Math.min(target.maxHp, target.hp + amt);
    log(`${m.name} heals ${target.name} for ${amt}.`);
  } else if (sk.type === 'buff') {
    for (const a of aliveParty()) a.buff = { mult: 1 + (sk.mult - 1) * (0.7 + q * 0.6), turns: 3 };
    log(`${m.name} rallies the party!`);
  }
  if (sk.cd) m.cd[id] = sk.cd;
  renderCombatParty();
  await sleep(650);
  return true;
}

async function itemFlow(m) {
  const opts = ['bandage', 'medkit', 'energy'].filter((k) => game.inv[k] > 0)
    .map((k) => ({ label: `${ITEMS[k].name} ×${game.inv[k]}`, value: k, sub: ITEMS[k].desc }));
  opts.push({ label: 'Back', value: null });
  const item = await choose('Use which item?', opts);
  if (!item) return false;
  const target = await pickTarget('ally');
  if (!target) return false;
  game.inv[item]--;
  const it = ITEMS[item];
  if (it.heal) { target.hp = Math.min(target.maxHp, target.hp + it.heal); log(`${m.name} uses ${it.name} on ${target.name}.`); }
  if (it.buff) { target.buff = { mult: it.buff, turns: 3 }; log(`${target.name} is energized!`); }
  renderCombatParty(); updateHud();
  await sleep(650);
  return true;
}

async function hitEnemy(e, dmg, crit) {
  e.hp -= dmg;
  e.hitT = 0.4;
  popup(String(dmg), enemyScreenPos(e), crit ? 'crit' : '');
  renderCombatParty();
  if (e.hp <= 0) { e.dying = 0.5; await sleep(450); }
}

async function enemyPhase() {
  for (const e of aliveEnemies()) {
    if (e.stunned) { e.stunned = false; log(`${e.name} is stunned and can't act.`); renderCombatParty(); await sleep(700); continue; }
    const targets = aliveParty();
    if (!targets.length) return;
    const t = targets[Math.floor(Math.random() * targets.length)];
    let dmg = Math.max(1, Math.round(e.atk * rand(0.8, 1.2)) - defOf(t));
    if (t.defending) dmg = Math.max(1, Math.round(dmg / 2));
    t.hp = Math.max(0, t.hp - dmg);
    e.lunge = 0.4; cState.shake = 0.35;
    $('cFlash').classList.add('on'); setTimeout(() => $('cFlash').classList.remove('on'), 60);
    log(`${e.name} hits ${t.name} for ${dmg}${t.hp <= 0 ? '. They collapse!' : '.'}`);
    renderCombatParty();
    await sleep(800);
  }
}

async function endCombat(result, group) {
  const clearEnemies = () => { for (const e of cState.enemies) cScene.remove(e.mesh); cState.enemies = []; };
  if (result === 'win') {
    const xp = Math.ceil(cState.enemies.reduce((s, e) => s + e.xp, 0) / aliveParty().length);
    const lines = [`Victory! Each survivor gains ${xp} XP.`];
    for (const m of aliveParty()) lines.push(...gainXp(m, xp));
    const loot = [];
    for (const e of cState.enemies) {
      if (Math.random() < 0.7) loot.push(Math.random() < 0.5 ? 'scrap' : 'cloth');
      if (Math.random() < 0.15) loot.push('bandage');
    }
    for (const k of loot) game.inv[k]++;
    if (loot.length) lines.push(`Loot: ${loot.map((k) => ITEMS[k].name).join(', ')}`);
    log(lines[0]);
    await choose(lines.join('  ·  '), [{ label: 'Continue', value: true }]);
    world.remove(group.mesh);
    exploreEnemies.splice(exploreEnemies.indexOf(group), 1);
  } else {
    await choose('The party collapses… You wake in the classroom.', [{ label: 'Continue', value: true }]);
    for (const m of everyone()) m.hp = Math.ceil(m.maxHp / 2);
    game.teacher.mesh.position.set(-20, 0, 0);
    placeParty();
    group.mesh.position.copy(group.home);
  }
  for (const m of everyone()) { m.buff = null; m.defending = false; m.cd = {}; }
  clearEnemies();
  $('cLog').textContent = '';
  $('combat').hidden = true;
  $('hud').hidden = false;
  game.mode = 'explore';
  updateHud();
  if (game.clues.length === CLUES.length && !game.finished) finishDemo();
}

function updateCombatVisuals(dt) {
  cState.shake = Math.max(0, cState.shake - dt);
  cCam.position.set((Math.random() - 0.5) * cState.shake * 0.6, 1.6 + (Math.random() - 0.5) * cState.shake * 0.4, 3);
  for (const e of cState.enemies) {
    const m = e.mesh;
    e.hitT = Math.max(0, (e.hitT || 0) - dt);
    e.lunge = Math.max(0, (e.lunge || 0) - dt);
    m.position.x = e.home.x + (e.hitT > 0 ? Math.sin(time * 70) * 0.15 : 0);
    m.position.z = e.home.z + Math.sin((e.lunge / 0.4) * Math.PI) * 3.5;
    m.position.y = Math.sin(time * 2 + e.home.x) * 0.12;
    if (e.dying !== undefined && e.hp <= 0) { e.dying = Math.max(0, e.dying - dt); m.scale.setScalar(Math.max(0.001, 1.5 * (e.dying / 0.5))); }
  }
  cState.hallLight.intensity = 22 + Math.sin(time * 9) * 2 + (Math.random() < 0.03 ? -14 : 0);
}

/* ------------------------------------------------------------------ loop */
function frame() {
  const now = performance.now();
  const dt = Math.min(0.05, (now - lastTick) / 1000);
  lastTick = now;
  time += dt;
  const axes = pollGamepad();
  if (game.mode === 'explore') updateExplore(dt, axes);
  if (game.mode === 'combat') { updateCombatVisuals(dt); renderer.render(cScene, cCam); }
  else renderer.render(world, topCam);
  requestAnimationFrame(frame);
}

buildWorld();
buildCombatScene();
buildParty();
topCam.position.set(-20, 21, 14);
topCam.lookAt(-20, 0, 1);
updateHud();
openRoster(true);
frame();
