// Turn-based, first-person combat (PRD: Combat), ported from prototype/src/main.js.
// The prototype used async/await; here the same flow is an explicit state machine:
// a menu is waiting for input, a minigame is running, or a timed pause precedes the next step.

function alive_enemies() {
    return array_filter(global.G.c.enemies, function(_e) { return _e.hp > 0; });
}

function combat_start(_group) {
    var _G = global.G;
    _G.mode = "combat";
    _G.prompt = "";
    _G.btns = [];
    var _t = global.ENEMY_TYPES[$ _group.type];
    var _n = _group.count;
    _G.c = {
        group: _group, enemies: [], active: undefined, turn: 0, eidx: 0,
        log: "", wait_t: 0, wait_fn: undefined, menu: undefined,
        pending_skill: "", pending_target: undefined, pending_item: "",
        result: "", shake: 0, flash: 0, popups: [], light: 22, shx: 0, shy: 0,
    };
    for (var _i = 0; _i < _n; _i++) {
        array_push(_G.c.enemies, {
            name: _t.name, hp: _t.hp, maxHp: _t.hp, atk: _t.atk, def: _t.def, xp: _t.xp,
            colour: _t.colour, eye: _t.eye, stun: 0, poison: 0, confuse: 0,   // status turns left
            hx: (_i - (_n - 1) / 2) * 2.6, hz: -7 - (_i mod 2),
            hitT: 0, lunge: 0, dying: -1, sc: 1.5,
        });
    }
    _G.c.log = _n > 1 ? $"{_n} {_t.name}s appear!" : $"A {_t.name} appears!";
    combat_wait(0.9, combat_round_start);
}

function combat_wait(_secs, _fn) {
    var _c = global.G.c;
    _c.menu = undefined;
    _c.wait_t = _secs;
    _c.wait_fn = _fn;
}

function combat_set_menu(_title, _kind, _opts) {
    var _G = global.G;
    _G.c.menu = { title: _title, kind: _kind, opts: _opts };
    _G.focus = 0;
    _G.btns = [];
}

function combat_update(_dt) {
    var _G = global.G, _c = _G.c;
    // visuals
    _c.shake = max(0, _c.shake - _dt);
    _c.flash = max(0, _c.flash - _dt);
    _c.light = 22 + sin(_G.time * 9) * 2 + (random(1) < 0.03 ? -14 : 0);
    for (var _i = 0; _i < array_length(_c.enemies); _i++) {
        var _e = _c.enemies[_i];
        _e.hitT = max(0, _e.hitT - _dt);
        _e.lunge = max(0, _e.lunge - _dt);
        if (_e.hp <= 0 && _e.dying > 0) _e.dying = max(0, _e.dying - _dt);
    }
    for (var _i = array_length(_c.popups) - 1; _i >= 0; _i--) {
        _c.popups[_i].t -= _dt;
        if (_c.popups[_i].t <= 0) array_delete(_c.popups, _i, 1);
    }

    if (is_struct(_G.mini)) { mini_update(_dt); return; }
    if (!is_undefined(_c.wait_fn)) {
        _c.wait_t -= _dt;
        if (_c.wait_t <= 0) {
            var _f = _c.wait_fn;
            _c.wait_fn = undefined;
            _f();
        }
        return;
    }
    if (is_struct(_c.menu)) ui_input();
}

/* ------------------------------------------------------------ turn order */

function combat_round_start() {
    global.G.c.turn = 0;
    combat_next_turn();
}

function combat_next_turn() {
    var _c = global.G.c;
    var _all = everyone();
    if (array_length(alive_enemies()) == 0) { combat_end("win"); return; }
    while (_c.turn < array_length(_all) && _all[_c.turn].hp <= 0) _c.turn++;
    if (_c.turn >= array_length(_all)) {
        _c.active = undefined;
        _c.eidx = 0;
        combat_enemy_next();
        return;
    }
    _c.active = _all[_c.turn];
    _c.log = $"{_c.active.name}'s turn";
    combat_action_menu();
}

function combat_end_turn() {
    global.G.c.turn++;
    combat_next_turn();
}

