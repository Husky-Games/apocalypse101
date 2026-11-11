// Rendering. Exploration is top-down with faux height (Undertale / Dragon Quest style);
// combat is a drawn first-person school hallway. No sprite assets: everything is primitives.

#macro HS 14   // pixels per unit of height (faux 3D lift)

/* ================================================================ world */

function draw_world() {
    var _G = global.G;
    if (_G.mode == "combat") return;

    // Ground
    draw_set_colour(rgb(0x2b3a2e));
    draw_rectangle(0, 0, room_width, room_height, false);
    // Grass tufts (deterministic)
    random_set_seed(7);
    draw_set_colour(rgb(0x24322a));
    repeat (500) { var _gx = irandom(room_width), _gy = irandom(room_height); draw_rectangle(_gx, _gy, _gx + 3, _gy + 1, false); }
    randomize();

    // Path
    draw_set_colour(rgb(0x4a4a50));
    draw_rectangle(wx(-22), wy(-2.5), wx(18), wy(2.5), false);
    draw_set_colour(rgb(0x5a5a60));
    for (var _x = -21; _x < 18; _x += 2) draw_rectangle(wx(_x), wy(-0.06), wx(_x + 1), wy(0.06), false);

    // Classroom floor (planks)
    draw_set_colour(rgb(0x8a7a5a));
    draw_rectangle(wx(-28), wy(-8), wx(-16), wy(8), false);
    draw_set_colour(rgb(0x7c6d50));
    for (var _z = -8; _z < 8; _z += 0.8) draw_line(wx(-28), wy(_z), wx(-16), wy(_z));

    // East quad
    draw_set_colour(rgb(0x33403a));
    draw_rectangle(wx(16.5), wy(-20), wx(29.5), wy(20), false);

    // Depth-sorted scene
    var _list = [];
    for (var _i = 0; _i < array_length(_G.boxes); _i++) array_push(_list, { k: _G.boxes[_i].z2, t: 0, r: _G.boxes[_i] });
    for (var _i = 0; _i < array_length(_G.trees); _i++) array_push(_list, { k: _G.trees[_i].z + 0.4, t: 1, r: _G.trees[_i] });
    for (var _i = 0; _i < array_length(_G.items); _i++) array_push(_list, { k: _G.items[_i].z, t: 2, r: _G.items[_i] });
    for (var _i = 0; _i < array_length(_G.enemies); _i++) array_push(_list, { k: _G.enemies[_i].z, t: 3, r: _G.enemies[_i] });
    array_push(_list, { k: _G.teacher.pz, t: 4, r: _G.teacher });
    for (var _i = 0; _i < array_length(_G.roster); _i++) array_push(_list, { k: _G.roster[_i].pz, t: 4, r: _G.roster[_i] });
    array_sort(_list, function(_a, _b) { return _a.k - _b.k; });

    for (var _i = 0; _i < array_length(_list); _i++) {
        var _e = _list[_i];
        switch (_e.t) {
            case 0: draw_box(_e.r); break;
            case 1: draw_tree(_e.r); break;
            case 2: draw_item(_e.r); break;
            case 3: draw_explore_enemy(_e.r); break;
            case 4: draw_char(_e.r); break;
        }
    }

    // Light glows (additive)
    gpu_set_blendmode(bm_add);
    var _pulse = 0.6 + sin(_G.time * 3) * 0.25;
    for (var _i = 0; _i < array_length(_G.tables); _i++) {
        var _tb = _G.tables[_i];
        draw_circle_colour(wx(_tb.x), wy(_tb.z) - 20, 3.4 * U, merge_colour(c_black, rgb(0x6a3a10), _pulse), c_black, false);
    }
    for (var _i = 0; _i < array_length(_G.items); _i++) {
        var _n = _G.items[_i];
        var _c = _n.type == "clue" ? rgb(0xfff27a) : global.ITEMS[$ _n.type].colour;
        draw_circle_colour(wx(_n.x), wy(_n.z) - 14, 0.9 * U, merge_colour(c_black, _c, 0.28), c_black, false);
    }
    gpu_set_blendmode(bm_normal);
}

function box_rect(_b) {
    var _lift = _b.h * _b.squash * HS, _base = _b.y * HS;
    return { x1: wx(_b.x1), x2: wx(_b.x2), y1: wy(_b.z1), y2: wy(_b.z2), lift: _lift, base: _base };
}

