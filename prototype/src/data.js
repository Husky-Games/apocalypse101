// Skill "minigame" is the skill-based component of an attack (PRD: Combat).
// target: 'enemy' | 'ally' | 'party'
export const SKILLS = {
  strike:      { name: 'Attack',      type: 'attack', target: 'enemy', mult: 1.0, minigame: null,     desc: 'A basic hit.' },
  power_swing: { name: 'Power Swing', type: 'attack', target: 'enemy', mult: 1.9, minigame: 'mash',   cd: 2, desc: 'Mash to build power.' },
  slingshot:   { name: 'Slingshot',   type: 'attack', target: 'enemy', mult: 1.5, minigame: 'timing', cd: 1, desc: 'Time the release.' },
  quiz:        { name: 'Pop Quiz',    type: 'attack', target: 'enemy', mult: 1.7, minigame: 'memory', cd: 2, stat: 'int', desc: 'Remember the sequence. Uses INT.' },
  flash:       { name: 'Camera Flash', type: 'status', target: 'enemy', mult: 0.5, minigame: 'timing', cd: 3, status: 'stun', desc: 'Stuns the target for a turn.' },
  patch_up:    { name: 'Patch Up',    type: 'heal',   target: 'ally',  mult: 2.6, minigame: 'timing', cd: 2, stat: 'int', desc: 'Heal an ally. Uses INT.' },
  rally:       { name: 'Rally',       type: 'buff',   target: 'party', mult: 1.3, minigame: 'timing', cd: 4, desc: 'Party ATK +30% for 3 rounds.' },
};

// Every student has a unique attribute set (PRD: Party Selection).
export const STUDENTS = [
  { id: 'maya', name: 'Maya Chen',     major: 'Biology',        clique: 'Scholars',  atk: 5, hp: 28, def: 3, int: 9, canJump: true,  color: 0x5ec8a0, skills: ['quiz'],        unlock: 'patch_up',    blurb: 'Top of the class.' },
  { id: 'jake', name: 'Jake Torres',   major: 'Kinesiology',    clique: 'Jocks',     atk: 9, hp: 36, def: 4, int: 3, canJump: true,  color: 0xe8a23c, skills: ['power_swing'], unlock: 'rally',       blurb: 'Hits first, thinks later.' },
  { id: 'priya', name: 'Priya Nair',   major: 'Mech. Eng.',     clique: 'Makers',    atk: 6, hp: 30, def: 4, int: 8, canJump: true,  color: 0x6aa0f0, skills: ['slingshot'],   unlock: 'quiz',        blurb: 'Can craft anywhere.', trait: 'craftAnywhere' },
  { id: 'leo',  name: 'Leo Park',      major: 'Film',           clique: 'Artists',   atk: 5, hp: 26, def: 2, int: 6, canJump: true,  color: 0xc07ae0, skills: ['flash'],       unlock: 'slingshot',   blurb: 'Always has a camera.' },
  { id: 'dev',  name: 'Dev Okafor',    major: 'History',        clique: 'Loners',    atk: 4, hp: 40, def: 6, int: 7, canJump: false, color: 0xd96a6a, skills: ['rally'],       unlock: 'patch_up',    blurb: 'Leg brace. Tough as nails.' },
  { id: 'tessa', name: 'Tessa Alvarez', major: 'Music',         clique: 'Bandmates', atk: 6, hp: 30, def: 3, int: 5, canJump: false, color: 0xe0d060, skills: ['flash'],       unlock: 'power_swing', blurb: 'Won\'t leave her cello.' },
];

export const TEACHER = {
  id: 'teacher', name: 'Ms. Rivera', major: 'Teacher', clique: 'Faculty',
  atk: 8, hp: 40, def: 3, int: 6, canJump: true, color: 0xf2f2f2, skills: ['rally'], unlock: null,
};

export const ENEMY_TYPES = {
  shade:  { name: 'Shade',  hp: 28, atk: 7,  def: 1, xp: 12, color: 0x2a1a2e, eye: 0xff3355 },
  hollow: { name: 'Hollow', hp: 46, atk: 10, def: 3, xp: 20, color: 0x1a2a30, eye: 0x33ffd0 },
};

export const ITEMS = {
  scrap:    { name: 'Scrap Metal',  kind: 'material', color: 0x9aa4b0 },
  cloth:    { name: 'Cloth',        kind: 'material', color: 0xd8c8a0 },
  bandage:  { name: 'Bandage',      kind: 'consumable', color: 0xffffff, heal: 15, desc: 'Heals 15 HP.' },
  medkit:   { name: 'Medkit',       kind: 'consumable', color: 0xff4a4a, heal: 30, desc: 'Heals 30 HP.' },
  energy:   { name: 'Energy Drink', kind: 'consumable', color: 0x4aff7a, buff: 1.4, desc: 'ATK +40% for 3 rounds.' },
};

// once: gear is crafted a single time and applied permanently.
export const RECIPES = [
  { id: 'bandage', name: 'Bandage', cost: { cloth: 2 }, gives: { bandage: 1 }, desc: 'Heals 15 HP.' },
  { id: 'bat', name: 'Reinforced Bat', cost: { scrap: 3, cloth: 1 }, once: true, desc: 'Teacher ATK +4 and learns Power Swing.' },
  { id: 'vest', name: 'Riot Vest', cost: { scrap: 2, cloth: 3 }, once: true, desc: 'Party DEF +2.' },
];

export const CLUES = [
  'Attendance sheet: every name is crossed out at 9:14 AM, in the same handwriting.',
  'A phone on the quad, still warm. 212 unsent messages: "Are you there?"',
  'Chalkboard in the lecture hall: "THEY WERE NEVER GONE. WE WERE."',
  'Faculty memo: "Do not open the east gate after the signal. Repeat: do not open."',
];
