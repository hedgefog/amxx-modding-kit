---
name: pawn-programming
description: Comprehensive guide for Pawn scripting language used in AMX Mod X and SourceMod. Use when writing, reviewing, or debugging Pawn code (.sma files), creating game server plugins, working with Half-Life/Counter-Strike mods, or when the user asks about Pawn syntax, AMX Mod X APIs, or game scripting. Covers language syntax, type system, functions, arrays, strings, control flow, preprocessor directives, and AMX Mod X plugin development patterns.
---

# Pawn Programming Language Guide

Pawn is an embeddable, almost typeless scripting language compiled to bytecode for a virtual machine. Originally named "Small" to emphasize its minimal specification. Used primarily in AMX Mod X (Half-Life/CS 1.6) and SourceMod (Source engine games).

## Core Language Characteristics

- **Single data type**: The "cell" (4 bytes on 32-bit, 8 bytes on 64-bit)
- **Tag system**: Weak static typing via tags (`Float:`, `bool:`, custom tags)
- **No heap allocation**: All variables on stack or data section (no GC needed)
- **Procedural only**: No OOP, lambdas, or nested functions
- **C-like syntax**: Similar to C but simplified

## Hungarian Notation

Use Hungarian notation prefixes for all variable names:

| Prefix | Type | Example |
|--------|------|---------|
| `g_` | Global variable | `g_pTrace`, `g_szModel` |
| `p` | Entity/Player pointer | `pPlayer`, `pEntity`, `pOwner` |
| `sz` | String (zero-terminated) | `szModel`, `szClassName` |
| `fl` | Float | `flDamage`, `flGameTime` |
| `i` | Integer | `iSlot`, `iTeam` |
| `b` | Boolean | `bActive`, `bEnabled` |
| `vec` | Vector (Float array[3]) | `vecOrigin`, `vecAngles` |
| `rg` | Array (range) | `g_rgiPlayerData`, `g_rgflDeathTime` |
| `gmsg` | Message IDs | `gmsgStatusIcon`, `gmsgScreenFade` |
| `g_pCvar` | CVar pointers | `g_pCvarEnabled` |
| `g_pfw` | Forward handles | `g_pfwPlayerSpawned` |

### Callback Naming

| Type | Prefix | Example |
|------|--------|---------|
| Task callback | `Task_` | `Task_Respawn` |
| Command handler | `Command_` | `Command_DropAmmo` |
| Event handler | `Event_` | `Event_Death` |
| Ham hook | `HamHook_` | `HamHook_Player_Spawn` |
| FakeMeta hook | `FMHook_` | `FMHook_PlayerPreThink` |
| Native impl | `Native_` | `Native_IsActivated` |
| CVar query | `Callback_ClientCvarQuery_` | `Callback_ClientCvarQuery_Rate` |
| SQL query | `Callback_SQLQuery_` | `Callback_SQLQuery_LoadPlayer` |

## Variables and Types

### Declaration Syntax

```pawn
new iValue;                      // Integer, initialized to 0
new iCount = 5;                  // Integer with value
new Float:flSpeed = 250.0;       // Float tag (fl prefix)
new bool:bActive = true;         // Boolean tag (b prefix)
new rgiSlots[32];                // Array of 32 cells (rg prefix)
new Float:vecOrigin[3] = {0.0, ...}; // Vector (vec prefix)
new szName[] = "Hello";          // String (sz prefix)
```

### Tag System

Tags provide compile-time type checking (warnings only, not enforced):

```pawn
new Float:flSpeed = 250.0;         // Float tag
new iCell = _:flSpeed;             // Cast Float to untagged cell
new Float:flBack = Float:iCell;    // Cast back to Float

// Custom tags
enum PlayerTeam { PlayerTeam_T, PlayerTeam_CT, PlayerTeam_Spec };
new PlayerTeam:iTeam = PlayerTeam_CT;
```

### Constants

```pawn
const MAX_PLAYERS = 32;           // Compile-time constant
new const g_szPluginName[] = "My Plugin";  // Constant string
#define ARRAY_SIZE 64             // Preprocessor constant
```

