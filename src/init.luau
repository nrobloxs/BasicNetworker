local server = require(script.NetworkServer)
local client = require(script.NetworkClient)

export type Server = server.NetworkServer
export type Client = client.NetworkClient

return {
	server = server,
	client = client,
}
