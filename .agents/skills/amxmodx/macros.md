---
name: amxmodx-macros
description: AMX Mod X macro conventions and patterns to avoid.
globs: "*.sma,*.inc"
---

# Macros

## Common Macros

```pawn
#define IS_PLAYER(%1) (%1 >= 1 && %1 <= MaxClients)
```

**Note**: Use `>= 1` consistently (not `> 0`), even though both are equivalent.

**Important**: Don't redefine macros - if `IS_PLAYER` is in internal include, don't redefine it in plugins.

## Macro Concatenation Pattern (Never Use in Code)

**Never** use non-standard macro syntax in plugin code. Patterns like `MACRO()_Suffix`, `MACRO()()`, and `MACRO<>()` break syntax highlighting and IDE support.

> **Note**: These patterns are only valid inside other macro definitions (macro-to-macro), never in actual plugin code.

```pawn
// ❌ NEVER DO THIS IN CODE - breaks syntax highlighting
CE_SetMember(this, ENTITY(Snowball)_Member_bLemonJuice, true);
CW_CallMethod(this, WEAPON(Rifle)_Method_GetPower);
CE_SetMember(this, ENTITY_MEMBER<Snowball>(bLemonJuice), true);

// ✅ CORRECT: Use full constant names in code
CE_SetMember(this, MyMod_Entity_Snowball_Member_bLemonJuice, true);
CW_CallMethod(this, MyMod_Weapon_Rifle_Method_GetPower);
CW_CallMethod(this, METHOD(GetPower));
```

## Best Practices

1. **Don't redefine macros** - use shared definitions from internal includes
2. **Never use `MACRO()_Suffix`, `MACRO()()`, `MACRO<>()` in code** - only valid in macro definitions
3. **Use `>= 1` consistently** in player checks (not `> 0`)
