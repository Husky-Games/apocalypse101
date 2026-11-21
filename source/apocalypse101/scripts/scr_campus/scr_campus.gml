// Campus layout, following content/campus_map.svg (1 unit = 13.3 map px).
// The campus is one outdoor area; every building has its own interior area, joined by doors.
// Blocked doors (white X on the map) only show a message. The tunnels (blue lines) come later.

#macro CAMPUS_W 114
#macro CAMPUS_H 64
#macro FENCE_X 84.8

function campus_build() {
    build_campus();
    build_main();
    build_classroom("classA", "Classroom A");
    build_classroom("classB", "Classroom B");
    build_classroom("classC", "Classroom C");
    build_gym();
    build_theater();
    build_library();
    build_cafeteria();
    build_lab();
    build_tunnels();
}

/* ============================================================= helpers */

/// Building on the campus: rooftop over the footprint, one-storey facade along its south edge.
/// _doors: [{ side: "s"|"n"|"e"|"w", pos, blocked, to, tx, tz, face, label }] (pos = x for s/n, z for e/w).
function add_building(_x1, _z1, _x2, _z2, _roof, _fac, _doors) {
    var _r = add_rect(_x1, _z1, _x2, _z2, "bld");
    _r.box.roof = _roof; _r.box.fac = _fac; _r.box.doors = _doors; _r.box.fac_h = 4;
    for (var _i = 0; _i < array_length(_doors); _i++) {
        var _d = _doors[_i], _x = 0, _z = 0;
        switch (_d.side) {
            case "s": _x = _d.pos; _z = _z2 + 0.7; break;
            case "n": _x = _d.pos; _z = _z1 - 0.7; break;
            case "w": _x = _x1 - 0.7; _z = _d.pos; break;
            case "e": _x = _x2 + 0.7; _z = _d.pos; break;
        }
        if (_d.blocked) add_door(_x, _z, "", 0, 0, 0, "", true);
        else add_door(_x, _z, _d.to, _d.tx, _d.tz, _d.face, _d.label, false, _d.gate, _d.msg);
    }
    return _r;
}

function door_s(_pos, _to, _tx, _tz, _label, _gate = "", _msg = "") { return { side: "s", pos: _pos, blocked: false, to: _to, tx: _tx, tz: _tz, face: 90, label: _label, gate: _gate, msg: _msg }; }
function door_open(_side, _pos, _to, _tx, _tz, _face, _label, _gate = "", _msg = "") { return { side: _side, pos: _pos, blocked: false, to: _to, tx: _tx, tz: _tz, face: _face, label: _label, gate: _gate, msg: _msg }; }
function door_x(_side, _pos) { return { side: _side, pos: _pos, blocked: true, to: "", tx: 0, tz: 0, face: 0, label: "", gate: "", msg: "" }; }

/// Destroyed building: rubble footprint you can't enter, with junk spilling out front.
function add_ruin(_x1, _z1, _x2, _z2) {
    add_rect(_x1, _z1, _x2, _z2, "ruin");
    for (var _x = _x1 + 1.5; _x < _x2 - 1; _x += 3.2) add_decor("junk", _x + random_range(-0.6, 0.6), _z2 + 0.3);
}

/// Interior area with a W x H room at (1, 3); returns the area (already in use for building).
function interior(_id, _name, _W, _H, _floor) {
    var _A = area_new(_id, _name, _W + 2, _H + 4.5);
    _A.floor = _floor;
    _A.room = [1, 3, _W + 1, _H + 3];
    area_use(_A);
    return _A;
}
function rx(_x) { return _x + 1; }   // room-local -> area coordinates
function rz(_z) { return _z + 3; }

