global.__mcp_socket = -1;
global.__mcp_enabled = false;
global.__mcp_log_lines = [];

/// @function __mcp_log(message)
/// @description Log a message to both debug output and MCP bridge
/// @param {string} message The message to log
function __mcp_log(_message) {
    var _timestamp = string(current_time);
    var _full_msg = "[" + _timestamp + "] " + string(_message);
    
    // Always log to standard debug output, and keep the newest lines for log_tail
    show_debug_message(_full_msg);
    array_push(global.__mcp_log_lines, _full_msg);
    if (array_length(global.__mcp_log_lines) > 200) array_delete(global.__mcp_log_lines, 0, 1);
    
    // Send to MCP bridge if connected
    if (global.__mcp_enabled && global.__mcp_socket >= 0) {
        var _packet = "LOG:" + _timestamp + "|" + string(_message) + chr(10);
        var _buffer = buffer_create(string_byte_length(_packet) + 1, buffer_fixed, 1);
        buffer_write(_buffer, buffer_string, _packet);
        network_send_raw(global.__mcp_socket, _buffer, buffer_tell(_buffer));
        buffer_delete(_buffer);
    }
}

/// @function __mcp_send_response(cmd_id, result)
/// @description Send a command response to MCP bridge
/// @param {string} cmd_id The command ID to respond to
/// @param {string} result The result string
function __mcp_send_response(_cmd_id, _result) {
    if (global.__mcp_enabled && global.__mcp_socket >= 0) {
        var _packet = "RSP:" + string(_cmd_id) + "|" + string(_result) + chr(10);
        var _buffer = buffer_create(string_byte_length(_packet) + 1, buffer_fixed, 1);
        buffer_write(_buffer, buffer_string, _packet);
        network_send_raw(global.__mcp_socket, _buffer, buffer_tell(_buffer));
        buffer_delete(_buffer);
    }
}
// gms-mcp generated asset sha256:68073f832ad1fc5982111a8bd388557b3db5d68c4282b2f9df180bb9ebc5c18b
