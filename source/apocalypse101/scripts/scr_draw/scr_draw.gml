// Rendering. Exploration is top-down using the LimeZu Modern Exteriors / Interiors art
// (16 px tiles drawn at 3x, see scr_atlas); combat is a drawn first-person school hallway.

#macro HS 14   // pixels per unit of height (hop / lift offsets)

/* ================================================================ atlas */

/// Draw atlas region `_name` with its top-left at (x, y).
function atl_draw(_name, _x, _y, _xs = AS, _ys = AS, _col = c_white, _a = 1) {
    var _r = global.ATLAS[$ _name];
    draw_sprite_part_ext(spr_atlas, 0, _r[0], _r[1], _r[2], _r[3], _x, _y, _xs, _ys, _col, _a);
}

/// Draw atlas region anchored at its bottom-centre.
function atl_draw_bc(_name, _x, _y, _col = c_white, _a = 1) {
    var _r = global.ATLAS[$ _name];
    draw_sprite_part_ext(spr_atlas, 0, _r[0], _r[1], _r[2], _r[3], round(_x - _r[2] * AS / 2), round(_y - _r[3] * AS), AS, AS, _col, _a);
}

/// Draw one 16x16 cell of a (possibly larger, repeating) tile pattern at grid cell (ix, iz).
function atl_tile(_name, _ix, _iz) {
    var _r = global.ATLAS[$ _name];
    var _cx = (_ix mod (_r[2] div 16)) * 16, _cz = (_iz mod (_r[3] div 16)) * 16;
    draw_sprite_part_ext(spr_atlas, 0, _r[0] + _cx, _r[1] + _cz, 16, 16, _ix * U, _iz * U, AS, AS, c_white, 1);
}

/// Which ground tile sits at grid cell (ix, iz).
function ground_at(_ix, _iz) {
    var _x = _ix - 30 + 0.5, _z = _iz - 20 + 0.5;
    if (_x > -28 && _x < -16 && _z > -8 && _z < 8) return "floor";
    if (_x > 16.5) return "pave";
    if (_x > -22 && _x < 18 && abs(_z) < 2.5) return "asphalt";
    return ((_ix * 7 + _iz * 13) mod 9 == 0) ? "grass2" : "grass";
}

/* ================================================================ world */

function draw_world() {
    var _G = global.G;
    if (_G.mode == "combat") return;
    gpu_set_tex_filter(false);

    // Ground: only the tiles inside the camera view
    var _cam = view_camera[0];
    var _cx = camera_get_view_x(_cam), _cy = camera_get_view_y(_cam);
    var _ix0 = max(0, floor(_cx / U)), _iz0 = max(0, floor(_cy / U));
    var _ix1 = min(room_width div U - 1, ceil((_cx + camera_get_view_width(_cam)) / U));
    var _iz1 = min(room_height div U - 1, ceil((_cy + camera_get_view_height(_cam)) / U));
    for (var _iz = _iz0; _iz <= _iz1; _iz++)
        for (var _ix = _ix0; _ix <= _ix1; _ix++) atl_tile(ground_at(_ix, _iz), _ix, _iz);

    // Depth-sorted scene (by the front edge of each thing)
    var _list = [];
    for (var _i = 0; _i < array_length(_G.boxes); _i++) {
        var _b = _G.boxes[_i];
        if (_b.kind == "fence") {
            // one entry per post so characters sort correctly against it
            for (var _z = -20 + 28 / 16; _z <= 20.01; _z += 28 / 16) {
                if (_G.fence_cleared && abs(_z - 0.3) < 2.4) continue; // the gap the party vaulted
                array_push(_list, { k: _z, t: 5, r: _z });
            }
            continue;
        }
        array_push(_list, { k: _b.z2, t: 0, r: _b });
    }
    for (var _i = 0; _i < array_length(_G.trees); _i++) array_push(_list, { k: _G.trees[_i].z + 0.4, t: 1, r: _G.trees[_i] });
    for (var _i = 0; _i < array_length(_G.decor); _i++) array_push(_list, { k: _G.decor[_i].z, t: 6, r: _G.decor[_i] });
    for (var _i = 0; _i < array_length(_G.items); _i++) array_push(_list, { k: _G.items[_i].z, t: 2, r: _G.items[_i] });
    for (var _i = 0; _i < array_length(_G.enemies); _i++) array_push(_list, { k: _G.enemies[_i].z, t: 3, r: _G.enemies[_i] });
    array_push(_list, { k: _G.teacher.pz, t: 4, r: _G.teacher });
    for (var _i = 0; _i < array_length(_G.roster); _i++) array_push(_list, { k: _G.roster[_i].pz, t: 4, r: _G.roster[_i] });
    array_sort(_list, function(_a, _b) { return sign(_a.k - _b.k); }); // sign(): comparator results are truncated to integers

    for (var _i = 0; _i < array_length(_list); _i++) {
        var _e = _list[_i];
        switch (_e.t) {
            case 0: draw_box(_e.r); break;
            case 1: atl_draw_bc(_e.r.art, wx(_e.r.x), wy(_e.r.z) + 0.45 * U); break;
            case 2: draw_item(_e.r); break;
            case 3: draw_explore_enemy(_e.r); break;
            case 4: draw_char(_e.r); break;
            case 5: atl_draw_bc("fence", wx(FENCE_X), wy(_e.r)); break;
            case 6: atl_draw_bc(_e.r.art, wx(_e.r.x), wy(_e.r.z)); break;
        }
    }

    // Night: multiply everything by a cool dark tint...
    var _vw = camera_get_view_width(_cam), _vh = camera_get_view_height(_cam);
    gpu_set_blendmode_ext(bm_dest_colour, bm_zero);
    draw_set_colour(rgb(0x7480a8));
    draw_rectangle(_cx - 2, _cy - 2, _cx + _vw + 2, _cy + _vh + 2, false);
    gpu_set_blendmode(bm_normal);

    // ...then add the lights back
    gpu_set_blendmode(bm_add);
    draw_set_alpha(0.16); draw_set_colour(rgb(0xffd9a0));          // classroom lights are still on
    draw_rectangle(wx(-28), wy(-8), wx(-16), wy(8), false);
    draw_set_alpha(1);
    var _t = _G.teacher;
    draw_circle_colour(wx(_t.px), wy(_t.pz) - U * 0.6, 3.2 * U, rgb(0x2a2a22), c_black, false); // the teacher's torch
    var _pulse = 0.6 + sin(_G.time * 3) * 0.25;
    for (var _i = 0; _i < array_length(_G.tables); _i++) {
        var _tb = _G.tables[_i];
        draw_circle_colour(wx(_tb.x), wy(_tb.z) - 20, 3.4 * U, merge_colour(c_black, rgb(0x6a3a10), _pulse), c_black, false);
    }
    for (var _i = 0; _i < array_length(_G.items); _i++) {
        var _n = _G.items[_i];
        var _c = _n.type == "clue" ? rgb(0xfff27a) : global.ITEMS[$ _n.type].colour;
        draw_circle_colour(wx(_n.x), wy(_n.z) - 14, 0.9 * U, merge_colour(c_black, _c, 0.35), c_black, false);
    }
    for (var _i = 0; _i < array_length(_G.enemies); _i++) {
        var _en = _G.enemies[_i];
        var _def = global.ENEMY_TYPES[$ _en.type];
        draw_circle_colour(wx(_en.x), wy(_en.z) - 1.2 * U * _en.scale, 1.3 * U * _en.scale, merge_colour(c_black, _def.eye, 0.22), c_black, false);
    }
    gpu_set_blendmode(bm_normal);
    gpu_set_tex_filter(true);
}

