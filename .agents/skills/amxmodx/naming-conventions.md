---
name: amxmodx-naming-conventions
description: AMX Mod X Hungarian notation and naming conventions for variables, functions, and callbacks.
globs: "*.sma,*.inc"
---

# Naming Conventions

## Hungarian Notation Prefixes

Use Hungarian notation for all variable names:

| Prefix | Type | Example |
|--------|------|---------|
| `g_` | Global variable | `g_pTrace`, `g_szModel` |
| `p` | Entity/Player pointer | `pPlayer`, `pEntity`, `pOwner` |
| `sz` | String (zero-terminated) | `szModel`, `szClassName` |
| `fl` | Float | `flDamage`, `flGameTime` |
| `i` | Integer | `iSlot`, `iTeam` |
| `b` | Boolean | `bRedeploy`, `bMissfire` |
| `vec` | Vector (Float array[3]) | `vecOrigin`, `vecAngles` |
| `rg` | Array (range) | `g_rgiPlayerAttributes`, `g_rgflPlayerDeathTime` |

## Global Variable Examples

```pawn
// Strings for resource paths
new g_szModel[MAX_RESOURCE_PATH_LENGTH];
new g_szHitSound[MAX_RESOURCE_PATH_LENGTH];

// Trace handle - ALWAYS use single global trace handle
new g_pTrace;

// CVars
new g_pCvarAutoGuidanceRange;

// Player data arrays
new g_rgiPlayerAttributes[MAX_PLAYERS + 1][PlayerAttribute];
new Float:g_rgflPlayerDeathTime[MAX_PLAYERS + 1];

// Message IDs - use gmsg prefix (without underscore after g)
new gmsgStatusIcon;
new gmsgScreenShake;

// Forwards - use LibraryName_OnSomething naming (NOT LibraryName_Fw_Something)
new g_pfwConfigLoaded;
```

## Sound Arrays

For multiple sounds of the same type, use a numbered array with a count variable:

```pawn
new g_rgszHitSounds[4][MAX_RESOURCE_PATH_LENGTH];
new g_iHitSoundsNum = 0;
```

## Player State Arrays

Use Hungarian notation prefix `g_rg` for player arrays with size `[MAX_PLAYERS + 1]`:

```pawn
// Boolean arrays
new bool:g_rgbPlayerVision[MAX_PLAYERS + 1];

// Float arrays
new Float:g_rgflPlayerRespawnTime[MAX_PLAYERS + 1];
new Float:g_rgflPlayerOrigin[MAX_PLAYERS + 1][3];

// Integer arrays
new g_rgiPlayerTeamPreference[MAX_PLAYERS + 1];

// Entity/Pointer arrays
new g_rgpPlayerInfector[MAX_PLAYERS + 1];
```

## Naming Conventions Summary Table

| Element | Prefix/Pattern | Example |
|---------|----------------|---------|
| Native implementation | `Native_` | `Native_IsPlayerInfected` |
| Native function | `ModPrefix_{Name}` | `ModPrefix_IsActivated` |
| Task callback | `Task_` | `Task_ActivateVision` |
| Callback (general) | `Callback_{Entity}_{Action}` | `Callback_Shop_Purchase` |
| Menu callback | `Callback_Menu_{Name}` | `Callback_Menu_Shop` |
| Menu item callback | `Callback_MenuItem_{Name}` | `Callback_MenuItem_ChangeTeam` |
| SQL query callback | `Callback_SQLQuery_{Name}` | `Callback_SQLQuery_LoadPlayer` |
| CVar query callback | `Callback_ClientCvarQuery_{Name}` | `Callback_ClientCvarQuery_Crosshair` |
| Command handler | `Command_` | `Command_DropAmmo` |
| Sound arrays | `g_rgsz` + `g_i*Num` | `g_rgszHitSounds`, `g_iHitSoundsNum` |
| Message IDs | `gmsg` | `gmsgStatusIcon` |
| Player arrays | `g_rg*[MAX_PLAYERS + 1]` | `g_rgbPlayerVision` |
| Multi-forward handle | `g_pfw` | `g_pfwPlayerInfected` |
| Ham forward handle | `g_pfwham` | `g_pfwhamPlayerPreThink` |
| FakeMeta forward handle | `g_pfwfm` | `g_pfmfwAddToFullPack` |

## Legacy Parameter Naming (Avoid)

Native AMX Mod X includes use inconsistent parameter naming. **Avoid these patterns:**

| Native Pattern | Avoid | Use Instead |
|---------------|-------|-------------|
| `id` | Player index | `pPlayer` |
| `index` | Entity index | `pEntity`, `pItem`, `pWeapon` |
| `_index` | With underscore | `pEntity` |
| `entindex` | Entity index | `pEntity` |
| `len`, `length` | Buffer length | `iLen`, `iMaxLen` |
| `string[]`, `buffer[]` | String buffer | `szBuffer[]`, `szName[]` |
| `output[]` | Output buffer | `szOutput[]`, `szBuffer[]` |
| `value` | Generic value | Use specific name with type prefix |

## Best Practices

1. **Use Hungarian notation** for all variable names
2. **Sound arrays use `g_rgsz` prefix** with `g_i*Num` counter
3. **Message IDs use `gmsg` prefix** (without underscore)
4. **Player arrays use `g_rg*[MAX_PLAYERS + 1]`** with type prefix
5. **Don't use `id` for players** - use `pPlayer`
6. **Don't use `index` for entities** - use `pEntity`, `pItem`, `pWeapon`
7. **Don't use short buffer names** - use `szBuffer`, `szName` instead of `string`, `output`
8. **Don't use `len` for lengths** - use `iLen`, `iMaxLen`
