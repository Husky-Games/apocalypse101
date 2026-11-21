// Playtest feedback: press N at any moment to freeze the game, grab a screenshot and type a note.
// Notes go to feedback/ next to the exe (the file sandbox is disabled for this), one markdown
// file per play session, with the time, where the player was, and the screenshot.

#macro FB_KEY ord("N")
#macro FB_MAX 600

function feedback_init() {
    var _t = date_current_datetime();
    global.FB = {
        open: false, text: "", shot: "", pending: false, clear_next: false,
        count: 0, blink: 0,
        stamp: feedback_stamp(_t, "-", "_"),
        started: feedback_stamp(_t, ":", " "),
        dir: program_directory + "feedback\\",
    };
}

/// "2026-11-21_14-05-09" (file names) or "2026-11-21 14:05:09" (text).
function feedback_stamp(_t, _tsep, _mid) {
    return string(date_get_year(_t)) + "-" + feedback_pad(date_get_month(_t)) + "-" + feedback_pad(date_get_day(_t)) + _mid
         + feedback_pad(date_get_hour(_t)) + _tsep + feedback_pad(date_get_minute(_t)) + _tsep + feedback_pad(date_get_second(_t));
}
function feedback_pad(_n) { return (_n < 10 ? "0" : "") + string(_n); }

function feedback_file() { return global.FB.dir + "session_" + global.FB.stamp + ".md"; }

/// Call first thing in the step. Returns true while the dialog is open (the game is paused).
function feedback_step() {
    var _F = global.FB;
    if (!_F.open) {
        if (keyboard_check_pressed(FB_KEY)) {
            _F.open = true; _F.pending = true; _F.clear_next = true;
            _F.text = ""; keyboard_string = "";
            _F.shot = "session_" + _F.stamp + "_note" + feedback_pad(_F.count + 1) + ".png";
            return true;
        }
        return false;
    }
    _F.blink += global.G.dt;
    if (_F.clear_next) { keyboard_string = ""; _F.clear_next = false; }   // drop the "n" that opened it
    if (keyboard_check_pressed(vk_escape)) { feedback_close(false); return true; }
    if (keyboard_check_pressed(vk_enter)) {
        if (keyboard_check(vk_shift)) keyboard_string += "\n";
        else { feedback_close(true); return true; }
    }
    if (string_length(keyboard_string) > FB_MAX) keyboard_string = string_copy(keyboard_string, 1, FB_MAX);
    _F.text = keyboard_string;
    return true;
}

function feedback_close(_save) {
    var _F = global.FB;
    _F.open = false;
    keyboard_string = "";
    if (_save && string_trim(_F.text) != "") {
        feedback_write();
        toast($"Feedback note {_F.count} saved.", 2);
    } else if (file_exists(_F.dir + _F.shot)) file_delete(_F.dir + _F.shot);
    io_clear();
}

/// Append the note to this session's markdown file.
function feedback_write() {
    var _F = global.FB, _G = global.G;
    _F.count++;
    var _path = feedback_file();
    var _new = !file_exists(_path);
    var _f = file_text_open_append(_path);
    if (_new) {
        file_text_write_string(_f, "# Apocalypse 101 playtest feedback\n\nSession started " + _F.started + ". Press N in game to add a note.\n\n");
    }
    var _now = date_current_datetime();
    var _secs = floor(_G.time);
    var _play = string(_secs div 60) + ":" + feedback_pad(_secs mod 60);
    var _t = _G.teacher;
    var _where = is_struct(_G.area) ? _G.area.name : "?";
    var _doing = "exploring";
    if (_G.mode == "combat" && is_struct(_G.c)) {
        var _names = [];
        for (var _i = 0; _i < array_length(_G.c.enemies); _i++) if (_G.c.enemies[_i].hp > 0) array_push(_names, _G.c.enemies[_i].name);
        _doing = "in combat (" + str_join(_names, ", ") + ")" + (is_struct(_G.mini) ? ", playing " + _G.mini.label : "");
    } else if (_G.mode == "ui") _doing = "in the " + _G.overlay + " menu";
    var _party = [];
    var _all = everyone();
    for (var _i = 0; _i < array_length(_all); _i++) array_push(_party, $"{_all[_i].name} {max(0, _all[_i].hp)}/{_all[_i].maxHp} HP, {_all[_i].ap} AP");
    var _next = route_next();
    var _lines = [
        $"## Note {_F.count} - {feedback_stamp(_now, ":", " ")} (play time {_play})",
        "",
        $"- **Where:** {_where} (x {string_format(_t.px, 1, 1)}, z {string_format(_t.pz, 1, 1)}), {_doing}",
        "- **Party:** " + str_join(_party, "; "),
        $"- **Progress:** clues {array_length(_G.clues)}/{array_length(global.CLUES)}" + (is_undefined(_next) ? ", route complete" : ", next: " + _next[1])
            + (_G.fence_cleared ? ", fence cleared" : "") + (_G.tunnels_found ? ", tunnels found" : ""),
        "",
    ];
    var _body = string_split(_F.text, "\n");
    for (var _i = 0; _i < array_length(_body); _i++) array_push(_lines, "> " + _body[_i]);
    array_push(_lines, "", $"![Note {_F.count}]({_F.shot})", "", "");
    file_text_write_string(_f, str_join(_lines, "\n"));
    file_text_close(_f);
}

/// Call at the end of the GUI draw: takes the screenshot (before the dialog appears), then draws it.
function feedback_draw() {
    var _F = global.FB;
    if (!_F.open) return;
    if (_F.pending) {
        _F.pending = false;
        if (!directory_exists(_F.dir)) directory_create(_F.dir);
        screen_save(_F.dir + _F.shot);
    }
    draw_set_alpha(0.55); draw_set_colour(c_black); draw_rectangle(0, 0, GUI_W, GUI_H, false); draw_set_alpha(1);
    var _x1 = GUI_W / 2 - 340, _x2 = GUI_W / 2 + 340, _y1 = GUI_H / 2 - 150, _y2 = GUI_H / 2 + 150;
    draw_panel(_x1, _y1, _x2, _y2, COL_PANEL, COL_ACCENT, 0.98);
    draw_txt(_x1 + 24, _y1 + 16, "Feedback note", COL_ACCENT, fnt_title);
    draw_txt(_x1 + 24, _y1 + 64, "What's happening right now? The screenshot and your place in the game are saved with it.",
             COL_MUTED, fnt_small, fa_left, _x2 - _x1 - 48);
    draw_panel(_x1 + 24, _y1 + 96, _x2 - 24, _y2 - 52, COL_PANEL2, COL_LINE, 1);
    var _cursor = (frac(_F.blink) < 0.5) ? "|" : "";
    draw_txt(_x1 + 36, _y1 + 106, _F.text + _cursor, COL_TEXT, fnt_ui, fa_left, _x2 - _x1 - 72);
    draw_txt(_x1 + 24, _y2 - 36, "Enter  save  ·  Shift+Enter  new line  ·  Esc  cancel", COL_MUTED, fnt_small);
    draw_txt(_x2 - 24, _y2 - 36, $"{string_length(_F.text)}/{FB_MAX}", COL_MUTED, fnt_small, fa_right);
}
