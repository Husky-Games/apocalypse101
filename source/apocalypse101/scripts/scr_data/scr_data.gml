// Game content, ported 1:1 from prototype/src/data.js. Tweak balance here.

function data_init() {
    // Skill "minigame" is the skill-based component of an attack (PRD: Combat).
    // target: "enemy" | "ally" | "party"
    global.SKILLS = {
        strike:      { name: "Attack",       type: "attack", target: "enemy", mult: 1.0, minigame: "",       cd: 0, stat: "atk", status: "",     desc: "A basic hit." },
        power_swing: { name: "Power Swing",  type: "attack", target: "enemy", mult: 1.9, minigame: "mash",   cd: 2, stat: "atk", status: "",     desc: "Mash to build power." },
        slingshot:   { name: "Slingshot",    type: "attack", target: "enemy", mult: 1.5, minigame: "timing", cd: 1, stat: "atk", status: "",     desc: "Time the release." },
        quiz:        { name: "Pop Quiz",     type: "attack", target: "enemy", mult: 1.7, minigame: "memory", cd: 2, stat: "int", status: "",     desc: "Remember the sequence. Uses INT." },
        flash:       { name: "Camera Flash", type: "status", target: "enemy", mult: 0.5, minigame: "timing", cd: 3, stat: "atk", status: "stun", desc: "Stuns the target for a turn." },
        patch_up:    { name: "Patch Up",     type: "heal",   target: "ally",  mult: 2.6, minigame: "timing", cd: 2, stat: "int", status: "",     desc: "Heal an ally. Uses INT." },
        rally:       { name: "Rally",        type: "buff",   target: "party", mult: 1.3, minigame: "timing", cd: 4, stat: "atk", status: "",     desc: "Party ATK +30% for 3 rounds." },
    };

    // Every student has a unique attribute set (PRD: Party Selection).
    global.STUDENTS = [
        { key: "maya",  name: "Maya Chen",     major: "Biology",     clique: "Scholars",  atk: 5, hp: 28, def: 3, int: 9, canJump: true,  colour: rgb(0x5ec8a0), skills: ["quiz"],        unlock: "patch_up",    blurb: "Top of the class.",           trait: "" },
        { key: "jake",  name: "Jake Torres",   major: "Kinesiology", clique: "Jocks",     atk: 9, hp: 36, def: 4, int: 3, canJump: true,  colour: rgb(0xe8a23c), skills: ["power_swing"], unlock: "rally",       blurb: "Hits first, thinks later.",   trait: "" },
        { key: "priya", name: "Priya Nair",    major: "Mech. Eng.",  clique: "Makers",    atk: 6, hp: 30, def: 4, int: 8, canJump: true,  colour: rgb(0x6aa0f0), skills: ["slingshot"],   unlock: "quiz",        blurb: "Can craft anywhere.",         trait: "craftAnywhere" },
        { key: "leo",   name: "Leo Park",      major: "Film",        clique: "Artists",   atk: 5, hp: 26, def: 2, int: 6, canJump: true,  colour: rgb(0xc07ae0), skills: ["flash"],       unlock: "slingshot",   blurb: "Always has a camera.",        trait: "" },
        { key: "dev",   name: "Dev Okafor",    major: "History",     clique: "Loners",    atk: 4, hp: 40, def: 6, int: 7, canJump: false, colour: rgb(0xd96a6a), skills: ["rally"],       unlock: "patch_up",    blurb: "Leg brace. Tough as nails.",  trait: "" },
        { key: "tessa", name: "Tessa Alvarez", major: "Music",       clique: "Bandmates", atk: 6, hp: 30, def: 3, int: 5, canJump: false, colour: rgb(0xe0d060), skills: ["flash"],       unlock: "power_swing", blurb: "Won't leave her cello.",      trait: "" },
    ];

    global.TEACHER = {
        key: "teacher", name: "Ms. Rivera", major: "Teacher", clique: "Faculty",
        atk: 8, hp: 40, def: 3, int: 6, canJump: true, colour: rgb(0xf2f2f2), skills: ["rally"], unlock: "", blurb: "", trait: "",
    };

    global.ENEMY_TYPES = {
        shade:  { name: "Shade",  hp: 28, atk: 7,  def: 1, xp: 12, colour: rgb(0x2a1a2e), eye: rgb(0xff3355) },
        hollow: { name: "Hollow", hp: 46, atk: 10, def: 3, xp: 20, colour: rgb(0x1a2a30), eye: rgb(0x33ffd0) },
    };

    global.ITEMS = {
        scrap:   { name: "Scrap Metal",  kind: "material",   colour: rgb(0x9aa4b0), heal: 0,  buff: 0,   desc: "" },
        cloth:   { name: "Cloth",        kind: "material",   colour: rgb(0xd8c8a0), heal: 0,  buff: 0,   desc: "" },
        bandage: { name: "Bandage",      kind: "consumable", colour: rgb(0xffffff), heal: 15, buff: 0,   desc: "Heals 15 HP." },
        medkit:  { name: "Medkit",       kind: "consumable", colour: rgb(0xff4a4a), heal: 30, buff: 0,   desc: "Heals 30 HP." },
        energy:  { name: "Energy Drink", kind: "consumable", colour: rgb(0x4aff7a), heal: 0,  buff: 1.4, desc: "ATK +40% for 3 rounds." },
    };
    global.ITEM_ORDER = ["scrap", "cloth", "bandage", "medkit", "energy"];

    // once: gear is crafted a single time and applied permanently.
    global.RECIPES = [
        { key: "bandage", name: "Bandage",        cost: [["cloth", 2]],              gives: [["bandage", 1]], once: false, desc: "Heals 15 HP." },
        { key: "bat",     name: "Reinforced Bat", cost: [["scrap", 3], ["cloth", 1]], gives: [],               once: true,  desc: "Teacher ATK +4 and learns Power Swing." },
        { key: "vest",    name: "Riot Vest",      cost: [["scrap", 2], ["cloth", 3]], gives: [],               once: true,  desc: "Party DEF +2." },
    ];

    global.CLUES = [
        "Attendance sheet: every name is crossed out at 9:14 AM, in the same handwriting.",
        "A phone on the quad, still warm. 212 unsent messages: \"Are you there?\"",
        "Chalkboard in the lecture hall: \"THEY WERE NEVER GONE. WE WERE.\"",
        "Faculty memo: \"Do not open the east gate after the signal. Repeat: do not open.\"",
    ];
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
        _m.atk += 1; _m.int += 1;
        if (_m.level % 2 == 1) _m.def += 1;
        array_push(_lines, $"{_m.name} reached level {_m.level}!");
        if (_m.level == 2 && learn(_m, _m.unlock)) array_push(_lines, $"{_m.name} learned {global.SKILLS[$ _m.unlock].name}!");
    }
    return _lines;
}

function inv_count(_k) { return global.G.inv[$ _k] ?? 0; }
function inv_add(_k, _n) { global.G.inv[$ _k] = inv_count(_k) + _n; }
