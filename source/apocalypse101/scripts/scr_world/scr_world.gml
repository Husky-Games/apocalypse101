// World layout and exploration, ported from prototype/src/main.js.

function game_init() {
    data_init();
    global.G = {
        mode: "ui",            // ui | explore | combat
        overlay: "",           // roster | craft | journal | finish
        overlay_closable: false,
        intro: true,
        inv: { scrap: 0, cloth: 0, bandage: 1, medkit: 0, energy: 0 },
        clues: [],
        crafted: {},
        fence_cleared: false,
        finished: false,
        finish_pending: -1,
        teacher: undefined,
        roster: [],
        party: [],
        sel: [],
        time: 0,
        dt: 0,
        pad: -1,
        stick_latch: false,
        toast_text: "",
        toast_t: 0,
        prompt: "",
        // world
        colliders: [],
        boxes: [],
        trees: [],
        tables: [],
        items: [],
        enemies: [],
        fence: undefined,
        cam_x: 0, cam_y: 0,
        // ui buttons registered by the GUI each frame
        btns: [],
        focus: 0,
        focus_want: "",
        mouse_last_x: 0, mouse_last_y: 0,
        // combat + minigame
        c: undefined,
        mini: undefined,
    };
    world_build();
    party_build();
    var _t = global.G.teacher;
    global.G.cam_x = wx(_t.px) - GUI_W / 2;
    global.G.cam_y = wy(_t.pz) - GUI_H / 2;
    roster_open(true);
}

/* ------------------------------------------------------------ world build */

function add_box(_x, _z, _w, _d, _h, _col, _collide = true, _y = 0, _kind = "box") {
    var _b = { x1: _x - _w / 2, x2: _x + _w / 2, z1: _z - _d / 2, z2: _z + _d / 2, h: _h, y: _y, colour: _col, kind: _kind, squash: 1 };
    array_push(global.G.boxes, _b);
    var _c = undefined;
    if (_collide) {
        _c = { minX: _b.x1, maxX: _b.x2, minZ: _b.z1, maxZ: _b.z2 };
        array_push(global.G.colliders, _c);
    }
    return { box: _b, col: _c };
}

function add_tree(_x, _z) {
    array_push(global.G.trees, { x: _x, z: _z });
    array_push(global.G.colliders, { minX: _x - 0.4, maxX: _x + 0.4, minZ: _z - 0.4, maxZ: _z + 0.4 });
}

function add_table(_x, _z) {
    add_box(_x, _z, 2.4, 1.2, 1, rgb(0x8a5a2a), true, 0, "table");
    array_push(global.G.tables, { x: _x, z: _z });
}

function add_item(_type, _x, _z) {
    array_push(global.G.items, { type: _type, x: _x, z: _z, phase: random(6) });
}

function add_explore_enemy(_type, _count, _x, _z) {
    array_push(global.G.enemies, {
        type: _type, count: _count, x: _x, z: _z, hx: _x, hz: _z, tx: _x, tz: _z, wait: 0,
        scale: 0.85 + _count * 0.12, face: 0,
    });
}

function world_build() {
    var _wall = rgb(0xc9c2b0);
    // Classroom (home base)
    add_box(-22, -8, 12.6, 0.6, 3, _wall);
    add_box(-22, 8, 12.6, 0.6, 3, _wall);
    add_box(-28, 0, 0.6, 16.6, 3, _wall);
    add_box(-16, -5, 0.6, 6, 3, _wall);
    add_box(-16, 5, 0.6, 6, 3, _wall);
    var _desks = [[-26, 3.5], [-23, 3.5], [-20, 3.5], [-26, 6], [-23, 6], [-20, 6]];
    for (var _i = 0; _i < array_length(_desks); _i++) add_box(_desks[_i][0], _desks[_i][1], 2, 1, 0.8, rgb(0x7a5a3a), true, 0, "desk");
    add_box(-20, -7.5, 4, 0.3, 2, rgb(0xf4f4f4), false, 0.6, "board"); // roster whiteboard
    add_table(-26, -5.5);

    // Campus
    add_box(-4, -12, 10, 6, 4, rgb(0x6d6a78), true, 0, "building"); // lecture hall
    add_box(6, 10, 9, 7, 4, rgb(0x7a6a5a), true, 0, "building");    // library
    add_box(-9, 12, 3, 2, 1.2, rgb(0x555b66), true, 0, "car");      // wrecked cars
    add_box(10, -4, 2, 2, 1.2, rgb(0x555b66), true, 0, "car");
    var _trees = [[-12, 8], [-10, -4], [3, 4], [12, 5], [13, -14], [-2, 17], [8, -9], [22, 15], [27, -6], [19, -15]];
    for (var _i = 0; _i < array_length(_trees); _i++) add_tree(_trees[_i][0], _trees[_i][1]);

    // The fence (needs the whole party to clear it)
    global.G.fence = add_box(FENCE_X, 0, 0.7, 40, 2.4, rgb(0xa85a2a), true, 0, "fence");
    // East quad
    add_table(24, -10);
    add_box(22, 10, 4, 3, 2.4, rgb(0x4a3d5a), true, 0, "shed");

    // Items
    var _spots = [
        ["cloth", -10, 4], ["cloth", -12, -7], ["scrap", -8, -1], ["scrap", 2, -3], ["scrap", 5, 3], ["medkit", 0, 14],
        ["energy", 10, -12], ["clue", -6, -7.5], ["clue", 8, -7],
        ["scrap", 22, 6], ["cloth", 20, -4], ["cloth", 25, 4], ["medkit", 26, 13], ["energy", 21, 14], ["scrap", 28, -12],
        ["clue", 27, -15], ["clue", 28, 1],
    ];
    for (var _i = 0; _i < array_length(_spots); _i++) add_item(_spots[_i][0], _spots[_i][1], _spots[_i][2]);

    // Enemies
    var _groups = [
        ["shade", 1, -8, 9], ["shade", 2, 2, -6], ["shade", 1, 9, 0], ["shade", 2, 11, 14], ["shade", 1, -3, 16],
        ["hollow", 2, 22, -5], ["hollow", 3, 24, 9],
    ];
    for (var _i = 0; _i < array_length(_groups); _i++) add_explore_enemy(_groups[_i][0], _groups[_i][1], _groups[_i][2], _groups[_i][3]);
}