### Static Variables

Static variables persist across function calls but remain scoped:

```pawn
CountCalls() {
  static iCalls = 0;    // Initialized once, value persists
  iCalls++;
  return iCalls;
}
// First call returns 1, second returns 2, etc.
```

## Arrays and Strings

### Arrays

```pawn
new rgData[10];                  // 10 cells, indexed 0-9
new rgiValues[4] = {1, 2, 3, 4}; // Initialized array
new rgiItems[] = {1, 2, 3};      // Size inferred (3)
rgiItems[0] = 5;                 // Access element

// 2D arrays
new rgiMatrix[3][3];              // 3x3 matrix
new g_rgszNames[32][64];          // 32 strings of max 63 chars + null
```

### Strings

Strings are null-terminated character arrays:

```pawn
new szBuffer[64] = "Hello";       // 64-char buffer with "Hello"
new szText[] = "Hello";           // Size 6 (5 chars + null terminator)

// String manipulation (use natives, never direct assignment)
copy(szDest, charsmax(szDest), szSource);       // AMX Mod X
strcopy(szDest, sizeof(szDest), szSource);      // SourceMod
format(szBuffer, charsmax(szBuffer), "Player: %s", szName);
formatex(szBuffer, charsmax(szBuffer), "Fast: %d", iNum);  // No overlap check

// String comparison
if (equal(szStr1, szStr2)) { }               // Case-sensitive
if (equali(szStr1, szStr2)) { }              // Case-insensitive
```

**Critical**: Never assign strings directly!

```pawn
// WRONG - causes buffer overflow or compile error
szBuffer = "New value"
szBuffer[0] = "text"

// CORRECT
copy(szBuffer, charsmax(szBuffer), "New value");
```

## Functions

### Function Types

```pawn
// Regular function (private, internal use)
Add(const iA, const iB) {
  return iA + iB;
}

// Public function (exposed to VM, hooks, other plugins)
public client_connect(const pPlayer) {
  // Called by engine
  return PLUGIN_CONTINUE;
}

// Stock function (compiled only if used, for includes)
stock Helper() {
  return 1;
}

// Native function (provided by module, declared in .inc)
native get_user_name(const pPlayer, szName[], const iMaxLen);

// Forward (callback declaration)
forward OnPlayerSpawn(const pPlayer);
```

### Parameters

```pawn
// By value (copied)
Func(iValue) { }

// By reference (modifiable)
Func(&iValue) { iValue = 5; }

// Array (always by reference)
Func(rgData[], const iSize) { }

// Const array (read-only reference)
Func(const rgData[]) { }

// Default values (not allowed in public functions)
Func(iValue = 10, szText[] = "default") { }

// Tagged parameters
Func(const Float:flSpeed, const bool:bActive) { }

// Variadic arguments
Func(const szFmt[], any:...) {
  new iArgs = numargs();
  new iVal = getarg(1);        // Get argument at index 1
  setarg(2, iNewVal);          // Set argument at index 2
}
```

### Return Values

```pawn
// Return untagged
Calculate() {
  return 42;
}

// Return tagged
Float:GetSpeed() {
  return 250.0;
}

// Return bool
bool:IsValidPlayer(const pPlayer) {
  return (pPlayer >= 1 && pPlayer <= MaxClients);
}
```

## Control Flow

### Conditionals

```pawn
// If-else (K&R brace style)
if (bCondition) {
  // code
} else if (bOther) {
  // code
} else {
  // code
}

// Single-line allowed for simple returns
if (!is_user_alive(pPlayer)) return HAM_IGNORED;

// Switch (no fall-through, more efficient than if-else chain)
switch (iValue) {
  case 1: { }
  case 2, 3, 4: { }           // Multiple values
  case 5..10: { }             // Range
  default: { }
}
```

### Loops

```pawn
// For loop
for (new i = 0; i < iSize; ++i) {
  // code
}

// While loop
while (bCondition) {
  // code
}

// Do-while
do {
  // code
} while (bCondition);

// Loop control
break;                          // Exit loop
continue;                       // Next iteration
```

