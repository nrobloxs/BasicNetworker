# BasicNetworker

A lightweight networking abstraction for Roblox games built around dynamic remote instances and simple request/response patterns.

This project wraps common RemoteEvent and RemoteFunction usage behind a cleaner API so you can keep gameplay logic focused on game behavior instead of repeatedly creating, naming, and connecting network objects by hand.

## What this system does

The library creates and manages network objects automatically under a dedicated folder structure in ReplicatedStorage:

- ReplicatedStorage._networkObjs
  - _remotes
    - Remote_Events
    - Remote_Functions
  - _bindables
    - Bindable_Events
    - Bindable_Functions

When a method like `server:ListenClientAsync("MyEvent")` or `client:FireServerAsync("Attack")` is used, the system resolves the correct RemoteEvent or RemoteFunction by name and either creates it or waits for it to exist on the other side.

This gives you a small, consistent API for:

- server-to-client communication
- client-to-server communication
- request/response calls with timeout protection
- local domain events/functions for server/client-side logic
- sending to groups of players rather than everybody

---

## Core idea

The library separates the concern of transport from the concern of game logic.

Instead of writing repeated boilerplate like:

```lua
local remote = ReplicatedStorage:WaitForChild("MyRemote")
remote.OnClientEvent:Connect(function(...) end)
```

you call a high-level method such as:

```lua
client:ListenServerAsync("MyRemote", function(...)
    -- handle payload
end)
```

The object manager handles creation and lookup, and the wrapper exposes a consistent pattern for event-driven or function-driven communication.

---

## How it works

### 1. Dynamic remote creation

The manager in `src/NetworkObjManager.luau` resolves a name and a type:

- RemoteEvent
- RemoteFunction
- BindableEvent
- BindableFunction

If the object does not exist yet, the server creates it. If the client asks for it before it exists, the client waits for it to appear using a timeout.

This is useful because it enables a more declarative style in which you can fire or listen on a network object without predefining everything in Studio.

### 2. Client/server wrappers

The API is split across:

- `src/NetworkServer.luau`
- `src/NetworkClient.luau`

These expose methods such as:

```lua
server:FireClientAsync("InventoryUpdated", player, payload)
server:FireAllClientsAsync("RoundStart", data)
server:ListenClientAsync("PlayerJump", function(player, jumpPower)
    -- logic
end)

client:FireServerAsync("Attack", targetId)
client:ListenServerAsync("DamageTaken", function(amount)
    -- handle damage
end)
```

### 3. Request and response flow

The library includes synchronous invocation helpers with timeouts.

```lua
local ok, value = client:FireServerSync("GetPlayerStats", 10, playerId)
```

Under the hood, these use a RemoteFunction and `InvokeServer` or `InvokeClient` with a timeout guard. If the request hangs or the other side does not respond, the call returns `false` (or a timeout result) rather than blocking indefinitely.

The timeout logic is implemented in `src/NetworkUtils.luau` through `InvokeWithTimeout`.

### 4. Domain events and bindables

The system also supports local, scoped signal systems using bindable domains. These are useful for modular subsystems that need events or functions without making network traffic.

```lua
server:FireInDomain("Combat", payload)
server:ListenInDomain("Combat", function(payload)
    -- local callback
end)

client:RegisterInDomain("UI", function(payload)
    return "ok"
end)
```

They are not full network transport; they behave like local pub/sub channels within a server/client context.

### 5. Group targeting

Server-side grouping is also supported:

```lua
server:AddGroup("RedTeam", { playerA, playerB })
server:FireInGroupAsync("RedTeam", "TeamUpdate", { score = 3 })
```

This helps broadcast to subsets of players without manually looping over all clients.

---

## Strengths

### Simple mental model

The API is compact and consistent. You mostly work with names and callbacks rather than manually managing remote instance creation and connection cleanup.

### Fast prototyping

Because required network objects are created on demand, the system is easy to iterate with during development. You do not need to maintain a massive remote folder in Studio by hand.

### Timeout-safe sync requests

The synchronous patterns guard against freeze-like hangs when a client or server fails to respond in time.

### Flexible communication styles

You can choose between:

- async event-style messaging
- synced function calls
- broadcast to all players
- targeted messages to a single player
- grouped communication
- local bindable domains