/* ------------------------------------------------------------ party setup */

function party_build() {
    var _G = global.G;
    _G.teacher = make_member(global.TEACHER);
    _G.teacher.scale = 1.12;
    _G.teacher.px = -20; _G.teacher.pz = 0;
    _G.roster = [];
    for (var _i = 0; _i < array_length(global.STUDENTS); _i++) array_push(_G.roster, make_member(global.STUDENTS[_i]));
    party_place();
}

function party_place() {
    var _G = global.G;
    var _idle = [[-26, -2.5], [-24.4, -2.5], [-22.8, -2.5], [-21.2, -2.5], [-19.6, -2.5], [-18, -2.5]];
    var _t = _G.teacher;
    for (var _i = 0; _i < array_length(_G.roster); _i++) {
        var _m = _G.roster[_i];
        var _k = array_get_index(_G.party, _m);
        if (_k >= 0) { _m.px = _t.px - 1 - _k * 0.2; _m.pz = _t.pz + 0.8 + _k * 0.8; }
        else { _m.px = _idle[_i][0]; _m.pz = _idle[_i][1]; }
        _m.py = 0;
    }
}

/* ------------------------------------------------------------ exploration */

function near_table(_x, _z, _r = 2.6) {
    var _tb = global.G.tables;
    for (var _i = 0; _i < array_length(_tb); _i++) if (point_distance(_tb[_i].x, _tb[_i].z, _x, _z) < _r) return true;
    return false;
}

function in_classroom(_x) { return _x < CLASSROOM_MAX_X; }

/// Returns { label, action } or undefined.
function find_interact() {
    var _t = global.G.teacher;
    if (near_table(_t.px, _t.pz)) return { label: "E / Space / A: Craft", action: "craft" };
    if (point_distance(_t.px, _t.pz, -20, -6.4) < 3) return { label: "E / Space / A: Change party", action: "roster" };
    if (!global.G.fence_cleared && abs(_t.px - FENCE_X) < 2.4) return { label: "E / Space / A: Jump the fence", action: "fence" };
    return undefined;
}

function interact() {
    var _a = find_interact();
    if (is_undefined(_a)) return;
    switch (_a.action) {
        case "craft": craft_open(); break;
        case "roster": roster_open(false); break;
        case "fence": try_fence(); break;
    }
}

function try_fence() {
    var _G = global.G;
    var _blockers = [];
    for (var _i = 0; _i < array_length(_G.party); _i++) if (!_G.party[_i].canJump) array_push(_blockers, _G.party[_i].name);
    if (array_length(_blockers) > 0) {
        toast($"{str_join(_blockers, " and ")} can't clear the fence. No one gets left behind. Swap them out at the classroom board.", 4.5);
        return;
    }
    _G.fence_cleared = true;
    arr_remove(_G.colliders, _G.fence.col);
    _G.fence.box.squash = 0.25;
    toast("The whole party vaults the fence together.");
}

function craft_anywhere() {
    var _ok = false;
    for (var _i = 0; _i < array_length(global.G.party); _i++) if (global.G.party[_i].trait == "craftAnywhere") _ok = true;
    if (_ok) craft_open();
    else toast("You need a table, or a crafter in the party (Priya).");
}

