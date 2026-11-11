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
            colour: _t.colour, eye: _t.eye, stunned: false,
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
    var _has_items = inv_count("bandage") > 0 || inv_count("medkit") > 0 || inv_count("energy") > 0;
    var _opts = [{ label: "Attack", value: "strike", sub: "", disabled: false, back: false }];
    for (var _i = 0; _i < array_length(_m.skills); _i++) {
        var _id = _m.skills[_i], _sk = global.SKILLS[$ _id], _cd = _m.cd[$ _id] ?? 0;
        array_push(_opts, { label: _sk.name, value: _id, sub: _cd > 0 ? $"Recharging ({_cd})" : _sk.desc, disabled: _cd > 0, back: false });
    }
    array_push(_opts, { label: "Item", value: "item", sub: "", disabled: !_has_items, back: false });
    array_push(_opts, { label: "Defend", value: "defend", sub: "", disabled: false, back: false });
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
    var _keys = ["bandage", "medkit", "energy"];
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
                _c.log = $"{_m.name} braces for impact.";
                combat_wait(0.5, combat_end_turn);
            } else if (_v == "item") {
                combat_item_menu();
            } else {
                _c.pending_skill = _v;
                var _sk = global.SKILLS[$ _v];
                if (_sk.target == "party") { _c.pending_target = undefined; combat_run_skill(); }
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

/// q = minigame quality 0..1 (0.5 when the skill has no minigame).
function combat_resolve_skill(_q) {
    var _c = global.G.c;
    var _m = _c.active, _id = _c.pending_skill, _sk = global.SKILLS[$ _id], _target = _c.pending_target;
    var _base = _sk.stat == "int" ? _m.int : atk_of(_m);
    var _power = _base * _sk.mult * (0.5 + _q) * random_range(0.92, 1.08);
    var _extra = 0;
    if (_sk.type == "attack" || _sk.type == "status") {
        var _dmg = max(1, round(_power - _target.def));
        hit_enemy(_target, _dmg, _q >= 0.95);
        if (_target.hp <= 0) _extra = 0.45;
        if (_sk.status == "stun" && _target.hp > 0) {
            if (_q >= 0.3) { _target.stunned = true; _c.log = $"{_m.name} stuns {_target.name}!"; }
            else _c.log = "The flash fizzles.";
        } else _c.log = $"{_m.name} uses {_sk.name}: {_dmg} damage!";
    } else if (_sk.type == "heal") {
        var _amt = round(_power) + 5;
        _target.hp = min(_target.maxHp, _target.hp + _amt);
        _c.log = $"{_m.name} heals {_target.name} for {_amt}.";
    } else if (_sk.type == "buff") {
        var _alive = alive_party();
        for (var _i = 0; _i < array_length(_alive); _i++) _alive[_i].buff = { mult: 1 + (_sk.mult - 1) * (0.7 + _q * 0.6), turns: 3 };
        _c.log = $"{_m.name} rallies the party!";
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
    if (_e.stunned) {
        _e.stunned = false;
        _c.log = $"{_e.name} is stunned and can't act.";
        combat_wait(0.7, combat_enemy_next);
        return;
    }
    var _targets = alive_party();
    if (array_length(_targets) == 0) { combat_round_end(); return; }
    var _t = _targets[irandom(array_length(_targets) - 1)];
    var _dmg = max(1, round(_e.atk * random_range(0.8, 1.2)) - _t.def);
    if (_t.defending) _dmg = max(1, round(_dmg / 2));
    _t.hp = max(0, _t.hp - _dmg);
    _e.lunge = 0.4;
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
// The skill-based component of an attack: timing bar, button mashing, or memory sequence.

#macro MINI_X1 380
#macro MINI_Y1 200
#macro MINI_X2 900
#macro MINI_Y2 420

function mini_start(_type, _label) {
    var _seq = [];
    if (_type == "memory") {
        var _d = ["U", "D", "L", "R"];
        repeat (3) array_push(_seq, _d[irandom(3)]);
    }
    global.G.mini = {
        type: _type, label: _label, t: 0, pos: 1, count: 0, left: 2,
        seq: _seq, input: [], phase: "show", show_t: 1.5,
        done: false, done_t: 0, q: 0, text: "",
    };
}

function mini_finish(_q, _text) {
    var _m = global.G.mini;
    _m.done = true; _m.done_t = 0.55; _m.q = _q; _m.text = _text;
}

/// Rect for memory direction button _i (0..3: L, U, D, R).
function mini_dir_rect(_i) {
    var _w = 64, _gap = 14, _total = 4 * _w + 3 * _gap;
    var _x = (MINI_X1 + MINI_X2) / 2 - _total / 2 + _i * (_w + _gap);
    return [_x, MINI_Y2 - 70, _x + _w, MINI_Y2 - 22];
}

function mini_update(_dt) {
    var _G = global.G, _m = _G.mini;
    if (_m.done) {
        _m.done_t -= _dt;
        if (_m.done_t <= 0) { var _q = _m.q; _G.mini = undefined; combat_resolve_skill(_q); }
        return;
    }
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
    }
}