function combat_action_menu() {
    var _m = global.G.c.active;
    var _has_items = false;
    for (var _i = 0; _i < array_length(global.HEAL_ITEMS); _i++) if (inv_count(global.HEAL_ITEMS[_i]) > 0) _has_items = true;
    if (inv_count("energy") > 0) _has_items = true;
    var _opts = [{ label: "Attack", value: "strike", sub: "", disabled: false, back: false }];
    for (var _i = 0; _i < array_length(_m.skills); _i++) {
        var _id = _m.skills[_i], _sk = global.SKILLS[$ _id], _cd = _m.cd[$ _id] ?? 0;
        array_push(_opts, { label: _sk.name, value: _id, sub: _cd > 0 ? $"Recharging ({_cd})" : _sk.desc, disabled: _cd > 0, back: false });
    }
    array_push(_opts, { label: "Item", value: "item", sub: "", disabled: !_has_items, back: false });
    array_push(_opts, { label: "Defend", value: "defend", sub: "Block the next enemy hit.", disabled: false, back: false });
    combat_set_menu($"{_m.name}: choose action", "action", _opts);
}

function combat_target_menu(_kind, _menu_kind) {
    var _list = _kind == "enemy" ? alive_enemies() : everyone();
    var _opts = [];
    for (var _i = 0; _i < array_length(_list); _i++) {
        var _t = _list[_i];
        var _sub = $"HP {max(0, _t.hp)}/{_t.maxHp}" + ((_kind != "enemy" && _t.hp <= 0) ? " (KO)" : "");
        array_push(_opts, { label: _t.name, value: _t, sub: _sub, disabled: false, back: false });
    }
    array_push(_opts, { label: "Back", value: undefined, sub: "", disabled: false, back: true });
    combat_set_menu(_kind == "enemy" ? "Select target" : "Select ally", _menu_kind, _opts);
}

function combat_item_menu() {
    var _keys = ["bandage", "food", "medkit", "energy"];
    var _opts = [];
    for (var _i = 0; _i < array_length(_keys); _i++) {
        var _k = _keys[_i];
        if (inv_count(_k) > 0) array_push(_opts, { label: $"{global.ITEMS[$ _k].name} ×{inv_count(_k)}", value: _k, sub: global.ITEMS[$ _k].desc, disabled: false, back: false });
    }
    array_push(_opts, { label: "Back", value: undefined, sub: "", disabled: false, back: true });
    combat_set_menu("Use which item?", "item", _opts);
}

/// A menu option was chosen (index into the current menu).
function combat_pick(_idx) {
    var _c = global.G.c;
    if (!is_struct(_c.menu)) return;
    var _kind = _c.menu.kind;
    var _v = _c.menu.opts[_idx].value;
    _c.menu = undefined;
    var _m = _c.active;
    switch (_kind) {
        case "action":
            if (_v == "defend") {
                _m.defending = true;
                _c.log = $"{_m.name} braces to block the next hit.";
                combat_wait(0.5, combat_end_turn);
            } else if (_v == "item") {
                combat_item_menu();
            } else {
                _c.pending_skill = _v;
                var _sk = global.SKILLS[$ _v];
                if (_sk.target == "party" || _sk.target == "enemies") { _c.pending_target = undefined; combat_run_skill(); }
                else combat_target_menu(_sk.target, "target");
            }
            break;
        case "target":
            if (is_undefined(_v)) { combat_action_menu(); break; }
            _c.pending_target = _v;
            combat_run_skill();
            break;
        case "item":
            if (is_undefined(_v)) { combat_action_menu(); break; }
            _c.pending_item = _v;
            combat_target_menu("ally", "itarget");
            break;
        case "itarget":
            if (is_undefined(_v)) { combat_action_menu(); break; }
            var _k = _c.pending_item, _it = global.ITEMS[$ _k];
            inv_add(_k, -1);
            if (_it.heal > 0) { _v.hp = min(_v.maxHp, _v.hp + _it.heal); _c.log = $"{_m.name} uses {_it.name} on {_v.name}."; }
            if (_it.buff > 0) { _v.buff = { mult: _it.buff, turns: 3 }; _c.log = $"{_v.name} is energized!"; }
            combat_wait(0.65, combat_end_turn);
            break;
        case "result":
            combat_finish();
            break;
    }
}

