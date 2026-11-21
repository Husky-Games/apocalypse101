// World state and exploration. The world is a set of areas (scr_campus builds them):
// the outdoor campus plus one interior per building, joined by doors. Each area has its own
// boxes/colliders/items/enemies; global.G.boxes etc. point at the current area's arrays.
// Area coordinates are in world units with the origin at the area's top-left corner.

function game_init() {
    data_init();
    atlas_init();
    global.G = {
        mode: "ui",            // ui | explore | combat
        overlay: "",           // roster | craft | journal | finish
        overlay_closable: false,
        intro: true,
        inv: { scrap: 0, cloth: 0, bandage: 1, medkit: 0, energy: 0 },
        clues: [],
        cleared: [],           // areas whose clue has been found (see ROUTE)
        tunnels_found: false,  // the Cafeteria hatch has been revealed
        tunnels_visited: false,
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
        // world: areas, and aliases of the current area's arrays
        areas: {},
        area: undefined,
        door: undefined,       // door the prompt refers to
        colliders: [],
        boxes: [],
        trees: [],
        decor: [],
        tables: [],
        items: [],
        enemies: [],
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
    party_build();
    campus_build();
    area_enter("main", MAIN_SPAWN_X, MAIN_SPAWN_Z, 270);
    party_place();
    roster_open(true);
}

/* ------------------------------------------------------------------ areas */

/// Create an area. Interiors get a room rectangle (floor bounds); the campus is outdoor.
function area_new(_id, _name, _w, _h) {
    var _A = {
        id: _id, name: _name, w: _w, h: _h,
        outdoor: false, safe: false, lit: false,
        tint: rgb(0x8890b0),      // night multiply colour
        floor: "floor", room: [0, 0, _w, _h], floors: [], decals: [], paths: [],
        boxes: [], colliders: [], trees: [], decor: [], tables: [], items: [], enemies: [], doors: [],
        fence: undefined,
    };
    global.G.areas[$ _id] = _A;
    return _A;
}

/// Point the global world arrays at area _A (used while building and when entering).
function area_use(_A) {
    var _G = global.G;
    _G.area = _A;
    _G.boxes = _A.boxes; _G.colliders = _A.colliders; _G.trees = _A.trees; _G.decor = _A.decor;
    _G.tables = _A.tables; _G.items = _A.items; _G.enemies = _A.enemies;
}

/// Move the party into area _id at (x, z), facing _face (0 right, 90 up, 180 left, 270 down).
function area_enter(_id, _x, _z, _face) {
    var _G = global.G, _A = _G.areas[$ _id];
    area_use(_A);
    if (_id == "tunnels") _G.tunnels_visited = true;
    var _t = _G.teacher;
    _t.px = _x; _t.pz = _z; _t.py = 0; _t.face = _face; _t.moving = false;
    // followers line up behind the leader
    var _bx = -lengthdir_x(1, _face), _bz = -lengthdir_y(1, _face);
    for (var _i = 0; _i < array_length(_G.party); _i++) {
        var _m = _G.party[_i];
        var _p = resolve_pos(_x + _bx * (_i + 1) * 0.9, _z + _bz * (_i + 1) * 0.9, 0.4);
        _m.px = _p[0]; _m.pz = _p[1]; _m.py = 0; _m.face = _face; _m.moving = false;
    }
    _G.door = undefined;
    var _c = camera_target();
    _G.cam_x = _c[0]; _G.cam_y = _c[1];
    toast(_A.name, 1.4);
}

function area_is(_id) { return global.G.area.id == _id; }

/* -------------------------------------------------------------- progression */
// The route through campus (content/campus_map.svg numbers 1, 2, 3, 6, 4, 5). Each building's
// clue unlocks the next; the Cafeteria clue reveals the tunnels, the only way into the Lab and
// Library.
#macro ROUTE [["main", "Main Classroom"], ["gym", "Gym"], ["theater", "Theater"], ["cafe", "Cafeteria"], ["lab", "Lab"], ["library", "Library"]]

/// Is a door gate satisfied? "" = always, "tunnels" = been underground, otherwise an area whose clue was found.
function gate_ok(_g) {
    var _G = global.G;
    if (_g == "") return true;
    if (_g == "tunnels") return _G.tunnels_visited;
    return arr_has(_G.cleared, _g);
}

/// The next building on the route, as [id, name], or undefined when all are done.
function route_next() {
    var _r = ROUTE;
    for (var _i = 0; _i < array_length(_r); _i++) if (!arr_has(global.G.cleared, _r[_i][0])) return _r[_i];
    return undefined;
}

function objective_text() {
    var _G = global.G, _n = route_next();
    if (is_undefined(_n)) return "You have searched every building.";
    switch (_n[0]) {
        case "main": return "Search the Main Classroom for anything left behind.";
        case "cafe":
            return _G.fence_cleared ? "Search the Cafeteria." : "Search the Cafeteria, past the fence. Everyone must be able to clear it.";
        case "lab": return "The Lab is caved in. Find another way: the tunnels under the Cafeteria.";
        case "library": return "Follow the tunnels to the Library.";
    }
    return "Search the " + _n[1] + ".";
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

/// Box from corners (x1, z1)-(x2, z2).
function add_rect(_x1, _z1, _x2, _z2, _kind, _collide = true) {
    return add_box((_x1 + _x2) / 2, (_z1 + _z2) / 2, _x2 - _x1, _z2 - _z1, 2, c_white, _collide, 0, _kind);
}

/// Furniture: atlas art drawn bottom-centred on a (w x d) footprint centred at (x, z).
function add_prop(_art, _x, _z, _w = 1, _d = 0.8, _collide = true) {
    var _r = add_box(_x, _z, _w, _d, 1, c_white, _collide, 0, "prop");
    _r.box.art = _art;
    return _r;
}

/// Picture/board hung on the north wall of a room whose wall line is at z = _wz.
function add_wallart(_art, _x, _wz) {
    var _r = add_box(_x, _wz + 0.5, 2, 0.2, 2, c_white, false, 0.6, "wallart");
    _r.box.art = _art;
    return _r;
}

function add_tree(_x, _z, _art) {
    array_push(global.G.trees, { x: _x, z: _z, art: _art });
    array_push(global.G.colliders, { minX: _x - 0.4, maxX: _x + 0.4, minZ: _z - 0.4, maxZ: _z + 0.4 });
}

/// Non-colliding scenery sprite (atlas name), anchored bottom-centre at (x, z).
function add_decor(_art, _x, _z) {
    array_push(global.G.decor, { art: _art, x: _x, z: _z });
}

/// Flat art on the ground. mode "center": one copy centred in the rect; "tile": repeated.
function add_decal(_art, _x1, _z1, _x2, _z2, _mode = "center") {
    array_push(global.G.area.decals, { art: _art, x1: _x1, z1: _z1, x2: _x2, z2: _z2, mode: _mode });
}

function add_table(_x, _z) {
    add_box(_x, _z, 3.6, 1, 1, rgb(0x8a5a2a), true, 0, "table");
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

/// A door trigger at (x, z) in the current area leading to area _to at (tx, tz) facing _tface.
/// Blocked doors only show a message. _gate: requirement to use it (see gate_ok), with _msg shown
/// otherwise; _hide: requirement for the door to exist at all (hidden hatches).
function add_door(_x, _z, _to, _tx, _tz, _tface, _label, _blocked = false, _gate = "", _msg = "", _hide = "") {
    var _d = { x: _x, z: _z, to: _to, tx: _tx, tz: _tz, face: _tface, label: _label, blocked: _blocked, gate: _gate, msg: _msg, hide: _hide };
    array_push(global.G.area.doors, _d);
    return _d;
}

/* ------------------------------------------------------------ party setup */

#macro MAIN_SPAWN_X 9
#macro MAIN_SPAWN_Z 11
#macro BOARD_X 9
#macro BOARD_Z 4.6

function party_build() {
    var _G = global.G;
    _G.teacher = make_member(global.TEACHER);
    _G.teacher.scale = 1.12;
    _G.teacher.px = MAIN_SPAWN_X; _G.teacher.pz = MAIN_SPAWN_Z;
    _G.roster = [];
    for (var _i = 0; _i < array_length(global.STUDENTS); _i++) array_push(_G.roster, make_member(global.STUDENTS[_i]));
}

/// Party members follow the teacher; the rest wait in the Main Classroom.
function party_place() {
    var _G = global.G;
    var _t = _G.teacher;
    for (var _i = 0; _i < array_length(_G.roster); _i++) {
        var _m = _G.roster[_i];
        var _k = array_get_index(_G.party, _m);
        if (_k >= 0) { _m.px = _t.px - 1 - _k * 0.2; _m.pz = _t.pz + 0.8 + _k * 0.8; }
        else { _m.px = 2.2 + _i * 1.4; _m.pz = 8.5; }
        _m.py = 0;
        _m.moving = false;
        _m.face = 270;
    }
}

/// Is roster member _m visible in the current area? (waiting students stay in the classroom)
function member_here(_m) {
    return _m == global.G.teacher || arr_has(global.G.party, _m) || area_is("main");
}

/* ------------------------------------------------------------ exploration */

function near_table(_x, _z, _r = 2.6) {
    var _tb = global.G.tables;
    for (var _i = 0; _i < array_length(_tb); _i++) if (point_distance(_tb[_i].x, _tb[_i].z, _x, _z) < _r) return true;
    return false;
}

function near_fence(_x, _z) {
    var _f = global.G.area.fence;
    if (!is_struct(_f) || global.G.fence_cleared || abs(_x - _f.x) >= 2.4) return false;
    for (var _i = 0; _i < array_length(_f.segs); _i++) if (_z >= _f.segs[_i][0] && _z <= _f.segs[_i][1]) return true;
    return false;
}

function nearest_door(_x, _z) {
    var _ds = global.G.area.doors, _best = undefined, _bd = 1.7;
    for (var _i = 0; _i < array_length(_ds); _i++) {
        if (!gate_ok(_ds[_i].hide)) continue;
        var _d = point_distance(_ds[_i].x, _ds[_i].z, _x, _z);
        if (_d < _bd) { _bd = _d; _best = _ds[_i]; }
    }
    return _best;
}

/// Returns { label, action } or undefined.
function find_interact() {
    var _G = global.G, _t = _G.teacher;
    var _door = nearest_door(_t.px, _t.pz);
    _G.door = _door;
    if (is_struct(_door)) {
        if (_door.blocked) return { label: "E / Space / A: Try the door", action: "door" };
        return { label: "E / Space / A: " + _door.label + (gate_ok(_door.gate) ? "" : " (locked)"), action: "door" };
    }
    if (near_table(_t.px, _t.pz)) return { label: "E / Space / A: Craft", action: "craft" };
    if (area_is("main") && point_distance(_t.px, _t.pz, BOARD_X, BOARD_Z) < 3) return { label: "E / Space / A: Change party", action: "roster" };
    if (near_fence(_t.px, _t.pz)) return { label: "E / Space / A: Jump the fence", action: "fence" };
    return undefined;
}

function interact() {
    var _a = find_interact();
    if (is_undefined(_a)) return;
    switch (_a.action) {
        case "door": use_door(global.G.door); break;
        case "craft": craft_open(); break;
        case "roster": roster_open(false); break;
        case "fence": try_fence(); break;
    }
}

function use_door(_d) {
    if (!is_struct(_d)) return;
    if (_d.blocked) { toast("The door is jammed shut. Something heavy is wedged against it.", 2.6); return; }
    if (!gate_ok(_d.gate)) { toast(_d.msg != "" ? _d.msg : "Locked.", 3); return; }
    area_enter(_d.to, _d.tx, _d.tz, _d.face);
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
    var _f = _G.area.fence;
    for (var _i = 0; _i < array_length(_f.cols); _i++) arr_remove(_G.colliders, _f.cols[_i]);
    toast("The whole party vaults the fence together.");
}

function craft_anywhere() {
    if (has_trait("craftAnywhere")) craft_open();
    else toast("You need a crafting table, or Scarlett in the party.");
}

function heal_lowest() {
    var _targets = array_filter(everyone(), function(_m) { return _m.hp < _m.maxHp; });
    if (array_length(_targets) == 0) { toast("Everyone is healthy."); return; }
    var _item = "";
    for (var _i = 0; _i < array_length(global.HEAL_ITEMS); _i++) if (_item == "" && inv_count(global.HEAL_ITEMS[_i]) > 0) _item = global.HEAL_ITEMS[_i];
    if (_item == "") { toast("No healing items. Craft bandages from cloth."); return; }
    array_sort(_targets, function(_a, _b) { return sign((_a.hp / _a.maxHp) - (_b.hp / _b.maxHp)); });
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
        if (!arr_has(_G.cleared, _G.area.id)) array_push(_G.cleared, _G.area.id);
        var _n = route_next();
        var _after = is_undefined(_n) ? "" : "\nNext: " + _n[1] + ".";
        if (_G.area.id == "cafe") { _G.tunnels_found = true; _after = "\nA hatch has opened in the kitchen floor..."; }
        toast($"Clue: {_text}" + _after, 6);
        if (array_length(_G.clues) == array_length(global.CLUES)) _G.finish_pending = 6.2;
    } else {
        var _it = global.ITEMS[$ _node.type];
        var _n = 1, _who = "";
        if (_it.food && has_trait("doubleFood")) { _n = 2; _who = " Jake finds extra."; }
        if (_it.medical && has_trait("doubleMedical")) { _n = 2; _who = " Zuri finds extra."; }
        inv_add(_node.type, _n);
        toast($"Picked up {_it.name}" + (_n > 1 ? $" ×{_n}.{_who}" : "."), 1.6);
    }
}

function finish_demo() {
    var _G = global.G;
    if (_G.finished || _G.mode == "combat") return;
    _G.finished = true;
    overlay_open("finish", true);
}

/// Push a circle of radius _r out of all colliders and keep it inside the area.
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
    var _A = global.G.area;
    return [clamp(_x, 0.5, _A.w - 0.5), clamp(_z, 0.5, _A.h - 0.5)];
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
    _t.moving = _moving;
    _t.py = 0;

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
        _m.moving = _active;
        _m.py = 0;
    }

    // Hop over the lowered fence
    var _f = _G.area.fence;
    if (_G.fence_cleared && is_struct(_f)) {
        var _all = everyone();
        for (var _i = 0; _i < array_length(_all); _i++) {
            var _fx = abs(_all[_i].px - _f.x);
            if (_fx < 1.8) _all[_i].py += 1.1 * (1 - _fx / 1.8);
        }
    }

    // Enemies wander, and chase unless the area is safe
    var _safe = _G.area.safe;
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
            _e.x = _p3[0]; _e.z = _p3[1];
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

/// Camera position that follows the teacher, clamped to the area (centred if the area is small).
function camera_target() {
    var _G = global.G, _t = _G.teacher, _A = _G.area;
    var _vw = camera_get_view_width(view_camera[0]), _vh = camera_get_view_height(view_camera[0]);
    var _aw = _A.w * U, _ah = _A.h * U;
    var _tx = _aw <= _vw ? (_aw - _vw) / 2 : clamp(wx(_t.px) - _vw / 2, 0, _aw - _vw);
    var _ty = _ah <= _vh ? (_ah - _vh) / 2 : clamp(wy(_t.pz + 1) - _vh / 2, 0, _ah - _vh);
    return [_tx, _ty];
}

function camera_update(_dt) {
    var _G = global.G;
    var _c = camera_target();
    var _k = 1 - power(0.001, _dt);
    _G.cam_x = lerp(_G.cam_x, _c[0], _k);
    _G.cam_y = lerp(_G.cam_y, _c[1], _k);
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
