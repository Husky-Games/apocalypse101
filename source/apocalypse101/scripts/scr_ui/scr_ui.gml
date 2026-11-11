// Menus and overlays: party roster, crafting, journal, finish screen.
// Buttons are registered while drawing the GUI and handled on the next Step, so
// mouse, keyboard (arrows/WASD + Enter/Space/E, number keys) and gamepad (d-pad/stick + A)
// all drive the same menus.

#macro COL_BG       rgb(0x10151f)
#macro COL_PANEL    rgb(0x161b26)
#macro COL_PANEL2   rgb(0x1f2635)
#macro COL_LINE     rgb(0x3a4560)
#macro COL_TEXT     rgb(0xe8ecf4)
#macro COL_MUTED    rgb(0x9aa4b8)
#macro COL_ACCENT   rgb(0xffb347)
#macro COL_WARN     rgb(0xff7a6a)
#macro COL_GOOD     rgb(0x5ee08a)

/* --------------------------------------------------------------- buttons */

/// Register a button for this frame. Returns true if it currently has focus.
function ui_button(_x, _y, _w, _h, _action, _arg, _enabled) {
    var _G = global.G;
    var _idx = array_length(_G.btns);
    array_push(_G.btns, { x: _x, y: _y, w: _w, h: _h, action: _action, arg: _arg, enabled: _enabled });
    if (_G.focus_want != "" && _G.focus_want == _action && _enabled) { _G.focus = _idx; _G.focus_want = ""; }
    return _idx == _G.focus;
}

function ui_step_focus(_from, _dir) {
    var _b = global.G.btns, _n = array_length(_b);
    if (_n == 0) return 0;
    var _i = _from;
    repeat (_n) {
        _i = (_i + _dir + _n) mod _n;
        if (_b[_i].enabled) return _i;
    }
    return _from;
}

function ui_fire(_b) {
    global.G.btns = [];
    ui_do(_b.action, _b.arg);
}

/// Shared menu input. Used by overlays (mode "ui") and combat menus.
function ui_input() {
    var _G = global.G;
    var _b = _G.btns, _n = array_length(_b);
    if (_n == 0) return;
    if (_G.focus >= _n || _G.focus < 0 || !_b[_G.focus].enabled) _G.focus = ui_step_focus(-1, 1);

    // Mouse
    var _mx = device_mouse_x_to_gui(0), _my = device_mouse_y_to_gui(0);
    var _moved = _mx != _G.mouse_last_x || _my != _G.mouse_last_y;
    _G.mouse_last_x = _mx; _G.mouse_last_y = _my;
    for (var _i = 0; _i < _n; _i++) {
        var _bt = _b[_i];
        if (!_bt.enabled) continue;
        if (point_in_rectangle(_mx, _my, _bt.x, _bt.y, _bt.x + _bt.w, _bt.y + _bt.h)) {
            if (_moved) _G.focus = _i;
            if (mouse_check_button_pressed(mb_left)) { ui_fire(_bt); return; }
        }
    }

    // Number keys pick the Nth enabled option
    for (var _k = 1; _k <= 9; _k++) {
        if (keyboard_check_pressed(ord(string(_k)))) {
            var _c = 0;
            for (var _i = 0; _i < _n; _i++) if (_b[_i].enabled) { _c++; if (_c == _k) { ui_fire(_b[_i]); return; } }
        }
    }

    var _d = inp_dir();
    if (_d == "U" || _d == "L") _G.focus = ui_step_focus(_G.focus, -1);
    if (_d == "D" || _d == "R") _G.focus = ui_step_focus(_G.focus, 1);

    if (inp_confirm()) {
        if (_G.focus >= 0 && _G.focus < _n && _b[_G.focus].enabled) { ui_fire(_b[_G.focus]); return; }
    }

    if (inp_back()) {
        if (_G.mode == "ui" && _G.overlay_closable) { overlay_close(); return; }
        if (_G.mode == "combat") {
            for (var _i = 0; _i < _n; _i++) if (_b[_i].action == "cback") { ui_fire(_b[_i]); return; }
        }
    }
}

function ui_do(_action, _arg) {
    var _G = global.G;
    switch (_action) {
        case "toggle":
            if (arr_has(_G.sel, _arg)) arr_remove(_G.sel, _arg);
            else if (array_length(_G.sel) < MAX_PARTY) array_push(_G.sel, _arg);
            break;
        case "rest":
            _G.teacher.hp = _G.teacher.maxHp;
            for (var _i = 0; _i < array_length(_G.roster); _i++) _G.roster[_i].hp = _G.roster[_i].maxHp;
            toast("Everyone rests and recovers.");
            break;
        case "leave":
            _G.party = array_filter(_G.roster, function(_m) { return arr_has(global.G.sel, _m.key); });
            party_place();
            overlay_close();
            break;
        case "craft": do_craft(global.RECIPES[_arg]); break;
        case "close": overlay_close(); break;
        case "cpick": case "cback": combat_pick(_arg); break;
    }
}

