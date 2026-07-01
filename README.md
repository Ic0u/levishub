# Levis Hub

Levis Hub is a Roblox Lua script hub. The loader checks the current place ID, loads a supported game script when one exists, and falls back to the universal script otherwise.

## Load

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/Ic0u/levishub/main/loader.lua"))()
```

## Supported Games

| Game | Place ID | Script |
| --- | --- | --- |
| Strucid | `2377868063` | `games/2377868063.lua` |
| Arsenal | `286090429` | `games/286090429.lua` |
| Blade Ball | `13772394625` | `games/13772394625.lua` |

Unsupported games load `scripts/Universal.lua`.

## Files

```text
loader.lua              main loader
games.json              place ID registry
games/                  game-specific scripts
scripts/Universal.lua   fallback script
libraries/              shared Lua libraries
version.txt             current version
```

## Credits

Made by Marcus Nguyen, Revi Hub, and Vietcombank.