## Operators

### Arithmetic
`+`, `-`, `*`, `/`, `%` (modulo)

### Comparison
`==`, `!=`, `<`, `>`, `<=`, `>=`

### Logical
`&&` (and), `||` (or), `!` (not)

### Bitwise
`&` (and), `|` (or), `^` (xor), `~` (not), `<<` (left shift), `>>` (right shift)

### Assignment Shortcuts
`+=`, `-=`, `*=`, `/=`, `%=`, `&=`, `|=`, `^=`, `<<=`, `>>=`
`++`, `--` (pre/post increment/decrement)

## Preprocessor Directives

```pawn
#pragma semicolon 1              // ALWAYS at file start

#include <amxmodx>               // Include file
#include "local.inc"             // Local include

#define MAX_VALUE 100            // Simple constant
#define SQR(%1) ((%1)*(%1))      // Macro with parameter
#define IS_PLAYER(%1) (%1 >= 1 && %1 <= MaxClients)  // Use >= 1, not > 0

#if defined CONDITION
  // Conditional compilation
#else
  // Alternative
#endif

#pragma dynamic 16384            // Stack size (cells)
#pragma ctrlchar '\'             // Escape character (default '^')
```

## AMX Mod X Plugin Structure

### Basic Plugin Template

```pawn
#pragma semicolon 1

#include <amxmodx>
#include <amxmisc>

#define PLUGIN_VERSION "1.0"

/*--------------------------------[ Plugin Initialization ]--------------------------------*/

public plugin_init() {
  register_plugin("Plugin Name", PLUGIN_VERSION, "Author");
  
  // Register commands, events, etc.
  register_clcmd("say /menu", "Command_Menu");
  register_event("DeathMsg", "Event_Death", "a");
  register_forward(FM_PlayerPreThink, "FMHook_PlayerPreThink");
}

public plugin_cfg() {
  // Called after plugin_init, configs loaded
}

public plugin_end() {
  // Cleanup on map change/server shutdown
}
```

### Common Callbacks

```pawn
// Client events
public client_connect(pPlayer) { }
public client_putinserver(pPlayer) { }
public client_disconnected(pPlayer) { }
public client_command(pPlayer) { return PLUGIN_CONTINUE; }

// Return values
PLUGIN_CONTINUE     // Allow other plugins to handle
PLUGIN_HANDLED      // Stop processing, event handled
PLUGIN_HANDLED_MAIN // Stop and suppress default behavior
```

### Struct-like Enums

```pawn
enum PlayerData {
  PlayerData_Kills,
  PlayerData_Deaths,
  Float:PlayerData_Speed,
  PlayerData_Name[32]
};

new g_rgPlayerData[MAX_PLAYERS + 1][PlayerData];

// Usage
g_rgPlayerData[pPlayer][PlayerData_Kills] = 10;
g_rgPlayerData[pPlayer][PlayerData_Speed] = 250.0;
copy(g_rgPlayerData[pPlayer][PlayerData_Name], charsmax(g_rgPlayerData[][PlayerData_Name]), "Player");
```

## Best Practices

### Performance

1. **Cache array indices**: Don't re-index in loops
   ```pawn
   // Bad
   for (new i = 0; i < iNum; ++i)
     Process(rgPlayers[i]), Check(rgPlayers[i]);
   
   // Good
   for (new i = 0; i < iNum; ++i) {
     new pPlayer = rgPlayers[i];
     Process(pPlayer);
     Check(pPlayer);
   }
   ```

2. **Use static for frequently called functions**: Avoid repeated allocation
   ```pawn
   public server_frame() {
     static szBuffer[256]; szBuffer[0] = EOS;  // Compact style
     static Float:vecOrigin[3]; pev(pEntity, pev_origin, vecOrigin);
   }
   ```

3. **Cache function results**: Don't call same function multiple times
   ```pawn
   new iTeam = get_user_team(pPlayer);
   if (iTeam == 1) { } else if (iTeam == 2) { }
   ```