/* -------------------------------------------------------------- overlays */

function overlay_open(_name, _closable) {
    var _G = global.G;
    _G.overlay = _name;
    _G.overlay_closable = _closable;
    _G.mode = "ui";
    _G.focus = 0;
    _G.focus_want = _name == "roster" ? "leave" : "";
    _G.btns = [];
    _G.prompt = "";
}

function overlay_close() {
    var _G = global.G;
    _G.overlay = "";
    _G.mode = "explore";
    _G.btns = [];
}

function roster_open(_intro) {
    var _G = global.G;
    _G.intro = _intro;
    _G.sel = [];
    for (var _i = 0; _i < array_length(_G.party); _i++) array_push(_G.sel, _G.party[_i].key);
    overlay_open("roster", false);
}

function craft_open() { overlay_open("craft", true); }

function recipe_can(_r) {
    if (_r.once && (global.G.crafted[$ _r.key] ?? false)) return false;
    for (var _i = 0; _i < array_length(_r.cost); _i++) if (inv_count(_r.cost[_i][0]) < _r.cost[_i][1]) return false;
    return true;
}

function cost_text(_pairs) {
    var _a = [];
    for (var _i = 0; _i < array_length(_pairs); _i++) array_push(_a, $"{global.ITEMS[$ _pairs[_i][0]].name} ×{_pairs[_i][1]}");
    return str_join(_a, ", ");
}

function do_craft(_r) {
    var _G = global.G;
    if (!recipe_can(_r)) return;
    for (var _i = 0; _i < array_length(_r.cost); _i++) inv_add(_r.cost[_i][0], -_r.cost[_i][1]);
    for (var _i = 0; _i < array_length(_r.gives); _i++) inv_add(_r.gives[_i][0], _r.gives[_i][1]);
    if (_r.key == "bat") {
        _G.teacher.atk += 4; learn(_G.teacher, "power_swing");
        toast("Reinforced Bat crafted: ATK +4, learned Power Swing!");
    } else if (_r.key == "vest") {
        _G.teacher.def += 2;
        for (var _i = 0; _i < array_length(_G.roster); _i++) _G.roster[_i].def += 2;
        toast("Riot Vest crafted: party DEF +2!");
    } else {
        toast($"Crafted {_r.name}.", 1.6);
    }
    if (_r.once) _G.crafted[$ _r.key] = true;
}

/* -------------------------------------------------------- drawing helpers */

function draw_panel(_x1, _y1, _x2, _y2, _fill = COL_PANEL, _line = COL_LINE, _alpha = 0.96) {
    draw_set_alpha(_alpha);
    draw_set_colour(_fill);
    draw_roundrect_ext(_x1, _y1, _x2, _y2, 14, 14, false);
    draw_set_alpha(1);
    draw_set_colour(_line);
    draw_roundrect_ext(_x1, _y1, _x2, _y2, 14, 14, true);
}

function draw_txt(_x, _y, _s, _col = COL_TEXT, _font = fnt_ui, _halign = fa_left, _w = -1) {
    draw_set_font(_font);
    draw_set_colour(_col);
    draw_set_halign(_halign);
    draw_set_valign(fa_top);
    if (_w > 0) tdraw_ext(_x, _y, _s, _w); else tdraw(_x, _y, _s);
    draw_set_halign(fa_left);
}

function txt_h(_s, _font, _w) {
    draw_set_font(_font);
    return _w > 0 ? string_height_ext(_s, -1, _w / TXT_S) * TXT_S : string_height(_s) * TXT_S;
}

/// Standard button. Registers it and draws it.
function ui_draw_button(_x, _y, _w, _h, _label, _action, _arg, _enabled = true, _primary = false, _sub = "") {
    var _f = ui_button(_x, _y, _w, _h, _action, _arg, _enabled);
    var _fill = _primary ? rgb(0x7a4a14) : COL_PANEL2;
    if (!_enabled) _fill = rgb(0x151922);
    else if (_f) _fill = merge_colour(_fill, c_white, 0.12);
    draw_set_colour(_fill);
    draw_roundrect_ext(_x, _y, _x + _w, _y + _h, 10, 10, false);
    draw_set_colour(_f && _enabled ? COL_ACCENT : (_primary ? COL_ACCENT : COL_LINE));
    draw_roundrect_ext(_x, _y, _x + _w, _y + _h, 10, 10, true);
    var _tc = _enabled ? COL_TEXT : rgb(0x5a6274);
    if (_sub == "") {
        draw_set_font(fnt_ui); draw_set_colour(_tc);
        draw_set_halign(fa_center); draw_set_valign(fa_middle);
        tdraw(_x + _w / 2, _y + _h / 2, _label);
        draw_set_halign(fa_left); draw_set_valign(fa_top);
    } else {
        draw_txt(_x + 12, _y + 6, _label, _tc, fnt_ui);
        draw_txt(_x + 12, _y + 28, _sub, _enabled ? COL_MUTED : rgb(0x4a5264), fnt_small);
    }
    return _f;
}

