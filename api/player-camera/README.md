# 🎥 Player Camera API

The **Player Camera API** provides a powerful system for manipulating player camera views in GoldSrc-based games. It allows developers to control camera positions, angles, distances, and more, enabling immersive and dynamic gameplay mechanics.

## 🚀 Features

- **Activate and Deactivate**: Easily enable or disable custom player cameras.
- **Dynamic Positioning**: Control camera offsets, angles, and distances.
- **Target Locking**: Set a specific entity as the camera’s focus.
- **Axis Locking**: Restrict camera movement on specific axes.
- **Think Delay**: Customize the update frequency of the camera logic.

## 📚 Using the Player Camera API

### ⚙️ Activating and Deactivating the Camera

The first step in using the API is toggling the camera for a player.

```pawn
#include <api_player_camera>

public plugin_init() {
  register_plugin("Player Camera Example", "1.0", "Author");
  register_clcmd("say /togglecamera", "Command_ToggleCamera");
}

public Command_ToggleCamera(const pPlayer) {
  if (PlayerCamera_IsActive(pPlayer)) {
    // Deactivate the camera if it’s already active
    PlayerCamera_Deactivate(pPlayer);
    client_print(pPlayer, print_chat, "Camera deactivated!");
  } else {
    // Activate the camera if it’s not active
    PlayerCamera_Activate(pPlayer);
    client_print(pPlayer, print_chat, "Camera activated!");
  }

  return PLUGIN_HANDLED;
}
```

### 🧩 Customizing Camera Position

You can adjust the camera’s position relative to the player using offsets and angles.

#### Example: Third-Person View

```pawn
new Float:vecOffset[3] = {0.0, 0.0, 50.0};
new Float:vecAngles[3] = {15.0, 0.0, 0.0};

PlayerCamera_SetOffset(pPlayer, vecOffset);
PlayerCamera_SetAngles(pPlayer, vecAngles);
```

This positions the camera above and behind the player, angled slightly downward.

### 🔗 Setting Camera Distance

Control the distance between the camera and the player for a zoomed-out or close-up view.

```pawn
PlayerCamera_SetDistance(pPlayer, 100.0); // Set the camera 100 units away
```

### 🎯 Locking Camera Axes

To create a stable camera, you can lock specific axes of movement.

```pawn
PlayerCamera_SetAxisLock(pPlayer, true, false, true); // Lock pitch and roll axes
```

### 🔍 Focusing on a Target Entity

You can set the camera to follow another entity dynamically.

```pawn
PlayerCamera_SetTargetEntity(pPlayer, pTarget);
```

### ⏱ Setting Think Delay

Adjust the update frequency of the camera logic to balance performance and responsiveness.

```pawn
PlayerCamera_SetThinkDelay(pPlayer, 0.1); // Updates every 0.1 seconds
```

### 🐌 Setting Damping

Adjust the damping of the camera to control the smoothness of the camera movement.

```pawn
PlayerCamera_SetDamping(pPlayer, 0.5); // Set damping to 0.5
```

## 🔧 Advanced Features

### Callbacks for Camera Events

You can hook into camera events to add custom logic when the camera is activated or deactivated.

#### Example: Activation Callback

```pawn
public PlayerCamera_OnActivated(pPlayer) {
  client_print(pPlayer, print_chat, "Your custom camera has been activated!");
}
```

#### Example: Deactivation Callback

```pawn
public PlayerCamera_OnDeactivated(pPlayer) {
  client_print(pPlayer, print_chat, "Your custom camera has been deactivated!");
}
```

## 🧩 Example: Spectator Mode

Here’s how you can implement a simple spectator camera that follows another player.

```pawn
#include <api_player_camera>

public plugin_init() {
  register_plugin("Spectator Camera", "1.0", "Author");

  register_concmd("spectate", "Command_Spectate");
}

public Command_Spectate(const pPlayer) {
  if (!is_user_alive(pPlayer)) {
    client_print(pPlayer, print_chat, "You must be alive to spectate!");
    return PLUGIN_HANDLED;
  }

  static szName[32]; read_argv(1, szName, charsmax(szName));

  new pTarget = find_player("b", szName);
  if (!pTarget) {
    client_print(pPlayer, print_chat, "No valid target to spectate.");
    return PLUGIN_HANDLED;
  }

  // Activate the camera and focus on the target player
  PlayerCamera_Activate(pPlayer);
  PlayerCamera_SetTargetEntity(pPlayer, pTarget);

  client_print(pPlayer, print_chat, "You are now spectating player %s!", szName);

  return PLUGIN_HANDLED;
}
```

---

## 📖 API Reference

See [`api_player_camera.inc`](include/api_player_camera.inc) for all available natives and forwards.
