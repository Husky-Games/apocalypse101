/// @description Clean up MCP bridge connection
if (global.__mcp_socket >= 0) {
    network_destroy(global.__mcp_socket);
    global.__mcp_socket = -1;
}
global.__mcp_enabled = false;
// gms-mcp generated asset sha256:3b36538acf53b3417fb2a1b23cbeee0d033e2a1f06a21e3b565141254c3663c9
