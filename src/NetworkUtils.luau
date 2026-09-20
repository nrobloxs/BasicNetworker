local NetworkUtils = {}

export type NetworkObj = RemoteEvent | RemoteFunction | BindableEvent | BindableFunction
export type NetObjType = "RemoteEvent" | "RemoteFunction" | "BindableEvent" | "BindableFunction"
export type DomainCallback = (...any) -> ()
export type DomainList = { DomainCallback }
export type DomainMap = { [string]: DomainList }
export type GroupList = { Player }
export type GroupMap = { [string]: GroupList }

export type NetworkObjs = {
	_Remotes: {
		Functions: { [string]: RemoteFunction },
		Events: { [string]: RemoteEvent },
	},

	_Bindables: {
		Functions: { [string]: BindableFunction },
		Events: { [string]: BindableEvent },
	},
}

function NetworkUtils.InvokeWithTimeout(
	obj: RemoteFunction,
	timeout: number,
	player: Player?,
	...: any
): (boolean, ...any)
	local args = table.pack(...)
	local co = coroutine.running()
	local done = false

	task.delay(timeout, function()
		if done then
			return
		end
		done = true
		local ok, err = coroutine.resume(co, false)
		if not ok then
			warn(err)
		end
	end)

	task.spawn(function()
		local packed
		if player then
			packed = table.pack(pcall(obj.InvokeClient, obj, player, table.unpack(args, 1, args.n)))
		else
			packed = table.pack(pcall(obj.InvokeServer, obj, table.unpack(args, 1, args.n)))
		end
		if done then
			return
		end
		done = true
		local ok = packed[1]
		if ok then
			coroutine.resume(co, true, table.unpack(packed, 2, packed.n))
		else
			coroutine.resume(co, false, packed[2])
		end
	end)

	return coroutine.yield()
end

return NetworkUtils
