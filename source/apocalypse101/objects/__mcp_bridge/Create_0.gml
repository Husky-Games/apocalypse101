/// @description Initialize MCP Bridge connection
global.__mcp_socket = -1;
global.__mcp_enabled = false;
global.__mcp_buffer = "";
global.__mcp_port = 0;
// Advertised in HELLO; the server refuses other commands with a clear error.
global.__mcp_commands = ["ping", "help", "state", "screenshot", "log_tail", "goto_room", "get_var", "set_var", "spawn", "room_info", "instance_count"];

var _port_text = environment_get_variable("GMS_MCP_BRIDGE_PORT");
var _credential = environment_get_variable("GMS_MCP_BRIDGE_TOKEN");
if (_credential == "" || string_length(_port_text) == 0 || string_length(_port_text) > 5) exit;
for (var _i = 1; _i <= string_length(_port_text); _i++) {
    var _digit = ord(string_char_at(_port_text, _i));
    if (_digit < ord("0") || _digit > ord("9")) exit;
}
global.__mcp_port = real(_port_text);
if (global.__mcp_port < 1 || global.__mcp_port > 65535) exit;

var _socket = network_create_socket(network_socket_tcp);
var _result = network_connect_raw(_socket, "127.0.0.1", global.__mcp_port);
if (_result >= 0) {
    global.__mcp_socket = _socket;
    global.__mcp_enabled = true;
    var _hello = "HELLO:" + json_stringify({protocol: 2, token: _credential, game: game_project_name, commands: global.__mcp_commands}) + chr(10);
    var _packet = buffer_create(string_byte_length(_hello) + 1, buffer_fixed, 1);
    buffer_write(_packet, buffer_string, _hello);
    network_send_raw(_socket, _packet, buffer_tell(_packet));
    buffer_delete(_packet);
    __mcp_log("[MCP] Bridge connected on port " + string(global.__mcp_port));
} else {
    network_destroy(_socket);
}
// gms-mcp generated asset sha256:0192fe1bb45207252276782060eef7ea09c0deb0c9866f861d6563db00ac1dcc