4. **Use switch over if-else chains**: Generates faster case tables

5. **Use formatex over format**: When output buffer isn't also input

6. **Use cvar pointers**: `get_pcvar_num()` instead of `get_cvar_num()`

### Code Organization

- Always use `#pragma semicolon 1` at file start
- Use section comments: `/*--------------------------------[ Section ]--------------------------------*/`
- Group related functions together
- Use `stock` only in include files
- Use Hungarian notation (g_, p, sz, fl, i, b, vec, rg)
- Use constants instead of magic numbers

### Memory Safety

- Always check array bounds
- Use `charsmax()` for string operations (returns size - 1)
- Use `sizeof()` for array element count
- Null-terminate strings after manipulation
- Avoid buffer overflows in string operations

## Escape Sequences

Default control character is `^` (can change with `#pragma ctrlchar`):

```pawn
^n    // Newline
^t    // Tab
^"    // Quote
^^    // Literal ^
^0    // Null terminator (for strings)
```

With `#pragma ctrlchar '\'`:
```pawn
\n, \t, \", \\, \0
```

## CVARs (Console Variables)

CVARs store configurable server settings accessible from console and config files.

### Registering and Using CVARs

```pawn
// Register in plugin_init, use pointer for performance
new g_pCvarEnabled;

public plugin_init() {
  g_pCvarEnabled = register_cvar("myplugin_enabled", "1");
}

// Get/Set values using pointers (FAST - always prefer this)
new iValue = get_pcvar_num(g_pCvarEnabled);
new Float:flValue = get_pcvar_float(g_pCvarEnabled);
get_pcvar_string(g_pCvarEnabled, szBuffer, charsmax(szBuffer));

set_pcvar_num(g_pCvarEnabled, 0);
set_pcvar_float(g_pCvarEnabled, 1.5);
set_pcvar_string(g_pCvarEnabled, "value");

// Name-based access (SLOW - avoid in hot paths)
new iVal = get_cvar_num("myplugin_enabled");
```

### CVAR Flags

```pawn
register_cvar("name", "default", FCVAR_SPONLY | FCVAR_PROTECTED);

// Common flags:
FCVAR_ARCHIVE       // Save to vars.rc
FCVAR_SERVER        // Notify players on change
FCVAR_PROTECTED     // Hide value (passwords)
FCVAR_SPONLY        // Server-only, clients can't change
FCVAR_UNLOGGED      // Don't log changes
```

### Client CVAR Query

```pawn
// Query client cvar asynchronously
query_client_cvar(pPlayer, "cl_cmdrate", "Callback_ClientCvarQuery_CmdRate");

public Callback_ClientCvarQuery_CmdRate(const pPlayer, const szCvar[], const szValue[], const szParam[]) {
  client_print(pPlayer, print_chat, "Your %s = %s", szCvar, szValue);
}
```

## Events System

### Registering Events

```pawn
// register_event(event, handler, flags, conditions...)
register_event("DeathMsg", "Event_Death", "a");           // All deaths
register_event("DeathMsg", "Event_Headshot", "a", "3!0"); // Headshots only
register_event("CurWeapon", "Event_WeaponChange", "be", "1=1"); // Weapon switch

// Flags:
// "a" - global event
// "b" - specified player
// "c" - send once when repeated
// "d" - call for dead players
// "e" - call for alive players

// Conditions: "param=value", "param>value", "param!value", "param&substring"
```

### Reading Event Data

```pawn
public Event_Death() {
  new pKiller = read_data(1);   // Killer ID
  new pVictim = read_data(2);   // Victim ID
  new bHeadshot = read_data(3); // Headshot flag
  
  new szWeapon[32];
  read_data(4, szWeapon, charsmax(szWeapon));  // Weapon name (string)
}
```

## Client Messages

Messages send data from server to client for HUD updates, effects, etc.

### Message Structure

