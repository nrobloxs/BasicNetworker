-- NetworkServer.luau
--!strict
local Players = game:GetService("Players")
local NetworkObjManager = require(script.Parent.NetworkObjManager)
local NetworkUtils = require(script.Parent.NetworkUtils)

local DEFAULT_TIMEOUT = 10

local NetworkServer = {}
NetworkServer.__index = NetworkServer

export type NetworkServer = typeof(setmetatable(
	{} :: {
		_Groups: NetworkUtils.GroupMap,
		_Domains: NetworkUtils.DomainMap,
	},
	NetworkServer
))

function NetworkServer.new()
	local self = setmetatable({
		_Groups = {},
		_Domains = {},
	}, NetworkServer)

	Players.PlayerRemoving:Connect(function(player)
		local groups: { [string]: { Player } } = self._Groups
		for _, group in pairs(groups) do
			local groupList: { Player } = group
			local idx = table.find(groupList, player)
			if idx then
				table.remove(groupList, idx)
			end
		end
	end)

	return self
end

function NetworkServer.FireClientAsync(self: NetworkServer, Name: string, player: Player, ...: any)
	if self == nil then
		return
	end
	local obj = NetworkObjManager:GetOrCreateNetObj(Name, "RemoteEvent") :: RemoteEvent
	if not obj then
		return
	end
	obj:FireClient(player, ...)
end

function NetworkServer.FireAllClientsAsync(self: NetworkServer, Name: string, ...: any)
	if self == nil then
		return
	end
	local obj = NetworkObjManager:GetOrCreateNetObj(Name, "RemoteEvent") :: RemoteEvent
	if not obj then
		return
	end
	obj:FireAllClients(...)
end

-- Server -> single client, synchronous. Client registers its handler via
-- NetworkClient:RespondServerSync(Name, cb). Timeout-guarded.
function NetworkServer.FireClientSync(
	self: NetworkServer,
	Name: string,
	player: Player,
	timeout: number?,
	...: any
): (boolean, ...any)
	if self == nil then
		return false
	end
	local obj = NetworkObjManager:GetOrCreateNetObj(Name, "RemoteFunction") :: RemoteFunction
	if not obj then
		return false
	end
	return NetworkUtils.InvokeWithTimeout(obj, timeout or DEFAULT_TIMEOUT, player, ...)
end

-- Server -> all clients, synchronous. Each client runs on its own thread so one
-- slow/unresponsive client can't block the rest. cb fires per-player as results
-- (or timeouts) come in.
function NetworkServer.FireAllClientsSync(
	self: NetworkServer,
	Name: string,
	timeout: number?,
	cb: ((player: Player, success: boolean, ...any) -> ())?,
	...: any
)
	if self == nil then
		return
	end
	local obj = NetworkObjManager:GetOrCreateNetObj(Name, "RemoteFunction") :: RemoteFunction
	if not obj then
		return
	end

	for _, player in Players:GetPlayers() do
		task.spawn(function(...)
			local results = table.pack(NetworkUtils.InvokeWithTimeout(obj, timeout or DEFAULT_TIMEOUT, player, ...))
			local success = results[1]

			if cb then
				cb(player, success, table.unpack(results, 2, results.n))
			end
		end, ...)
	end
end

function NetworkServer.AddGroup(self: NetworkServer, GroupTag: string, players: { Player })
	if self._Groups[GroupTag] then
		warn("Group Already Exists, overwriting: " .. GroupTag)
	end
	self._Groups[GroupTag] = players
end

function NetworkServer.RemoveGroup(self: NetworkServer, GroupTag: string)
	self._Groups[GroupTag] = nil
end

function NetworkServer.AddPlayerToGroup(self: NetworkServer, GroupTag: string, player: Player)
	local group: { Player }? = self._Groups[GroupTag]
	if not group then
		self._Groups[GroupTag] = { player }
		return
	end
	if not table.find(group, player) then
		table.insert(group, player)
	end
end

function NetworkServer.RemovePlayerFromGroup(self: NetworkServer, GroupTag: string, player: Player)
	local group: { Player }? = self._Groups[GroupTag]
	if not group then
		return
	end
	local idx = table.find(group, player)
	if idx then
		table.remove(group, idx)
	end
end

function NetworkServer.FireInGroupAsync(self: NetworkServer, GroupTag: string, Name: string, ...: any)
	local group = self._Groups[GroupTag]
	if not group then
		return
	end

	local obj = NetworkObjManager:GetOrCreateNetObj(Name, "RemoteEvent") :: RemoteEvent
	if not obj then
		return
	end

	for _, player in ipairs(group) do
		obj:FireClient(player, ...)
	end
end

-- Local (non-networked) pub/sub, scoped to the server. Overlaps with GoodSignal —
-- confirm this is actually what "Domain" was meant to be.
local function GetDomainEventName(Domain: string): string
	return "DomainEvent_" .. Domain
end

local function GetDomainFunctionName(Domain: string): string
	return "DomainFunction_" .. Domain
end

function NetworkServer.FireInDomain(self: NetworkServer, Domain: string, ...: any)
	local event = NetworkObjManager:GetOrCreateNetObj(GetDomainEventName(Domain), "BindableEvent") :: BindableEvent
	if event then
		event:Fire(...)
	end
end

function NetworkServer.ListenInDomain(self: NetworkServer, Domain: string, cb: NetworkUtils.DomainCallback): () -> ()
	local listeners: { NetworkUtils.DomainCallback } = self._Domains[Domain]
	if not listeners then
		listeners = {}
		self._Domains[Domain] = listeners
	end
	table.insert(listeners, cb)

	local event = NetworkObjManager:GetOrCreateNetObj(GetDomainEventName(Domain), "BindableEvent") :: BindableEvent
	local connection = event.Event:Connect(function(...)
		cb(...)
	end)

	return function()
		local idx = table.find(listeners, cb)
		if idx then
			table.remove(listeners, idx)
		end
		connection:Disconnect()
	end
end

function NetworkServer.CallInDomain(self: NetworkServer, Domain: string, ...: any): ...any
	local _ = self
	local fn =
		NetworkObjManager:GetOrCreateNetObj(GetDomainFunctionName(Domain), "BindableFunction") :: BindableFunction
	return fn:Invoke(...)
end

function NetworkServer.RegisterInDomain(self: NetworkServer, Domain: string, cb: (...any) -> ...any)
	local _ = self
	local fn =
		NetworkObjManager:GetOrCreateNetObj(GetDomainFunctionName(Domain), "BindableFunction") :: BindableFunction
	fn.OnInvoke = cb
end

return NetworkServer