### Modular design

The system is split into clear layers:

- network object lifecycle
- transport wrappers
- utility helpers

This makes it easier to extend without rewriting the entire message system.

---

## Drawbacks

### Less explicit than a manually defined remote map

Because objects are created dynamically by name, it is easy to accidentally duplicate names, mistype a remote identifier, or forget what a message is meant to do.

This is a convenience feature, but it trades some clarity for automation.

### Weak naming discipline is required

A project can become confusing if every message is just a string literal without a central registry or schema. For larger projects, documenting message names and payload shapes becomes important.

### Bindable domain semantics are a little fuzzy

The domain functions resemble local event buses, but they are not a full architecture by themselves. They are useful, but they are not a substitute for a more formal message bus or ECS-style event layer.

### Synchronous calls can still be fragile in game logic

Even with timeout protection, calling functions over the network is still slower and more failure-prone than local logic. This system is excellent for simple gameplay communication, but it is not a replacement for careful architecture in large multiplayer projects.

### One network object per name

The design uses a single object per name and type. This is convenient, but it assumes consistent naming. If your project grows beyond a certain size, you may want a more explicit remote registry and contract validation layer.

---

## Common usage patterns

### Server to client event

```lua
local server = require(game.ServerScriptService.Network).server

server:ListenClientAsync("MoveRequest", function(player, direction)
    print(player.Name .. " requested movement: " .. direction)
end)
```

### Client to server function call

```lua
local client = require(game.ReplicatedStorage.Network).client

local ok, result = client:FireServerSync("GetInventory", 10)
if ok then
    print(result)
end
```

### Server responder

```lua
local server = require(game.ServerScriptService.Network).server

server:RespondClientSync("GetInventory", function(player)
    return {
        coins = 100,
        gems = 12,
    }
end)
```

### Local domain event

```lua
local server = require(game.ServerScriptService.Network).server

server:ListenInDomain("CombatState", function(state)
    print("Combat state changed:", state)
end)
```

---

## Methods at a glance

### Server API

- `FireClientAsync(Name, player, ...)`
- `FireAllClientsAsync(Name, ...)`
- `ListenClientAsync(Name, cb)`
- `FireClientSync(Name, player, timeout, ...)`
- `RespondClientSync(Name, cb)`
- `FireAllClientsSync(Name, timeout, cb, ...)`
- `AddGroup(GroupTag, players)`
- `RemoveGroup(GroupTag)`
- `AddPlayerToGroup(GroupTag, player)`
- `RemovePlayerFromGroup(GroupTag, player)`
- `FireInGroupAsync(GroupTag, Name, ...)`
- `FireInDomain(Domain, ...)`
- `ListenInDomain(Domain, cb)`
- `CallInDomain(Domain, ...)`
- `RegisterInDomain(Domain, cb)`

### Client API

- `FireServerAsync(Name, ...)`
- `FireServerSync(Name, timeout, ...)`
- `RespondServerSync(Name, cb)`
- `ListenServerAsync(Name, cb)`
- `FireInDomain(Domain, ...)`
- `ListenInDomain(Domain, cb)`
- `CallInDomain(Domain, ...)`
- `RegisterInDomain(Domain, cb)`

---

## Recommended usage

This is a strong fit for:

- prototype multiplayer systems
- small- to medium-scale Roblox games
- modular event-driven architecture
- simple request/response gameplay mechanics
- local subsystem coordination

This is less ideal for:

- very large games with strict engineering contracts
- distributed message schemas requiring validation and tooling
- projects that need a more explicit remote registry and discovery layer

---

## Summary

BasicNetworker is a compact networking utility that abstracts away the boilerplate of RemoteEvent and RemoteFunction creation and consumption.

Its main value is clarity and speed: you can define gameplay behaviors in terms of action names and callbacks, while the library handles the underlying object creation, lifecycle, and timeout behavior.

It is not a full multiplayer framework, but it is a useful base layer for building one cleanly and efficiently.

---

## Getting started

To build the project with Rojo:

```bash
rojo build -o "BasicNetworker.rbxlx"
```

Then open the generated file in Roblox Studio, and run:

```bash
rojo serve
```

For more help, see the [Rojo documentation](https://rojo.space/docs).
