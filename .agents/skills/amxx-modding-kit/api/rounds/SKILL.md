---
name: amxx-modding-kit-api-rounds
description: Guide for Rounds API usage managing round-based gameplay including timing, win conditions, and round events.
---

# Rounds API

Flexible round management for game modes, supporting both integration with existing round systems (like Counter-Strike) and custom round implementation.

For complete API documentation, see [README.md](https://github.com/hedgefog/amxx-modding-kit/api/rounds/README.md).

---

## Enable Custom Rounds

For games without native round systems:

```pawn
public plugin_init() {
  Round_UseCustomManager();
}
```

---

## Round State Queries

```pawn
// Check if round has started
if (Round_IsStarted()) {
  // Round is active
}

// Check if round has ended
if (Round_IsEnd()) {
  // Round is over
}

// Check if in freeze period
if (Round_IsFreezePeriod()) {
  // Players are frozen
}

// Check if waiting for players
if (Round_IsPlayersNeeded()) {
  // Not enough players to start
}
```

---

## Time Management

### Set Round Time

```pawn
// Set round duration in seconds
Round_SetTime(300); // 5 minutes
```

### Get Time Information

```pawn
// Get remaining time
new Float:flRemaining = Round_GetRemainingTime();
client_print(0, print_chat, "Time remaining: %.0f seconds", flRemaining);

// Get round start time
new Float:flStartTime = Round_GetStartTime();

// Get total round time
new Float:flRoundTime = Round_GetTime();

// Get freeze/intro time
new Float:flIntroTime = Round_GetIntroTime();

// Get restart time
new Float:flRestartTime = Round_GetRestartTime();
```

---

## Win Conditions

### Dispatch Win

Declare winning team with delay:

```pawn
// Team wins after delay
Round_DispatchWin(TEAM_CT, 5.0); // CTs win in 5 seconds
Round_DispatchWin(TEAM_T, 3.0);  // Ts win in 3 seconds
```

### Terminate Round

End round immediately or with delay:

```pawn
// Terminate immediately
Round_Terminate(0.0, TEAM_CT);

// Terminate after delay
Round_Terminate(2.0, TEAM_T);

// Draw (no winner)
Round_Terminate(0.0, 0);
```

### Check Win Conditions

Manually trigger win condition check:

```pawn
Round_CheckWinConditions();
```

---

## Round Event Forwards

Implement these forwards to react to round events:

### New Round Initialized

```pawn
public Round_OnInit() {
  // Called when new round is initialized
  // Good place to reset variables, prepare map
  
  ResetGameState();
}
```

### Round Started

```pawn
public Round_OnStart() {
  // Called when round starts (after freeze period)
  
  client_print(0, print_chat, "Round started! Fight!");
  StartGameplay();
}
```

### Round Ended

```pawn
public Round_OnEnd(iWinnerTeam) {
  // Called when round ends with winning team
  
  switch (iWinnerTeam) {
    case TEAM_CT: client_print(0, print_chat, "Counter-Terrorists Win!");
    case TEAM_T: client_print(0, print_chat, "Terrorists Win!");
    default: client_print(0, print_chat, "Draw!");
  }
}
```

### Round Expired

```pawn
public Round_OnExpired() {
  // Called when round timer runs out
  
  client_print(0, print_chat, "Time's up!");
  
  // Handle timeout - e.g., draw or specific team wins
  Round_Terminate(0.0, TEAM_CT); // CTs win on timeout
}
```

### Round Restart

```pawn
public Round_OnRestart() {
  // Called when round restarts
  
  ResetAllPlayers();
}
```

### Timer Events

```pawn
public Round_OnTimerTick() {
  // Called every second during round
  
  UpdateTimerDisplay();
}

public Round_OnUpdateTimer(iRemainingTime) {
  // Called when timer updates
  
  if (iRemainingTime <= 30) {
    client_print(0, print_center, "%d seconds remaining!", iRemainingTime);
  }
}
```

---

## Check Forwards (with Return Values)

**Important**: These forwards return `Round_CheckResult` enum, NOT `PLUGIN_*` constants.

### Check Round Start

```pawn
public Round_CheckResult:Round_OnCanStartCheck() {
  new iPlayersNum = 0;
  
  for (new pPlayer = 1; pPlayer <= MaxClients; ++pPlayer) {
    if (!is_user_connected(pPlayer)) continue;
    if (IsPlayerSpectator(pPlayer)) continue;
    iPlayersNum++;
  }
  
  // Allow round to start only if players present
  return iPlayersNum > 0 ? Round_CheckResult_Continue : Round_CheckResult_Supercede;
}
```

### Check Win Conditions

```pawn
public Round_CheckResult:Round_OnCheckWinConditions() {
  // Block default win condition check
  return Round_CheckResult_Supercede;
}
```

### Return Values

| Value | Description |
|-------|-------------|
| `Round_CheckResult_Continue` | Allow default behavior |
| `Round_CheckResult_Supercede` | Block default behavior |

---

## Common Patterns

### Custom Win Conditions

```pawn
// Check win conditions when player dies
public HamHook_Player_Killed_Post(pPlayer, pKiller, iShouldGib) {
  Round_CheckWinConditions();
  return HAM_HANDLED;
}

public Round_CheckResult:Round_OnCheckWinConditions() {
  // Block default check, handle manually
  return Round_CheckResult_Supercede;
}

CheckWinConditions() {
  new iSurvivorsAlive = CountPlayersWithRole(ROLE_SURVIVOR);
  new iZombiesAlive = CountPlayersWithRole(ROLE_ZOMBIE);
  
  if (iSurvivorsAlive == 0) {
    Round_DispatchWin(TEAM_ZOMBIE, 3.0);
  } else if (iZombiesAlive == 0) {
    Round_DispatchWin(TEAM_SURVIVOR, 3.0);
  }
}
```

### Dynamic Round Time

```pawn
public Round_OnStart() {
  // Adjust round time based on player count
  new iPlayers = GetPlayerCount();
  new iRoundTime = 180 + (iPlayers * 15); // Base 3 min + 15 sec per player
  
  Round_SetTime(iRoundTime);
}
```

### Overtime

```pawn
public Round_OnExpired() {
  if (IsObjectiveIncomplete()) {
    // Add overtime
    Round_SetTime(60); // 1 minute overtime
    client_print(0, print_center, "OVERTIME! 60 seconds added!");
    return;
  }
  
  // Normal timeout
  Round_Terminate(0.0, TEAM_DEFENDER);
}
```

---

## Checklist

- [ ] Call `Round_UseCustomManager()` for non-CS games
- [ ] Implement `Round_OnStart` and `Round_OnEnd`
- [ ] Handle `Round_OnExpired` for timeout logic
- [ ] Call `Round_CheckWinConditions()` after relevant events
- [ ] Use `Round_DispatchWin` for delayed win announcements
- [ ] Use `Round_Terminate` for immediate round end
- [ ] Return `Round_CheckResult` from check forwards (not `PLUGIN_*`)