function draw_box(_b) {
    var _x1 = wx(_b.x1), _x2 = wx(_b.x2), _y1 = wy(_b.z1), _y2 = wy(_b.z2);
    var _mx = (_x1 + _x2) / 2;
    switch (_b.kind) {
        case "wall_n": case "wall":
            // LimeZu-style wall: white "ceiling" top with dark outline, wood panelling below.
            // Only the north wall shows its full face; the others show a thin edge.
            var _face = _b.kind == "wall_n" ? 2 * U : 0.35 * U;
            var _top = _y1 - _face, _bot = _y2 - _face;
            if (_b.kind == "wall_n") {
                var _r = global.ATLAS.wall;
                for (var _x = _x1; _x < _x2; _x += 16 * AS) {
                    var _w = min(16, (_x2 - _x) / AS);
                    draw_sprite_part_ext(spr_atlas, 0, _r[0], _r[1], _w, 32, _x, _bot, AS, AS, c_white, 1);
                }
            } else {
                draw_set_colour(rgb(0x8a6a48));
                draw_rectangle(_x1, _bot, _x2, _y2, false);
            }
            draw_set_colour(rgb(0xf4f2ee));
            draw_rectangle(_x1, _top, _x2, _bot, false);
            draw_set_colour(rgb(0x3a3d4a));
            draw_rectangle(_x1, _top, _x2, _bot, true);
            draw_rectangle(_x1 + 1, _top + 1, _x2 - 1, _bot - 1, true);
            break;
        case "wallart": atl_draw_bc(_b.art, _mx, _y2 - 0.9 * U); break;
        case "desk":    atl_draw_bc(_b.art, _mx, _y2 + 0.2 * U); break;
        case "prop":    atl_draw_bc(_b.art, _mx, _y2 + 0.2 * U); break;
        case "table":   atl_draw_bc("workbench", _mx, _y2 + 0.3 * U); break;
        case "school":  atl_draw_bc("school", _mx, _y2 + 2 * U); break;
        case "tower":   atl_draw_bc("tower", _mx, _y2 + 0.4 * U); break;
        case "car1": case "car2": case "container":
            atl_draw_bc(_b.kind, _mx, _y2 + 0.5 * U); break;
    }
}

function draw_item(_n) {
    var _G = global.G;
    var _x = wx(_n.x), _y = wy(_n.z) - (0.8 + sin(_G.time * 2 + _n.phase) * 0.12) * HS * 1.4;
    draw_set_alpha(0.3); draw_set_colour(c_black);
    draw_ellipse(wx(_n.x) - 9, wy(_n.z) - 3, wx(_n.x) + 9, wy(_n.z) + 3, false);
    draw_set_alpha(1);
    var _spin = cos(_G.time * 2 + _n.phase);
    if (_n.type == "clue") {
        var _w = max(2, abs(_spin) * 10);
        draw_set_colour(rgb(0xfff27a));
        draw_rectangle(_x - _w, _y - 13, _x + _w, _y + 13, false);
        draw_set_colour(rgb(0x9a8a3a));
        if (_w > 5) for (var _l = -7; _l <= 7; _l += 5) draw_line(_x - _w + 3, _y + _l, _x + _w - 3, _y + _l);
    } else {
        var _c = global.ITEMS[$ _n.type].colour;
        var _w = max(2, abs(_spin) * 13);
        draw_primitive_begin(pr_trianglefan);
        draw_vertex_colour(_x, _y, merge_colour(_c, c_white, 0.3), 1);
        draw_vertex_colour(_x, _y - 14, _c, 1);
        draw_vertex_colour(_x + _w, _y, merge_colour(_c, c_black, 0.25), 1);
        draw_vertex_colour(_x, _y + 14, merge_colour(_c, c_black, 0.4), 1);
        draw_vertex_colour(_x - _w, _y, _c, 1);
        draw_vertex_colour(_x, _y - 14, _c, 1);
        draw_primitive_end();
    }
}

/// Character sprite frame: strips are 24 frames of 16x32 (right, up, left, down x6);
/// row 0 = idle animation, row 1 = walk.
function char_frame(_spr, _face, _moving, _x, _y, _scale = AS, _col = c_white, _a = 1, _phase = 0) {
    var _dir = ((round(_face / 90) mod 4) + 4) mod 4;
    var _f = floor(global.G.time * (_moving ? 10 : 6) + _phase) mod 6;
    draw_sprite_part_ext(_spr, 0, (_dir * 6 + _f) * 16, _moving ? 32 : 0, 16, 32,
        round(_x - 8 * _scale), round(_y - 31 * _scale), _scale, _scale, _col, _a);
}

function draw_char(_m) {
    var _x = wx(_m.px), _y = wy(_m.pz), _lift = _m.py * HS * 1.4;
    draw_set_alpha(0.35); draw_set_colour(c_black);
    draw_ellipse(_x - 16, _y - 6, _x + 16, _y + 6, false);
    draw_set_alpha(1);
    char_frame(_m.spr, _m.face, _m.moving, _x, _y - _lift, AS, c_white, 1, _m.px);
}

