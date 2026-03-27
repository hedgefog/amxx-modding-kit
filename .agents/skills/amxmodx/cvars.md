---
name: amxmodx-cvars
description: AMX Mod X CVar creation, binding, hooks, and management patterns.
globs: "*.sma,*.inc"
---

# CVars

## CVar Creation

**Always use `create_cvar`** instead of deprecated `register_cvar`:

```pawn
// CORRECT: Use create_cvar
new pCvar = create_cvar("mymod_damage_multiplier", "1.5");

// DEPRECATED: Never use register_cvar
register_cvar("mymod_damage", "1.5"); // Wrong! Use create_cvar
```

---

## CVar Binding (Recommended)

**Prefer `bind_pcvar_*`** over `get_pcvar_*` for frequently read cvars:

```pawn
// CORRECT: Use bind_pcvar_* to auto-update variables
new Float:g_flDamageMultiplier;
new g_iRoundTime;
new g_szMapPrefix[32];

public plugin_init() {
  // Bind cvar values directly to variables - updates automatically on cvar change
  bind_pcvar_float(create_cvar("mymod_damage_multiplier", "1.5"), g_flDamageMultiplier);
  bind_pcvar_num(create_cvar("mymod_round_time", "120"), g_iRoundTime);
  bind_pcvar_string(create_cvar("mymod_map_prefix", "zm_"), g_szMapPrefix, charsmax(g_szMapPrefix));
}

// Use bound variables directly - no native call overhead
public SomeFunction() {
  new Float:flDamage = flBaseDamage * g_flDamageMultiplier; // Direct access
}
```

```pawn
// AVOID: Expensive get_pcvar_* calls
new g_pCvarDamageMultiplier;

public plugin_init() {
  g_pCvarDamageMultiplier = create_cvar("mymod_damage_multiplier", "1.5");
}

public SomeFunction() {
  // Each get_pcvar_float call is a native call - expensive in hot paths!
  new Float:flDamage = flBaseDamage * get_pcvar_float(g_pCvarDamageMultiplier);
}
```

---

## CVar Binding Types

```pawn
// Integer binding
new g_iValue;
bind_pcvar_num(create_cvar("mymod_value", "10"), g_iValue);

// Float binding
new Float:g_flValue;
bind_pcvar_float(create_cvar("mymod_float", "1.5"), g_flValue);

// String binding
new g_szValue[64];
bind_pcvar_string(create_cvar("mymod_string", "default"), g_szValue, charsmax(g_szValue));
```

---

## CVar Hooks

Monitor cvar changes with `hook_cvar_change`:

### Naming Convention

```pawn
public CvarHook_Version(const pCvar, const szOldValue[], const szNewValue[])
public CvarHook_RoundTime(const pCvar, const szOldValue[], const szNewValue[])
```

### Example

```pawn
new g_pCvarVersion;
new Float:g_flRoundTime;

public plugin_init() {
  g_pCvarVersion = create_cvar("mymod_version", MYMOD_VERSION, FCVAR_SERVER | FCVAR_SPONLY);
  hook_cvar_change(g_pCvarVersion, "CvarHook_Version");
  
  new pCvarRoundTime = create_cvar("mymod_round_time", "120.0");
  bind_pcvar_float(pCvarRoundTime, g_flRoundTime);
  hook_cvar_change(pCvarRoundTime, "CvarHook_RoundTime");
}

// Prevent version cvar from being changed
public CvarHook_Version(const pCvar, const szOldValue[], const szNewValue[]) {
  if (!equal(szNewValue, MYMOD_VERSION)) {
    set_pcvar_string(pCvar, MYMOD_VERSION);
  }
}

// React to round time changes
public CvarHook_RoundTime(const pCvar, const szOldValue[], const szNewValue[]) {
  log_amx("Round time changed from %s to %s", szOldValue, szNewValue);
  // Note: bound variable g_flRoundTime is already updated automatically
}
```

---

## Best Practices

1. **Use `create_cvar`** instead of deprecated `register_cvar`
2. **Use `bind_pcvar_*`** instead of `get_pcvar_*` - auto-updates variables on cvar change
3. **CVar variable naming**: use `g_pCvar` prefix for pointers, bound variables use standard naming
4. **Use `hook_cvar_change`** to react to cvar changes
5. **Use `CvarHook_` prefix** for cvar change callbacks