```pawn
// Cache message ID in plugin_init for performance (gmsg prefix, no underscore)
new gmsgScreenFade;

public plugin_init() {
  gmsgScreenFade = get_user_msgid("ScreenFade");
}

// Send message
message_begin(MSG_ONE, gmsgScreenFade, _, pPlayer);
write_short(1<<12);       // Duration (1 second)
write_short(1<<12);       // Hold time
write_short(FFADE_IN);    // Fade type
write_byte(255);          // Red
write_byte(0);            // Green
write_byte(0);            // Blue
write_byte(100);          // Alpha
message_end();
```

### Message Destinations

```pawn
MSG_BROADCAST        // All clients (unreliable)
MSG_ONE              // Single client (reliable)
MSG_ALL              // All clients (reliable)
MSG_ONE_UNRELIABLE   // Single client (unreliable, preferred)
MSG_SPEC             // Spectators only
```

### Temp Entities (Visual Effects)

```pawn
new g_iBeamSprite;

public plugin_precache() {
  g_iBeamSprite = precache_model("sprites/laserbeam.spr");
}

// Create beam between two points
message_begin(MSG_BROADCAST, SVC_TEMPENTITY);
write_byte(TE_BEAMPOINTS);
write_coord(floatround(vecStart[0])); write_coord(floatround(vecStart[1])); write_coord(floatround(vecStart[2]));
write_coord(floatround(vecEnd[0])); write_coord(floatround(vecEnd[1])); write_coord(floatround(vecEnd[2]));
write_short(g_iBeamSprite);  // Sprite
write_byte(1);               // Start frame
write_byte(10);              // Frame rate
write_byte(10);              // Life (0.1s units)
write_byte(10);              // Width
write_byte(0);               // Noise
write_byte(255);             // R
write_byte(255);             // G
write_byte(255);             // B
write_byte(200);             // Brightness
write_byte(0);               // Scroll speed
message_end();
```

## File Operations

### Simple File API (Line-based)

```pawn
// Write line to file (-1 = append)
write_file(szFilePath, "content", -1);

// Read specific line (0-indexed)
new szBuffer[256], iLength;
read_file(szFilePath, iLineNum, szBuffer, charsmax(szBuffer), iLength);

// Get file info
new iLines = file_size(szFilePath, 1);  // 0=bytes, 1=lines, 2=has newline at end
```

### Advanced File API (Stream-based, faster)

```pawn
// Open modes: "r"=read, "w"=write, "a"=append, add "+"=read+write, "b"=binary
new pFile = fopen(szFilePath, "r");
if (pFile) {
  new szBuffer[256];
  while (fgets(pFile, szBuffer, charsmax(szBuffer))) {
      // Process line (includes newline character)
  }
  fclose(pFile);
}

// Writing
new pFile = fopen(szFilePath, "a+");  // Create if not exists, append
if (pFile) {
  fputs(pFile, "Line content^n");
  fprintf(pFile, "Formatted: %d^n", iValue);  // Like format() but to file
  fclose(pFile);
}

// Binary I/O for structured data
fwrite_raw(pFile, rgData, sizeof(rgData), BLOCK_INT);
fread_raw(pFile, rgData, sizeof(rgData), BLOCK_INT);

// Cursor control
fseek(pFile, 0, SEEK_SET);   // Beginning
fseek(pFile, 0, SEEK_END);   // End
rewind(pFile);               // Reset to start
new iPos = ftell(pFile);     // Get position
```

## Dynamic Natives (Plugin-to-Plugin API)

Create natives in Pawn plugins instead of C++ modules.

### Provider Plugin

```pawn
public plugin_natives() {
  register_library("mylib");
  register_native("MyLib_DoSomething", "Native_DoSomething");
}

// Handler receives (plugin_id, num_params)
public Native_DoSomething(const iPlugin, const iParams) {
  if (iParams != 2) return 0;
  
  new pPlayer = get_param(1);
  new iValue = get_param(2);
  
  // For strings/arrays
  new szBuffer[64]; get_string(1, szBuffer, charsmax(szBuffer));
  
  // Set output string
  set_string(2, "result", charsmax(szBuffer));
  
  return 1;
}
```