function draw_explore_enemy(_e) {
    var _s = _e.scale;
    var _def = global.ENEMY_TYPES[$ _e.type];
    var _x = wx(_e.x), _y = wy(_e.z);
    draw_set_alpha(0.35); draw_set_colour(c_black);
    draw_ellipse(_x - 18 * _s, _y - 6 * _s, _x + 18 * _s, _y + 6 * _s, false);
    draw_set_alpha(1);
    // Zombies from the pack, darkened into shadow silhouettes with glowing eyes
    var _spr = _e.type == "hollow" ? spr_en_hollow : spr_en_shade;
    var _tint = _e.type == "hollow" ? rgb(0x2a4a52) : rgb(0x4a2c58);
    char_frame(_spr, _e.face, true, _x, _y, AS * _s, _tint, 1, _e.hx);
    var _dir = ((round(_e.face / 90) mod 4) + 4) mod 4;
    if (_dir != 1) { // eyes visible unless walking away
        var _hy = _y - 20 * AS * _s, _ex = (_dir == 0 ? 2 : (_dir == 2 ? -2 : 0)) * AS * _s;
        draw_set_colour(_def.eye);
        if (_dir == 3) { draw_circle(_x - 2.5 * AS * _s, _hy, 0.9 * AS * _s, false); draw_circle(_x + 2.5 * AS * _s, _hy, 0.9 * AS * _s, false); }
        else draw_circle(_x + _ex, _hy, 0.9 * AS * _s, false);
    }
    if (_e.count > 1) {
        draw_set_font(fnt_small); draw_set_halign(fa_center); draw_set_colour(_def.eye);
        tdraw(_x, _y - 36 * AS * _s, $"×{_e.count}");
        draw_set_halign(fa_left);
    }
}

/// Small portrait (front-facing idle frame) for menus/HUD.
function draw_portrait(_m, _x, _y, _scale) {
    gpu_set_tex_filter(false);
    draw_sprite_part_ext(_m.spr, 0, 18 * 16, 0, 16, 32, _x, _y, _scale, _scale, c_white, 1);
    gpu_set_tex_filter(true);
}

/* ================================================================== GUI */

function draw_gui() {
    var _G = global.G;
    _G.btns = [];
    draw_set_alpha(1);
    if (_G.mode == "combat") { draw_combat(); return; }
    draw_vignette();
    draw_hud();
    if (_G.mode == "ui") draw_overlay();
}

function draw_vignette() {
    var _a = 0.55, _w = 220;
    draw_primitive_begin(pr_trianglelist);
    // top
    draw_vertex_colour(0, 0, c_black, _a); draw_vertex_colour(GUI_W, 0, c_black, _a); draw_vertex_colour(0, _w * 0.6, c_black, 0);
    draw_vertex_colour(GUI_W, 0, c_black, _a); draw_vertex_colour(GUI_W, _w * 0.6, c_black, 0); draw_vertex_colour(0, _w * 0.6, c_black, 0);
    // bottom
    draw_vertex_colour(0, GUI_H, c_black, _a); draw_vertex_colour(GUI_W, GUI_H, c_black, _a); draw_vertex_colour(0, GUI_H - _w * 0.6, c_black, 0);
    draw_vertex_colour(GUI_W, GUI_H, c_black, _a); draw_vertex_colour(GUI_W, GUI_H - _w * 0.6, c_black, 0); draw_vertex_colour(0, GUI_H - _w * 0.6, c_black, 0);
    // left
    draw_vertex_colour(0, 0, c_black, _a); draw_vertex_colour(0, GUI_H, c_black, _a); draw_vertex_colour(_w, 0, c_black, 0);
    draw_vertex_colour(0, GUI_H, c_black, _a); draw_vertex_colour(_w, GUI_H, c_black, 0); draw_vertex_colour(_w, 0, c_black, 0);
    // right
    draw_vertex_colour(GUI_W, 0, c_black, _a); draw_vertex_colour(GUI_W, GUI_H, c_black, _a); draw_vertex_colour(GUI_W - _w, 0, c_black, 0);
    draw_vertex_colour(GUI_W, GUI_H, c_black, _a); draw_vertex_colour(GUI_W - _w, GUI_H, c_black, 0); draw_vertex_colour(GUI_W - _w, 0, c_black, 0);
    draw_primitive_end();
}

function draw_bar(_x, _y, _w, _h, _frac, _col, _bg = rgb(0x0c0f16)) {
    draw_set_colour(_bg);
    draw_rectangle(_x, _y, _x + _w, _y + _h, false);
    draw_set_colour(_col);
    if (_frac > 0) draw_rectangle(_x, _y, _x + _w * clamp(_frac, 0, 1), _y + _h, false);
}

function draw_member_card(_m, _x, _y, _w, _active, _show_xp) {
    var _ko = _m.hp <= 0;
    var _h = _show_xp ? 62 : 56;
    if (is_struct(_m.buff)) _h += 18;
    draw_panel(_x, _y, _x + _w, _y + _h, _active ? rgb(0x2a2414) : COL_PANEL, _active ? COL_ACCENT : COL_LINE, 0.9);
    gpu_set_tex_filter(false);
    draw_sprite_part_ext(_m.spr, 0, 18 * 16 + 1, 10, 14, 14, _x + 5, _y + 4, 1.6, 1.6, _ko ? c_gray : c_white, 1);
    gpu_set_tex_filter(true);
    draw_txt(_x + 30, _y + 6, _m.name, _ko ? COL_MUTED : COL_TEXT, fnt_ui);
    draw_txt(_x + _w - 10, _y + 9, $"Lv{_m.level} · " + (_ko ? "KO" : $"{_m.hp}/{_m.maxHp}"), _ko ? COL_WARN : COL_MUTED, fnt_small, fa_right);
    var _frac = _m.hp / _m.maxHp;
    draw_bar(_x + 10, _y + 34, _w - 20, 8, _frac, _frac > 0.5 ? COL_GOOD : (_frac > 0.25 ? COL_ACCENT : COL_WARN));
    var _ny = _y + 46;
    if (_show_xp) { draw_bar(_x + 10, _y + 47, _w - 20, 4, _m.xp / (_m.level * 25), rgb(0x6aa0f0)); _ny = _y + 54; }
    if (is_struct(_m.buff)) draw_txt(_x + 10, _ny, $"ATK +{round((_m.buff.mult - 1) * 100)}% ({_m.buff.turns})", COL_ACCENT, fnt_small);
    return _h;
}