function draw_box(_b) {
    var _r = box_rect(_b);
    var _top = _r.y1 - _r.lift - _r.base, _bot = _r.y2 - _r.lift - _r.base;
    var _front = merge_colour(_b.colour, c_black, 0.38);

    if (_b.kind != "board") {
        draw_set_alpha(0.28); draw_set_colour(c_black);
        draw_rectangle(_r.x1 + 4, _r.y1 + 4, _r.x2 + 4 + _r.lift * 0.4, _r.y2 + 6, false);
        draw_set_alpha(1);
    }
    // front face
    draw_set_colour(_front);
    draw_rectangle(_r.x1, _bot, _r.x2, _r.y2 - _r.base, false);

    switch (_b.kind) {
        case "fence":
            for (var _y = _top; _y < _bot; _y += 24) {
                draw_set_colour(((_y - _top) div 24) mod 2 ? rgb(0x2a2018) : _b.colour);
                draw_rectangle(_r.x1, _y, _r.x2, min(_bot, _y + 24), false);
            }
            break;
        case "board":
            draw_set_colour(rgb(0xf4f4f4));
            draw_rectangle(_r.x1, _top, _r.x2, _bot + 10, false);
            draw_set_colour(rgb(0x3a4a6a));
            draw_rectangle(_r.x1, _top, _r.x2, _bot + 10, true);
            draw_set_font(fnt_small); draw_set_colour(rgb(0x2a3a8a)); draw_set_halign(fa_center);
            draw_text((_r.x1 + _r.x2) / 2, _top - 2, "PARTY ROSTER");
            draw_set_halign(fa_left);
            break;
        case "table":
            draw_set_colour(_b.colour);
            draw_rectangle(_r.x1, _top, _r.x2, _bot, false);
            var _p = 0.6 + sin(global.G.time * 3) * 0.25;
            draw_set_colour(merge_colour(rgb(0xffb347), rgb(0xff8a1a), 1 - _p));
            draw_rectangle(_r.x1 + 4, _top + 4, _r.x2 - 4, _bot - 4, false);
            break;
        case "building":
            draw_set_colour(_b.colour);
            draw_rectangle(_r.x1, _top, _r.x2, _bot, false);
            draw_set_colour(merge_colour(_b.colour, c_white, 0.12));
            draw_rectangle(_r.x1 + 6, _top + 6, _r.x2 - 6, _bot - 6, true);
            // dark windows on the front face
            draw_set_colour(rgb(0x1a1d26));
            for (var _wx = _r.x1 + 14; _wx < _r.x2 - 20; _wx += 34) draw_rectangle(_wx, _bot + 12, _wx + 18, _r.y2 - _r.base - 14, false);
            break;
        case "car":
            draw_set_colour(_b.colour);
            draw_rectangle(_r.x1, _top, _r.x2, _bot, false);
            draw_set_colour(rgb(0x22262e));
            draw_rectangle(_r.x1 + 10, _top + 8, _r.x2 - 10, _bot - 8, false);
            break;
        default:
            draw_set_colour(_b.colour);
            draw_rectangle(_r.x1, _top, _r.x2, _bot, false);
            break;
    }
    if (_b.kind != "board") {
        draw_set_colour(merge_colour(_b.colour, c_black, 0.55));
        draw_rectangle(_r.x1, _top, _r.x2, _r.y2 - _r.base, true);
    }
}