### Include File (mylib.inc)

```pawn
#if defined _mylib_included
  #endinput
#endif
#define _mylib_included

#pragma reqlib "mylib"

native MyLib_DoSomething(const pPlayer, const iValue);
```

### Consumer Plugin

```pawn
#pragma semicolon 1

#include <amxmodx>
#include <mylib>

SomeFunction() {
  MyLib_DoSomething(pPlayer, 100);  // Calls the dynamic native
}
```

## XVars (Cross-Plugin Variables)

XVars are public variables accessible across plugins - faster than dynamic natives for simple variable sharing, more secure than CVARs (can't be changed from console).

### Creating XVars

```pawn
// Must be global (outside functions) and use 'public' instead of 'new'
public g_iExampleVar;
public bool:g_bExampleBool = true;
public Float:g_flExampleFloat = 3.14;

// Inside the creating plugin, use like normal variables
g_iExampleVar = 10;
if (g_bExampleBool) { }
```

**Limitations**: Only cells (int, float, bool) supported. NO arrays or strings.

### Accessing from Other Plugins

```pawn
new g_pxvExampleVar;  // Store XVar pointer (pxv prefix)

public plugin_init() {
  g_pxvExampleVar = get_xvar_id("g_iExampleVar");
  
  if (g_pxvExampleVar == -1) {
      set_fail_state("XVar not found: g_iExampleVar");
  }
  
  // Or just check existence
  if (!xvar_exists("g_iExampleVar")) {
      set_fail_state("XVar not found");
  }
}

// Get values
new iVal = get_xvar_num(g_pxvExampleVar);
new bool:bVal = bool:get_xvar_num(g_pxvBoolVar);
new Float:flVal = get_xvar_float(g_pxvFloatVar);

// Set values
set_xvar_num(g_pxvExampleVar, 10);
set_xvar_num(g_pxvBoolVar, false);
set_xvar_float(g_pxvFloatVar, 19.6);
```

### XVar vs CVAR vs Dynamic Native

| Feature | XVar | CVAR | Dynamic Native |
|---------|------|------|----------------|
| Console access | No | Yes | No |
| Speed | Fast | Medium | Slower |
| Data types | Cells only | String-based | Any |
| Use case | Private plugin config | Server config | Complex APIs |

**Note**: If multiple plugins declare the same XVar name, only the first-loaded plugin's variable is used by `get_xvar_id()`.

## AMX Mod X Tags Reference

Common tags in AMX Mod X:

| Tag | Usage |
|-----|-------|
| `Float:` | Floating point numbers |
| `bool:` | Boolean (true/false) |
| `Handle:` | SQLX database handle |
| `Sql:` | DBI SQL connection |
| `Result:` | DBI query result |
| `Vault:` | nVault file handle |
| `Array:` | Dynamic array handle |
| `Trie:` | Trie (hash map) handle |
| `DataPack:` | Data pack handle |

### Tag Coalescence

```pawn
// Strip tag with _: (empty tag)
new iCell = _:flValue;

// Cast to specific tag
new Float:flResult = Float:iCell;

// Common with enums storing floats
enum PlayerData { Float:PlayerData_Speed };
g_rgPlayerData[pPlayer][PlayerData_Speed] = _:250.0;  // Store float in cell
new Float:flSpeed = Float:g_rgPlayerData[pPlayer][PlayerData_Speed];  // Retrieve
```

## Common Natives Reference

For detailed native documentation, consult the include files (`.inc`) in the scripting/include directory. Key includes:
- `amxmodx.inc` - Core AMX Mod X functions
- `amxmisc.inc` - Miscellaneous utilities
- `cstrike.inc` - Counter-Strike specific
- `engine.inc` - Engine functions
- `fakemeta.inc` - Fake metamod functions
- `fun.inc` - Player manipulation
- `hamsandwich.inc` - Ham (function hooking)
- `sqlx.inc` - SQL database access
- `nvault.inc` - Key-value storage