function draw_hud() {
    var _G = global.G;
    // Party (top-left)
    var _y = 14, _all = everyone();
    for (var _i = 0; _i < array_length(_all); _i++) _y += draw_member_card(_all[_i], 14, _y, 250, false, true) + 8;

    // Inventory + objective (top-right)
    var _x1 = GUI_W - 344, _x2 = GUI_W - 14;
    var _inv = [];
    for (var _i = 0; _i < array_length(global.ITEM_ORDER); _i++) {
        var _k = global.ITEM_ORDER[_i];
        if (inv_count(_k) > 0) array_push(_inv, $"{global.ITEMS[$ _k].name} ×{inv_count(_k)}");
    }
    var _invs = array_length(_inv) ? str_join(_inv, " · ") : "Empty";
    var _ih = 34 + txt_h(_invs, fnt_small, _x2 - _x1 - 24);
    draw_panel(_x1, 14, _x2, 14 + _ih, COL_PANEL, COL_LINE, 0.9);
    draw_txt(_x1 + 12, 20, "Inventory", COL_ACCENT, fnt_ui);
    draw_txt(_x1 + 12, 42, _invs, COL_TEXT, fnt_small, fa_left, _x2 - _x1 - 24);

    var _oy = 14 + _ih + 8;
    var _obj = _G.fence_cleared ? "The east quad is open." : "A fence blocks the east quad. Everyone must be able to clear it.";
    var _body = "Scavenge the campus and piece together what happened.\n" + _obj;
    var _oh = 34 + txt_h(_body, fnt_small, _x2 - _x1 - 24);
    draw_panel(_x1, _oy, _x2, _oy + _oh, COL_PANEL, COL_LINE, 0.9);
    draw_txt(_x1 + 12, _oy + 6, $"Clues {array_length(_G.clues)}/{array_length(global.CLUES)}", rgb(0xfff27a), fnt_ui);
    draw_txt(_x1 + 12, _oy + 28, _body, COL_MUTED, fnt_small, fa_left, _x2 - _x1 - 24);

    // Interaction prompt
    if (_G.mode == "explore" && _G.prompt != "") {
        draw_set_font(fnt_ui);
        var _pw = twidth(_G.prompt) + 36;
        draw_panel(GUI_W / 2 - _pw / 2, GUI_H - 104, GUI_W / 2 + _pw / 2, GUI_H - 68, rgb(0x2a2414), COL_ACCENT, 0.95);
        draw_txt(GUI_W / 2, GUI_H - 99, _G.prompt, COL_ACCENT, fnt_ui, fa_center);
    }

    // Toast
    if (_G.toast_t > 0 && _G.toast_text != "") {
        var _a = clamp(_G.toast_t / 0.3, 0, 1);
        var _tw = 560;
        var _th = txt_h(_G.toast_text, fnt_ui, _tw - 36) + 22;
        draw_set_alpha(_a);
        draw_panel(GUI_W / 2 - _tw / 2, 18, GUI_W / 2 + _tw / 2, 18 + _th, COL_PANEL2, COL_LINE, 0.95 * _a);
        draw_set_alpha(_a);
        draw_txt(GUI_W / 2, 29, _G.toast_text, COL_TEXT, fnt_ui, fa_center, _tw - 36);
        draw_set_alpha(1);
    }

    // Controls help
    draw_txt(GUI_W / 2, GUI_H - 30,
        "WASD / Arrows / Left stick  move  ·  E / Space / A  interact  ·  H / X  heal  ·  C / Y  craft anywhere  ·  J / Start  journal  ·  F11  fullscreen",
        COL_MUTED, fnt_small, fa_center);
}

/* =============================================================== combat */

#macro CF 520     // focal length in pixels
#macro CBG rgb(0x05060a)

/// Project a hallway point to the screen. Returns [sx, sy, pixels-per-unit, depth].
function cproj(_x, _y, _z) {
    var _c = global.G.c;
    var _d = max(0.35, 3 - _z);
    var _sx = GUI_W / 2 + _x * CF / _d + _c.shx;
    var _sy = GUI_H / 2 - (_y - 1.55) * CF / _d + _c.shy;
    return [_sx, _sy, CF / _d, _d];
}

function cfog(_col, _d) { return merge_colour(_col, CBG, clamp((_d - 5) / 19, 0, 1)); }

function cquad(_p1, _p2, _p3, _p4, _col) {
    draw_primitive_begin(pr_trianglestrip);
    draw_vertex_colour(_p1[0], _p1[1], _col, 1);
    draw_vertex_colour(_p2[0], _p2[1], _col, 1);
    draw_vertex_colour(_p4[0], _p4[1], _col, 1);
    draw_vertex_colour(_p3[0], _p3[1], _col, 1);
    draw_primitive_end();
}

