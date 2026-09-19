-- NetworkClient.luau
--!strict
local NetworkObjManager = require(script.Parent.NetworkObjManager)
local NetworkUtils = require(script.Parent.NetworkUtils)

local DEFAULT_TIMEOUT = 10

local NetworkClient = {}
NetworkClient.__index = NetworkClient

export type NetworkClient = typeof(setmetatable({} :: {}, NetworkClient))

function NetworkClient.new()
	local self = setmetatable({}, NetworkClient)
	return self
end

--[[
	@param _self NetworkClient
	@param Name string
	@param ... any
]]
function NetworkClient.FireServerAsync(_self: NetworkClient, Name: string, ...: any)
	local obj = NetworkObjManager:GetOrCreateNetObj(Name, "RemoteEvent") :: RemoteEvent
	if not obj then
		return
	end
	obj:FireServer(...)
end

--[[
	@param _self NetworkClient
	@param Name string
	@param timeout number?
	@param ... any
	@return boolean, ...any
]]
function NetworkClient.FireServerSync(_self: NetworkClient, Name: string, timeout: number?, ...: any): (boolean, ...any)
	local obj = NetworkObjManager:GetOrCreateNetObj(Name, "RemoteFunction") :: RemoteFunction
	if not obj then
		return false
	end
	return NetworkUtils.InvokeWithTimeout(obj, timeout or DEFAULT_TIMEOUT, nil, ...)
end

--[[
	@param _self NetworkClient
	@param Name string
	@param cb (...any) -> ...any
]]
function NetworkClient.RespondServerSync(_self: NetworkClient, Name: string, cb: (...any) -> ...any): (() -> ())?
	local obj = NetworkObjManager:GetOrCreateNetObj(Name, "RemoteFunction") :: RemoteFunction
	if not obj then
		return nil
	end
	local previous = obj.OnClientInvoke
	obj.OnClientInvoke = cb

	return function()
		if obj.OnClientInvoke == cb then
			obj.OnClientInvoke = previous
		end
	end
end

--[[
	@param _self NetworkClient
	@param Name string
	@param cb (...any) -> ()
	@return RBXScriptConnection?
]]
function NetworkClient.ListenServerAsync(_self: NetworkClient, Name: string, cb: (...any) -> ()): RBXScriptConnection?
	local obj = NetworkObjManager:GetOrCreateNetObj(Name, "RemoteEvent") :: RemoteEvent
	if not obj then
		return nil
	end
	return obj.OnClientEvent:Connect(cb)
end

local function GetDomainEventName(Domain: string): string
	return "DomainEvent_" .. Domain
end

local function GetDomainFunctionName(Domain: string): string
	return "DomainFunction_" .. Domain
end

--[[
	@param self NetworkClient
	@param Domain string
	@param ... any
]]
function NetworkClient.FireInDomain(self: NetworkClient, Domain: string, ...: any)
	local event = NetworkObjManager:GetOrCreateNetObj(GetDomainEventName(Domain), "BindableEvent") :: BindableEvent
	if event then
		event:Fire(...)
	end
end

--[[
	@param self NetworkClient
	@param Domain string
	@param cb (...any) -> ()
	@return () -> ()
]]
function NetworkClient.ListenInDomain(self: NetworkClient, Domain: string, cb: (...any) -> ()): () -> ()
	local event = NetworkObjManager:GetOrCreateNetObj(GetDomainEventName(Domain), "BindableEvent") :: BindableEvent
	local connection = event.Event:Connect(function(...)
		cb(...)
	end)

	return function()
		connection:Disconnect()
	end
end

--[[
	@param self NetworkClient
	@param Domain string
	@param ... any
	@return ...any
]]
function NetworkClient.CallInDomain(self: NetworkClient, Domain: string, ...: any): ...any
	local _ = self
	local fn =
		NetworkObjManager:GetOrCreateNetObj(GetDomainFunctionName(Domain), "BindableFunction") :: BindableFunction
	return fn:Invoke(...)
end

--[[
	@param self NetworkClient
	@param Domain string
	@param cb (...any) -> ...any
]]
function NetworkClient.RegisterInDomain(self: NetworkClient, Domain: string, cb: (...any) -> ...any): () -> ()
	local fn =
		NetworkObjManager:GetOrCreateNetObj(GetDomainFunctionName(Domain), "BindableFunction") :: BindableFunction
	local previous = fn.OnInvoke
	fn.OnInvoke = cb

	return function()
		if fn.OnInvoke == cb then
			fn.OnInvoke = previous
		end
	end
end

return NetworkClient
