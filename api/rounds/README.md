# ⏱️ Rounds API

The **Rounds API** provides a flexible system for managing rounds in GoldSrc-based games. It supports integration with existing round systems, such as in Counter-Strike, or can be used to implement round mechanics in games without built-in round logic, like Half-Life.

## 🚀 Features

- **Custom Round Logic**: Enable round-based gameplay in games without native round systems.
- **Time Management**: Set and retrieve round times, freeze periods, and round start times.
- **Win Conditions**: Dispatch round wins, check conditions, and terminate rounds.
- **Forward Hooks**: Respond to key round events such as start, end, or timer updates.

## 📚 Using the Rounds API

### ⚙️ Enabling Custom Rounds

To activate custom rounds, use the `Round_UseCustomManager` function. This is essential for games without built-in round systems.

```pawn
#include <api_rounds>

public plugin_init() {
    register_plugin("Rounds API Example", "1.0", "Author");

    // Enable custom round logic
    Round_UseCustomManager();
}
```

### 🕒 Setting and Managing Round Times

#### Set Round Time

Use `Round_SetTime` to set the duration of a round in seconds.

```pawn
Round_SetTime(300); // Set round time to 5 minutes
```

#### Get Remaining Time

Retrieve the remaining time in the current round using `Round_GetRemainingTime`.

```pawn
new Float:flTime = Round_GetRemainingTime();
client_print(0, print_chat, "Time remaining: %.2f seconds", flTime);
```

### 🎯 Dispatching Round Wins and Terminating Rounds

#### Dispatch a Win

Call `Round_DispatchWin` to declare a winning team after a delay.

```pawn
Round_DispatchWin(TEAM_CT, 5.0); // CTs win after 5 seconds
```

#### Terminate a Round

Use `Round_Terminate` to end the round immediately or with a delay.

```pawn
Round_Terminate(2.0, TEAM_T); // Terminate round in 2 seconds, awarding win to Ts
```

### 🔍 Checking Round States

The API provides several functions to query the current round state:

- `Round_IsStarted()`
- `Round_IsEnd()`
- `Round_IsFreezePeriod()`
- `Round_IsPlayersNeeded()`

Example:

```pawn
if (Round_IsFreezePeriod()) {
    client_print(0, print_chat, "Freeze period is active.");
}
```

### 🛠 Responding to Round Events

The API includes several forward hooks for round events:

- `Round_OnInit()`: Triggered when a new round is initialized.
- `Round_OnStart()`: Triggered at the start of a round.
- `Round_OnEnd(iTeam)`: Triggered at the end of a round with the winning team.
- `Round_OnExpired()`: Triggered when the round timer expires.
- `Round_OnRestart()`: Triggered when the round restarts.
- `Round_OnTimerTick()`: Triggered every second during the round timer.
- `Round_OnUpdateTimer(iRemainingTime)`: Triggered when the timer updates.

#### Example: Handling Round Start

```pawn
public Round_OnStart() {
    client_print(0, print_chat, "A new round has started!");
}
```

### 🔧 Advanced Features

#### Check Win Conditions

Use `Round_CheckWinConditions` to manually evaluate and handle win conditions.

#### Retrieve Round Times

You can retrieve specific times using these functions:

- `Round_GetTime()`
- `Round_GetIntroTime()`
- `Round_GetStartTime()`
- `Round_GetRestartTime()`

Example:

```pawn
new Float:flStartTime = Round_GetStartTime();
client_print(0, print_chat, "Round started at: %.2f", flStartTime);
```

## 🧩 Example: Custom Rounds System

This example demonstrates implementing a simple custom rounds system:

```pawn
#include <api_rounds>

enum Team {
  Team_None = 0,
  Team_Red,
  Team_Blue
};

public plugin_init() {
    register_plugin("Custom Rounds System", "1.0", "Author");

    Round_UseCustomManager();
}

public Round_OnInit() {
    client_print(0, print_chat, "A new round is being prepared.");
}

public Round_OnStart() {
    client_print(0, print_chat, "Round started! Fight!");
}

public Round_OnEnd(iTeam) {
    switch (iTeam) {
        case Team_Red: client_print(0, print_chat, "Red Team Win!");
        case Team_Blue: client_print(0, print_chat, "Blue Team Win!");
        case Team_None: client_print(0, print_chat, "The round ended in a draw.");
    }
}

public Round_OnExpired() {
    client_print(0, print_chat, "Time's up! The round is a draw.");
    Round_Terminate(0.0, 0); // End round immediately
}
```

---

## 📖 API Reference

See [`api_rounds.inc`](include/api_rounds.inc) and [`api_rounds_const.inc`](include/api_rounds_const.inc) for all available natives, forwards, and constants.
