---
name: amxmodx-basics
description: Helps with AMX Mod X (Pawn) coding conventions and best practices.
---

# AMX Mod X (Pawn) Code Style Guide

This document provides an overview of coding conventions for AMX Mod X projects. Each topic is covered in detail in its own file.

## Core Conventions

| Category | Description |
|----------|-------------|
| [Basics](mdc:basics.md) | Syntax, basics |
| [Code Style](mdc:code-style.md) | File structure, formatting, braces, spacing, plugin registration |
| [Naming Conventions](mdc:naming-conventions.md) | Hungarian notation, variable prefixes, naming patterns |
| [Constants & Enums](mdc:constants-enums.md) | Define constants, enums, TASKID constants |
| [Macros](mdc:macros.md) | Common macros, IS_PLAYER, patterns to avoid |
| [Function Declarations](mdc:function-declarations.md) | Return types, @ prefix, static variables |
| [Validations](mdc:validations.md) | FM_NULLENT, entity checks, player validation, early returns |

## API Patterns

| Category | Description |
|----------|-------------|
| [Hooks](mdc:hooks.md) | Ham, FakeMeta, ReAPI, Event, Message hooks and handles |
| [Forwards](mdc:forwards.md) | CreateMultiForward, ExecuteForward, pre/post patterns |
| [Natives](mdc:natives.md) | Native registration and implementation |
| [Callbacks](mdc:callbacks.md) | Tasks, SQL queries, CVar queries |
| [Menus](mdc:menus.md) | Menu creation, callbacks, and patterns |
| [Commands](mdc:commands.md) | Client, server, and console commands |
| [CVars](mdc:cvars.md) | CVar creation, binding, and change hooks |

## Performance & Data

| Category | Description |
|----------|-------------|
| [Optimizations](mdc:optimizations.md) | Native call reduction, dynamic hooks, model path caching |
| [Data Structures](mdc:data-structures.md) | Arrays, Tries, entity access, strings |

---

## Custom API Reference

For project-specific APIs, see dedicated skill files:

| API | Description |
|-----|-------------|
| [assets](mdc:.agent/skills/assets/SKILL.md) | Asset management from JSON configs |
| [custom-entities](mdc:.agent/skills/custom-entities/SKILL.md) | OOP-style custom entities |
| [custom-events](mdc:.agent/skills/custom-events/SKILL.md) | Pub/sub event system |
| [custom-weapons](mdc:.agent/skills/custom-weapons/SKILL.md) | Custom weapon framework |
| [entity-force](mdc:.agent/skills/entity-force/SKILL.md) | Physics force application |
| [entity-grab](mdc:.agent/skills/entity-grab/SKILL.md) | Entity grab and carry |
| [player-camera](mdc:.agent/skills/player-camera/SKILL.md) | Custom camera views |
| [player-model](mdc:.agent/skills/player-model/SKILL.md) | Custom player models |
| [player-music](mdc:.agent/skills/player-music/SKILL.md) | MP3 music playback |
| [player-roles](mdc:.agent/skills/player-roles/SKILL.md) | Player role management |
| [rounds](mdc:.agent/skills/rounds/SKILL.md) | Round management |
| [shops](mdc:.agent/skills/shops/SKILL.md) | In-game shop system |
| [states](mdc:.agent/skills/states/SKILL.md) | State machine implementation |

For large project organization with namespace constants, see [amxx-modding-kit-project](mdc:.agent/skills/amxx-modding-kit-project/SKILL.md).

---

## Quick Reference: Best Practices Summary

### Code Style
1. Always use `#pragma semicolon 1` at file start
2. Use Hungarian notation for all variable names
3. Use K&R brace style (opening brace on same line)
4. Pass plugin info directly to `register_plugin()` - avoid macros
5. Group hooks and functions with section comments

### Constants & Validation
6. Use `FM_NULLENT` instead of `-1` or `0` for null entity checks
7. Always check `FM_NULLENT` after entity creation before processing
8. Return `FM_NULLENT` not `0` for failures - `0` is worldspawn
9. Return early for invalid conditions

### Macros
10. Don't redefine macros - use shared definitions from includes
11. Never use `MACRO()_Suffix` patterns in code - only in macro definitions

### Function Declarations
12. Use `@` prefix only for OOP-like methods: `@{EntityName}_{MethodName}`
13. Never add `public` keyword to `@` prefixed functions
14. Use `const` prefix for all handle arguments
15. Use `const &this` for "this" argument in OOP-like methods
16. Use static variables in frequently called class methods
17. Declare and assign static on same line using semicolon separator

### Hooks
18. Ham hooks must return `HAM_*` constants
19. FakeMeta hooks must return `FMRES_*` constants
20. ReAPI hooks must return `HC_*` constants
21. Message hooks must return `PLUGIN_*` constants
22. Hook handle variables: `g_pfwham` (Ham), `g_pfwfm` (FakeMeta)
23. Inline `get_user_msgid` when only used once in `register_message`

### Forwards
24. Forward names use `LibraryName_OnSomething` - not `Fw_` prefix
25. Multi-forward handle variables use `g_pfw` prefix

### Natives & Callbacks
26. Native implementations use `Native_` prefix with `const` for arguments
27. Task callbacks use `Task_` prefix with offset in task ID
28. SQL callbacks use `Callback_SQLQuery_{Name}` prefix

### Menus
29. Menu callbacks use `Callback_Menu_{Name}` prefix
30. Use enum for menu items to avoid index mistakes
31. Destroy dynamic menus in callback with `menu_destroy`

### Commands & CVars
32. Command handlers use `Command_` prefix, server commands use `ServerCommand_`
33. Use `register_concmd` for admin commands that should work from RCON
34. Avoid `client_cmd` - use `engclient_cmd` for server-side execution
35. Use `create_cvar` instead of deprecated `register_cvar`
36. Use `bind_pcvar_*` instead of `get_pcvar_*` for cvar access

### Optimizations
37. Minimize native calls in hot paths
38. Use single global `g_pTrace` - never create trace handles per-call
39. Register high-frequency hooks dynamically
40. Use `xs_vec_set` instead of `xs_vec_copy` for vector initialization
41. Cache model index with static inside function, not in separate global

### Naming Conventions
42. Sound arrays use `g_rgsz` prefix with `g_i*Num` counter
43. Message IDs use `gmsg` prefix (without underscore)
44. Player arrays use `g_rg*[MAX_PLAYERS + 1]` with type prefix
45. Don't use `id` for players - use `pPlayer`
46. Don't use `index` for entities - use `pEntity`

### Data Structures
47. Always free dynamic handles - `ArrayDestroy`, `TrieDestroy` in `plugin_end()`