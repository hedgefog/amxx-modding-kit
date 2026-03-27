---
name: amxmodx-callbacks
description: AMX Mod X callback patterns for tasks, SQL queries, and CVar queries.
globs: "*.sma,*.inc"
---

# Callbacks

> **Note**: For menu callbacks and patterns, see [menus.md](mdc:menus.md).

## Task Callbacks

Task callbacks use `Task_` prefix. Always use the `const` keyword for the `iTaskId` argument.

Define `TASKID_*` constants with high enough step between values to avoid collision:

```pawn
#define TASKID_RESPAWN 100
#define TASKID_ACTIVATE_VISION 200

// Setting a task with player offset
set_task(1.0, "Task_ActivateVision", TASKID_ACTIVATE_VISION + pPlayer);

// Task callback - extract player from task ID
public Task_ActivateVision(const iTaskId) {
  new pPlayer = iTaskId - TASKID_ACTIVATE_VISION;

  if (!is_user_connected(pPlayer)) return;

  SetPlayerVision(pPlayer, true);
}

// Removing task
remove_task(TASKID_ACTIVATE_VISION + pPlayer);
```

### Task with Data Array

```pawn
// Pass data to task
new rgData[3];
rgData[0] = pPlayer;
rgData[1] = iWeaponId;
rgData[2] = iAmmo;
set_task(1.0, "Task_GiveWeapon", TASKID_GIVE_WEAPON, rgData, sizeof(rgData));

// Receive data in callback
public Task_GiveWeapon(const rgData[], const iTaskId) {
  new pPlayer = rgData[0];
  new iWeaponId = rgData[1];
  new iAmmo = rgData[2];
  
  if (!is_user_connected(pPlayer)) return;
  
  give_item(pPlayer, g_rgszWeaponNames[iWeaponId]);
  cs_set_user_bpammo(pPlayer, iWeaponId, iAmmo);
}
```

### Repeating Tasks

```pawn
// Repeat task with flags
set_task(0.1, "Task_UpdateHUD", TASKID_UPDATE_HUD + pPlayer, _, _, "b"); // "b" = repeat

// Stop repeating task
remove_task(TASKID_UPDATE_HUD + pPlayer);
```

---

## SQL Query Callbacks

### Naming Convention

```pawn
// Single query plugin - use Callback_SQLQuery
public Callback_SQLQuery(const iFailState, const pQuery, const szError[], iErrNum, const rgData[], iDataSize, Float:flQueueTime)

// Multi-query plugin - use Callback_SQLQuery_{QueryName}
public Callback_SQLQuery_LoadPlayer(...)
public Callback_SQLQuery_SaveStats(...)
```

### Example

```pawn
public Callback_SQLQuery_LoadPlayer(const iFailState, const pQuery, const szError[], iErrNum, const rgData[], iDataSize, Float:flQueueTime) {
  if (iFailState != TQUERY_SUCCESS) {
    log_amx("SQL Error: %s", szError);
    return;
  }
  
  new pPlayer = rgData[0];
  if (!is_user_connected(pPlayer)) return;
  
  // Process query results
  if (SQL_NumResults(pQuery) > 0) {
    g_rgiPlayerScore[pPlayer] = SQL_ReadResult(pQuery, 0);
    g_rgiPlayerKills[pPlayer] = SQL_ReadResult(pQuery, 1);
  }
}
```

---

## CVar Query Callbacks

Query client cvars asynchronously:

### Naming Convention

```pawn
public Callback_ClientCvarQuery_{Name}(const pPlayer, const szCvar[], const szValue[], const szParam[])
```

### Example

```pawn
public client_putinserver(pPlayer) {
  query_client_cvar(pPlayer, "cl_updaterate", "Callback_ClientCvarQuery_UpdateRate");
}

public Callback_ClientCvarQuery_UpdateRate(const pPlayer, const szCvar[], const szValue[], const szParam[]) {
  new iUpdateRate = str_to_num(szValue);
  
  if (iUpdateRate < 60) {
    client_print(pPlayer, print_chat, "[Server] Your cl_updaterate is too low. Recommended: 100+");
  }
}
```

---

## Best Practices

1. **Task callbacks use `Task_` prefix** with offset in task ID
2. **Use high enough steps between `TASKID_*` values** to avoid collisions (MAX_PLAYERS + 1 for player tasks)
3. **Use `const iTaskId`** argument in task callbacks
4. **SQL callbacks use `Callback_SQLQuery_{Name}` prefix**
5. **CVar query callbacks use `Callback_ClientCvarQuery_{Name}` prefix**
6. **Always check `is_user_connected`** in delayed callbacks - player may have left