/// Walls around the current area's room. Each list holds door specs on that wall:
/// { pos (absolute), open, to, tx, tz, face, label }. Open doors leave a 2-unit gap with a
/// trigger; blocked ones are drawn boarded up.
function room_walls(_n, _s, _w, _e) {
    var _A = global.G.area, _r = _A.room;
    var _x1 = _r[0], _z1 = _r[1], _x2 = _r[2], _z2 = _r[3];
    wall_run(true, _z1, _x1 - 0.3, _x2 + 0.3, _n, "wall_n");
    wall_run(true, _z2, _x1 - 0.3, _x2 + 0.3, _s, "wall");
    wall_run(false, _x1, _z1, _z2, _w, "wall");
    wall_run(false, _x2, _z1, _z2, _e, "wall");
    // keep everyone out of the margins beyond the walls
    add_rect(0, 0, _A.w, _z1 - 0.3, "none");
    add_rect(0, _z2 + 0.3, _A.w, _A.h, "none");
    add_rect(0, 0, _x1 - 0.3, _A.h, "none");
    add_rect(_x2 + 0.3, 0, _A.w, _A.h, "none");
    // door triggers and markers
    var _sides = [["n", _n], ["s", _s], ["w", _w], ["e", _e]];
    for (var _k = 0; _k < 4; _k++) {
        var _side = _sides[_k][0], _list = _sides[_k][1];
        for (var _i = 0; _i < array_length(_list); _i++) {
            var _d = _list[_i], _tx = 0, _tz = 0;
            switch (_side) {
                case "n": _tx = _d.pos; _tz = _z1 + 0.8; break;
                case "s": _tx = _d.pos; _tz = _z2 - 0.7; break;
                case "w": _tx = _x1 + 0.7; _tz = _d.pos; break;
                case "e": _tx = _x2 - 0.7; _tz = _d.pos; break;
            }
            if (_d.open) {
                add_door(_tx, _tz, _d.to, _d.tx, _d.tz, _d.face, _d.label);
                if (_side == "s") add_decal("rug_red", _d.pos - 0.5, _z2 - 1, _d.pos + 0.5, _z2);
            } else {
                add_door(_tx, _tz, "", 0, 0, 0, "", true);
                var _m = add_box(_side == "w" ? _x1 : (_side == "e" ? _x2 : _d.pos), _side == "n" ? _z1 : (_side == "s" ? _z2 : _d.pos),
                                 0.2, 0.2, 1, c_white, false, 0, "doorx");
                _m.box.side = _side;
            }
        }
    }
}

/// One wall line split around its open doors. Horizontal walls run along z = _at from _a to _b.
function wall_run(_horiz, _at, _a, _b, _doors, _kind) {
    var _cuts = [];
    for (var _i = 0; _i < array_length(_doors); _i++) if (_doors[_i].open) array_push(_cuts, _doors[_i].pos);
    array_sort(_cuts, true);
    var _from = _a;
    for (var _i = 0; _i <= array_length(_cuts); _i++) {
        var _to = _i < array_length(_cuts) ? _cuts[_i] - 1 : _b;
        if (_to - _from > 0.05) {
            if (_horiz) add_box((_from + _to) / 2, _at, _to - _from, 0.6, 3, c_white, true, 0, _kind);
            else add_box(_at, (_from + _to) / 2, 0.6, _to - _from, 3, c_white, true, 0, _kind);
        }
        if (_i < array_length(_cuts)) _from = _cuts[_i] + 1;
    }
}

function wd_open(_pos, _to, _tx, _tz, _face, _label) { return { pos: _pos, open: true, to: _to, tx: _tx, tz: _tz, face: _face, label: _label }; }
function wd_x(_pos) { return { pos: _pos, open: false }; }

/// Classroom furniture: two rows of desks, board, teacher's desk, locker.
function class_desks(_x0, _z0, _gap) {
    var _k = 1;
    for (var _row = 0; _row < 2; _row++)
        for (var _c = 0; _c < 3; _c++) {
            var _d = add_box(_x0 + _c * _gap, _z0 + _row * 2.5, 2, 1, 0.8, rgb(0x7a5a3a), true, 0, "desk");
            _d.box.art = "desk" + string(_k); _k++;
        }
}

/* ============================================================== campus */

