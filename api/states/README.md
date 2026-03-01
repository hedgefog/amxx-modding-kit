# 🔀 States API

The **States API** provides a flexible and efficient way to manage different states. This API allows you to define states, register hooks for transitions, and manage the state lifecycle of the game or entities, such as players or game objects.

## 🚀 Features
- **State Contexts**: Group and manage related states under a single context.
- **Hooks**: Register callbacks for state changes, entries, exits, and transitions.
- **Guards** — Conditionally allow or block transitions
- **State Manager**: Create and control state managers for individual entities.
- **State Transitions**: Schedule and manage timed transitions between states.

---

## 🧩 Example: Player Health State

In this example, we'll demonstrate how to use the **States API** to handle the health states of a player in a game.

### 📃 Creating a States Enum

First, we need to define three state constants: `Healthy`, `Injured`, and `Critical`.

```pawn
enum HealthState {
  HealthState_Healthy,
  HealthState_Injured,
  HealthState_Critical
};
```

### 🪪 Registering a State Context

Next, we'll register a context for the player's health states.

```pawn
#include <api_states>

public plugin_precache() {
    State_Context_Register("player_health", HealthState_Healthy);
}
```

### 🪝 Registering Hooks

Now it's time to register hooks to handle entering and exiting different health states.

```pawn
public plugin_precache() {
  // Register the health context
  State_Context_Register("player_health", HealthState_Healthy);

  // Register enter hooks for different health states
  State_Context_RegisterEnterHook("player_health", HealthState_Healthy, "@State_Healthy_Enter");
  State_Context_RegisterEnterHook("player_health", HealthState_Injured, "@State_Injured_Enter");
  State_Context_RegisterEnterHook("player_health", HealthState_Critical, "@State_Critical_Enter");

  // Register exit hook for the 'Critical' state
  State_Context_RegisterExitHook("player_health", HealthState_Critical, "@State_Critical_Exit");
}

@State_Healthy_Enter(const StateManager:this) {
  static pPlayer; pPlayer = State_Manager_GetUserToken(this);
  client_print(pPlayer, print_center, "You are healthy!");
}

@State_Injured_Enter(const StateManager:this) {
  static pPlayer; pPlayer = State_Manager_GetUserToken(this);
  client_print(pPlayer, print_center, "You are injured. Be careful!");
}

@State_Critical_Enter(const StateManager:this) {
  static pPlayer; pPlayer = State_Manager_GetUserToken(this);
  client_print(pPlayer, print_center, "You are in critical condition! Find a medkit!");
}

@State_Critical_Exit(const StateManager:this) {
  static pPlayer; pPlayer = State_Manager_GetUserToken(this);
  client_print(pPlayer, print_center, "You have recovered from critical condition.");
}
```

### 🔧 Setting Up the State Manager

To use the state manager in your game logic, you need to create a manager instance for each player.

```pawn
new StateManager:g_rgpPlayerStateManagers[MAX_PLAYERS + 1];

public client_connect(pPlayer) {
    g_rgpPlayerStateManagers[pPlayer] = State_Manager_Create("player_health", pPlayer);
}

public client_disconnect(pPlayer) {
    State_Manager_Destroy(g_rgpPlayerStateManagers[pPlayer]);
}
```

### 🔄 Managing State Transitions

Finally, let's manage transitions between these states based on the player's health.

```pawn
@Player_UpdateState(const this) {
  static StateManager:pManager; pManager = g_rgpPlayerStateManagers[this];
  static Float:flHealth; pev(this, pev_health, flHealth);

  if (flHealth < 10.0) {
      State_Manager_SetState(pManager, HealthState_Critical);
  } else if (flHealth < 50.0) {
      State_Manager_SetState(pManager, HealthState_Injured);
  } else {
      State_Manager_SetState(pManager, HealthState_Healthy);
  }
}
```

---

## 📖 API Reference

See [`api_states.inc`](include/api_states.inc) and [`api_states_const.inc`](include/api_states_const.inc) for all available natives and constants.
