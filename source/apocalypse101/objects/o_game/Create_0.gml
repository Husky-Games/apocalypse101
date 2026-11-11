/// @description Boot: display, camera, game state
window_set_caption("Apocalypse 101");
display_init(); // window size; display_update() handles scaling and F11 / Alt+Enter fullscreen
application_surface_draw_enable(false); // drawn by display_present() in Post Draw

view_enabled = true;
view_visible[0] = true;
view_wport[0] = GUI_W;
view_hport[0] = GUI_H;
view_camera[0] = camera_create_view(0, 0, GUI_W, GUI_H);

// Dev bridge (gms-mcp) for live logs/screenshots, if installed. Looked up by name so
// the game still builds after `gm_bridge_uninstall`.
var _bridge = asset_get_index("__mcp_bridge");
if (_bridge != -1 && object_exists(_bridge)) instance_create_depth(0, 0, 0, _bridge);

randomize();
game_init();