function build_campus() {
    var _A = area_new("campus", "Campus", CAMPUS_W, CAMPUS_H);
    _A.outdoor = true;
    _A.tint = rgb(0x7480a8);
    _A.floor = "";
    area_use(_A);

    // Walkways (grey lines on the map): quad ring, Theater-Library avenue, lanes, north road
    _A.paths = [
        [32, 20, 84, 22], [32, 20, 34, 41], [82, 20, 84, 41], [32, 39, 84, 41],
        [22, 32, 88, 34],
        [42, 22, 44, 37], [56, 22, 58, 37], [70, 22, 72, 37],
        [40, 19, 42, 21], [84, 20, 94, 22], [92, 16, 94, 22],
        [32, 41, 34, 62], [32, 60, 52, 62], [49, 58, 51, 61],
    ];

    // The quad: three classrooms with the Main Classroom in the middle, and two ruins
    add_building(51, 23, 62, 29, "roof", "fac_win",
        [door_s(56.5, "main", 11.6, 17.7, "Enter the Main Classroom"), door_x("n", 56.5), door_x("w", 26), door_x("e", 26)]);
    add_building(37, 23.5, 48, 29.5, "roof", "fac_win2",
        [door_x("s", 42.5), door_x("n", 42.5), door_x("w", 26.5), door_x("e", 26.5)]);
    add_building(65.5, 23.5, 76.5, 29.5, "roof", "fac_win2",
        [door_s(71, "classB", 8.25, 10.7, "Enter Classroom B"), door_x("n", 71), door_x("w", 26.5)]);
    add_building(37.5, 36.5, 48.5, 43, "roof", "fac_win",
        [door_open("n", 43, "classC", 8.25, 4.3, 270, "Enter Classroom C")]);
    add_ruin(51, 36.5, 62, 43);
    add_ruin(65.5, 36.5, 77.5, 43);

    // 2 Gym, with its open-air court on the west (reached through the gym)
    add_building(29.5, 4, 53, 19.5, "roof2", "fac_arch",
        [door_s(41, "gym", 12, 15.7, "Enter the Gym"), door_open("w", 12, "gym", 2.3, 10, 0, "Enter the Gym")]);
    add_decal("court", 16.5, 5.5, 29.5, 18.5);
    add_rect(16.2, 5.2, 29.5, 5.8, "lowwall");
    add_rect(16.2, 18.2, 29.5, 18.8, "lowwall");
    add_rect(16.2, 5.2, 16.8, 18.8, "lowwall");
    add_decor("floodlight", 17.6, 6.6); add_decor("floodlight", 17.6, 17.9);
    add_hatch("annex", 21.5, 9.5);

    // 6 Cafeteria (kitchen block behind)
    add_rect(89.5, 7.5, 99, 10.2, "roofonly");
    add_building(72, 10, 102, 16.5, "roof", "fac_win",
        [door_s(93, "cafe", 13, 11.7, "Enter the Cafeteria", "theater", "Locked. Something in the Theater might open it.")]);

    // 3 Theater: a fan-shaped hall, approximated by three blocks; doors face the avenue
    add_building(17, 20.5, 25, 27, "roof2", "fac_win2", []);
    add_building(12.5, 27, 22.5, 40, "roof2", "fac_arch",
        [door_open("e", 33, "theater", 11, 17.7, 90, "Enter the Theater", "gym", "Locked. Something in the Gym might open it.")]);
    add_building(16.5, 40, 24.5, 46, "roof2", "fac_win2", []);

    // 5 Library with its round entrance hall
    add_building(90.5, 24.5, 104, 41, "roof", "fac_arch", []);
    add_building(87, 29.5, 90.5, 36, "roof2", "fac_door",
        [door_x("w", 33)]);

    // 4 Lab, joined to Classroom C (and the ruins) by covered corridors
    add_building(38, 48.5, 62, 58.5, "roof", "fac_win2",
        [door_x("s", 50)]);
    add_rect(42, 43, 44.5, 48.6, "roofonly");
    add_rect(55.5, 43, 57.5, 48.6, "roofonly");

    // The fence: only a party that can all jump gets to the Library and Cafeteria
    var _f = { x: FENCE_X, segs: [[0, 10], [16.5, CAMPUS_H]], gaps: [21, 33], cols: [] };
    for (var _i = 0; _i < array_length(_f.segs); _i++) {
        var _c = { minX: FENCE_X - 0.25, maxX: FENCE_X + 0.25, minZ: _f.segs[_i][0], maxZ: _f.segs[_i][1] };
        array_push(_A.colliders, _c);
        array_push(_f.cols, _c);
    }
    _A.fence = _f;

    // Scenery
    add_decor("bench", 47, 35.4); add_decor("bench", 64, 35.4);
    add_decor("sign", 83.6, 30.6); add_decor("sign", 83.6, 24.6);
    add_box(30, 50, 4, 2, 1.2, c_white, true, 0, "car1");
    add_box(80, 52, 4, 2, 1.2, c_white, true, 0, "car2");
    add_box(100, 58, 4, 2, 2.4, c_white, true, 0, "container");
    var _trees = [
        [6, 8, "tree_dead1"], [9, 22, "tree_big"], [5, 34, "tree_leaf1"], [8, 48, "tree_dead2"], [14, 58, "tree_leaf2"],
        [26, 56, "tree_dead1"], [4, 62, "tree_big"], [20, 61, "tree_dead2"], [66, 50, "tree_leaf1"], [72, 58, "tree_dead1"],
        [80, 62, "tree_big"], [98, 52, "tree_dead2"], [108, 46, "tree_leaf1"], [110, 30, "tree_dead1"], [108, 12, "tree_big"],
        [64, 7, "tree_leaf2"], [58, 14, "tree_dead2"], [112, 4, "tree_dead1"], [14, 3, "tree_leaf1"], [60, 2, "tree_big"],
        [70, 4, "tree_dead1"], [106, 6, "tree_leaf2"], [88, 48, "tree_dead2"], [102, 60, "tree_leaf1"], [76, 47, "tree_big"],
    ];
    for (var _i = 0; _i < array_length(_trees); _i++) add_tree(_trees[_i][0], _trees[_i][1], _trees[_i][2]);

    // Items: west of the fence, then east of it
    var _spots = [
        ["scrap", 35, 27], ["cloth", 60, 33], ["scrap", 79, 46], ["cloth", 28, 46], ["medkit", 66, 60], ["food", 60, 45.5],
        ["energy", 14, 50],
        ["food", 108, 32], ["scrap", 100, 20], ["cloth", 92, 44], ["medkit", 108, 50], ["energy", 96, 48],
    ];
    for (var _i = 0; _i < array_length(_spots); _i++) add_item(_spots[_i][0], _spots[_i][1], _spots[_i][2]);

    var _groups = [
        ["shade", 1, 28, 36], ["shade", 2, 64, 48], ["shade", 1, 47, 46], ["shade", 2, 36, 60], ["shade", 1, 60, 8],
        ["hollow", 2, 96, 46], ["hollow", 3, 106, 20],
    ];
    for (var _i = 0; _i < array_length(_groups); _i++) add_explore_enemy(_groups[_i][0], _groups[_i][1], _groups[_i][2], _groups[_i][3]);
}

