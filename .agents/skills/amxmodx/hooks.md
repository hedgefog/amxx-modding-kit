---
name: amxmodx-hooks
description: AMX Mod X hook patterns for Ham Sandwich, FakeMeta, ReAPI, Event, and Message hooks.
globs: "*.sma,*.inc"
---

# Hooks

## General Hook Rules

- Use descriptive prefixes indicating the hook type
- Add `_Post` suffix for post-hooks
- Always return appropriate constants for each hook type

## Hook Handle Variable Naming

Use type-specific prefixes for hook handle variables:

```pawn
// RegisterHam - use g_pfwham prefix
new HamHook:g_pfwhamPlayerPreThink = HamHook:0;
new HamHook:g_pfwhamPlayerPostThink = HamHook:0;

// register_forward (FakeMeta) - use g_pfwfm prefix
new g_pfwfmAddToFullPack = 0;
new g_pfwfmCheckVisibility = 0;
```

---

## Ham Sandwich Hooks

### Registration Patterns

```pawn
// RegisterHamPlayer - use named .Post parameter for clarity
RegisterHamPlayer(Ham_TakeDamage, "HamHook_Player_TakeDamage", .Post = 0);
RegisterHamPlayer(Ham_TakeDamage, "HamHook_Player_TakeDamage_Post", .Post = 1);
RegisterHamPlayer(Ham_Spawn, "HamHook_Player_Spawn_Post", .Post = 1);
RegisterHamPlayer(Ham_Killed, "HamHook_Player_Killed_Post", .Post = 1);

// RegisterHam - for entity-specific hooks
RegisterHam(Ham_TakeDamage, "func_breakable", "HamHook_Breakable_TakeDamage");
```

### Naming Convention

```pawn
public HamHook_Player_Spawn_Post(const pPlayer)
public HamHook_Player_TakeDamage(const pPlayer, const pInflictor, const pAttacker, Float:flDamage, iDamageBits)
public HamHook_Player_TakeDamage_Post(const pPlayer, const pInflictor, const pAttacker, Float:flDamage, iDamageBits)
public HamHook_Player_Killed_Post(const pPlayer)
```

### Return Values

**Ham hooks MUST return `HAM_*` constants:**

| Constant | Meaning |
|----------|---------|
| `HAM_IGNORED` | No side effects, hook did nothing meaningful |
| `HAM_HANDLED` | Hook did something (modified state, played sound, etc.) |
| `HAM_SUPERCEDE` | Block the original native call |

### Examples

```pawn
public HamHook_Player_Spawn_Post(const pPlayer) {
  if (!is_user_alive(pPlayer)) return HAM_IGNORED;

  emit_sound(pPlayer, CHAN_BODY, g_szSpawnSound, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);

  return HAM_HANDLED;
}

public HamHook_Player_TakeDamage(const pPlayer, const pInflictor, const pAttacker, Float:flDamage, iDamageBits) {
  new Float:flRatio = CalculateDamageRatio(pAttacker, pPlayer);
  SetHamParamFloat(4, flDamage * flRatio);
  return HAM_HANDLED;
}
```

---

## FakeMeta Hooks

### Naming Convention

```pawn
public FMHook_GetGameDescription()
public FMHook_CheckVisibility(const pEntity)
public FMHook_AddToFullPack(const es, const e, const pEntity, const pHost, const iHostFlags, const iPlayer, const pSet)
```

### Return Values

**FakeMeta hooks MUST return `FMRES_*` constants:**

| Constant | Meaning |
|----------|---------|
| `FMRES_IGNORED` | No side effects, hook did nothing meaningful |
| `FMRES_HANDLED` | Hook did something (modified state, etc.) |
| `FMRES_SUPERCEDE` | Block the original engine call (use with `forward_return`) |

### Examples

```pawn
public FMHook_GetGameDescription() {
  static szGameName[32];
  format(szGameName, charsmax(szGameName), "%s %s", MYMOD_TITLE, MYMOD_VERSION);
  forward_return(FMV_STRING, szGameName);

  return FMRES_SUPERCEDE;
}

public FMHook_CheckVisibility(const pEntity) {
  if (pEntity == g_pInstallationPreview) {
    forward_return(FMV_CELL, (g_iPlayerPreviewVisibilityBits & BIT(g_pCurrentPlayer & 31)) ? 1 : 0);
    return FMRES_SUPERCEDE;
  }

  return FMRES_IGNORED;
}
```

---

## ReAPI Hooks

### Registration Patterns