function draw_combat() {
    var _G = global.G, _c = _G.c;
    _c.shx = (random(1) - 0.5) * _c.shake * 60;
    _c.shy = (random(1) - 0.5) * _c.shake * 40;

    draw_set_colour(CBG);
    draw_rectangle(0, 0, GUI_W, GUI_H, false);

    // Hallway slices, far to near
    for (var _z = -17; _z < 2; _z += 1) {
        var _z0 = _z, _z1 = _z + 1;
        var _d = 3 - (_z0 + 0.5);
        var _alt = (_z mod 2 == 0);
        // floor
        cquad(cproj(-4.5, 0, _z0), cproj(4.5, 0, _z0), cproj(4.5, 0, _z1), cproj(-4.5, 0, _z1), cfog(_alt ? rgb(0x2a2d36) : rgb(0x30333d), _d));
        // ceiling
        cquad(cproj(-4.5, 3.6, _z0), cproj(4.5, 3.6, _z0), cproj(4.5, 3.6, _z1), cproj(-4.5, 3.6, _z1), cfog(rgb(0x1a1c22), _d));
        // side walls
        cquad(cproj(-4.5, 0, _z0), cproj(-4.5, 3.6, _z0), cproj(-4.5, 3.6, _z1), cproj(-4.5, 0, _z1), cfog(rgb(0x2e3440), _d));
        cquad(cproj(4.5, 0, _z0), cproj(4.5, 3.6, _z0), cproj(4.5, 3.6, _z1), cproj(4.5, 0, _z1), cfog(rgb(0x2e3440), _d));
    }
    // back wall
    var _b1 = cproj(-4.5, 3.6, -17), _b2 = cproj(4.5, 0, -17);
    draw_set_colour(cfog(rgb(0x14161c), 20));
    draw_rectangle(_b1[0], _b1[1], _b2[0], _b2[1], false);

    // Lockers along both walls, far to near
    var _lz = [];
    for (var _z = 2; _z > -16; _z -= 1.3) array_push(_lz, _z);
    for (var _i = array_length(_lz) - 1; _i >= 0; _i--) {
        var _z = _lz[_i];
        var _d = 3 - _z;
        for (var _s = -1; _s <= 1; _s += 2) {
            var _col = cfog((_i mod 2) ? rgb(0x3a5068) : rgb(0x35485e), _d);
            var _xf = _s * 3.65;
            cquad(cproj(_xf, 0, _z + 0.5), cproj(_xf, 2.3, _z + 0.5), cproj(_xf, 2.3, _z - 0.5), cproj(_xf, 0, _z - 0.5), _col);
            // top of locker
            cquad(cproj(_xf, 2.3, _z + 0.5), cproj(_s * 4.4, 2.3, _z + 0.5), cproj(_s * 4.4, 2.3, _z - 0.5), cproj(_xf, 2.3, _z - 0.5), cfog(rgb(0x24303e), _d));
            // vents + seam
            var _v1 = cproj(_xf, 1.9, _z + 0.3), _v2 = cproj(_xf, 1.9, _z - 0.3);
            draw_set_colour(cfog(rgb(0x1c2430), _d));
            draw_line_width(_v1[0], _v1[1], _v2[0], _v2[1], max(1, _v1[2] * 0.03));
            var _s1 = cproj(_xf, 0, _z - 0.5), _s2 = cproj(_xf, 2.3, _z - 0.5);
            draw_line_width(_s1[0], _s1[1], _s2[0], _s2[1], max(1, _s1[2] * 0.02));
        }
    }

    // Lights
    gpu_set_blendmode(bm_add);
    var _red = cproj(0, 2, -12);
    draw_circle_colour(_red[0], _red[1], _red[2] * 4.5, rgb(0x5a1020), c_black, false);
    var _hl = cproj(0, 3.55, -3);
    var _li = clamp(_c.light / 22, 0, 1.2);
    draw_circle_colour(_hl[0], _hl[1] + 60, _hl[2] * 3.2, merge_colour(c_black, rgb(0x404a66), _li), c_black, false);
    gpu_set_blendmode(bm_normal);
    var _f1 = cproj(-0.7, 3.58, -2.6), _f2 = cproj(0.7, 3.58, -3.4);
    draw_set_colour(merge_colour(rgb(0x404452), rgb(0xdfe8ff), clamp(_li, 0, 1)));
    draw_rectangle(_f1[0], _f2[1], _f2[0], _f1[1], false);

    // Enemies, far to near
    var _es = arr_copy(_c.enemies);
    array_sort(_es, function(_a, _b) { return sign(_a.hz - _b.hz); });
    for (var _i = 0; _i < array_length(_es); _i++) draw_combat_enemy(_es[_i]);

    // Flicker darkness
    draw_set_alpha(clamp(1 - _c.light / 22, 0, 0.6));
    draw_set_colour(c_black);
    draw_rectangle(0, 0, GUI_W, GUI_H, false);
    draw_set_alpha(1);

    // Damage popups
    for (var _i = 0; _i < array_length(_c.popups); _i++) {
        var _p = _c.popups[_i];
        var _pp = cproj(_p.e.hx, 2.2 * 1.5, _p.e.hz);
        draw_set_alpha(clamp(_p.t / 0.4, 0, 1));
        draw_txt(_pp[0], _pp[1] - (1 - _p.t) * 50 - 30, _p.text + (_p.crit ? "!" : ""), _p.crit ? rgb(0xffe04a) : c_white, fnt_title, fa_center);
        draw_set_alpha(1);
    }

    // Hit flash
    if (_c.flash > 0) {
        draw_set_alpha(0.45 * (_c.flash / 0.08));
        draw_set_colour(rgb(0xff2040));
        draw_rectangle(0, 0, GUI_W, GUI_H, false);
        draw_set_alpha(1);
    }

    draw_combat_ui();
}

function draw_combat_enemy(_e) {
    var _G = global.G;
    var _sc = _e.sc;
    if (_e.hp <= 0) {
        if (_e.dying <= 0) return;
        _sc = 1.5 * (_e.dying / 0.5);
    }
    var _x = _e.hx + (_e.hitT > 0 ? sin(_G.time * 70) * 0.15 : 0);
    var _z = _e.hz + sin((_e.lunge / 0.4) * pi) * 3.5;
    var _y = sin(_G.time * 2 + _e.hx) * 0.12;
    var _bot = cproj(_x, _y, _z), _head = cproj(_x, _y + 1.6 * _sc, _z);
    var _k = _bot[2], _hr = 0.4 * _sc * _k;

    // Fantasy Battlers sprite (LimeZu), tinted into a shadow creature and fogged by distance
    var _art = _e.name == "Hollow" ? "bt_hollow" : "bt_shade";
    var _tint = _e.name == "Hollow" ? rgb(0x9ec4bc) : rgb(0xa890d0);
    var _r = global.ATLAS[$ _art];
    var _s = (2.1 * _sc * _k) / _r[3];                       // ~2.1 world units tall at full size
    var _dx = round(_bot[0] - _r[2] * _s / 2), _dy = round(_bot[1] - _r[3] * _s);

    gpu_set_blendmode(bm_add);
    draw_circle_colour(_head[0], (_head[1] + _bot[1]) / 2, 1.4 * _sc * _k, merge_colour(c_black, _e.eye, 0.14), c_black, false);
    gpu_set_blendmode(bm_normal);

    gpu_set_tex_filter(false);
    draw_sprite_part_ext(spr_atlas, 0, _r[0], _r[1], _r[2], _r[3], _dx, _dy, _s, _s, cfog(_tint, _bot[3] - 4), 1);
    if (_e.hitT > 0) {
        gpu_set_fog(true, c_white, 0, 1);
        draw_sprite_part_ext(spr_atlas, 0, _r[0], _r[1], _r[2], _r[3], _dx, _dy, _s, _s, c_white, _e.hitT / 0.4 * 0.7);
        gpu_set_fog(false, c_white, 0, 1);
    }
    gpu_set_tex_filter(true);

    if (_e.stun > 0) {
        var _sp = cproj(_x, _y + 2.55 * _sc, _z);
        draw_set_colour(rgb(0xffe04a));
        for (var _a = 0; _a < 3; _a++) {
            var _ang = _G.time * 180 + _a * 120;
            draw_circle(_sp[0] + lengthdir_x(_hr, _ang), _sp[1] + lengthdir_y(_hr * 0.3, _ang), 4, false);
        }
    }
}