/* =========================================================== interiors */

// 1 Main Classroom: home base (the roster board, a crafting table, lights still on)
function build_main() {
    var _A = interior("main", "Main Classroom", 12, 16, "floor");
    _A.safe = true; _A.lit = true; _A.tint = rgb(0xb0aca8);
    room_walls([wd_x(6.2)], [wd_open(11.6, "campus", 56.5, 30.4, 270, "Leave the classroom")], [wd_x(11)], [wd_x(11)]);
    class_desks(3, 14.5, 3);
    add_wallart("board", 9, 3);
    add_wallart("map", 4.4, 3);
    add_wallart("cork", 11.6, 3);
    add_prop("tdesk", 10.6, 5.6, 1.8, 0.8);
    add_prop("locker", 1.7, 3.75, 0.8, 0.5);
    add_table(3, 5.5);
    add_item("clue", 4.5, 11.5);
    add_hatch("main", 12, 11.5);
}

// Classrooms A, B, C (A's doors are all blocked; its way in is a tunnel, coming later)
function build_classroom(_id, _name) {
    var _A = interior(_id, _name, 12, 9, "floor");
    switch (_id) {
        case "classA":
            room_walls([wd_x(8.25)], [wd_x(8.25)], [wd_x(7.5)], [wd_x(7.5)]);
            add_wallart("board", 4.5, 3); add_wallart("map", 11.5, 3);
            add_prop("locker", rx(11.3), rz(0.75), 0.8, 0.5);
            add_item("energy", rx(1), rz(8)); add_item("food", rx(11), rz(8));
            add_hatch("classA", rx(11.2), rz(2.2));
            break;
        case "classB":
            room_walls([wd_x(8.25)], [wd_open(8.25, "campus", 71, 30.9, 270, "Leave Classroom B")], [wd_x(7.5)], []);
            add_wallart("whiteboard", 5.5, 3); add_wallart("map", 11.5, 3);
            add_prop("bookcase1", rx(1.4), rz(0.8), 2, 1); add_prop("bookcase2", rx(3.6), rz(0.8), 2, 1);
            add_prop("globe", rx(11.2), rz(1.2), 0.8, 0.5);
            add_item("scrap", rx(1.5), rz(8)); add_item("bandage", rx(10.5), rz(8));
            add_explore_enemy("shade", 1, rx(10), rz(2.5));
            break;
        case "classC":
            room_walls([wd_open(8.25, "campus", 43, 35.2, 90, "Leave Classroom C")],
                       [wd_x(8.25)], [], []);   // the corridor to the Lab has caved in
            add_wallart("board", 4, 3);
            add_prop("computer", rx(11), rz(0.8), 2, 1);
            add_item("cloth", rx(1.5), rz(8));
            add_explore_enemy("shade", 1, rx(11), rz(3));
            break;
    }
    class_desks(rx(2), rz(4.5), 3.5);
}

