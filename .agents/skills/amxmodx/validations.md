---
name: amxmodx-validations
description: AMX Mod X validation patterns for entities, players, FM_NULLENT, and early returns.
globs: "*.sma,*.inc"
---

# Validations

## FM_NULLENT Constant

**IMPORTANT**: Always use `FM_NULLENT` instead of `-1` or `0` for null entity checks and returns.

### Comparison Style

```pawn
// ✅ CORRECT
if (pEntity == FM_NULLENT) return;
if (pProjectile == FM_NULLENT) return FM_NULLENT;

// ❌ AVOID
if (pEntity == -1) return;
if (pEntity == 0) return; // 0 is worldspawn, not null!
```

### Return FM_NULLENT for Failures

**Return `FM_NULLENT` (-1)** instead of `0` for unsuccessful entity results. Returning `0` is dangerous because entity index `0` is worldspawn - modifying it causes crashes, bugs, and memory corruption:

```pawn
// ✅ CORRECT: Return FM_NULLENT for failure
CreateProjectile(const pOwner) {
  new pEntity = CE_Create(ENTITY_NAME, vecOrigin);
  if (pEntity == FM_NULLENT) return FM_NULLENT; // Safe failure indicator
  
  return pEntity;
}

// ❌ DANGEROUS: Returning 0 means worldspawn!
CreateProjectile(const pOwner) {
  new pEntity = CE_Create(ENTITY_NAME, vecOrigin);
  if (pEntity == FM_NULLENT) return 0; // Wrong! Caller may modify worldspawn!
  
  return pEntity;
}
```

---

## Check Entity Returns

**Always check for `FM_NULLENT`** before processing entities returned from creation functions:

```pawn
// ✅ CORRECT: Check before processing
new pEntity = CE_Create(ENTITY_NAME, vecOrigin);
if (pEntity == FM_NULLENT) return FM_NULLENT;

CE_SetMember(pEntity, m_flDamage, 100.0);
dllfunc(DLLFunc_Spawn, pEntity);
```

```pawn
// ❌ DANGEROUS: No check before processing
new pEntity = CE_Create(ENTITY_NAME, vecOrigin);
CE_SetMember(pEntity, m_flDamage, 100.0); // May corrupt worldspawn if creation failed!
```

---

## Player Validation

```pawn
// Check player state
if (!is_user_connected(pPlayer)) return;
if (!is_user_alive(pPlayer)) return;
if (is_user_bot(pPlayer)) return;
```

---

## Early Return Pattern

```pawn
ProcessEntity(const this) {
  if (pev(this, pev_waterlevel) > 1) {
    ExecuteHamB(Ham_TakeDamage, this, 0, 0, 1.0, DMG_GENERIC);
    return;
  }

  if (pev(this, pev_deadflag) != DEAD_NO) return;

  // Main logic...
}
```

---

## Loop Over Players

```pawn
for (new pPlayer = 1; pPlayer <= MaxClients; ++pPlayer) {
  if (!is_user_connected(pPlayer)) continue;
  if (!is_user_alive(pPlayer)) continue;
  
  // Process player...
}
```

---

## Entity Existence Check

```pawn
// Check if entity exists and is valid
if (!pev_valid(pEntity)) return;

// For players specifically
if (!IS_PLAYER(pEntity)) return;
if (!is_user_connected(pEntity)) return;
```

---

## Best Practices

1. **Use `FM_NULLENT`** instead of `-1` or `0` for null entity checks
2. **Always check `FM_NULLENT`** after entity creation before processing
3. **Return `FM_NULLENT` not `0` for failures** - `0` is worldspawn, causes corruption
4. **Return early** for invalid conditions
5. **Check `is_user_connected`** before `is_user_alive` in player loops
6. **Use `pev_valid`** to check entity existence