function draw_combat_ui() {
    var _G = global.G, _c = _G.c;

    // Enemy bars (top)
    var _n = array_length(_c.enemies), _ew = 200, _eg = 14;
    var _ex = GUI_W / 2 - (_n * _ew + (_n - 1) * _eg) / 2;
    for (var _i = 0; _i < _n; _i++) {
        var _e = _c.enemies[_i];
        var _x = _ex + _i * (_ew + _eg);
        draw_set_alpha(_e.hp <= 0 ? 0.35 : 1);
        draw_panel(_x, 14, _x + _ew, 62, COL_PANEL, _e.stun > 0 ? rgb(0xffe04a) : (_e.poison > 0 ? rgb(0x7ad04a) : (_e.confuse > 0 ? rgb(0xc07ae0) : COL_LINE)), 0.85);
        draw_set_alpha(_e.hp <= 0 ? 0.35 : 1);
        var _st = (_e.stun > 0 ? $" stun {_e.stun}" : "") + (_e.poison > 0 ? $" psn {_e.poison}" : "") + (_e.confuse > 0 ? $" conf {_e.confuse}" : "");
        draw_txt(_x + 10, 18, _e.name + _st, COL_TEXT, fnt_ui);
        draw_bar(_x + 10, 46, _ew - 20, 8, max(0, _e.hp) / _e.maxHp, rgb(0xd03040));
        draw_set_alpha(1);
    }

    // Party (bottom-left)
    var _all = everyone();
    var _px = 14;
    for (var _i = 0; _i < array_length(_all); _i++) {
        var _m = _all[_i];
        var _h = 56 + (is_struct(_m.buff) ? 18 : 0);
        draw_member_card(_m, _px, GUI_H - 14 - _h, 220, _m == _c.active, false);
        _px += 228;
    }

    // Log
    if (_c.log != "" && !(is_struct(_c.menu) && _c.menu.kind == "result")) {
        draw_set_font(fnt_ui);
        var _lw = min(820, twidth(_c.log) + 40);
        var _lx = 480 - _lw / 2 + 0;
        draw_panel(_lx, GUI_H - 140, _lx + _lw, GUI_H - 104, COL_PANEL, COL_LINE, 0.85);
        draw_txt(_lx + _lw / 2, GUI_H - 135, _c.log, COL_TEXT, fnt_ui, fa_center);
    }

    // Menu (right)
    if (is_struct(_c.menu) && !is_struct(_G.mini)) {
        var _menu = _c.menu;
        var _mw = 330, _mx = GUI_W - 14 - _mw;
        var _rowh = 50, _gap = 6;
        if (_menu.kind == "result") {
            var _tw = 620, _th = txt_h(_menu.title, fnt_ui, _tw - 48) + 110;
            var _tx = GUI_W / 2 - _tw / 2, _ty = GUI_H / 2 - _th / 2 - 40;
            draw_panel(_tx, _ty, _tx + _tw, _ty + _th);
            draw_txt(_tx + 24, _ty + 22, _menu.title, COL_TEXT, fnt_ui, fa_left, _tw - 48);
            ui_draw_button(_tx + _tw - 24 - 160, _ty + _th - 62, 160, 42, "1. Continue", "cpick", 0, true, true);
        } else {
            var _cnt = array_length(_menu.opts);
            var _mh = 44 + _cnt * (_rowh + _gap);
            var _my = GUI_H - 14 - _mh;
            draw_panel(_mx, _my, _mx + _mw, _my + _mh, COL_PANEL, COL_LINE, 0.92);
            draw_txt(_mx + 14, _my + 10, _menu.title, COL_ACCENT, fnt_ui, fa_left, _mw - 28);
            var _num = 0;
            for (var _i = 0; _i < _cnt; _i++) {
                var _o = _menu.opts[_i];
                var _label = _o.label;
                if (!_o.disabled) { _num++; _label = $"{_num}. {_label}"; }
                var _by = _my + 40 + _i * (_rowh + _gap);
                ui_draw_button(_mx + 10, _by, _mw - 20, _rowh, _label, _o.back ? "cback" : "cpick", _i, !_o.disabled, false, _o.sub == "" ? " " : _o.sub);
            }
        }
    }

    if (is_struct(_G.mini)) draw_mini();
}

function draw_mini() {
    var _m = global.G.mini;
    var _cx = (MINI_X1 + MINI_X2) / 2;
    draw_panel(MINI_X1, MINI_Y1, MINI_X2, MINI_Y2, COL_PANEL, _m.flash > 0 ? COL_WARN : COL_ACCENT, 0.95);
    draw_txt(_cx, MINI_Y1 + 14, _m.label, COL_ACCENT, fnt_title, fa_center);
    if (_m.done) {
        draw_txt(_cx, (MINI_Y1 + MINI_Y2) / 2 - 20, _m.text, COL_TEXT, fnt_title, fa_center);
        return;
    }
    var _timer = variable_struct_exists(_m, "left") && _m.type != "timing" && _m.type != "memory" && _m.type != "chords";
    if (_timer) draw_txt(MINI_X2 - 24, MINI_Y1 + 22, string_format(max(0, _m.left), 1, 1) + "s", COL_MUTED, fnt_ui, fa_right);
    switch (_m.type) {
        case "timing":
            draw_txt(_cx, MINI_Y1 + 58, "Press Space / click / A when the marker is in the green", COL_MUTED, fnt_ui, fa_center);
            var _bx1 = MINI_X1 + 60, _bx2 = MINI_X2 - 60, _by = (MINI_Y1 + MINI_Y2) / 2;
            draw_bar(_bx1, _by, _bx2 - _bx1, 30, 0, c_white, rgb(0x2a1418));
            var _bw = _bx2 - _bx1;
            // "Good" (q >= 0.5) when |pos-0.5| < 0.287; "Perfect" in the green when < 0.06
            draw_set_colour(rgb(0x3a3a1a)); draw_rectangle(_bx1 + _bw * 0.213, _by, _bx1 + _bw * 0.787, _by + 30, false);
            draw_set_colour(COL_GOOD); draw_rectangle(_bx1 + _bw * 0.44, _by, _bx1 + _bw * 0.56, _by + 30, false);
            var _mk = _bx1 + _bw * _m.pos;
            draw_set_colour(c_white); draw_rectangle(_mk - 3, _by - 8, _mk + 3, _by + 38, false);
            break;

        case "mash":
            draw_txt(_cx, MINI_Y1 + 58, "Mash Space / click / A to heat the flame!", COL_MUTED, fnt_ui, fa_center);
            draw_txt(_cx, MINI_Y1 + 130, string(_m.count), COL_TEXT, fnt_title, fa_center);
            draw_bar(MINI_X1 + 100, MINI_Y1 + 200, MINI_X2 - MINI_X1 - 200, 14, _m.count / 14, COL_ACCENT);
            break;

        case "memory":
            var _show = _m.phase == "show";
            draw_txt(_cx, MINI_Y1 + 58, _show ? "Memorize the sequence…" : "Enter it with arrows / WASD / d-pad", COL_MUTED, fnt_ui, fa_center);
            var _s = "";
            for (var _i = 0; _i < 3; _i++) {
                if (_show) _s += dir_glyph(_m.seq[_i]) + "  ";
                else _s += (_i < array_length(_m.input) ? dir_glyph(_m.input[_i]) : "?") + "  ";
            }
            draw_txt(_cx, MINI_Y1 + 130, _s, COL_TEXT, fnt_title, fa_center);
            if (!_show) {
                var _order = ["L", "U", "D", "R"];
                for (var _i = 0; _i < 4; _i++) {
                    var _r = mini_dir_rect(_i);
                    draw_set_colour(COL_PANEL2); draw_roundrect_ext(_r[0], _r[1], _r[2], _r[3], 8, 8, false);
                    draw_set_colour(COL_LINE); draw_roundrect_ext(_r[0], _r[1], _r[2], _r[3], 8, 8, true);
                    draw_txt((_r[0] + _r[2]) / 2, _r[1] + 8, dir_glyph(_order[_i]), COL_TEXT, fnt_title, fa_center);
                }
            }
            break;

        case "focus": draw_mini_focus(_m, _cx); break;
        case "stir": draw_mini_stir(_m, _cx); break;
        case "chords": draw_mini_chords(_m, _cx); break;
        case "trace": case "operation": draw_mini_path(_m, _cx); break;
    }
}