// 2 Gym: a court in the hall, bleachers and trophies; the west door opens onto the outdoor court
function build_gym() {
    var _A = interior("gym", "Gym", 22, 14, "fl_parquet");
    room_walls([], [wd_open(12, "campus", 41, 20.9, 270, "Leave the Gym")],
               [wd_open(10, "campus", 27.8, 12, 180, "Go out to the court")], []);
    add_decal("court", rx(4.5), rz(0.5), rx(17.5), rz(13.5));
    add_prop("bleachers", rx(2.2), rz(1.6), 4, 1.4); add_prop("bleachers", rx(19.8), rz(1.6), 4, 1.4);
    add_prop("trophies", rx(8), rz(0.9), 2, 0.8); add_prop("trophies", rx(14), rz(0.9), 2, 0.8);
    add_wallart("medals", rx(11), 3);
    add_prop("bag1", rx(0.8), rz(3.5), 0.8, 0.6); add_prop("bag2", rx(0.8), rz(11), 0.8, 0.6);
    add_decal("mat_blue", rx(18), rz(10), rx(21.5), rz(13.5), "tile");
    add_prop("barbell", rx(19.6), rz(11.6), 2, 0.5, false); add_prop("kettlebell", rx(20.8), rz(12.8), 1, 0.5, false);
    add_item("bandage", rx(3), rz(12)); add_item("scrap", rx(20), rz(3.5));
    add_item("clue", rx(11), rz(2.6));
    add_hatch("gym", rx(20), rz(5));
    add_explore_enemy("shade", 2, rx(11), rz(7));
}