/* ------------------------------------------------------- overlay drawing */

function draw_overlay() {
    var _G = global.G;
    draw_set_alpha(0.6); draw_set_colour(c_black);
    draw_rectangle(0, 0, GUI_W, GUI_H, false);
    draw_set_alpha(1);
    switch (_G.overlay) {
        case "roster":  draw_roster(); break;
        case "craft":   draw_craft(); break;
        case "journal": draw_journal(); break;
        case "finish":  draw_finish(); break;
    }
}

function draw_roster() {
    var _G = global.G;
    var _x1 = 110, _y1 = 40, _x2 = GUI_W - 110, _y2 = GUI_H - 40;
    draw_panel(_x1, _y1, _x2, _y2);
    draw_txt(_x1 + 30, _y1 + 22, _G.intro ? "Apocalypse 101" : "Classroom", COL_ACCENT, fnt_title);
    var _p = _G.intro
        ? "Everyone else has vanished. You are the teacher. Choose 0–3 students to bring along. No one gets left behind: the party moves as one."
        : "Choose 0–3 students to accompany you.";
    draw_txt(_x1 + 30, _y1 + 66, _p, COL_MUTED, fnt_ui, fa_left, _x2 - _x1 - 60);

    var _cw = 330, _ch = 186, _gap = 15;
    var _gx = _x1 + 30, _gy = _y1 + 120;
    for (var _i = 0; _i < array_length(_G.roster); _i++) {
        var _m = _G.roster[_i];
        var _cx = _gx + (_i mod 3) * (_cw + _gap), _cy = _gy + (_i div 3) * (_ch + _gap);
        var _sel = arr_has(_G.sel, _m.key);
        var _can = _sel || array_length(_G.sel) < MAX_PARTY;
        var _f = ui_button(_cx, _cy, _cw, _ch, "toggle", _m.key, true);
        draw_set_colour(_sel ? rgb(0x2a2414) : COL_PANEL2);
        draw_roundrect_ext(_cx, _cy, _cx + _cw, _cy + _ch, 12, 12, false);
        draw_set_colour(_sel ? COL_ACCENT : (_f ? COL_TEXT : COL_LINE));
        draw_roundrect_ext(_cx, _cy, _cx + _cw, _cy + _ch, 12, 12, true);
        if (_f && _sel) { draw_roundrect_ext(_cx + 1, _cy + 1, _cx + _cw - 1, _cy + _ch - 1, 12, 12, true); }
        if (!_can) { draw_set_alpha(0.35); draw_set_colour(c_black); draw_roundrect_ext(_cx, _cy, _cx + _cw, _cy + _ch, 12, 12, false); draw_set_alpha(1); }

        draw_set_colour(_m.colour); draw_circle(_cx + 22, _cy + 22, 9, false);
        draw_txt(_cx + 40, _cy + 10, $"{_i + 1}. {_m.name}", COL_TEXT, fnt_ui);
        if (_sel) draw_txt(_cx + _cw - 14, _cy + 12, "IN PARTY", COL_ACCENT, fnt_small, fa_right);
        draw_txt(_cx + 14, _cy + 40, $"{_m.major} · {_m.clique} · Lv{_m.level}", COL_MUTED, fnt_small);
        draw_txt(_cx + 14, _cy + 62, $"ATK {_m.atk}    HP {_m.maxHp}    DEF {_m.def}    INT {_m.int}", COL_TEXT, fnt_small);
        var _sk = [];
        for (var _s = 0; _s < array_length(_m.skills); _s++) array_push(_sk, global.SKILLS[$ _m.skills[_s]].name);
        draw_txt(_cx + 14, _cy + 84, "Skills: " + str_join(_sk, ", "), COL_MUTED, fnt_small, fa_left, _cw - 28);
        draw_txt(_cx + 14, _cy + 106, "\"" + _m.blurb + "\"", COL_MUTED, fnt_small, fa_left, _cw - 28);
        var _ty = _cy + 132;
        if (!_m.canJump) { draw_txt(_cx + 14, _ty, "! Cannot jump obstacles", COL_WARN, fnt_small); _ty += 20; }
        if (_m.trait == "craftAnywhere") draw_txt(_cx + 14, _ty, "* Group can craft anywhere", COL_ACCENT, fnt_small);
        // HP if hurt
        if (_m.hp < _m.maxHp) draw_txt(_cx + _cw - 14, _cy + 40, $"HP {_m.hp}/{_m.maxHp}", COL_WARN, fnt_small, fa_right);
    }

    var _by = _y2 - 62;
    var _n = array_length(_G.sel);
    draw_txt(_x1 + 30, _by + 12, $"Party {_n}/{MAX_PARTY}", COL_MUTED, fnt_ui);
    ui_draw_button(_x2 - 30 - 360 - 12 - 180, _by, 180, 42, "Rest (full heal)", "rest", 0);
    ui_draw_button(_x2 - 30 - 360, _by, 360, 42, $"Leave classroom with {_n} student{_n == 1 ? "" : "s"}", "leave", 0, true, true);
}

