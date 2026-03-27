---
name: amxmodx-forwards
description: AMX Mod X multi-forward creation and execution with CreateMultiForward and ExecuteForward.
globs: "*.sma,*.inc"
---

# Forwards

Multi-forwards allow plugins to notify other plugins about events. This skill covers `CreateMultiForward` and `ExecuteForward` usage.

> **Note**: For hook-based forwards (Ham Sandwich, FakeMeta, ReAPI), see [hooks.md](mdc:hooks.md).

## Forward Handle Variable Naming

Use `g_pfw` prefix for multi-forward handles:

```pawn
new g_pfwConfigLoaded;
new g_pfwPlayerInfected;
new g_pfwRoundStarted;
```

## Forward Names

Forwards created with `CreateMultiForward` should use `LibraryName_OnSomething` pattern:

```pawn
// ✅ CORRECT: LibraryName_OnEventName
public plugin_init() {
  g_pfwConfigLoaded = CreateMultiForward("MyMod_OnConfigLoaded", ET_IGNORE);
  g_pfwPlayerInfected = CreateMultiForward("MyMod_OnPlayerInfected", ET_STOP, FP_CELL, FP_CELL);
  g_pfwRoundStarted = CreateMultiForward("MyMod_OnRoundStarted", ET_IGNORE);
}

// ❌ DEPRECATED: Don't use Fw_ prefix
g_pfwPlayerInfected = CreateMultiForward("MyMod_Fw_PlayerInfected", ...); // Wrong!
```

## Execution Types

| Type | Description |
|------|-------------|
| `ET_IGNORE` | Return values are ignored, all handlers are always called |
| `ET_STOP` | Stops execution on first handler returning `PLUGIN_HANDLED` |
| `ET_STOP2` | Same as `ET_STOP` but also stops on `PLUGIN_HANDLED_MAIN` |
| `ET_CONTINUE` | All handlers are called, highest return value is kept |

## Parameter Types

| Type | Description |
|------|-------------|
| `FP_CELL` | Integer, bool, entity index |
| `FP_FLOAT` | Float value |
| `FP_STRING` | String (passed by reference) |
| `FP_ARRAY` | Array (passed by reference) |

## Forward Execution

```pawn
new iForwardReturn;
ExecuteForward(g_pfwPlayerInfect, iForwardReturn, pPlayer, pInfector);

// If forward blocked the action (for ET_STOP forwards)
if (iForwardReturn == PLUGIN_HANDLED) return;

// Doing something after pre-forward check passed

// Call post-forward without return check
ExecuteForward(g_pfwPlayerInfected, _, pPlayer, pInfector);
```

## Pre/Post Forward Pattern

```pawn
new g_pfwPlayerInfect;    // Pre-forward (can be blocked)
new g_pfwPlayerInfected;  // Post-forward (notification only)

public plugin_init() {
  // Pre-forward with ET_STOP - can be blocked by returning PLUGIN_HANDLED
  g_pfwPlayerInfect = CreateMultiForward("MyMod_OnPlayerInfect", ET_STOP, FP_CELL, FP_CELL);
  
  // Post-forward with ET_IGNORE - always executes, return ignored
  g_pfwPlayerInfected = CreateMultiForward("MyMod_OnPlayerInfected", ET_IGNORE, FP_CELL, FP_CELL);
}

InfectPlayer(const pPlayer, const pInfector) {
  // Execute pre-forward
  new iReturn;
  ExecuteForward(g_pfwPlayerInfect, iReturn, pPlayer, pInfector);
  
  // Check if blocked
  if (iReturn == PLUGIN_HANDLED) return false;
  
  // Do the actual infection
  SetPlayerInfected(pPlayer, true);
  
  // Execute post-forward (no return check)
  ExecuteForward(g_pfwPlayerInfected, _, pPlayer, pInfector);
  
  return true;
}
```

## Best Practices

1. **Forward names use `LibraryName_OnSomething`** - not deprecated `Fw_` prefix
2. **Use `g_pfw` prefix** for multi-forward handle variables
3. **Use `ET_STOP` for pre-forwards** that can be blocked
4. **Use `ET_IGNORE` for post-forwards** that are notifications only
5. **Check return value** for pre-forwards, use `_` placeholder for post-forwards
6. **Destroy forwards** in `plugin_end()` to free resources
