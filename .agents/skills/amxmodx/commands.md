---
name: amxmodx-commands
description: AMX Mod X console command registration for client and server commands.
globs: "*.sma,*.inc"
---

# Commands

## Client Commands

Client commands are triggered by players via console.

### Naming Convention

Command handlers use `Command_` prefix. Arguments should be marked as `const`:

```pawn
public plugin_init() {
  register_clcmd("chooseteam", "Command_ChangeTeam");
}

public Command_ChangeTeam(const pPlayer) {
  if (!is_user_alive(pPlayer)) return PLUGIN_HANDLED;

  // Command logic...

  return PLUGIN_HANDLED;
}
```

### With Access Level

```pawn
public plugin_init() {
  register_clcmd("amx_testcmd", "Command_Test", ADMIN_KICK, "- test command");
}

public Command_Test(const pPlayer, const iLevel, const iCId) {
  if (!cmd_access(pPlayer, iLevel, iCId, 1)) return PLUGIN_HANDLED;
  
  // Admin command logic...
  
  return PLUGIN_HANDLED;
}
```

---

## Server Commands

Server commands are executed via server console or RCON.

### Naming Convention

Use `ServerCommand_` prefix for server-only commands:

```pawn
public plugin_init() {
  register_srvcmd("mymod_reload", "ServerCommand_Reload");
  register_srvcmd("mymod_status", "ServerCommand_Status");
}

public ServerCommand_Reload() {
  LoadConfig();
  server_print("[MyMod] Configuration reloaded");
  return PLUGIN_HANDLED;
}

public ServerCommand_Status() {
  server_print("[MyMod] Active players: %d", GetActivePlayersCount());
  return PLUGIN_HANDLED;
}
```

---

## Console Commands (Both Client and Server)

`register_concmd` registers a command that works from both client and server console.

### Naming Convention

Use `Command_` prefix (same as client commands):

```pawn
public plugin_init() {
  // Works from both client console (with admin check) and server console
  register_concmd("amx_heal", "Command_Heal", ADMIN_SLAY, "<target> [amount] - heal player");
  register_concmd("amx_restart", "Command_Restart", ADMIN_RCON, "- restart round");
}

public Command_Heal(const pPlayer, const iLevel, const iCId) {
  // pPlayer is 0 when executed from server console
  if (pPlayer && !cmd_access(pPlayer, iLevel, iCId, 2)) return PLUGIN_HANDLED;
  
  static szTarget[32];
  read_argv(1, szTarget, charsmax(szTarget));
  
  new pTarget = cmd_target(pPlayer, szTarget, CMDTARGET_ALLOW_SELF);
  if (!pTarget) return PLUGIN_HANDLED;
  
  new iAmount = read_argc() > 2 ? read_argv_int(2) : 100;
  
  set_user_health(pTarget, min(get_user_health(pTarget) + iAmount, 100));
  
  // Log admin action
  if (pPlayer) {
    console_print(pPlayer, "[MyMod] Healed %s for %d HP", szTarget, iAmount);
  } else {
    server_print("[MyMod] Healed %s for %d HP", szTarget, iAmount);
  }
  
  return PLUGIN_HANDLED;
}
```

---

## client_cmd vs engclient_cmd

**Avoid `client_cmd`** - it's unreliable and can be filtered by `cl_filterstuffcmd`.

### For Server-Side Command Execution

Use `engclient_cmd` to trigger command hooks on server without sending to client:

```pawn
// Execute on server side (triggers registered command handlers)
engclient_cmd(pPlayer, "custom_command", "arg1");

// AVOID: Sends to client, may be filtered
client_cmd(pPlayer, "custom_command arg1");
```

### For Client CVar Changes

**Don't force client cvars** - notify and handle refusal gracefully:

```pawn
// Query and handle result
query_client_cvar(pPlayer, "cl_crosshair_color", "Callback_ClientCvarQuery_Crosshair");

public Callback_ClientCvarQuery_Crosshair(const pPlayer, const szCvar[], const szValue[], const szParam[]) {
  if (!equal(szValue, "255 0 0")) {
    // Option 1: Just notify
    client_print(pPlayer, print_chat, "[Notice] Custom crosshair colors are recommended.");
    
    // Option 2: Disable feature
    g_rgbPlayerFeatureEnabled[pPlayer] = false;
  }
}

// AVOID: Forcing cvars
client_cmd(pPlayer, "cl_crosshair_color ^"255 0 0^""); // May not work
```

---

## Best Practices

1. **Client command handlers use `Command_` prefix** with `const` for arguments
2. **Server command handlers use `ServerCommand_` prefix**
3. **Use `register_concmd`** for admin commands that should work from RCON too
4. **Check `pPlayer == 0`** in concmd handlers for server console execution
5. **Avoid `client_cmd`** - use `engclient_cmd` for server-side execution
6. **Don't force client cvars** - query and notify/disable features instead
7. **Return `PLUGIN_HANDLED`** to block further processing
8. **Use `cmd_access`** for admin permission checks