function combat_run_skill() {
    var _sk = global.SKILLS[$ global.G.c.pending_skill];
    if (_sk.minigame != "") mini_start(_sk.minigame, _sk.name);
    else combat_resolve_skill(0.5);
}

/// q = minigame quality 0..1 (0.5 when the skill has no minigame). q >= 0.95 is a crit.
function combat_resolve_skill(_q) {
    var _c = global.G.c;
    var _m = _c.active, _id = _c.pending_skill, _sk = global.SKILLS[$ _id], _target = _c.pending_target;
    var _crit = _sk.minigame != "" && _q >= 0.95;
    var _extra = 0;
    switch (_sk.type) {
        case "attack":
            // Basic attack: half ATK. Skills: base damage plus a quarter of ATK, scaled by the minigame.
            var _raw = _id == "strike"
                ? atk_of(_m) * 0.5 * random_range(0.9, 1.1)
                : (_sk.base + atk_of(_m) * 0.25) * (0.6 + 0.4 * _q) * random_range(0.95, 1.05) * (_crit ? 1.5 : 1);
            var _list = _sk.target == "enemies" ? alive_enemies() : [_target];
            var _last = 0, _hit = 0;
            for (var _i = 0; _i < array_length(_list); _i++) {
                var _e = _list[_i];
                _last = mitigate(_raw, _e.def);
                hit_enemy(_e, _last, _crit);
                _hit++;
                if (_e.hp <= 0) { _extra = 0.45; continue; }
                if (_sk.status == "poison") _e.poison = max(_e.poison, _sk.turns);
                if (_sk.status == "confuse") _e.confuse = max(_e.confuse, _sk.turns);
            }
            var _tail = (_crit ? " Critical!" : "") + (_sk.status == "poison" ? " Poisoned!" : (_sk.status == "confuse" ? " Confused!" : ""));
            _c.log = _hit > 1 ? $"{_m.name} uses {_sk.name} on {_hit} enemies!{_tail}"
                              : (_id == "strike" ? $"{_m.name} attacks: {_last} damage." : $"{_m.name} uses {_sk.name}: {_last} damage!{_tail}");
            break;
        case "status": // Freeze Frame: stun 2 turns, 3 on a crit
            if (_q >= 0.3) {
                var _turns = _crit ? _sk.turns + 1 : _sk.turns;
                _target.stun = max(_target.stun, _turns);
                _target.hitT = 0.3;
                _c.log = $"{_m.name} snaps {_target.name}: stunned for {_turns} turns!" + (_crit ? " Perfect shot!" : "");
            } else _c.log = $"{_m.name}'s photo is too blurry. {_target.name} shakes it off.";
            break;
        case "heal": // heals every conscious ally up to base% of their max HP
            var _pct = _sk.base / 100 * max(0.25, _q);
            var _alive = alive_party(), _sum = 0;
            for (var _i = 0; _i < array_length(_alive); _i++) {
                var _a = _alive[_i], _amt = max(1, round(_a.maxHp * _pct));
                _sum += min(_amt, _a.maxHp - _a.hp);
                _a.hp = min(_a.maxHp, _a.hp + _amt);
            }
            _c.log = $"{_m.name} uses {_sk.name}: the party recovers {_sum} HP ({round(_pct * 100)}%).";
            break;
        case "buff": // Pop Quiz: +10% ATK per correct answer (3 answers -> up to 30%)
            var _boost = _sk.base / 100 * _q;
            if (_boost > 0.001) {
                var _alive2 = alive_party();
                for (var _i = 0; _i < array_length(_alive2); _i++) _alive2[_i].buff = { mult: 1 + _boost, turns: _sk.turns };
                _c.log = $"{_m.name}'s Pop Quiz pays off: party ATK +{round(_boost * 100)}% for {_sk.turns} turns!";
            } else _c.log = "Nobody remembered the answers. No boost.";
            break;
    }
    if (_sk.cd > 0) _m.cd[$ _id] = _sk.cd;
    combat_wait(0.65 + _extra, combat_end_turn);
}

function hit_enemy(_e, _dmg, _crit) {
    _e.hp -= _dmg;
    _e.hitT = 0.4;
    array_push(global.G.c.popups, { text: string(_dmg), e: _e, t: 1, crit: _crit });
    if (_e.hp <= 0) _e.dying = 0.5;
}

