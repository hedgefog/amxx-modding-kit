---
name: amxmodx-function-declarations
description: AMX Mod X function declarations, return types, @ prefix for OOP-like methods, and static variables.
globs: "*.sma,*.inc"
---

# Function Declarations

## Return Type Annotations

Specify return types for non-void functions:

```pawn
Float:GetMaxSpeed(const this) {
  return 250.0;
}

bool:CanTakeDamage(const this, const pInflictor, const pAttacker) {
  new pOwner = pev(this, pev_owner);
  if (!pOwner || !IS_PLAYER(pOwner)) return false;
  return true;
}
```

---

## @ Prefix Functions (OOP-like Methods)

The `@` prefix makes a function **public by default** in Pawn. It is used **only for OOP-like class methods** with the pattern `@{EntityName_or_EntityType}_{MethodName}`.

### Naming Pattern

```pawn
@{EntityName}_{MethodName}
@{EntityType}_{MethodName}
```

### Examples

```pawn
// Entity class methods
@Snowball_Create(const &this)
@Snowball_Think(const &this)
@Snowball_Touch(const &this, const &pTouched)
@Snowball_Kill(const &this)

// Weapon class methods
@Rifle_PrimaryAttack(const &this)
@Rifle_SecondaryAttack(const &this)
@Rifle_Reload(const &this)

// Player class methods (for player-specific entity extensions)
@Player_CameraThink(const &this)
@Player_Reset(const &this)
```

### Never Add Redundant `public` Keyword

```pawn
// CORRECT: @ prefix is already public
@Entity_Think(const &this) {
  // Function logic
}

// WRONG: Redundant public keyword
public @Entity_Think(const &this) {
  // Function logic
}
```

### Do NOT Use @ For

- Hooks (`HamHook_*`, `FMHook_*`, `Event_*`, `Message_*`)
- Callbacks (`Callback_*`, `Task_*`)
- Commands (`Command_*`, `ServerCommand_*`)
- Regular utility functions

---

## Static Variables Pattern

### Purpose

Use `static` variables in frequently called functions (Think, Touch callbacks) to avoid stack allocation overhead.

**WARNING**: Do NOT use static in potentially recursive functions.

### Compact Declaration Style

Declare and assign static variables on the same line using semicolon separator:

```pawn
// Compact single-line declaration + assignment
static Float:vecOrigin[3]; pev(this, pev_origin, vecOrigin);
static Float:flDamage; flDamage = GetEntityDamage(this);
static pOwner; pOwner = pev(this, pev_owner);
static iTeam; iTeam = pev(this, pev_team);
```

### When NOT to Use Static

- **Recursive functions** - static would retain values between recursive calls
- **Functions that need separate instances** for each call context
- Simple helper functions called rarely

---

## Best Practices

1. **Use `@` prefix only** for OOP-like class methods: `@{EntityName}_{MethodName}`
2. **Never add `public`** keyword to `@` prefixed functions
3. **Use `const` prefix** for all handle arguments (entities, structures, etc.)
4. **Use `const &this`** for "this" argument in OOP-like methods with direct calls
5. **Use static variables** in frequently called class methods
6. **Declare and assign static on same line** using semicolon separator
7. **Avoid static in recursive functions**