// 3 Theater: stage up front, rows of seats, a red aisle
function build_theater() {
    var _A = interior("theater", "Theater", 20, 16, "fl_stage");
    array_push(_A.floors, [rx(0), rz(0), rx(20), rz(4.5), "fl_parquet"], [rx(9), rz(4.5), rx(11), rz(16), "fl_red"]);
    room_walls([], [wd_open(11, "campus", 24, 33, 0, "Leave the Theater")], [], []);
    add_prop("spotlight", rx(1.5), rz(4.2), 2, 0.8); add_prop("spotlight", rx(18.5), rz(4.2), 2, 0.8);
    add_prop("drums", rx(5), rz(3), 2, 0.8); add_prop("guitar", rx(8), rz(2.8), 1, 0.6);
    add_prop("micstand", rx(10), rz(3.2), 1, 0.5, false); add_prop("podium", rx(14), rz(3), 1, 0.8);
    var _rows = [7, 9.5, 12];
    for (var _r = 0; _r < 3; _r++)
        for (var _s = 0; _s < 5; _s++) {
            add_prop("seat", rx(2 + _s * 1.2), rz(_rows[_r]), 0.8, 0.6);
            add_prop("seat", rx(12.4 + _s * 1.2), rz(_rows[_r]), 0.8, 0.6);
        }
    add_item("clue", rx(10), rz(6)); add_item("food", rx(18), rz(14.5));
    add_explore_enemy("hollow", 1, rx(4), rz(14.5));
    add_hatch("theater", rx(19), rz(14.5));
}

// 5 Library: bookcases on the walls, rows of shelves, the front desk
function build_library() {
    var _A = interior("library", "Library", 20, 14, "fl_carpet");
    room_walls([], [wd_open(11, "campus", 85.6, 33, 180, "Leave the Library")], [], []);
    add_prop("bookcase1", rx(1.5), rz(0.8), 2, 1); add_prop("bookcase2", rx(3.5), rz(0.8), 2, 1);
    add_prop("bookcase1", rx(16.5), rz(0.8), 2, 1); add_prop("bookcase2", rx(18.5), rz(0.8), 2, 1);
    var _sh = ["shelf1", "shelf2", "shelf3", "shelf4", "shelf5"], _k = 0;
    var _xs = [2, 4, 6, 14, 16, 18];
    for (var _r = 0; _r < 2; _r++)
        for (var _i = 0; _i < 6; _i++) { add_prop(_sh[_k mod 5], rx(_xs[_i]), rz(5 + _r * 3.5), 2, 1); _k++; }
    add_prop("libdesk", rx(15), rz(12), 2, 1);
    add_prop("computer", rx(4), rz(12), 2, 1); add_prop("computer", rx(6), rz(12), 2, 1);
    add_item("clue", rx(10), rz(4)); add_item("medkit", rx(1.5), rz(12.5)); add_item("energy", rx(18.5), rz(10));
    add_explore_enemy("hollow", 2, rx(10), rz(8));
    add_hatch("library", rx(18.5), rz(12.8));
}

// 6 Cafeteria: kitchen along the back wall, lunch tables, vending machines
function build_cafeteria() {
    var _A = interior("cafe", "Cafeteria", 24, 10, "fl_checker");
    room_walls([], [wd_open(13, "campus", 93, 17.9, 270, "Leave the Cafeteria")], [], []);
    add_prop("fridge", rx(1), rz(0.9), 1.6, 0.8);
    add_prop("stove", rx(3.5), rz(0.9), 2, 0.8); add_prop("stove", rx(5.7), rz(0.9), 2, 0.8);
    add_prop("counter", rx(8.5), rz(1.1), 3, 0.6); add_prop("counter", rx(11.5), rz(1.1), 3, 0.6);
    add_prop("vending1", rx(21), rz(0.9), 1.4, 0.8); add_prop("vending2", rx(22.8), rz(0.9), 1.4, 0.8);
    var _xs = [3, 6.5, 10, 14, 17.5, 21];
    for (var _i = 0; _i < 6; _i++) add_prop("lunchtable", rx(_xs[_i]), rz(4.5), 1.8, 1.6);
    var _xs2 = [3, 6.5, 17.5, 21];
    for (var _i = 0; _i < 4; _i++) add_prop("lunchtable", rx(_xs2[_i]), rz(7.5), 1.8, 1.6);
    add_item("clue", rx(12), rz(6.5)); add_item("food", rx(1.5), rz(8.5)); add_item("food", rx(22.5), rz(8.5));
    add_explore_enemy("hollow", 3, rx(12), rz(2.6));
    add_hatch("cafe", rx(15), rz(2.3));
}