function heal_lowest() {
    var _targets = array_filter(everyone(), function(_m) { return _m.hp < _m.maxHp; });
    if (array_length(_targets) == 0) { toast("Everyone is healthy."); return; }
    var _item = inv_count("bandage") > 0 ? "bandage" : (inv_count("medkit") > 0 ? "medkit" : "");
    if (_item == "") { toast("No healing items. Craft bandages from cloth."); return; }
    array_sort(_targets, function(_a, _b) { return (_a.hp / _a.maxHp) - (_b.hp / _b.maxHp); });
    var _t = _targets[0];
    inv_add(_item, -1);
    _t.hp = min(_t.maxHp, _t.hp + global.ITEMS[$ _item].heal);
    toast($"{_t.name} used a {global.ITEMS[$ _item].name}.");
}

function pickup(_node) {
    var _G = global.G;
    arr_remove(_G.items, _node);
    if (_node.type == "clue") {
        var _text = global.CLUES[array_length(_G.clues) mod array_length(global.CLUES)];
        array_push(_G.clues, _text);
        toast($"Clue: {_text}", 6);
        if (array_length(_G.clues) == array_length(global.CLUES)) _G.finish_pending = 6.2;
    } else {
        inv_add(_node.type, 1);
        toast($"Picked up {global.ITEMS[$ _node.type].name}.", 1.6);
    }
}

function finish_demo() {
    var _G = global.G;
    if (_G.finished || _G.mode == "combat") return;
    _G.finished = true;
    overlay_open("finish", true);
}

/// Push a circle of radius _r (at struct _p.{px,pz} or .{x,z}) out of all colliders.
function resolve_pos(_x, _z, _r) {
    var _cs = global.G.colliders;
    for (var _i = 0; _i < array_length(_cs); _i++) {
        var _c = _cs[_i];
        var _cx = clamp(_x, _c.minX, _c.maxX), _cz = clamp(_z, _c.minZ, _c.maxZ);
        var _dx = _x - _cx, _dz = _z - _cz, _d2 = _dx * _dx + _dz * _dz;
        if (_d2 >= _r * _r) continue;
        if (_d2 > 0.00000001) {
            var _d = sqrt(_d2);
            _x = _cx + (_dx / _d) * _r; _z = _cz + (_dz / _d) * _r;
        } else {
            var _l = _x - _c.minX, _rr = _c.maxX - _x, _tp = _z - _c.minZ, _bt = _c.maxZ - _z;
            var _m = min(_l, _rr, _tp, _bt);
            if (_m == _l) _x = _c.minX - _r;
            else if (_m == _rr) _x = _c.maxX + _r;
            else if (_m == _tp) _z = _c.minZ - _r;
            else _z = _c.maxZ + _r;
        }
    }
    return [clamp(_x, -BOUND_X, BOUND_X), clamp(_z, -BOUND_Z, BOUND_Z)];
}