function draw_tree(_t) {
    var _x = wx(_t.x), _y = wy(_t.z);
    draw_set_alpha(0.3); draw_set_colour(c_black);
    draw_ellipse(_x - 30, _y - 8, _x + 42, _y + 12, false);
    draw_set_alpha(1);
    draw_set_colour(rgb(0x4a3524));
    draw_rectangle(_x - 6, _y - 22, _x + 6, _y + 2, false);
    draw_set_colour(rgb(0x173a29)); draw_circle(_x, _y - 46, 1.4 * U, false);
    draw_set_colour(rgb(0x1f4a34)); draw_circle(_x - 6, _y - 52, 1.1 * U, false);
    draw_set_colour(rgb(0x2a5c42)); draw_circle(_x - 14, _y - 60, 0.55 * U, false);
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

function draw_char(_m) {
    var _s = _m.scale;
    var _x = wx(_m.px), _y = wy(_m.pz), _lift = _m.py * HS * 1.4;
    draw_set_alpha(0.35); draw_set_colour(c_black);
    draw_ellipse(_x - 15 * _s, _y - 5 * _s, _x + 15 * _s, _y + 5 * _s, false);
    draw_set_alpha(1);
    var _bw = 13 * _s, _bh = 26 * _s;
    var _by2 = _y - _lift, _by1 = _by2 - _bh;
    draw_set_colour(merge_colour(_m.colour, c_black, 0.25));
    draw_roundrect_ext(_x - _bw, _by1, _x + _bw, _by2, 10 * _s, 10 * _s, false);
    draw_set_colour(_m.colour);
    draw_roundrect_ext(_x - _bw + 2, _by1, _x + _bw - 2, _by2 - 4 * _s, 10 * _s, 10 * _s, false);
    var _hy = _by1 - 7 * _s, _hr = 11 * _s;
    draw_set_colour(rgb(0xf0d2b0));
    draw_circle(_x, _hy, _hr, false);
    // face direction: eyes slide toward the facing side; hidden when facing away (up)
    var _fx = lengthdir_x(5 * _s, _m.face), _fy = lengthdir_y(3 * _s, _m.face);
    if (_fy > -2 * _s) {
        draw_set_colour(rgb(0x2a2a30));
        draw_circle(_x + _fx - 4 * _s, _hy + _fy, 1.6 * _s, false);
        draw_circle(_x + _fx + 4 * _s, _hy + _fy, 1.6 * _s, false);
    }
    draw_set_colour(merge_colour(_m.colour, c_black, 0.5));
    draw_circle(_x, _hy, _hr, true);
}

function draw_explore_enemy(_e) {
    var _G = global.G;
    var _s = _e.scale;
    var _x = wx(_e.x), _y = wy(_e.z) - sin(_G.time * 3 + _e.hx) * 0.1 * HS * 2;
    var _def = global.ENEMY_TYPES[$ _e.type];
    draw_set_alpha(0.35); draw_set_colour(c_black);
    draw_ellipse(wx(_e.x) - 18 * _s, wy(_e.z) - 6 * _s, wx(_e.x) + 18 * _s, wy(_e.z) + 6 * _s, false);
    draw_set_alpha(1);
    gpu_set_blendmode(bm_add);
    draw_circle_colour(_x, _y - 30 * _s, 34 * _s, merge_colour(c_black, _def.eye, 0.18), c_black, false);
    gpu_set_blendmode(bm_normal);
    draw_set_colour(_def.colour);
    draw_roundrect_ext(_x - 15 * _s, _y - 48 * _s, _x + 15 * _s, _y, 14 * _s, 14 * _s, false);
    draw_circle(_x, _y - 52 * _s, 13 * _s, false);
    draw_set_colour(merge_colour(_def.colour, _def.eye, 0.25));
    draw_circle(_x, _y - 52 * _s, 13 * _s, true);
    var _fx = lengthdir_x(3 * _s, _e.face);
    draw_set_colour(_def.eye);
    draw_circle(_x + _fx - 5 * _s, _y - 53 * _s, 2.4 * _s, false);
    draw_circle(_x + _fx + 5 * _s, _y - 53 * _s, 2.4 * _s, false);
    if (_e.count > 1) {
        draw_set_font(fnt_small); draw_set_halign(fa_center); draw_set_colour(_def.eye);
        draw_text(_x, _y - 82 * _s, $"×{_e.count}");
        draw_set_halign(fa_left);
    }
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
    draw_set_colour(_m.colour); draw_circle(_x + 14, _y + 16, 5, false);
    draw_txt(_x + 26, _y + 6, _m.name, _ko ? COL_MUTED : COL_TEXT, fnt_ui);
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
        var _pw = string_width(_G.prompt) + 36;
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
        "WASD / Arrows / Left stick  move  ·  E / Space / A  interact  ·  H / X  heal  ·  C / Y  craft anywhere  ·  J / Start  journal",
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
    array_sort(_es, function(_a, _b) { return _a.hz - _b.hz; });
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
    var _bot = cproj(_x, _y, _z), _top = cproj(_x, _y + 1.9 * _sc, _z), _head = cproj(_x, _y + 1.95 * _sc, _z);
    var _k = _bot[2];
    var _bw = 0.45 * _sc * _k, _hr = 0.4 * _sc * _k;
    var _col = cfog(_e.colour, _bot[3] - 4);

    gpu_set_blendmode(bm_add);
    draw_circle_colour(_head[0], (_head[1] + _bot[1]) / 2, 1.4 * _sc * _k, merge_colour(c_black, _e.eye, 0.12), c_black, false);
    gpu_set_blendmode(bm_normal);

    draw_set_colour(_col);
    draw_roundrect_ext(_bot[0] - _bw, _top[1] + _bw * 0.4, _bot[0] + _bw, _bot[1], _bw, _bw, false);
    draw_circle(_head[0], _head[1], _hr, false);
    draw_set_colour(merge_colour(_col, _e.eye, 0.22));
    draw_circle(_head[0], _head[1], _hr, true);
    draw_roundrect_ext(_bot[0] - _bw, _top[1] + _bw * 0.4, _bot[0] + _bw, _bot[1], _bw, _bw, true);

    if (_e.hitT > 0) {
        draw_set_alpha(_e.hitT / 0.4 * 0.6); draw_set_colour(c_white);
        draw_circle(_head[0], _head[1], _hr, false);
        draw_roundrect_ext(_bot[0] - _bw, _top[1] + _bw * 0.4, _bot[0] + _bw, _bot[1], _bw, _bw, false);
        draw_set_alpha(1);
    }

    // eyes
    for (var _s = -1; _s <= 1; _s += 2) {
        var _ep = cproj(_x + _s * 0.15 * _sc, _y + 2.0 * _sc, _z);
        gpu_set_blendmode(bm_add);
        draw_circle_colour(_ep[0], _ep[1], 0.25 * _sc * _k, merge_colour(c_black, _e.eye, 0.6), c_black, false);
        gpu_set_blendmode(bm_normal);
        draw_set_colour(_e.eye);
        draw_circle(_ep[0], _ep[1], max(2, 0.07 * _sc * _k), false);
    }

    if (_e.stunned) {
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
        draw_panel(_x, 14, _x + _ew, 62, COL_PANEL, _e.stunned ? rgb(0xffe04a) : COL_LINE, 0.85);
        draw_set_alpha(_e.hp <= 0 ? 0.35 : 1);
        draw_txt(_x + 10, 18, _e.name + (_e.stunned ? " (stunned)" : ""), COL_TEXT, fnt_ui);
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
        var _lw = min(820, string_width(_c.log) + 40);
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
    draw_panel(MINI_X1, MINI_Y1, MINI_X2, MINI_Y2, COL_PANEL, COL_ACCENT, 0.95);
    draw_txt(_cx, MINI_Y1 + 14, _m.label, COL_ACCENT, fnt_title, fa_center);
    if (_m.done) {
        draw_txt(_cx, MINI_Y1 + 100, _m.text, COL_TEXT, fnt_title, fa_center);
        return;
    }
    switch (_m.type) {
        case "timing":
            draw_txt(_cx, MINI_Y1 + 58, "Press Space / click / A when the marker is in the green", COL_MUTED, fnt_ui, fa_center);
            var _bx1 = MINI_X1 + 40, _bx2 = MINI_X2 - 40, _by = MINI_Y1 + 120;
            draw_bar(_bx1, _by, _bx2 - _bx1, 30, 0, c_white, rgb(0x2a1418));
            var _bw = _bx2 - _bx1;
            // "Good" (q >= 0.5) when |pos-0.5| < 0.287; "Perfect" in the green when < 0.06
            draw_set_colour(rgb(0x3a3a1a)); draw_rectangle(_bx1 + _bw * 0.213, _by, _bx1 + _bw * 0.787, _by + 30, false);
            draw_set_colour(COL_GOOD); draw_rectangle(_bx1 + _bw * 0.44, _by, _bx1 + _bw * 0.56, _by + 30, false);
            var _mk = _bx1 + _bw * _m.pos;
            draw_set_colour(c_white); draw_rectangle(_mk - 3, _by - 8, _mk + 3, _by + 38, false);
            break;
        case "mash":
            draw_txt(_cx, MINI_Y1 + 58, "Mash Space / click / A!", COL_MUTED, fnt_ui, fa_center);
            draw_txt(_cx, MINI_Y1 + 96, string(_m.count), COL_TEXT, fnt_title, fa_center);
            draw_bar(MINI_X1 + 80, MINI_Y1 + 150, MINI_X2 - MINI_X1 - 160, 12, _m.count / 14, COL_ACCENT);
            draw_txt(_cx, MINI_Y1 + 172, string_format(max(0, _m.left), 1, 1) + "s", COL_MUTED, fnt_ui, fa_center);
            break;
        case "memory":
            var _show = _m.phase == "show";
            draw_txt(_cx, MINI_Y1 + 58, _show ? "Memorize the sequence…" : "Enter it with arrows / WASD / d-pad", COL_MUTED, fnt_ui, fa_center);
            var _s = "";
            for (var _i = 0; _i < 3; _i++) {
                if (_show) _s += dir_glyph(_m.seq[_i]) + "  ";
                else _s += (_i < array_length(_m.input) ? dir_glyph(_m.input[_i]) : "?") + "  ";
            }
            draw_txt(_cx, MINI_Y1 + 92, _s, COL_TEXT, fnt_title, fa_center);
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
    }
}