/// Freeze Frame: a viewfinder showing the target, pixelated by how far off the focus is.
function draw_mini_focus(_m, _cx) {
    draw_txt(_cx, MINI_Y1 + 58, "Turn the lens with ↑/↓ (W/S, stick, wheel). Space / A to snap!", COL_MUTED, fnt_ui, fa_center);
    var _tgt = global.G.c.pending_target;
    var _art = is_struct(_tgt) && _tgt.name == "Hollow" ? "bt_hollow" : "bt_shade";
    var _tint = _art == "bt_hollow" ? rgb(0x9ec4bc) : rgb(0xa890d0);
    var _r = global.ATLAS[$ _art];
    var _box = 230, _bx = _cx - _box / 2, _by = MINI_AY1;
    var _err = abs(_m.focus - _m.target);
    var _block = 1 + floor(min(_err, 0.6) * 55);      // GUI px per "pixel" of blur
    var _sw = ceil(_box / _block);
    var _surf = surface_create(max(1, _sw), max(1, _sw));
    surface_set_target(_surf);
    draw_clear_alpha(rgb(0x14161c), 1);
    var _s = (_box * 0.85 / _block) / _r[3];
    gpu_set_tex_filter(false);
    draw_sprite_part_ext(spr_atlas, 0, _r[0], _r[1], _r[2], _r[3], _sw / 2 - _r[2] * _s / 2, _sw - _r[3] * _s - 2 / _block, _s, _s, _tint, 1);
    surface_reset_target();
    draw_surface_part_ext(_surf, 0, 0, _box / _block, _box / _block, _bx, _by, _block, _block, c_white, 1);
    gpu_set_tex_filter(true);
    surface_free(_surf);
    // viewfinder frame
    draw_set_colour(c_white);
    var _c = 22;
    draw_line_width(_bx, _by, _bx + _c, _by, 3); draw_line_width(_bx, _by, _bx, _by + _c, 3);
    draw_line_width(_bx + _box, _by, _bx + _box - _c, _by, 3); draw_line_width(_bx + _box, _by, _bx + _box, _by + _c, 3);
    draw_line_width(_bx, _by + _box, _bx + _c, _by + _box, 3); draw_line_width(_bx, _by + _box, _bx, _by + _box - _c, 3);
    draw_line_width(_bx + _box, _by + _box, _bx + _box - _c, _by + _box, 3); draw_line_width(_bx + _box, _by + _box, _bx + _box, _by + _box - _c, 3);
    // lens ring
    var _rx = _bx + _box + 60, _ry1 = _by, _ry2 = _by + _box;
    draw_bar(_rx - 6, _ry1, 12, _ry2 - _ry1, 0, c_white, COL_PANEL2);
    var _ky = lerp(_ry2, _ry1, _m.focus);
    draw_set_colour(COL_ACCENT); draw_rectangle(_rx - 16, _ky - 4, _rx + 16, _ky + 4, false);
    draw_txt(_rx, _ry2 + 8, "focus", COL_MUTED, fnt_small, fa_center);
}

/// Soup's On: a pot to stir round with W A S D.
function draw_mini_stir(_m, _cx) {
    draw_txt(_cx, MINI_Y1 + 58, "Stir round the pot: W → D → S → A (arrows / d-pad work too)", COL_MUTED, fnt_ui, fa_center);
    var _py = (MINI_AY1 + MINI_AY2) / 2 + 4, _pr = 70;
    draw_set_colour(rgb(0x3a3d4a)); draw_circle(_cx, _py, _pr + 12, false);       // pot rim
    draw_set_colour(rgb(0xc8782c)); draw_circle(_cx, _py, _pr, false);            // soup
    draw_set_colour(rgb(0xe8a040));
    for (var _i = 0; _i < 6; _i++) {                                              // swirl
        var _ang = _m.count * 30 + _i * 60;
        draw_circle(_cx + lengthdir_x(_pr * 0.55, _ang), _py + lengthdir_y(_pr * 0.55, _ang), 9, false);
    }
    var _sx = _cx + lengthdir_x(_pr * 0.6, _m.angle), _sy = _py + lengthdir_y(_pr * 0.6, _m.angle);
    draw_set_colour(rgb(0x8a5a2a)); draw_line_width(_sx, _sy, _sx + 34, _sy - 84, 8);   // spoon
    draw_set_colour(rgb(0xb07838)); draw_circle(_sx, _sy, 12, false);
    var _keys = ["W", "D", "S", "A"];
    for (var _i = 0; _i < 4; _i++) {
        var _kx = _cx + lengthdir_x(_pr + 40, 90 - _i * 90), _ky = _py + lengthdir_y(_pr + 40, 90 - _i * 90);
        draw_txt(_kx, _ky - 12, _keys[_i], _m.last == _i ? COL_ACCENT : COL_MUTED, fnt_ui, fa_center);
    }
    draw_bar(MINI_X1 + 100, MINI_Y2 - 36, MINI_X2 - MINI_X1 - 200, 12, _m.count / _m.goal, COL_GOOD);
}