function explore_update(_dt) {
    var _G = global.G;
    var _t = _G.teacher;

    // Actions
    if (key_any_pressed([ord("E"), vk_space]) || pad_pressed(gp_face1)) { interact(); return; }
    if (keyboard_check_pressed(ord("H")) || pad_pressed(gp_face3)) heal_lowest();
    if (keyboard_check_pressed(ord("C")) || pad_pressed(gp_face4)) { craft_anywhere(); if (_G.mode != "explore") return; }
    if (keyboard_check_pressed(ord("J")) || pad_pressed(gp_start)) { overlay_open("journal", true); return; }

    // Movement (cardinal + diagonal, keyboard or left stick)
    var _ix = (key_any([ord("D"), vk_right]) ? 1 : 0) - (key_any([ord("A"), vk_left]) ? 1 : 0);
    var _iz = (key_any([ord("S"), vk_down]) ? 1 : 0) - (key_any([ord("W"), vk_up]) ? 1 : 0);
    if (_G.pad >= 0) {
        var _ax = gamepad_axis_value(_G.pad, gp_axislh), _ay = gamepad_axis_value(_G.pad, gp_axislv);
        if (abs(_ax) >= 0.2) _ix += _ax;
        if (abs(_ay) >= 0.2) _iz += _ay;
        _ix += (gamepad_button_check(_G.pad, gp_padr) ? 1 : 0) - (gamepad_button_check(_G.pad, gp_padl) ? 1 : 0);
        _iz += (gamepad_button_check(_G.pad, gp_padd) ? 1 : 0) - (gamepad_button_check(_G.pad, gp_padu) ? 1 : 0);
    }
    var _len = point_distance(0, 0, _ix, _iz);
    var _moving = _len > 0.01;
    if (_moving) {
        _ix /= max(1, _len); _iz /= max(1, _len);
        var _p = resolve_pos(_t.px + _ix * 6.5 * _dt, _t.pz + _iz * 6.5 * _dt, 0.5);
        _t.px = _p[0]; _t.pz = _p[1];
        _t.face = point_direction(0, 0, _ix, _iz);
    }
    _t.py = _moving ? abs(sin(_G.time * 11)) * 0.08 : 0;

    // Followers trail the leader; the party moves as one.
    for (var _i = 0; _i < array_length(_G.party); _i++) {
        var _m = _G.party[_i];
        var _L = _i == 0 ? _t : _G.party[_i - 1];
        var _dx = _L.px - _m.px, _dz = _L.pz - _m.pz, _d = point_distance(0, 0, _dx, _dz);
        var _active = false;
        if (_d > 1.5) {
            var _s = min(_d - 1.5, 8 * _dt);
            var _p2 = resolve_pos(_m.px + (_dx / _d) * _s, _m.pz + (_dz / _d) * _s, 0.4);
            _m.px = _p2[0]; _m.pz = _p2[1];
            _m.face = point_direction(0, 0, _dx, _dz);
            _active = true;
        }
        _m.py = _active ? abs(sin(_G.time * 11)) * 0.08 : 0;
    }

    // Hop over the lowered fence
    if (_G.fence_cleared) {
        var _all = everyone();
        for (var _i = 0; _i < array_length(_all); _i++) {
            var _fx = abs(_all[_i].px - FENCE_X);
            if (_fx < 1.8) _all[_i].py += 1.1 * (1 - _fx / 1.8);
        }
    }

    // Enemies wander, and chase outside the classroom
    var _safe = in_classroom(_t.px);
    for (var _i = 0; _i < array_length(_G.enemies); _i++) {
        var _e = _G.enemies[_i];
        var _d = point_distance(_t.px, _t.pz, _e.x, _e.z);
        var _speed = 1.6;
        if (!_safe && _d < 7.5) { _e.tx = _t.px; _e.tz = _t.pz; _speed = 3.3; }
        else {
            _e.wait -= _dt;
            if (_e.wait <= 0 || point_distance(_e.tx, _e.tz, _e.x, _e.z) < 0.5) {
                _e.tx = _e.hx + random_range(-4, 4); _e.tz = _e.hz + random_range(-4, 4);
                _e.wait = random_range(2, 5);
            }
        }
        var _ex = _e.tx - _e.x, _ez = _e.tz - _e.z, _dd = point_distance(0, 0, _ex, _ez);
        if (_dd > 0.2) {
            var _p3 = resolve_pos(_e.x + (_ex / _dd) * _speed * _dt, _e.z + (_ez / _dd) * _speed * _dt, 0.5);
            _e.x = max(_p3[0], CLASSROOM_MAX_X + 0.6); _e.z = _p3[1];
            _e.face = point_direction(0, 0, _ex, _ez);
        }
        if (!_safe && _d < 1.2) { combat_start(_e); return; }
    }

    // Pickups
    for (var _i = array_length(_G.items) - 1; _i >= 0; _i--) {
        var _n = _G.items[_i];
        if (point_distance(_n.x, _n.z, _t.px, _t.pz) < 1.1) pickup(_n);
    }

    var _act = find_interact();
    _G.prompt = is_undefined(_act) ? "" : _act.label;
}

function camera_update(_dt) {
    var _G = global.G;
    var _t = _G.teacher;
    var _tx = clamp(wx(_t.px) - GUI_W / 2, 0, room_width - GUI_W);
    var _ty = clamp(wy(_t.pz + 1) - GUI_H / 2, 0, room_height - GUI_H);
    var _k = 1 - power(0.001, _dt);
    _G.cam_x = lerp(_G.cam_x, _tx, _k);
    _G.cam_y = lerp(_G.cam_y, _ty, _k);
    camera_set_view_pos(view_camera[0], round(_G.cam_x), round(_G.cam_y));
}

/* -------------------------------------------------------------- main loop */

function game_step() {
    var _G = global.G;
    _G.dt = min(0.05, delta_time / 1000000);
    _G.time += _G.dt;
    _G.pad = pad_find();
    display_update();
    if (_G.toast_t > 0) _G.toast_t -= _G.dt;

    if (_G.finish_pending > 0) {
        _G.finish_pending -= _G.dt;
        if (_G.finish_pending <= 0) finish_demo(); // combat end re-checks if this lands mid-fight
    }

    switch (_G.mode) {
        case "ui":      ui_input(); break;
        case "explore": explore_update(_G.dt); break;
        case "combat":  combat_update(_G.dt); break;
    }
    if (_G.mode != "combat") camera_update(_G.dt);
}
