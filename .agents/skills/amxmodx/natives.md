---
name: amxmodx-natives
description: AMX Mod X native function registration and implementation patterns.
globs: "*.sma,*.inc"
---

# Natives

## Native Implementation

Native callbacks use `Native_` prefix. Arguments for native callbacks should always be marked as `const`:

```pawn
public plugin_natives() {
  register_library("my_library");
  register_native("MyMod_IsPlayerInfected", "Native_IsPlayerInfected");
  register_native("MyMod_SetPlayerInfected", "Native_SetInfected");
}

public Native_IsPlayerInfected(const iPluginId, const iArgc) {
  static pPlayer; pPlayer = get_param(1);
  return IsPlayerInfected(pPlayer);
}

public Native_SetInfected(const iPluginId, const iArgc) {
  new pPlayer = get_param(1);
  new bool:bValue = bool:get_param(2);
  SetPlayerInfected(pPlayer, bValue);
}
```

## Native Function Naming

Native functions exposed to other plugins should use `ModPrefix_FunctionName` pattern:

```pawn
// Exposed as: MyMod_IsPlayerInfected(pPlayer)
// Exposed as: MyMod_SetPlayerInfected(pPlayer, bool:bValue)
```

## Getting Parameters

```pawn
// Get cell (integer, bool, entity)
new pPlayer = get_param(1);
new bool:bValue = bool:get_param(2);

// Get float
new Float:flValue = get_param_f(1);

// Get string
new szBuffer[64];
get_string(1, szBuffer, charsmax(szBuffer));

// Get array
new rgData[10];
get_array(1, rgData, sizeof(rgData));

// Set return string
set_string(2, szResult, iMaxLen);

// Set return array
set_array(2, rgResult, sizeof(rgResult));
```

## Best Practices

1. **Native implementations use `Native_` prefix**
2. **Use `const` for `iPluginId` and `iArgc` arguments**
3. **Use static for frequently accessed parameters** in hot-path natives
4. **Register library** with `register_library()` before registering natives
5. **Use `ModPrefix_FunctionName`** pattern for exposed native names