// 4 Lab: cabinets and specimens, a workbench for crafting; the north corridor leads to Classroom C
function build_lab() {
    var _A = interior("lab", "Lab", 18, 10, "fl_tile");
    room_walls([wd_x(4)], [wd_x(10)], [], []);
    add_wallart("whiteboard", rx(9), 3);
    add_prop("cabinet", rx(6), rz(0.9), 1.7, 0.8); add_prop("cabinet2", rx(7.8), rz(0.9), 1.7, 0.8);
    add_prop("chemshelf", rx(13), rz(0.9), 1.9, 0.8); add_prop("chemshelf", rx(15), rz(0.9), 1.9, 0.8);
    add_prop("skeleton", rx(17.2), rz(1.2), 0.7, 0.5);
    add_prop("scanner", rx(15.5), rz(7), 2, 1.2);
    add_table(rx(7), rz(6.5));
    add_item("clue", rx(12), rz(5)); add_item("medkit", rx(2), rz(8)); add_item("bandage", rx(17), rz(8.8));
    add_explore_enemy("shade", 2, rx(14), rz(4));
    add_hatch("lab", rx(3), rz(4));
}

/* ============================================================= tunnels */
// The tunnels under the school (blue lines on the map), found mid-game through a hatch in the
// Cafeteria kitchen. They are the only way into the Lab and the Library. The tunnel area uses
// campus coordinates, so each entrance sits under its building.

/// Where each entrance comes out in the tunnels (campus coordinates).
function tunnel_entrances() {
    return {
        main: [56, 26], gym: [50, 7], annex: [21.5, 13.5], theater: [17.5, 42], cafe: [75, 15.5],
        lab: [51, 54], library: [99, 39], classA: [43, 26],
    };
}

/// A hatch down to the tunnels at (x, z) in the current area, for entrance _key.
/// The Cafeteria hatch appears with its clue; other hatches (apart from the Lab and Library,
/// which are only reached from below) appear once the tunnels have been explored.
function add_hatch(_key, _x, _z) {
    var _G = global.G;
    if (!variable_struct_exists(_G, "hatches")) _G.hatches = {};
    var _e = tunnel_entrances()[$ _key];
    var _hide = _key == "cafe" ? "cafe" : ((_key == "lab" || _key == "library") ? "" : "tunnels");
    var _d = add_door(_x, _z, "tunnels", _e[0], _e[1] + 1.4, 270, "Climb down into the tunnels", false, "", "", _hide);
    var _b = add_box(_x, _z, 1.4, 1.4, 0, c_white, false, 0, "hatch");
    _b.box.door = _d;
    _G.hatches[$ _key] = { area: _G.area.id, x: _x, z: _z };
}

