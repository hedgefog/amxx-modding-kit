---
name: amxmodx-code-style
description: AMX Mod X code style, formatting, and file structure conventions.
globs: "*.sma,*.inc"
---

# Code Style

## File Header

Always start files with `#pragma semicolon 1`:

```pawn
#pragma semicolon 1
```

## Include Order

Files must follow this include structure:

```pawn
#pragma semicolon 1

// 1. AMX Mod X core includes
#include <amxmodx>
#include <amxmisc>

// 2. Engine/Game includes
#include <fakemeta>
#include <hamsandwich>
#include <reapi>
#include <engine>
#include <xs>

// 3. API/Library includes
#include <api_assets>
#include <api_custom_entities>
#include <api_custom_weapons>

// 4. Project-specific includes
#include <mymod_const>
#include <mymod>
```

## Standard Function Order

1. `plugin_precache()` - Resource precaching, class registration
2. `plugin_init()` - Plugin registration, hook registration
3. `plugin_end()` - Cleanup (free handles, etc.)
4. `plugin_natives()` - Native function registration
5. `plugin_cfg()` - Configuration loading
6. Client callbacks (`client_connect`, `client_disconnected`)
7. Native implementations
8. Hook handlers (grouped by type)
9. Class methods (`@Entity_*`, `@Weapon_*`, `@Player_*`)
10. Helper functions

## Section Comments

Use comment headers to separate logical sections:

```pawn
/*--------------------------------[ Hooks ]--------------------------------*/

public HamHook_Player_Spawn_Post(const pPlayer) {
  // ...
}

/*--------------------------------[ Methods ]--------------------------------*/

@Entity_Create(const this) {
  // ...
}

/*--------------------------------[ Tasks ]--------------------------------*/

public Task_Respawn(const iTaskId) {
  // ...
}
```

### Common Section Names

Use these consistent section names across plugins:

```pawn
// Variables & State
/*--------------------------------[ Helpers ]--------------------------------*/
/*--------------------------------[ Constants ]--------------------------------*/
/*--------------------------------[ Assets ]--------------------------------*/
/*--------------------------------[ Plugin State ]--------------------------------*/
/*--------------------------------[ Player State ]--------------------------------*/
/*--------------------------------[ Entity State ]--------------------------------*/

// Plugin Lifecycle
/*--------------------------------[ Plugin Initialization ]--------------------------------*/
/*--------------------------------[ Forwards ]--------------------------------*/
/*--------------------------------[ Commands ]--------------------------------*/
/*--------------------------------[ Hooks ]--------------------------------*/
/*--------------------------------[ Methods ]--------------------------------*/
/*--------------------------------[ Tasks ]--------------------------------*/
```

## Formatting

### Braces

Use K&R style (opening brace on same line):

```pawn
public plugin_init() {
  register_plugin("[My Mod] Example", MYMOD_VERSION, "Author");
}

if (condition) {
  // ...
} else {
  // ...
}

for (new i = 0; i < count; ++i) {
  // ...
}
```

### Single-line if statements

Allowed for simple returns/continues:

```pawn
if (!is_user_alive(pPlayer)) return HAM_IGNORED;
if (pOwner == pPlayer) continue;
if (!iTeam || iTeam == iOwnerTeam) return;
```

### Spacing

- Space after keywords: `if (`, `for (`, `while (`
- Space around operators: `a + b`, `x == y`
- No space after function names: `function_call(`
- Space after commas in parameter lists

## Plugin Registration

Pass plugin info directly to `register_plugin()` without defining macros:

```pawn
public plugin_init() {
  register_plugin("[My Mod] Component Name", MYMOD_VERSION, "Author Name");
}
```

**Core plugin exception**: The core/main plugin should be registered with just the mod name (no prefix):

```pawn
// In core.sma - use mod name only
public plugin_init() {
  register_plugin(MYMOD_TITLE, MYMOD_VERSION, "Author Name");
}
```

## Best Practices

1. **Always use `#pragma semicolon 1`** at file start
2. **Use K&R brace style** (opening brace on same line)
3. **Pass plugin info directly** to `register_plugin()` - avoid PLUGIN/VERSION/AUTHOR macros
4. **Core plugin uses mod name only** - register as "My Mod", not "[My Mod] Core"
5. **Group hooks and functions** with section comments