/// Encore: four chords slide toward the strike line.
function draw_mini_chords(_m, _cx) {
    draw_txt(_cx, MINI_Y1 + 58, "Space / click / A as each chord crosses the line", COL_MUTED, fnt_ui, fa_center);
    var _x1 = MINI_AX1 + 20, _x2 = MINI_AX2 - 20, _ly = (MINI_AY1 + MINI_AY2) / 2;
    var _hitx = _x1 + 110, _speed = 260;   // px per second
    draw_set_colour(COL_LINE);
    for (var _s = -2; _s <= 2; _s++) draw_line_width(_x1, _ly + _s * 18, _x2, _ly + _s * 18, 2);   // strings
    draw_set_colour(COL_GOOD); draw_line_width(_hitx, _ly - 60, _hitx, _ly + 60, 4);
    for (var _i = 0; _i < 4; _i++) {
        var _nx = _hitx + (_m.times[_i] - _m.t) * _speed;
        var _h = _m.hits[_i];
        if (_h < 0) {
            if (_nx < _x2 + 20 && _nx > _x1 - 20) {
                draw_set_colour(rgb(0xffd060)); draw_circle(_nx, _ly, 20, false);
                draw_set_colour(rgb(0x5a3a10)); draw_circle(_nx, _ly, 20, true);
                draw_line_width(_nx + 6, _ly - 4, _nx + 6, _ly - 34, 4); draw_circle(_nx, _ly - 2, 7, false);
            }
        }
        var _jc = _m.judge[_i] == "Perfect" ? COL_GOOD : (_m.judge[_i] == "Good" ? COL_ACCENT : COL_WARN);
        draw_set_colour(_h < 0 ? COL_PANEL2 : _jc);
        draw_circle(_cx - 90 + _i * 60, MINI_Y2 - 34, 12, false);
        if (_m.judge[_i] != "") draw_txt(_cx - 90 + _i * 60, MINI_Y2 - 70, _m.judge[_i], _jc, fnt_small, fa_center);
    }
}

/// Creative License (trace) and Invasive Surgery (operation): a path to follow with a cursor.
function draw_mini_path(_m, _cx) {
    var _op = _m.type == "operation";
    draw_txt(_cx, MINI_Y1 + 58, _op ? "Guide the tweezers to the heart: arrows / WASD / stick, or drag. Don't touch the edges!"
                                    : "Trace the stroke dot to dot: arrows / WASD / stick, or drag with the mouse",
             COL_MUTED, fnt_ui, fa_center, MINI_X2 - MINI_X1 - 60);
    var _p = _m.path, _n = array_length(_p);
    // canvas / patient
    draw_set_colour(_op ? rgb(0xe8b898) : rgb(0xf4eedc));
    draw_roundrect_ext(MINI_AX1, MINI_AY1, MINI_AX2, MINI_AY2, 16, 16, false);
    if (_op) {
        // the channel: dark edges, cavity inside
        draw_set_colour(rgb(0x5a1a1a));
        for (var _i = 0; _i < _n - 1; _i++) draw_line_width(_p[_i][0], _p[_i][1], _p[_i + 1][0], _p[_i + 1][1], _m.halfw * 2 + 8);
        for (var _i = 0; _i < _n; _i++) draw_circle(_p[_i][0], _p[_i][1], _m.halfw + 4, false);
        draw_set_colour(rgb(0xb04848));
        for (var _i = 0; _i < _n - 1; _i++) draw_line_width(_p[_i][0], _p[_i][1], _p[_i + 1][0], _p[_i + 1][1], _m.halfw * 2);
        for (var _i = 0; _i < _n; _i++) draw_circle(_p[_i][0], _p[_i][1], _m.halfw, false);
        var _e = _p[_n - 1];
        draw_set_colour(rgb(0xff3050)); draw_circle(_e[0] - 6, _e[1] - 4, 9, false); draw_circle(_e[0] + 6, _e[1] - 4, 9, false);
        draw_triangle(_e[0] - 15, _e[1], _e[0] + 15, _e[1], _e[0], _e[1] + 16, false);
        if (_m.flash > 0) { draw_set_alpha(_m.flash); draw_set_colour(c_red); draw_roundrect_ext(MINI_AX1, MINI_AY1, MINI_AX2, MINI_AY2, 16, 16, false); draw_set_alpha(1); }
        // tweezers
        draw_set_colour(rgb(0xc8ccd8)); draw_line_width(_m.cx, _m.cy, _m.cx + 26, _m.cy - 46, 5); draw_line_width(_m.cx + 4, _m.cy, _m.cx + 34, _m.cy - 42, 5);
        draw_set_colour(c_white); draw_circle(_m.cx, _m.cy, 5, false);
        var _st = $"Slips: {_m.touches}";
        draw_txt(MINI_X1 + 24, MINI_Y1 + 22, _st, _m.touches > 0 ? COL_WARN : COL_MUTED, fnt_ui);
    } else {
        // faint guide stroke, then the painted part
        draw_set_alpha(0.35); draw_set_colour(rgb(0xd04870));
        for (var _i = 0; _i < _n - 1; _i++) draw_line_width(_p[_i][0], _p[_i][1], _p[_i + 1][0], _p[_i + 1][1], 22);
        for (var _i = 1; _i < _n - 1; _i++) draw_circle(_p[_i][0], _p[_i][1], 10, false);
        draw_set_alpha(1);
        draw_set_colour(rgb(0xd04870));
        for (var _i = 0; _i < _m.next - 1; _i++) draw_line_width(_p[_i][0], _p[_i][1], _p[_i + 1][0], _p[_i + 1][1], 22);
        for (var _i = 0; _i < _m.next; _i++) draw_circle(_p[_i][0], _p[_i][1], 10, false);
        for (var _i = 0; _i < _n; _i++) {
            draw_set_colour(_i < _m.next ? rgb(0xd04870) : rgb(0x6a2a40));
            draw_circle(_p[_i][0], _p[_i][1], _i == _m.next ? 10 : 7, _i >= _m.next);
        }
        if (_m.flash > 0) { draw_set_alpha(_m.flash * 2); draw_set_colour(COL_WARN); draw_roundrect_ext(MINI_AX1, MINI_AY1, MINI_AX2, MINI_AY2, 16, 16, true); draw_set_alpha(1); }
        // brush
        draw_set_colour(rgb(0x8a5a2a)); draw_line_width(_m.cx, _m.cy, _m.cx + 22, _m.cy - 40, 6);
        draw_set_colour(rgb(0xd04870)); draw_circle(_m.cx, _m.cy, 9, false);
        draw_txt(MINI_X1 + 24, MINI_Y1 + 22, $"Smudges: {_m.smudges}", _m.smudges > 0 ? COL_WARN : COL_MUTED, fnt_ui);
    }
}
