/// @description Process any pending MCP commands
// This runs every frame to check for incoming commands

// Nothing to do if not connected
if (!global.__mcp_enabled) exit;

// Connection check - if socket was closed, disable
if (global.__mcp_socket < 0) {
    global.__mcp_enabled = false;
    exit;
}
// gms-mcp generated asset sha256:edc4374e07a081c99ca6664f2bf43cdc6019e954050827eb671e865e57d02888