function draw_craft() {
    var _G = global.G;
    var _x1 = 240, _y1 = 110, _x2 = GUI_W - 240, _y2 = GUI_H - 110;
    draw_panel(_x1, _y1, _x2, _y2);
    draw_txt(_x1 + 30, _y1 + 22, "Crafting", COL_ACCENT, fnt_title);
    var _mats = [];
    for (var _i = 0; _i < array_length(global.ITEM_ORDER); _i++) {
        var _k = global.ITEM_ORDER[_i];
        if (inv_count(_k) > 0 && global.ITEMS[$ _k].kind == "material") array_push(_mats, $"{global.ITEMS[$ _k].name} ×{inv_count(_k)}");
    }
    draw_txt(_x1 + 30, _y1 + 66, "You have: " + (array_length(_mats) ? str_join(_mats, ", ") : "no materials"), COL_MUTED, fnt_ui);
    var _ry = _y1 + 104;
    for (var _i = 0; _i < array_length(global.RECIPES); _i++) {
        var _r = global.RECIPES[_i];
        var _done = _r.once && (_G.crafted[$ _r.key] ?? false);
        draw_set_colour(COL_PANEL2);
        draw_roundrect_ext(_x1 + 30, _ry, _x2 - 30, _ry + 74, 10, 10, false);
        draw_txt(_x1 + 46, _ry + 10, _r.name, COL_TEXT, fnt_ui);
        draw_txt(_x1 + 46, _ry + 36, $"{_r.desc} — Cost: {cost_text(_r.cost)}", COL_MUTED, fnt_small, fa_left, _x2 - _x1 - 240);
        ui_draw_button(_x2 - 30 - 140, _ry + 16, 124, 42, _done ? "Crafted" : "Craft", "craft", _i, recipe_can(_r));
        _ry += 86;
    }
    ui_draw_button(_x2 - 30 - 160, _y2 - 62, 160, 42, "Close (Esc)", "close", 0);
}

function draw_journal() {
    var _G = global.G;
    var _x1 = 240, _y1 = 110, _x2 = GUI_W - 240, _y2 = GUI_H - 110;
    draw_panel(_x1, _y1, _x2, _y2);
    draw_txt(_x1 + 30, _y1 + 22, "Journal", COL_ACCENT, fnt_title);
    var _y = _y1 + 76;
    if (array_length(_G.clues) == 0) draw_txt(_x1 + 30, _y, "No clues yet.", COL_MUTED, fnt_ui);
    for (var _i = 0; _i < array_length(_G.clues); _i++) {
        draw_set_colour(rgb(0xfff27a)); draw_circle(_x1 + 38, _y + 11, 4, false);
        draw_txt(_x1 + 54, _y, _G.clues[_i], COL_TEXT, fnt_ui, fa_left, _x2 - _x1 - 90);
        _y += txt_h(_G.clues[_i], fnt_ui, _x2 - _x1 - 90) + 14;
    }
    ui_draw_button(_x2 - 30 - 160, _y2 - 62, 160, 42, "Close (Esc)", "close", 0);
}

function draw_finish() {
    var _x1 = 300, _y1 = 220, _x2 = GUI_W - 300, _y2 = GUI_H - 220;
    draw_panel(_x1, _y1, _x2, _y2);
    draw_txt(_x1 + 30, _y1 + 22, "Prototype complete", COL_ACCENT, fnt_title);
    draw_txt(_x1 + 30, _y1 + 70, "You found every clue. The mystery of the disappearance continues in the full game.", COL_TEXT, fnt_ui, fa_left, _x2 - _x1 - 60);
    ui_draw_button(_x2 - 30 - 200, _y2 - 62, 200, 42, "Keep exploring", "close", 0, true, true);
}
