// Shared constants, helpers and input for Apocalypse 101.
// World logic runs in "units" (same coordinates as the browser prototype: x across, z down).
// wx()/wy() convert units to room pixels for drawing.

#macro U 40                    // pixels per world unit
#macro GUI_W 1280
#macro GUI_H 720
#macro MAX_PARTY 3
#macro BOUND_X 29.5
#macro BOUND_Z 19.5
#macro FENCE_X 16
#macro CLASSROOM_MAX_X -15.5

/// Convert a 0xRRGGBB literal to a GameMaker (BGR) colour.
function rgb(_hex) {
    return make_colour_rgb((_hex >> 16) & 255, (_hex >> 8) & 255, _hex & 255);
}

function wx(_x) { return (_x + 30) * U; }
function wy(_z) { return (_z + 20) * U; }

function arr_copy(_a) {
    var _b = array_create(array_length(_a));
    array_copy(_b, 0, _a, 0, array_length(_a));
    return _b;
}

function arr_remove(_a, _v) {
    var _i = array_get_index(_a, _v);
    if (_i >= 0) array_delete(_a, _i, 1);
}

function arr_has(_a, _v) { return array_get_index(_a, _v) >= 0; }

function str_join(_a, _sep) {
    var _s = "";
    for (var _i = 0; _i < array_length(_a); _i++) _s += (_i > 0 ? _sep : "") + string(_a[_i]);
    return _s;
}

function toast(_msg, _secs = 3.2) {
    global.G.toast_text = _msg;
    global.G.toast_t = _secs;
}

/* ------------------------------------------------------------------ input */

function pad_find() {
    for (var _i = 0; _i < 12; _i++) if (gamepad_is_connected(_i)) return _i;
    return -1;
}

function pad_pressed(_btn) {
    var _p = global.G.pad;
    return _p >= 0 && gamepad_button_check_pressed(_p, _btn);
}

function key_any_pressed(_keys) {
    for (var _i = 0; _i < array_length(_keys); _i++) if (keyboard_check_pressed(_keys[_i])) return true;
    return false;
}

function key_any(_keys) {
    for (var _i = 0; _i < array_length(_keys); _i++) if (keyboard_check(_keys[_i])) return true;
    return false;
}

/// Confirm in menus/minigames: Space, Enter, E, or pad A.
function inp_confirm() {
    return key_any_pressed([vk_space, vk_enter, ord("E")]) || pad_pressed(gp_face1);
}

function inp_back() {
    return keyboard_check_pressed(vk_escape) || pad_pressed(gp_face2);
}

/// Direction pressed this frame: "U", "D", "L", "R" or "".
function inp_dir() {
    if (key_any_pressed([vk_up, ord("W")]) || pad_pressed(gp_padu)) return "U";
    if (key_any_pressed([vk_down, ord("S")]) || pad_pressed(gp_padd)) return "D";
    if (key_any_pressed([vk_left, ord("A")]) || pad_pressed(gp_padl)) return "L";
    if (key_any_pressed([vk_right, ord("D")]) || pad_pressed(gp_padr)) return "R";
    // Left stick flick for menus
    var _p = global.G.pad;
    if (_p >= 0) {
        var _ax = gamepad_axis_value(_p, gp_axislh), _ay = gamepad_axis_value(_p, gp_axislv);
        var _held = abs(_ax) > 0.6 || abs(_ay) > 0.6;
        if (_held && !global.G.stick_latch) {
            global.G.stick_latch = true;
            if (abs(_ay) > abs(_ax)) return _ay < 0 ? "U" : "D";
            return _ax < 0 ? "L" : "R";
        }
        if (!_held) global.G.stick_latch = false;
    }
    return "";
}

function dir_glyph(_d) {
    switch (_d) {
        case "U": return "↑";
        case "D": return "↓";
        case "L": return "←";
        case "R": return "→";
    }
    return "?";
}