/* ----------------------------------------------------------- enemy phase */

function combat_enemy_next() {
    var _c = global.G.c;
    var _n = array_length(_c.enemies);
    while (_c.eidx < _n && _c.enemies[_c.eidx].hp <= 0) _c.eidx++;
    if (_c.eidx >= _n) { combat_round_end(); return; }
    var _e = _c.enemies[_c.eidx];
    _c.eidx++;
    // Poison ticks at the start of the enemy's turn
    if (_e.poison > 0) {
        _e.poison--;
        var _pd = max(1, round(_e.maxHp * 0.06));
        hit_enemy(_e, _pd, false);
        if (_e.hp <= 0) { _c.log = $"{_e.name} succumbs to the poison."; combat_wait(0.9, combat_enemy_next); return; }
    }
    if (_e.stun > 0) {
        _e.stun--;
        _c.log = $"{_e.name} is stunned and can't act." + (_e.stun > 0 ? $" ({_e.stun} more)" : "");
        combat_wait(0.7, combat_enemy_next);
        return;
    }
    if (_e.confuse > 0) {
        _e.confuse--;
        if (random(1) < 0.5) {
            var _others = alive_enemies();
            var _v = _others[irandom(array_length(_others) - 1)];
            var _cd2 = mitigate(_e.atk * 0.5 * random_range(0.8, 1.2), _v.def);
            hit_enemy(_v, _cd2, false);
            _e.lunge = 0.3;
            _c.log = _v == _e ? $"{_e.name} is confused and hurts itself for {_cd2}!" : $"{_e.name} is confused and strikes another {_v.name} for {_cd2}!";
            combat_wait(0.8, combat_enemy_next);
            return;
        }
    }
    var _targets = alive_party();
    if (array_length(_targets) == 0) { combat_round_end(); return; }
    var _t = _targets[irandom(array_length(_targets) - 1)];
    _e.lunge = 0.4;
    if (_t.defending) {
        _t.defending = false; // Defend blocks one hit completely
        _c.log = $"{_e.name} attacks {_t.name}, but the hit is blocked!";
        combat_wait(0.8, combat_enemy_next);
        return;
    }
    var _dmg = mitigate(_e.atk * 0.5 * random_range(0.8, 1.2), _t.def);
    _t.hp = max(0, _t.hp - _dmg);
    _c.shake = 0.35;
    _c.flash = 0.08;
    _c.log = $"{_e.name} hits {_t.name} for {_dmg}" + (_t.hp <= 0 ? ". They collapse!" : ".");
    combat_wait(0.8, combat_enemy_next);
}

function combat_round_end() {
    if (array_length(alive_party()) == 0) { combat_end("lose"); return; }
    var _all = everyone();
    for (var _i = 0; _i < array_length(_all); _i++) {
        var _m = _all[_i];
        var _ks = variable_struct_get_names(_m.cd);
        for (var _k = 0; _k < array_length(_ks); _k++) variable_struct_set(_m.cd, _ks[_k], max(0, variable_struct_get(_m.cd, _ks[_k]) - 1));
        _m.defending = false;
        if (is_struct(_m.buff)) { _m.buff.turns--; if (_m.buff.turns <= 0) _m.buff = undefined; }
    }
    combat_round_start();
}

/* ----------------------------------------------------------- end of fight */

function combat_end(_result) {
    var _c = global.G.c;
    _c.result = _result;
    _c.active = undefined;
    if (_result == "win") {
        var _alive = alive_party();
        var _sum = 0;
        for (var _i = 0; _i < array_length(_c.enemies); _i++) _sum += _c.enemies[_i].xp;
        var _xp = ceil(_sum / array_length(_alive));
        var _lines = [ $"Victory! Each survivor gains {_xp} XP."];
        for (var _i = 0; _i < array_length(_alive); _i++) {
            var _lv = gain_xp(_alive[_i], _xp);
            for (var _j = 0; _j < array_length(_lv); _j++) array_push(_lines, _lv[_j]);
        }
        var _loot = [];
        for (var _i = 0; _i < array_length(_c.enemies); _i++) {
            if (random(1) < 0.7) array_push(_loot, random(1) < 0.5 ? "scrap" : "cloth");
            if (random(1) < 0.15) array_push(_loot, "bandage");
        }
        var _names = [];
        for (var _i = 0; _i < array_length(_loot); _i++) { inv_add(_loot[_i], 1); array_push(_names, global.ITEMS[$ _loot[_i]].name); }
        if (array_length(_loot) > 0) array_push(_lines, "Loot: " + str_join(_names, ", "));
        _c.log = _lines[0];
        combat_set_menu(str_join(_lines, "\n"), "result", [{ label: "Continue", value: true, sub: "", disabled: false, back: false }]);
    } else {
        _c.log = "";
        combat_set_menu("The party collapses… You wake in the classroom.", "result", [{ label: "Continue", value: true, sub: "", disabled: false, back: false }]);
    }
}

