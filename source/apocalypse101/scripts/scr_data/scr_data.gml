// Game content. Characters, stats and skills follow content/characters.md; tweak balance here.
//
// Stats (HP/ATK/DEF) use characters.md's scale. Damage: raw * 50 / (50 + DEF), minimum 1.
// characters.md mentions PP/AP move costs; until a PP system exists, costs map to cooldowns:
//   average = 2 rounds, more = 3, significantly more = 4, most = 5.

function data_init() {
    // type: attack | status | heal | buff ; target: enemy | enemies | party
    // base: base damage (attacks) or max % of max HP healed / % ATK boost (heal, buff)
    // minigame: the skill-based component (PRD: Combat). Several characters.md minigames
    // (lens focus, stirring, chords, paint tracing, Operation) are placeholders using
    // timing / mash / memory until those minigames are built.
    global.SKILLS = {
        strike:           { name: "Attack",           type: "attack", target: "enemy",   base: 0,  minigame: "",       cd: 0, status: "",        turns: 0, desc: "A basic hit." },
        pop_quiz:         { name: "Pop Quiz",         type: "buff",   target: "party",   base: 30, minigame: "memory", cd: 2, status: "",        turns: 3, desc: "Party ATK +10% per correct answer (max 30%)." },
        homerun:          { name: "Homerun",          type: "attack", target: "enemy",   base: 20, minigame: "timing", cd: 2, status: "",        turns: 0, desc: "20 base dmg. Time the swing; perfect = crit." },
        freeze_frame:     { name: "Freeze Frame",     type: "status", target: "enemy",   base: 0,  minigame: "timing", cd: 2, status: "stun",    turns: 2, desc: "Stun one enemy 2 turns (3 on a sharp shot)." },
        soups_on:         { name: "Soup's On",        type: "heal",   target: "party",   base: 30, minigame: "mash",   cd: 2, status: "",        turns: 0, desc: "Heal all allies up to 30% max HP. Stir!" },
        death_blade:      { name: "Death Blade",      type: "attack", target: "enemy",   base: 40, minigame: "timing", cd: 3, status: "",        turns: 0, desc: "40 base dmg. Time the strike; perfect = crit." },
        encore:           { name: "Encore",           type: "attack", target: "enemies", base: 10, minigame: "timing", cd: 3, status: "",        turns: 0, desc: "10 base dmg to all enemies. Perfect = crit." },
        chemical_burn:    { name: "Chemical Burn",    type: "attack", target: "enemies", base: 15, minigame: "mash",   cd: 4, status: "poison",  turns: 3, desc: "15 dmg to all enemies + poison (3 turns)." },
        creative_license: { name: "Creative License", type: "attack", target: "enemy",   base: 15, minigame: "memory", cd: 4, status: "confuse", turns: 3, desc: "15 dmg + confuse one enemy (3 turns)." },
        invasive_surgery: { name: "Invasive Surgery", type: "heal",   target: "party",   base: 40, minigame: "timing", cd: 5, status: "",        turns: 0, desc: "Heal all allies up to 40% max HP." },
    };

    // role: [Starter|Advanced] DPS / Controller / Healer
    // trait: craftAnywhere | doubleFood | doubleMedical | ""
    global.STUDENTS = [
        { key: "pritya",   name: "Pritya Nair",       role: "Starter DPS",         major: "Baseball",      hp: 30, atk: 50, def: 20, canJump: true,  colour: rgb(0xa8484e), skills: ["homerun"],          trait: "" },
        { key: "maya",     name: "Maya Chen",         role: "Starter Controller",  major: "Photography",   hp: 50, atk: 20, def: 30, canJump: true,  colour: rgb(0xf0e6b0), skills: ["freeze_frame"],     trait: "" },
        { key: "jake",     name: "Jake Torres",       role: "Starter Healer",      major: "Culinary Arts", hp: 30, atk: 20, def: 50, canJump: true,  colour: rgb(0xf2f2f2), skills: ["soups_on"],         trait: "doubleFood" },
        { key: "axel",     name: "Axel Thompson",     role: "Advanced DPS",        major: "Anime enjoyer", hp: 20, atk: 70, def: 10, canJump: false, colour: rgb(0x8a1c1c), skills: ["death_blade"],      trait: "" },
        { key: "viola",    name: "Viola Abelard",     role: "Advanced DPS",        major: "Cello",         hp: 30, atk: 50, def: 20, canJump: true,  colour: rgb(0x4a7a52), skills: ["encore"],           trait: "" },
        { key: "jorge",    name: "Jorge Gutierrez",   role: "Advanced Controller", major: "Chemistry",     hp: 40, atk: 20, def: 40, canJump: true,  colour: rgb(0x5ec8b0), skills: ["chemical_burn"],    trait: "" },
        { key: "scarlett", name: "Scarlett Andersen", role: "Advanced Controller", major: "Arts",          hp: 30, atk: 30, def: 40, canJump: false, colour: rgb(0xf090b8), skills: ["creative_license"], trait: "craftAnywhere" },
        { key: "zuri",     name: "Zuri Williams",     role: "Advanced Healer",     major: "Medicine",      hp: 40, atk: 10, def: 50, canJump: false, colour: rgb(0x5aa8a0), skills: ["invasive_surgery"], trait: "doubleMedical" },
    ];

    global.TEACHER = {
        key: "teacher", name: "Mr. Ramirez", role: "Teacher", major: "Faculty",
        hp: 70, atk: 30, def: 50, canJump: true, colour: rgb(0xe0f8f8), skills: ["pop_quiz"], trait: "",
    };

    // Rebalanced to the characters.md stat scale.
    global.ENEMY_TYPES = {
        shade:  { name: "Shade",  hp: 60,  atk: 30, def: 15, xp: 12, colour: rgb(0x2a1a2e), eye: rgb(0xff3355) },
        hollow: { name: "Hollow", hp: 100, atk: 40, def: 25, xp: 20, colour: rgb(0x1a2a30), eye: rgb(0x33ffd0) },
    };

    // food / medical: doubled on pickup by Jake (doubleFood) / Zuri (doubleMedical)
    global.ITEMS = {
        scrap:   { name: "Scrap Metal",  kind: "material",   colour: rgb(0x9aa4b0), heal: 0,  buff: 0,   food: false, medical: false, desc: "" },
        cloth:   { name: "Cloth",        kind: "material",   colour: rgb(0xd8c8a0), heal: 0,  buff: 0,   food: false, medical: false, desc: "" },
        bandage: { name: "Bandage",      kind: "consumable", colour: rgb(0xffffff), heal: 15, buff: 0,   food: false, medical: true,  desc: "Heals 15 HP." },
        medkit:  { name: "Medkit",       kind: "consumable", colour: rgb(0xff4a4a), heal: 30, buff: 0,   food: false, medical: true,  desc: "Heals 30 HP." },
        food:    { name: "Canned Food",  kind: "consumable", colour: rgb(0xe8a040), heal: 20, buff: 0,   food: true,  medical: false, desc: "Heals 20 HP." },
        energy:  { name: "Energy Drink", kind: "consumable", colour: rgb(0x4aff7a), heal: 0,  buff: 1.4, food: false, medical: false, desc: "ATK +40% for 3 rounds." },
    };
    global.ITEM_ORDER = ["scrap", "cloth", "bandage", "medkit", "food", "energy"];
    global.HEAL_ITEMS = ["bandage", "food", "medkit"];   // order the H key uses them

    // once: gear is crafted a single time and applied permanently.
    global.RECIPES = [
        { key: "bandage", name: "Bandage",        cost: [["cloth", 2]],              gives: [["bandage", 1]], once: false, desc: "Heals 15 HP." },
        { key: "bat",     name: "Reinforced Bat", cost: [["scrap", 3], ["cloth", 1]], gives: [],               once: true,  desc: "Mr. Ramirez ATK +10." },
        { key: "vest",    name: "Riot Vest",      cost: [["scrap", 2], ["cloth", 3]], gives: [],               once: true,  desc: "Party DEF +8." },
    ];

    global.CLUES = [
        "Attendance sheet: every name is crossed out at 9:14 AM, in the same handwriting.",
        "A phone on the quad, still warm. 212 unsent messages: \"Are you there?\"",
        "Chalkboard in the lecture hall: \"THEY WERE NEVER GONE. WE WERE.\"",
        "Faculty memo: \"Do not open the east gate after the signal. Repeat: do not open.\"",
    ];
}

