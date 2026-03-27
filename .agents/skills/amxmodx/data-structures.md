---
name: amxmodx-data-structures
description: AMX Mod X data structures including arrays, tries, entity access, and string operations.
globs: "*.sma,*.inc"
---

# Data Structures

## Dynamic Arrays

```pawn
// Create array
new Array:g_aPlayers = ArrayCreate(1);

// Add elements
ArrayPushCell(g_aPlayers, pPlayer);

// Get elements
new pPlayer = ArrayGetCell(g_aPlayers, iIndex);

// Iterate
for (new i = 0; i < ArraySize(g_aPlayers); ++i) {
  new pPlayer = ArrayGetCell(g_aPlayers, i);
  // Process...
}

// Destroy when done (plugin_end)
ArrayDestroy(g_aPlayers);
```

## Hash Maps (Trie)

```pawn
// Create trie
new Trie:g_tPlayerData = TrieCreate();

// Set values
TrieSetCell(g_tPlayerData, szSteamId, iValue);
TrieSetString(g_tPlayerData, szKey, szValue);

// Get values
new iValue;
if (TrieGetCell(g_tPlayerData, szSteamId, iValue)) {
  // Key exists, use iValue
}

// Check existence
if (TrieKeyExists(g_tPlayerData, szKey)) {
  // Key exists
}

// Destroy when done (plugin_end)
TrieDestroy(g_tPlayerData);
```

## Entity Data Access

```pawn
// Entity variables (pev/set_pev)
new Float:flHealth; pev(pEntity, pev_health, flHealth);
set_pev(pEntity, pev_health, 100.0);

// Entity flags
new iFlags = pev(pEntity, pev_flags);
set_pev(pEntity, pev_flags, iFlags | FL_GODMODE);

// Entity vectors
static Float:vecOrigin[3]; pev(pEntity, pev_origin, vecOrigin);
set_pev(pEntity, pev_origin, vecNewOrigin);

// Entity classname
static szClassname[32]; pev(pEntity, pev_classname, szClassname, charsmax(szClassname));

// Get string with length (no reason to use `strlen()` after, avoid it)
static szValue[32];
new iValueLen = pev(pEntity, pev_target, szValue, charsmax(szValue));
```

## Player Functions

```pawn
// Get player info
static szName[32]; get_user_name(pPlayer, szName, charsmax(szName));
new iTeam = get_user_team(pPlayer);
new iFrags = get_user_frags(pPlayer);

// Player position
static Float:vecOrigin[3]; pev(pPlayer, pev_origin, vecOrigin);
engfunc(EngFunc_SetOrigin, pPlayer, vecNewOrigin);
```

## String Operations

```pawn
// Format strings
formatex(szBuffer, charsmax(szBuffer), "Player: %s, Score: %d", szName, iScore);

// Copy strings
copy(szDest, charsmax(szDest), szSource);

// Compare strings
if (equal(szString1, szString2)) { /* strings match */ }
if (equali(szString1, szString2)) { /* case-insensitive */ }

// Find substring
new iPos = contain(szSource, szSubstring);
if (iPos != -1) { /* found at position iPos */ }

// Replace
replace_string(szBuffer, charsmax(szBuffer), "old", "new");

// Inline formatting
engfunc(EngFunc_SetModel, pEntity, fmt("models/player/%s/%s.mdl", szSkin, szSkin));
```

## Best Practices

1. **Always free dynamic handles** - `ArrayDestroy`, `TrieDestroy` in `plugin_end()`
2. **Use `charsmax()`** for buffer size parameters
3. **Use static for vectors** in frequently called functions
4. **Get string length from pev** - avoid separate `strlen()` call
5. **Use `fmt()`** for inline string formatting in function calls