function combat_finish() {
    var _G = global.G, _c = _G.c;
    var _all = everyone();
    if (_c.result == "win") {
        arr_remove(_G.enemies, _c.group);
    } else {
        for (var _i = 0; _i < array_length(_all); _i++) _all[_i].hp = ceil(_all[_i].maxHp / 2);
        _G.teacher.px = -20; _G.teacher.pz = 0;
        party_place();
        _c.group.x = _c.group.hx; _c.group.z = _c.group.hz;
        _c.group.tx = _c.group.hx; _c.group.tz = _c.group.hz;
    }
    for (var _i = 0; _i < array_length(_all); _i++) { _all[_i].buff = undefined; _all[_i].defending = false; _all[_i].cd = {}; }
    _G.c = undefined;
    _G.btns = [];
    _G.mode = "explore";
    if (array_length(_G.clues) == array_length(global.CLUES) && !_G.finished) finish_demo();
}

/* -------------------------------------------------------------- minigames */
// The skill-based component of each attack (PRD: Combat). Every minigame ends with
// mini_finish(q, text), q = quality 0..1 (q >= 0.95 is a crit / perfect result).
//   timing    - stop the marker in the green          (Homerun, Death Blade)
//   mash      - mash confirm                           (Chemical Burn)
//   memory    - repeat an arrow sequence               (Pop Quiz)
//   focus     - turn the lens until the photo is sharp (Freeze Frame)
//   stir      - stir the pot W -> D -> S -> A, round   (Soup's On)
//   chords    - strike 4 chords as they reach the line (Encore)
//   trace     - trace the paint stroke                 (Creative License)
//   operation - steer through the channel, no touching (Invasive Surgery)

#macro MINI_X1 300
#macro MINI_Y1 130
#macro MINI_X2 980
#macro MINI_Y2 510
// play area inside the panel (below the title and instructions)
#macro MINI_AX1 (MINI_X1 + 30)
#macro MINI_AY1 (MINI_Y1 + 96)
#macro MINI_AX2 (MINI_X2 - 30)
#macro MINI_AY2 (MINI_Y2 - 50)

function mini_start(_type, _label) {
    var _m = {
        type: _type, label: _label, t: 0, pos: 1, count: 0, left: 2,
        seq: [], input: [], phase: "show", show_t: 1.5,
        done: false, done_t: 0, q: 0, text: "", flash: 0,
    };
    switch (_type) {
        case "memory":
            var _d = ["U", "D", "L", "R"];
            repeat (3) array_push(_m.seq, _d[irandom(3)]);
            break;
        case "focus":
            _m.target = random_range(0.2, 0.8);
            _m.focus = _m.target > 0.5 ? random_range(0, _m.target - 0.3) : random_range(_m.target + 0.3, 1);
            _m.left = 5;
            break;
        case "stir":
            _m.left = 3.5; _m.last = -1; _m.angle = 90; _m.goal = 18;
            break;
        case "chords":
            _m.hits = [-1, -1, -1, -1];          // quality per chord, -1 = not yet judged
            _m.times = [1.1, 1.75, 2.4, 3.05];   // when each chord reaches the strike line
            _m.judge = ["", "", "", ""];
            break;
        case "trace":
        case "operation":
            // a wavy path across the play area
            var _n = _type == "trace" ? 9 : 12;
            _m.path = [];
            var _w = MINI_AX2 - MINI_AX1 - 60, _h = MINI_AY2 - MINI_AY1 - 40;
            var _ph = random(2 * pi), _amp = _h * (_type == "trace" ? 0.38 : 0.32);
            for (var _i = 0; _i < _n; _i++) {
                var _f = _i / (_n - 1);
                array_push(_m.path, [MINI_AX1 + 30 + _f * _w, (MINI_AY1 + MINI_AY2) / 2 + sin(_ph + _f * pi * 2.2) * _amp + random_range(-12, 12)]);
            }
            _m.cx = _m.path[0][0]; _m.cy = _m.path[0][1];
            _m.next = 1; _m.smudges = 0; _m.off = false;
            _m.touches = 0; _m.safe = 0; _m.best = 0;
            _m.halfw = 17;
            _m.left = _type == "trace" ? 6 : 8;
            break;
    }
    global.G.mini = _m;
}