```pawn
// Use named .post parameter for clarity
RegisterHookChain(RG_CBasePlayer_OnSpawnEquip, "HC_Player_SpawnEquip", .post = 0);
RegisterHookChain(RG_CBasePlayer_OnSpawnEquip, "HC_Player_SpawnEquip_Post", .post = 1);
RegisterHookChain(RG_CSGameRules_RestartRound, "HC_GameRules_RestartRound", .post = 0);
```

### Naming Convention

```pawn
public HC_Player_SpawnEquip(const pPlayer)
public HC_Player_SpawnEquip_Post(const pPlayer)
public HC_CheckWinConditions()
public HC_CheckWinConditions_Post()
public HC_GameRules_RestartRound()
```

### Return Values

**ReAPI hooks return `HC_*` constants:**

| Constant | Meaning |
|----------|---------|
| `HC_CONTINUE` | Continue normal execution |
| `HC_SUPERCEDE` | Block the original call |

### Example

```pawn
public HC_Player_Jump(const pPlayer) {
  if (SomeCondition(pPlayer)) {
    return HC_SUPERCEDE;
  }

  return HC_CONTINUE;
}
```

---

## Event Hooks

### Naming Convention

```pawn
public Event_CurWeapon(const pPlayer)
public Event_DeathMsg()
public Event_HLTV()
```

### Registration

```pawn
public plugin_init() {
  // Player-specific events (pPlayer is passed as first argument)
  register_event("CurWeapon", "Event_CurWeapon", "be", "1=1");
  register_event("Health", "Event_Health", "be");
  
  // Global events (no player argument)
  register_event("DeathMsg", "Event_DeathMsg", "a");
  register_event("HLTV", "Event_HLTV", "a", "1=0", "2=0"); // New round
}

public Event_CurWeapon(const pPlayer) {
  new iWeaponId = read_data(2);
  new iAmmo = read_data(3);
  
  // Handle weapon change...
}

public Event_HLTV() {
  // New round started (freezetime begin)
}
```

### Event Flags

| Flag | Description |
|------|-------------|
| `"a"` | Global event (sent to all) |
| `"b"` | Player event (sent to single player) |
| `"e"` | Execute even if dead |

---

## Message Hooks

### Naming Convention

```pawn
public Message_SendAudio()
public Message_TextMsg()
public Message_StatusIcon()
```

### Return Values

**Message hooks return `PLUGIN_*` constants:**

| Constant | Meaning |
|----------|---------|
| `PLUGIN_CONTINUE` | Allow message to be sent |
| `PLUGIN_HANDLED` | Block the message |

### Message ID Caching

Store message IDs with `gmsg` prefix when used in multiple places:

```pawn
new gmsgStatusIcon;
new gmsgScreenShake;

public plugin_init() {
  gmsgStatusIcon = get_user_msgid("StatusIcon");
  gmsgScreenShake = get_user_msgid("ScreenShake");
}
```

If message ID is only used once (e.g., only in `register_message`), inline it:

```pawn
public plugin_init() {
  // Inline when only used for registration
  register_message(get_user_msgid("TextMsg"), "Message_TextMsg");
}
```

### Message Hook Example

```pawn
public plugin_init() {
  register_message(get_user_msgid("TextMsg"), "Message_TextMsg");
}

public Message_TextMsg() {
  static szMsg[64];
  get_msg_arg_string(2, szMsg, charsmax(szMsg));
  
  if (contain(szMsg, "#Game_will_restart") != -1) {
    return PLUGIN_HANDLED;
  }
  
  return PLUGIN_CONTINUE;
}
```

---

## Best Practices

1. **Ham hooks must return `HAM_*`** - `HAM_IGNORED`, `HAM_HANDLED`, or `HAM_SUPERCEDE`
2. **FakeMeta hooks must return `FMRES_*`** - `FMRES_IGNORED`, `FMRES_HANDLED`, or `FMRES_SUPERCEDE`
3. **ReAPI hooks must return `HC_*`** - `HC_CONTINUE` or `HC_SUPERCEDE`
4. **Message hooks must return `PLUGIN_*`** - `PLUGIN_CONTINUE` or `PLUGIN_HANDLED`
5. **Add `_Post` suffix** for post-hooks
6. **Use descriptive prefixes** indicating hook type (`HamHook_`, `FMHook_`, `HC_`, `Event_`, `Message_`)
7. **Hook handle variables**: `g_pfwham` (Ham), `g_pfwfm` (FakeMeta)
8. **Inline `get_user_msgid`** when only used once, cache with `gmsg` prefix when reused
