-- NetworkObjManager.luau
--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local NetworkUtils = require(script.Parent.NetworkUtils)

local IS_SERVER = RunService:IsServer()
local WAIT_TIMEOUT = 5

type NetObjType = NetworkUtils.NetObjType

type NetworkObj = NetworkUtils.NetworkObj

local NetworkObjContainer: Folder
local Remotes: Folder
local Bindables: Folder
local RemoteFunctions: Folder
local RemoteEvents: Folder
local BindableFunctions: Folder
local BindableEvents: Folder

local function InitiateFolderStructure()
	if not RunService:IsServer() then
		return
	end

	if not NetworkObjContainer then
		NetworkObjContainer = Instance.new("Folder")
		NetworkObjContainer.Name = "_networkObjs"
		NetworkObjContainer.Parent = ReplicatedStorage
	end

	if not Remotes then
		Remotes = Instance.new("Folder")
		Remotes.Name = "_remotes"
		Remotes.Parent = NetworkObjContainer
	end

	if not Bindables then
		Bindables = Instance.new("Folder")
		Bindables.Name = "_bindables"
		Bindables.Parent = NetworkObjContainer
	end

	if not RemoteFunctions then
		RemoteFunctions = Instance.new("Folder")
		RemoteFunctions.Name = "Remote_Functions"
		RemoteFunctions.Parent = Remotes
	end

	if not RemoteEvents then
		RemoteEvents = Instance.new("Folder")
		RemoteEvents.Name = "Remote_Events"
		RemoteEvents.Parent = Remotes
	end

	if not BindableFunctions then
		BindableFunctions = Instance.new("Folder")
		BindableFunctions.Name = "Bindable_Functions"
		BindableFunctions.Parent = Bindables
	end

	if not BindableEvents then
		BindableEvents = Instance.new("Folder")
		BindableEvents.Name = "Bindable_Events"
		BindableEvents.Parent = Bindables
	end
end

InitiateFolderStructure()

local NetworkObjManager = {
	_Remotes = {
		Functions = {} :: { [string]: RemoteFunction },
		Events = {} :: { [string]: RemoteEvent },
	},

	_Bindables = {
		Functions = {} :: { [string]: BindableFunction },
		Events = {} :: { [string]: BindableEvent },
	},
}

type NetworkObjManager = typeof(NetworkObjManager) & {
	_Remotes: {
		Functions: { [string]: RemoteFunction },
		Events: { [string]: RemoteEvent },
	},

	_Bindables: {
		Functions: { [string]: BindableFunction },
		Events: { [string]: BindableEvent },
	},
}

-- Resolves Type -> (bucket table, parent folder, Instance class name)
local function GetBucket(self: NetworkObjManager, Type: NetObjType): ({ [string]: any }?, Folder?, string?)
	if Type == "RemoteEvent" then
		return self._Remotes.Events :: { [string]: any }, RemoteEvents, "RemoteEvent"
	elseif Type == "RemoteFunction" then
		return self._Remotes.Functions :: { [string]: any }, RemoteFunctions, "RemoteFunction"
	elseif Type == "BindableEvent" then
		return self._Bindables.Events :: { [string]: any }, BindableEvents, "BindableEvent"
	elseif Type == "BindableFunction" then
		return self._Bindables.Functions :: { [string]: any }, BindableFunctions, "BindableFunction"
	end
	return nil, nil, nil
end

--[[
	@param self NetworkObjManager
	@param Name string
	@param Type NetObjType
	@return NetworkObj | nil
]]
function NetworkObjManager.GetOrCreateNetObj(self: NetworkObjManager, Name: string, Type: NetObjType): NetworkObj | nil
	assert(typeof(Name) == "string", "Argument Name must be a string")

	local bucket, folder, className = GetBucket(self, Type)
	if not bucket or not folder or not className then
		warn("Invalid Type: " .. tostring(Type))
		return nil
	end

	if bucket[Name] then
		return bucket[Name]
	end

	if IS_SERVER then
		local obj = Instance.new(className :: any)
		obj.Name = Name
		obj.Parent = folder
		bucket[Name] = obj :: any
		return obj :: any
	else
		local obj = folder:WaitForChild(Name, WAIT_TIMEOUT)
		if not obj then
			warn(`Timed out waiting for {className} "{Name}"`)
			return nil
		end
		bucket[Name] = obj :: any
		return obj :: any
	end
end

--[[
	@param self NetworkObjManager
	@param Name string
	@param Type NetObjType
]]
function NetworkObjManager.DeleteNetworkObj(self: NetworkObjManager, Name: string, Type: NetObjType)
	assert(typeof(Name) == "string", "Argument Name must be a string")

	local bucket = GetBucket(self, Type)
	if not bucket then
		warn("Invalid Type: " .. tostring(Type))
		return
	end

	local obj = bucket[Name]
	if obj then
		bucket[Name] = nil
		obj:Destroy()
	end
end

return NetworkObjManager :: NetworkObjManager