function mini_finish(_q, _text) {
    var _m = global.G.mini;
    _m.done = true; _m.done_t = 0.75; _m.q = clamp(_q, 0, 1); _m.text = _text;
}

/// Rect for memory direction button _i (0..3: L, U, D, R).
function mini_dir_rect(_i) {
    var _w = 64, _gap = 14, _total = 4 * _w + 3 * _gap;
    var _x = (MINI_X1 + MINI_X2) / 2 - _total / 2 + _i * (_w + _gap);
    return [_x, MINI_Y2 - 110, _x + _w, MINI_Y2 - 62];
}

/// Held direction for continuous movement: arrows / WASD / left stick / d-pad -> [x, y].
function mini_axis() {
    var _ax = (key_any([vk_right, ord("D")]) ? 1 : 0) - (key_any([vk_left, ord("A")]) ? 1 : 0);
    var _ay = (key_any([vk_down, ord("S")]) ? 1 : 0) - (key_any([vk_up, ord("W")]) ? 1 : 0);
    var _p = global.G.pad;
    if (_p >= 0) {
        var _sx = gamepad_axis_value(_p, gp_axislh), _sy = gamepad_axis_value(_p, gp_axislv);
        if (abs(_sx) > 0.2) _ax += _sx;
        if (abs(_sy) > 0.2) _ay += _sy;
        _ax += (gamepad_button_check(_p, gp_padr) ? 1 : 0) - (gamepad_button_check(_p, gp_padl) ? 1 : 0);
        _ay += (gamepad_button_check(_p, gp_padd) ? 1 : 0) - (gamepad_button_check(_p, gp_padu) ? 1 : 0);
    }
    var _l = point_distance(0, 0, _ax, _ay);
    if (_l > 1) { _ax /= _l; _ay /= _l; }
    return [_ax, _ay];
}

/// Distance from (px,py) to the polyline; returns [distance, progress 0..1 along it].
function mini_path_dist(_path, _px, _py) {
    var _best = 1000000, _prog = 0, _n = array_length(_path);
    for (var _i = 0; _i < _n - 1; _i++) {
        var _ax = _path[_i][0], _ay = _path[_i][1], _bx = _path[_i + 1][0], _by = _path[_i + 1][1];
        var _dx = _bx - _ax, _dy = _by - _ay, _l2 = _dx * _dx + _dy * _dy;
        var _t = _l2 > 0 ? clamp(((_px - _ax) * _dx + (_py - _ay) * _dy) / _l2, 0, 1) : 0;
        var _d = point_distance(_px, _py, _ax + _dx * _t, _ay + _dy * _t);
        if (_d < _best) { _best = _d; _prog = (_i + _t) / (_n - 1); }
    }
    return [_best, _prog];
}

/// Move the brush / tweezers: keys & stick, or drag with the mouse.
function mini_move_cursor(_m, _dt, _speed) {
    if (mouse_check_button(mb_left)) {
        var _mx = device_mouse_x_to_gui(0), _my = device_mouse_y_to_gui(0);
        var _dx = _mx - _m.cx, _dy = _my - _m.cy, _d = point_distance(0, 0, _dx, _dy);
        var _step = _speed * 1.6 * _dt;   // mouse is faster but still continuous (no teleporting)
        if (_d > _step) { _dx *= _step / _d; _dy *= _step / _d; }
        _m.cx += _dx; _m.cy += _dy;
    } else {
        var _a = mini_axis();
        _m.cx += _a[0] * _speed * _dt; _m.cy += _a[1] * _speed * _dt;
    }
    _m.cx = clamp(_m.cx, MINI_AX1, MINI_AX2);
    _m.cy = clamp(_m.cy, MINI_AY1, MINI_AY2);
}