function build_tunnels() {
    var _A = area_new("tunnels", "Tunnels", CAMPUS_W, CAMPUS_H);
    _A.tunnel = true;
    _A.floor = "fl_tile";
    _A.tint = rgb(0x5a6278);
    area_use(_A);

    // Corridors (axis-aligned runs approximating the blue lines), 3 units wide
    var _segs = [
        [56, 14, 56, 32], [21.5, 14, 56, 14], [50, 7, 50, 14],            // Main Classroom - Gym - court
        [56, 20, 83, 20], [72, 15.5, 72, 20], [72, 15.5, 75, 15.5],       // - Cafeteria
        [83, 20, 83, 45], [83, 45, 99, 45], [99, 39, 99, 45],             // Cafeteria - Library
        [34.5, 31.5, 56, 31.5], [43, 26, 43, 31.5],                       // - Classroom A
        [34.5, 31.5, 34.5, 48], [17.5, 48, 34.5, 48], [17.5, 42, 17.5, 48], // - Theater
        [34.5, 43.5, 42, 43.5], [42, 43.5, 42, 54], [42, 54, 51, 54],     // - Lab
    ];
    var _ents = tunnel_entrances(), _keys = variable_struct_get_names(_ents);
    var _w = _A.w, _h = _A.h;
    var _grid = array_create(_w * _h, false);
    for (var _iz = 0; _iz < _h; _iz++)
        for (var _ix = 0; _ix < _w; _ix++) {
            var _x = _ix + 0.5, _z = _iz + 0.5, _walk = false;
            for (var _i = 0; _i < array_length(_segs) && !_walk; _i++) {
                var _s = _segs[_i];
                if (_x >= min(_s[0], _s[2]) - 1.5 && _x <= max(_s[0], _s[2]) + 1.5 && _z >= min(_s[1], _s[3]) - 1.5 && _z <= max(_s[1], _s[3]) + 1.5) _walk = true;
            }
            for (var _i = 0; _i < array_length(_keys) && !_walk; _i++) {   // a small chamber under each entrance
                var _e = _ents[$ _keys[_i]];
                if (abs(_x - _e[0]) <= 2.5 && abs(_z - _e[1]) <= 2.5) _walk = true;
            }
            _grid[_iz * _w + _ix] = _walk;
        }
    _A.grid = _grid;

    // Solid cells that touch a walkable one become colliders (merged into runs per row)
    for (var _iz = 0; _iz < _h; _iz++) {
        var _run = -1;
        for (var _ix = 0; _ix <= _w; _ix++) {
            var _edge = false;
            if (_ix < _w && !_grid[_iz * _w + _ix])
                for (var _dz = -1; _dz <= 1; _dz++) for (var _dx = -1; _dx <= 1; _dx++) {
                    var _nx = _ix + _dx, _nz = _iz + _dz;
                    if (_nx >= 0 && _nz >= 0 && _nx < _w && _nz < _h && _grid[_nz * _w + _nx]) _edge = true;
                }
            if (_edge && _run < 0) _run = _ix;
            if (!_edge && _run >= 0) { array_push(_A.colliders, { minX: _run, maxX: _ix, minZ: _iz, maxZ: _iz + 1 }); _run = -1; }
        }
    }

    // Ladders up to each building's hatch (the Library's opens once the Lab has been searched)
    var _names = { main: "the Main Classroom", gym: "the Gym", annex: "the outdoor court", theater: "the Theater", cafe: "the Cafeteria",
                   lab: "the Lab", library: "the Library", classA: "Classroom A" };
    var _hs = global.G.hatches;
    for (var _i = 0; _i < array_length(_keys); _i++) {
        var _k = _keys[_i];
        if (!variable_struct_exists(_hs, _k)) continue;
        var _e = _ents[$ _k], _hh = _hs[$ _k];
        var _gate = _k == "library" ? "lab" : "";
        var _d = add_door(_e[0], _e[1], _hh.area, _hh.x, _hh.z + 1.3, 270, "Climb up into " + _names[$ _k], false, _gate,
                          "The hatch above won't budge. Maybe something in the Lab explains how to open it.");
        var _b = add_box(_e[0], _e[1] - 0.2, 1.2, 0.4, 0, c_white, false, 0, "ladder");
        _b.box.door = _d;
    }

    add_item("medkit", 42, 50); add_item("scrap", 64, 20); add_item("energy", 83, 26); add_item("cloth", 25, 48);
    add_explore_enemy("shade", 2, 34.5, 39); add_explore_enemy("hollow", 2, 83, 38); add_explore_enemy("shade", 1, 30, 14);
}