/// Damage after DEF: raw * 50 / (50 + def), at least 1.
function mitigate(_raw, _def) { return max(1, round(_raw * 50 / (50 + _def))); }

function has_trait(_trait) {
    for (var _i = 0; _i < array_length(global.G.party); _i++) if (global.G.party[_i].trait == _trait) return true;
    return false;
}

/* ------------------------------------------------------------------ party */

function make_member(_d) {
    var _m = {};
    var _names = variable_struct_get_names(_d);
    for (var _i = 0; _i < array_length(_names); _i++) variable_struct_set(_m, _names[_i], variable_struct_get(_d, _names[_i]));
    _m.level = 1;
    _m.xp = 0;
    _m.maxHp = _d.hp;
    _m.skills = arr_copy(_d.skills);
    _m.cd = {};
    _m.buff = undefined;
    _m.defending = false;
    _m.px = 0; _m.pz = 0; _m.py = 0; _m.face = 270; _m.moving = false;
    _m.spr = asset_get_index("spr_ch_" + _d.key);
    _m.scale = 1;
    return _m;
}

function atk_of(_m) { return _m.atk * (is_struct(_m.buff) ? _m.buff.mult : 1); }

function everyone() {
    var _a = [global.G.teacher];
    for (var _i = 0; _i < array_length(global.G.party); _i++) array_push(_a, global.G.party[_i]);
    return _a;
}

function alive_party() {
    return array_filter(everyone(), function(_m) { return _m.hp > 0; });
}

function learn(_m, _id) {
    if (_id != "" && !arr_has(_m.skills, _id)) { array_push(_m.skills, _id); return true; }
    return false;
}

/// Returns an array of level-up messages.
function gain_xp(_m, _amount) {
    var _lines = [];
    _m.xp += _amount;
    while (_m.xp >= _m.level * 25) {
        _m.xp -= _m.level * 25;
        _m.level++;
        _m.maxHp += 5; _m.hp = min(_m.maxHp, _m.hp + 5);
        _m.atk += 3; _m.def += 2;
        array_push(_lines, $"{_m.name} reached level {_m.level}!");
    }
    return _lines;
}

function inv_count(_k) { return global.G.inv[$ _k] ?? 0; }
function inv_add(_k, _n) { global.G.inv[$ _k] = inv_count(_k) + _n; }