function mini_update(_dt) {
    var _G = global.G, _m = _G.mini;
    if (_m.done) {
        _m.done_t -= _dt;
        if (_m.done_t <= 0) { var _qf = _m.q; _G.mini = undefined; combat_resolve_skill(_qf); }
        return;
    }
    _m.flash = max(0, _m.flash - _dt);
    var _mx = device_mouse_x_to_gui(0), _my = device_mouse_y_to_gui(0);
    var _click = mouse_check_button_pressed(mb_left) && point_in_rectangle(_mx, _my, MINI_X1, MINI_Y1, MINI_X2, MINI_Y2);
    var _confirm = key_any_pressed([vk_space, vk_enter, ord("E")]) || pad_pressed(gp_face1) || _click;

    switch (_m.type) {
        case "timing":
            _m.t += _dt;
            _m.pos = abs(((_m.t * 0.95) mod 2) - 1);
            if (_confirm) {
                var _d = abs(_m.pos - 0.5);
                var _q = _d < 0.06 ? 1 : clamp(1 - (_d - 0.06) * 2.2, 0, 1);
                mini_finish(_q, _q >= 0.95 ? "Perfect!" : (_q >= 0.5 ? "Good" : "Weak"));
            }
            break;

        case "mash":
            if (_confirm) _m.count++;
            _m.left -= _dt;
            if (_m.left <= 0) {
                var _q2 = min(1, _m.count / 14);
                mini_finish(_q2, _q2 >= 0.95 ? "Maximum power!" : $"{_m.count} hits");
            }
            break;

        case "memory":
            if (_m.phase == "show") {
                _m.show_t -= _dt;
                if (_m.show_t <= 0) _m.phase = "input";
                break;
            }
            var _dir = inp_dir();
            if (_dir == "" && mouse_check_button_pressed(mb_left)) {
                var _order = ["L", "U", "D", "R"];
                for (var _i = 0; _i < 4; _i++) {
                    var _r = mini_dir_rect(_i);
                    if (point_in_rectangle(_mx, _my, _r[0], _r[1], _r[2], _r[3])) _dir = _order[_i];
                }
            }
            if (_dir != "") {
                array_push(_m.input, _dir);
                if (array_length(_m.input) == 3) {
                    var _ok = 0;
                    for (var _i = 0; _i < 3; _i++) if (_m.input[_i] == _m.seq[_i]) _ok++;
                    mini_finish(_ok / 3, _ok == 3 ? "Perfect recall!" : $"{_ok}/3 correct");
                }
            }
            break;

        case "focus": // turn the lens with up/down (or the mouse wheel) until the photo is sharp
            var _a = mini_axis();
            _m.focus = clamp(_m.focus - _a[1] * 0.42 * _dt
                + (mouse_wheel_up() ? 0.035 : 0) - (mouse_wheel_down() ? 0.035 : 0), 0, 1);
            _m.left -= _dt;
            if (_confirm || _m.left <= 0) {
                var _err = abs(_m.focus - _m.target);
                var _q3 = _err < 0.03 ? 1 : clamp(1 - (_err - 0.03) / 0.3, 0, 1);
                if (_m.left <= 0 && !_confirm) _q3 *= 0.5; // the moment passed
                mini_finish(_q3, _q3 >= 0.95 ? "Crystal clear!" : (_q3 >= 0.3 ? "Got the shot" : "Too blurry"));
            }
            break;

        case "stir": // W -> D -> S -> A (or the reverse): each step round the pot counts
            var _sd = inp_dir();
            if (_sd != "") {
                var _idx = _sd == "U" ? 0 : (_sd == "R" ? 1 : (_sd == "D" ? 2 : 3));
                if (_m.last < 0 || _idx == (_m.last + 1) mod 4 || _idx == (_m.last + 3) mod 4) {
                    if (_m.last >= 0) _m.count++;
                    _m.last = _idx;
                    _m.angle = 90 - _idx * 90;
                } else _m.flash = 0.15; // same key or straight across: no stir
            }
            _m.left -= _dt;
            if (_m.left <= 0) {
                var _q4 = min(1, _m.count / _m.goal);
                mini_finish(_q4, _q4 >= 0.95 ? "Perfectly stirred!" : $"{_m.count} stirs");
            }
            break;

        case "chords": // strike each chord as it crosses the line
            _m.t += _dt;
            if (_confirm) {
                var _bi = -1, _bd = 0.3;
                for (var _i = 0; _i < 4; _i++) if (_m.hits[_i] < 0 && abs(_m.t - _m.times[_i]) < _bd) { _bd = abs(_m.t - _m.times[_i]); _bi = _i; }
                if (_bi >= 0) {
                    var _hq = _bd < 0.05 ? 1 : clamp(1 - (_bd - 0.05) / 0.25, 0, 1);
                    _m.hits[_bi] = _hq;
                    _m.judge[_bi] = _hq >= 0.95 ? "Perfect" : (_hq >= 0.4 ? "Good" : "Off");
                }
            }
            var _all = true, _sum = 0, _perfect = 0, _made = 0;
            for (var _i = 0; _i < 4; _i++) {
                if (_m.hits[_i] < 0 && _m.t > _m.times[_i] + 0.3) { _m.hits[_i] = 0; _m.judge[_i] = "Miss"; }
                if (_m.hits[_i] < 0) _all = false;
                else { _sum += _m.hits[_i]; if (_m.hits[_i] >= 0.95) _perfect++; if (_m.hits[_i] >= 0.4) _made++; }
            }
            if (_all) {
                var _q5 = _sum / 4;
                mini_finish(_q5, _perfect == 4 ? "Standing ovation!" : $"{_made}/4 chords");
            }
            break;

        case "trace": // follow the paint stroke from dot to dot without wandering off
            mini_move_cursor(_m, _dt, 240);
            var _np = array_length(_m.path);
            if (_m.next < _np && point_distance(_m.cx, _m.cy, _m.path[_m.next][0], _m.path[_m.next][1]) < 18) _m.next++;
            var _pd = mini_path_dist(_m.path, _m.cx, _m.cy)[0];
            if (_pd > 30 && !_m.off) { _m.off = true; _m.smudges++; _m.flash = 0.25; }
            if (_pd < 18) _m.off = false;
            _m.left -= _dt;
            if (_m.next >= _np || _m.left <= 0) {
                var _q6 = (_m.next - 1) / (_np - 1) * max(0, 1 - 0.2 * _m.smudges);
                if (_m.next >= _np && _m.smudges == 0) _q6 = 1;
                mini_finish(_q6, _q6 >= 0.95 ? "A masterpiece!" : (_m.next >= _np ? $"Done, {_m.smudges} smudge" + (_m.smudges == 1 ? "" : "s") : "Unfinished"));
            }
            break;

        case "operation": // steer the tweezers through the channel; touching the edge buzzes
            mini_move_cursor(_m, _dt, 170);
            _m.safe = max(0, _m.safe - _dt);
            var _pp = mini_path_dist(_m.path, _m.cx, _m.cy);
            _m.best = max(_m.best, _pp[1]);
            if (_pp[0] > _m.halfw && _m.safe <= 0) {
                _m.touches++; _m.flash = 0.35; _m.safe = 0.6;
                // snap back onto the channel at the furthest safe point reached
                var _seg = _m.best * (array_length(_m.path) - 1), _si = min(floor(_seg), array_length(_m.path) - 2), _st = _seg - _si;
                _m.cx = lerp(_m.path[_si][0], _m.path[_si + 1][0], _st);
                _m.cy = lerp(_m.path[_si][1], _m.path[_si + 1][1], _st);
            }
            _m.left -= _dt;
            var _end = _m.path[array_length(_m.path) - 1];
            var _reached = point_distance(_m.cx, _m.cy, _end[0], _end[1]) < 16;
            if (_reached || _m.left <= 0) {
                var _q7 = _reached ? max(0, 1 - 0.25 * _m.touches) : _m.best * 0.5 * max(0, 1 - 0.25 * _m.touches);
                mini_finish(_q7, _q7 >= 0.95 ? "Flawless operation!" : (_reached ? $"Done, {_m.touches} slip" + (_m.touches == 1 ? "" : "s") : "Ran out of time"));
            }
            break;
    }
}
