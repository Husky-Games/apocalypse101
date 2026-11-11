// Shared constants, helpers and input for Apocalypse 101.
// World logic runs in "units" (same coordinates as the browser prototype: x across, z down).
// wx()/wy() convert units to room pixels for drawing.

#macro U 48                    // room pixels per world unit (one 16 px tile at 3x)
#macro AS 3                    // art scale: LimeZu 16x16 pixels drawn at 3x
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
    if (keyboard_check(vk_alt)) return false; // Alt+Enter = fullscreen
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

/* ---------------------------------------------------------------- display */
// Fonts are rendered at 2x and drawn at half scale, so text stays crisp when
// the 1280x720 layout is scaled up to large or high-DPI windows.

#macro TXT_S 0.5

function tdraw(_x, _y, _s) { draw_text_transformed(_x, _y, _s, TXT_S, TXT_S, 0); }
function tdraw_ext(_x, _y, _s, _w) { draw_text_ext_transformed(_x, _y, _s, -1, _w / TXT_S, TXT_S, TXT_S, 0); }
function twidth(_s) { return string_width(_s) * TXT_S; }

/// Open the window at the largest quarter-step scale that fills ~85% of the screen.
function display_init() {
    global.disp_w = -1;
    global.disp_h = -1;
    var _s = min(display_get_width() * 0.85 / GUI_W, display_get_height() * 0.85 / GUI_H);
    _s = max(1, floor(_s * 4) / 4);
    window_set_size(round(GUI_W * _s), round(GUI_H * _s));
    call_later(2, time_source_units_frames, function() { window_center(); });
}

/// Render at the window's real resolution (letterboxed to 16:9) whenever it changes size.
/// The game draws the application surface itself (display_present) so it is scaled and
/// centred correctly in fullscreen too.
function display_update() {
    if (keyboard_check_pressed(vk_f11)) window_set_fullscreen(!window_get_fullscreen());
    var _fs = window_get_fullscreen();    var _ww = _fs ? display_get_width() : window_get_width();
    var _wh = _fs ? display_get_height() : window_get_height();
    if (_ww <= 0 || _wh <= 0) return; // minimized
    if (_ww == global.disp_w && _wh == global.disp_h) return;
    // Resize the swap chain to the new window/screen size (GameMaker keeps the old
    // backbuffer size after a fullscreen switch otherwise).
    if (global.disp_w > 0) display_reset(0, true);
    global.disp_w = _ww;
    global.disp_h = _wh;
    var _s = min(_ww / GUI_W, _wh / GUI_H);
    var _sw = round(GUI_W * _s), _sh = round(GUI_H * _s);
    global.disp_x = floor((_ww - _sw) / 2);
    global.disp_y = floor((_wh - _sh) / 2);
    surface_resize(application_surface, _sw, _sh);
    view_wport[0] = _sw;
    view_hport[0] = _sh;
    // Zoom the world camera so each art pixel covers a whole number of screen pixels
    // (crisp pixel art), keeping roughly 28 tiles across.
    var _n = max(1, round(AS * _sw / 1350));
    var _vw = AS * _sw / _n;
    camera_set_view_size(view_camera[0], _vw, _vw * GUI_H / GUI_W);
    display_set_gui_maximize(_s, _s, global.disp_x, global.disp_y);
}

/// Post Draw: blit the game frame centred in the window with black bars around it.
function display_present() {
    draw_clear(c_black);
    if (!surface_exists(application_surface) || global.disp_w < 0) return;
    gpu_set_blendenable(false);
    draw_surface(application_surface, global.disp_x, global.disp_y);
    gpu_set_blendenable(true);
}
