local NetworkClient = require(script.NetworkClient)
local NetworkServer = require(script.NetworkServer)
local server = NetworkServer
local client = NetworkClient

export type Server = NetworkServer.NetworkServer
export type Client = NetworkClient.NetworkClient

return {
	server = server,
	client = client,
}
