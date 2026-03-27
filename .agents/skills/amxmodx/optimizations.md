---
name: amxmodx-optimizations
description: AMX Mod X performance optimization patterns and techniques.
globs: "*.sma,*.inc"
---

# Optimizations

## Minimize Native Calls

In high-load functions (think, update, per-frame hooks), **minimize native calls**:

```pawn
// CORRECT: Call get_gametime() once and reuse
@Entity_Think(const &this) {
  static Float:flGameTime; flGameTime = get_gametime();
  
  static Float:flNextAttack; flNextAttack = CE_GetMember(this, m_flNextAttack);
  if (flNextAttack > flGameTime) return;
  
  static Float:flNextMove; flNextMove = CE_GetMember(this, m_flNextMove);
  if (flNextMove > flGameTime) return;
  
  CE_SetMember(this, m_flNextAttack, flGameTime + 1.0);
  CE_SetMember(this, m_flNextMove, flGameTime + 0.5);
}

// AVOID: Multiple get_gametime() calls
@Entity_Think(const &this) {
  if (CE_GetMember(this, m_flNextAttack) > get_gametime()) return;
  if (CE_GetMember(this, m_flNextMove) > get_gametime()) return;
  CE_SetMember(this, m_flNextAttack, get_gametime() + 1.0);
  CE_SetMember(this, m_flNextMove, get_gametime() + 0.5);
}
```

---

## Cache Game Time Globally

If your plugin calls `get_gametime()` in hooks like AddToFullPack, PreThink, PostThink, etc., cache it in a global variable from `server_frame()` forward:

```pawn
new Float:g_flGameTime = 0.0;

public server_frame() {
  g_flGameTime = get_gametime();
}

@Entity_Think(const &this) {
  if (Float:CE_GetMember(this, m_flNextAttack) > g_flGameTime) return;
  if (Float:CE_GetMember(this, m_flNextMove) > g_flGameTime) return;
  
  CE_SetMember(this, m_flNextAttack, g_flGameTime + 1.0);
  CE_SetMember(this, m_flNextMove, g_flGameTime + 0.5);
}
```

---

## Dynamic Hook Registration

**Avoid global registration** of high-frequency hooks like `FM_AddToFullPack`, `Ham_Player_PreThink`, `Ham_Player_PostThink`. These hooks are called multiple times per frame (per player/entity), severely impacting performance.

**Register hooks dynamically** based on whether relevant entities exist:

```pawn
new g_iActiveEntitiesNum = 0;
new g_pfwfmAddToFullPack = 0;
new HamHook:g_pfwhamPlayerPreThink = HamHook:0;

OnEntityCreated(const pEntity) {
  g_iActiveEntitiesNum++;
  UpdateHooks();
}

OnEntityRemoved(const pEntity) {
  g_iActiveEntitiesNum--;
  UpdateHooks();
}

UpdateHooks() {
  if (g_iActiveEntitiesNum) {
    if (!g_pfwfmAddToFullPack) {
      g_pfwfmAddToFullPack = register_forward(FM_AddToFullPack, "FMHook_AddToFullPack_Post", 1);
    }
    
    if (!g_pfwhamPlayerPreThink) {
      g_pfwhamPlayerPreThink = RegisterHamPlayer(Ham_Player_PreThink, "HamHook_Player_PreThink");
    } else {
      EnableHamForward(g_pfwhamPlayerPreThink);
    }
  } else {    
    if (g_pfwfmAddToFullPack) {
      unregister_forward(FM_AddToFullPack, g_pfwfmAddToFullPack, 1);
      g_pfwfmAddToFullPack = 0;
    }
    
    if (g_pfwhamPlayerPreThink) {
      DisableHamForward(g_pfwhamPlayerPreThink);
    }
  }
}
```

---

## Vector Initialization

Use `xs_vec_set` instead of `xs_vec_copy` for vector initialization:

```pawn
// CORRECT: Use xs_vec_set
static Float:vecTemp[3];
xs_vec_set(vecTemp, 0.0, 0.0, 0.0);
xs_vec_set(vecTemp, 100.0, 200.0, 50.0);

// AVOID: xs_vec_copy with literal array
static Float:vecTemp[3];
xs_vec_copy(Float:{0.0, 0.0, 0.0}, vecTemp);
```

---

## Trace Handle Rule

**IMPORTANT**: Always use a single global trace handle (`g_pTrace`) rather than creating new trace structures every time:

```pawn
new g_pTrace;

public plugin_precache() {
  g_pTrace = create_tr2();
}

public plugin_end() {
  free_tr2(g_pTrace);
}
```

---

## Model Index Caching

**Don't store model index in separate global variable** - it creates inconsistency when renaming resources and increases human error. Instead, use static caching inside functions:

```pawn
// CORRECT: Store path globally, cache index with static inside function
new g_szModel[MAX_RESOURCE_PATH_LENGTH];

public plugin_precache() {
  copy(g_szModel, charsmax(g_szModel), "models/mymod/projectile.mdl");
  precache_model(g_szModel);
}

SpawnProjectile(const Float:vecOrigin[3]) {
  // Cache index locally - everything related to model is in one place
  static iModelIndex = 0;
  if (!iModelIndex) {
    iModelIndex = engfunc(EngFunc_ModelIndex, g_szModel);
  }
  
  new pEntity = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "info_target"));
  engfunc(EngFunc_SetModel, pEntity, g_szModel);
  // ...
}

// AVOID: Separate global for index - inconsistency risk when renaming
new g_szModel[MAX_RESOURCE_PATH_LENGTH];
new g_iModelIndex; // Extra variable to maintain, easy to forget when updating path
```

**Why this approach:**
- When you rename/update model path, everything is in one place
- No risk of forgetting to update the index variable name
- Static caching still provides performance benefit (native called only once)
- Model indices don't change during map lifetime

---

## Cached Values Pattern

**Cache expensive values** with static variables inside functions:

```pawn
// Stock function - static initialization keeps it self-contained
stock UTIL_ShowBloodEffect(const pEntity) {
  static iBloodModelIndex = 0;
  if (!iBloodModelIndex) {
    iBloodModelIndex = precache_model("sprites/blood.spr");
  }
  
  // Use iBloodModelIndex...
}
```

**Prefer global variables** when value is reused across multiple functions:

```pawn
// Global scope - when used in multiple places
new gmsgStatusIcon;
new gmsgScreenShake;

public plugin_init() {
  gmsgStatusIcon = get_user_msgid("StatusIcon");
  gmsgScreenShake = get_user_msgid("ScreenShake");
}

// Now can be used in any function without additional lookup
ShowStatusIcon(const pPlayer) {
  message_begin(MSG_ONE, gmsgStatusIcon, _, pPlayer);
  // ...
}

HideStatusIcon(const pPlayer) {
  message_begin(MSG_ONE, gmsgStatusIcon, _, pPlayer);
  // ...
}
```

---

## Best Practices

1. **Minimize native calls in hot paths** - call `get_gametime()` once per function
2. **Use single global `g_pTrace`** - never create trace handles per-call
3. **Register high-frequency hooks dynamically** - `FM_AddToFullPack`, `Ham_Player_PreThink` etc.
4. **Use `xs_vec_set`** instead of `xs_vec_copy` for vector initialization
5. **Use `bind_pcvar_*`** instead of `get_pcvar_*` for cvar access
6. **Cache game time globally** when using in multiple per-frame hooks
7. **Cache model index with static** inside function, not in separate global variable
8. **Use global variables** for cached values reused across multiple functions
