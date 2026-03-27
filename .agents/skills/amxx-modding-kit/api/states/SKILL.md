---
name: amxx-modding-kit-api-states
description: Guide for States API usage implementing state machines with transitions, guards, and lifecycle hooks.
---

# States API

State machine implementation for managing entity and player states with transitions, guards, enter/exit hooks, and timed state changes.

For complete API documentation, see [README.md](https://github.com/hedgefog/amxx-modding-kit/api/states/README.md).

---

## State Context Registration

### Define States

```pawn
enum HealthState {
  HealthState_Healthy = 0,
  HealthState_Injured,
  HealthState_Critical,
  HealthState_Dead
};
```

### Register Context

```pawn
#define STATE_CONTEXT_HEALTH "myplugin.health"

public plugin_precache() {
  // Register context with initial state
  State_Context_Register(STATE_CONTEXT_HEALTH, HealthState_Healthy);
}
```

---

## Register Hooks

### Enter/Exit Hooks

```pawn
public plugin_precache() {
  State_Context_Register(STATE_CONTEXT_HEALTH, HealthState_Healthy);
  
  // Enter hooks - called when entering state
  State_Context_RegisterEnterHook(STATE_CONTEXT_HEALTH, HealthState_Healthy, "@Health_Healthy_Enter");
  State_Context_RegisterEnterHook(STATE_CONTEXT_HEALTH, HealthState_Injured, "@Health_Injured_Enter");
  State_Context_RegisterEnterHook(STATE_CONTEXT_HEALTH, HealthState_Critical, "@Health_Critical_Enter");
  
  // Exit hooks - called when leaving state
  State_Context_RegisterExitHook(STATE_CONTEXT_HEALTH, HealthState_Critical, "@Health_Critical_Exit");
}
```

### Transition Hook

Called on specific state-to-state transition:

```pawn
public plugin_precache() {
  // ...
  
  // Called when transitioning from Injured to Critical
  State_Context_RegisterTransitionHook(
    STATE_CONTEXT_HEALTH, 
    HealthState_Injured, 
    HealthState_Critical, 
    "@Health_Injured_To_Critical"
  );
}

@Health_Injured_To_Critical(const StateManager:this) {
  static pPlayer; pPlayer = State_Manager_GetUserToken(this);
  client_print(pPlayer, print_center, "Warning: Condition worsening!");
}
```

### Change Hook

Called on any state change:

```pawn
public plugin_precache() {
  State_Context_RegisterChangeHook(STATE_CONTEXT_HEALTH, "@Health_Changed");
}

@Health_Changed(const StateManager:this) {
  static pPlayer; pPlayer = State_Manager_GetUserToken(this);
  static HealthState:iNewState; iNewState = State_Manager_GetState(this);
  
  // Update HUD, play sound, etc.
  UpdateHealthHUD(pPlayer, iNewState);
}
```

### Change Guard

Validate state changes before they happen:

```pawn
public plugin_precache() {
  State_Context_RegisterChangeGuard(STATE_CONTEXT_HEALTH, "@Health_CanChange");
}

bool:@Health_CanChange(const StateManager:this, any:iOldState, any:iNewState) {
  static pPlayer; pPlayer = State_Manager_GetUserToken(this);
  
  // Can't become healthy if poisoned
  if (iNewState == HealthState_Healthy && IsPlayerPoisoned(pPlayer)) {
    return false;
  }
  
  return true;
}
```

---

## State Manager Lifecycle

### Create Manager

```pawn
new StateManager:g_rgpPlayerStateManagers[MAX_PLAYERS + 1] = { StateManager_Invalid, ... };

public client_connect(pPlayer) {
  // Create manager with player as user token
  g_rgpPlayerStateManagers[pPlayer] = State_Manager_Create(STATE_CONTEXT_HEALTH, pPlayer);
}
```

### Destroy Manager

```pawn
public client_disconnected(pPlayer) {
  if (g_rgpPlayerStateManagers[pPlayer] != StateManager_Invalid) {
    State_Manager_Destroy(g_rgpPlayerStateManagers[pPlayer]);
    g_rgpPlayerStateManagers[pPlayer] = StateManager_Invalid;
  }
}
```

---

## State Transitions

### Immediate Transition

```pawn
// Set state immediately
State_Manager_SetState(g_rgpPlayerStateManagers[pPlayer], HealthState_Injured);
```

### Timed Transition

```pawn
// Transition to state after delay
State_Manager_SetState(g_rgpPlayerStateManagers[pPlayer], HealthState_Critical, 5.0);
```

### Force Transition

```pawn
// Force transition even during another transition
State_Manager_SetState(g_rgpPlayerStateManagers[pPlayer], HealthState_Dead, _, true);
```

### Reset to Initial State

```pawn
// Reset to initial state (HealthState_Healthy)
State_Manager_ResetState(g_rgpPlayerStateManagers[pPlayer]);
```

### Query Current State

```pawn
new HealthState:iState = State_Manager_GetState(g_rgpPlayerStateManagers[pPlayer]);

switch (iState) {
  case HealthState_Healthy: { /* ... */ }
  case HealthState_Injured: { /* ... */ }
  case HealthState_Critical: { /* ... */ }
  case HealthState_Dead: { /* ... */ }
}
```

---

## Hook Implementations

### Enter Hook

```pawn
@Health_Healthy_Enter(const StateManager:this) {
  static pPlayer; pPlayer = State_Manager_GetUserToken(this);
  client_print(pPlayer, print_center, "You are healthy!");
  
  // Clear any negative effects
  ClearHealthEffects(pPlayer);
}

@Health_Injured_Enter(const StateManager:this) {
  static pPlayer; pPlayer = State_Manager_GetUserToken(this);
  client_print(pPlayer, print_center, "You are injured. Be careful!");
  
  // Apply visual effect
  ApplyInjuredEffect(pPlayer);
}

@Health_Critical_Enter(const StateManager:this) {
  static pPlayer; pPlayer = State_Manager_GetUserToken(this);
  client_print(pPlayer, print_center, "CRITICAL! Find a medkit!");
  
  // Apply urgent effects
  ApplyCriticalEffect(pPlayer);
  StartHeartbeatSound(pPlayer);
}
```

### Exit Hook

```pawn
@Health_Critical_Exit(const StateManager:this) {
  static pPlayer; pPlayer = State_Manager_GetUserToken(this);
  
  // Remove critical effects
  StopHeartbeatSound(pPlayer);
  ClearCriticalEffect(pPlayer);
  
  client_print(pPlayer, print_center, "Condition stabilizing...");
}
```

---

## Common Patterns

### Health-Based State Updates

```pawn
@Player_TakeDamage_Post(const pPlayer) {
  UpdateHealthState(pPlayer);
}

@Player_Healed(const pPlayer) {
  UpdateHealthState(pPlayer);
}

UpdateHealthState(const pPlayer) {
  static StateManager:pManager; pManager = g_rgpPlayerStateManagers[pPlayer];
  if (pManager == StateManager_Invalid) return;
  
  static Float:flHealth; pev(pPlayer, pev_health, flHealth);
  
  if (flHealth <= 0.0) {
    State_Manager_SetState(pManager, HealthState_Dead);
  } else if (flHealth < 20.0) {
    State_Manager_SetState(pManager, HealthState_Critical);
  } else if (flHealth < 50.0) {
    State_Manager_SetState(pManager, HealthState_Injured);
  } else {
    State_Manager_SetState(pManager, HealthState_Healthy);
  }
}
```

### Infection State Machine

```pawn
enum InfectionState {
  InfectionState_None = 0,
  InfectionState_Infected,
  InfectionState_Transforming,
  InfectionState_Zombie
};

#define STATE_CONTEXT_INFECTION "myplugin.infection"

public plugin_precache() {
  State_Context_Register(STATE_CONTEXT_INFECTION, InfectionState_None);
  
  State_Context_RegisterEnterHook(STATE_CONTEXT_INFECTION, InfectionState_Infected, "@Infection_Infected_Enter");
  State_Context_RegisterEnterHook(STATE_CONTEXT_INFECTION, InfectionState_Transforming, "@Infection_Transforming_Enter");
  State_Context_RegisterEnterHook(STATE_CONTEXT_INFECTION, InfectionState_Zombie, "@Infection_Zombie_Enter");
  
  State_Context_RegisterChangeGuard(STATE_CONTEXT_INFECTION, "@Infection_CanChange");
}

// When player is bitten
InfectPlayer(const pPlayer) {
  new StateManager:pManager = g_rgpPlayerInfectionState[pPlayer];
  
  // Start infection, transform after 10 seconds
  State_Manager_SetState(pManager, InfectionState_Infected);
  State_Manager_SetState(pManager, InfectionState_Transforming, 10.0);
}

@Infection_Transforming_Enter(const StateManager:this) {
  static pPlayer; pPlayer = State_Manager_GetUserToken(this);
  
  // Schedule final transformation
  State_Manager_SetState(this, InfectionState_Zombie, 5.0);
  
  client_print(pPlayer, print_center, "Transformation beginning...");
}

@Infection_Zombie_Enter(const StateManager:this) {
  static pPlayer; pPlayer = State_Manager_GetUserToken(this);
  
  // Complete transformation
  PlayerRole_Player_AssignRole(pPlayer, ROLE_ZOMBIE);
}
```

### Reset on Spawn

```pawn
public HamHook_Player_Spawn_Post(const pPlayer) {
  if (!is_user_alive(pPlayer)) return HAM_IGNORED;
  
  // Reset health state
  State_Manager_ResetState(g_rgpPlayerStateManagers[pPlayer]);
  
  // Reset infection state
  State_Manager_ResetState(g_rgpPlayerInfectionState[pPlayer]);
  
  return HAM_HANDLED;
}
```

---

## Checklist

- [ ] Define state enum
- [ ] Register context in `plugin_precache`
- [ ] Create managers in `client_connect`
- [ ] Destroy managers in `client_disconnected`
- [ ] Register enter/exit hooks for state effects
- [ ] Use guard hooks to validate transitions
- [ ] Get user token with `State_Manager_GetUserToken`
- [ ] Reset states on spawn if appropriate
