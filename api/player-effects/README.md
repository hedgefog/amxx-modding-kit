# 🏃 Player Effects API

The **Player Effects API** enables developers to apply custom effects to players in GoldSrc-based games. This API provides functions to register effects, activate or deactivate them, and manage their properties dynamically.

## 🚀 Features

- **Register Custom Effects**: Define effects with unique identifiers, invoke functions, and revoke logic.
- **Apply and Revoke Effects**: Control the activation and duration of effects on players.
- **Effect Metadata**: Store icons and colors associated with each effect.
- **State Management**: Query and manage the state and timers of effects.

## 📚 Using the Player Effects API

### ⚙️ Registering an Effect

To create a new effect, use the `PlayerEffect_Register` function. Provide an identifier, invoke and revoke function names, and optional icon settings.

```pawn
#include <api_player_effects>

public plugin_init() {
  register_plugin("Player Effects Example", "1.0", "Author");

  PlayerEffect_Register(
    "example-effect",
    "@Player_EffectInvoke",
    "@Player_EffectRevoke",
    "example_icon",
    {255, 128, 0} // Orange color
  );
}

@Player_EffectInvoke(this) {
  client_print(this, print_chat, "Effect invoked on you!");
}

@Player_EffectRevoke(this) {
  client_print(this, print_chat, "Effect revoked from you!");
}
```

### 🧩 Activating and Deactivating Effects

Use the `PlayerEffect_Set` function to activate or deactivate an effect for a player.

```pawn
new Float:flDuration = 10.0;
PlayerEffect_Set(pPlayer, "example-effect", true, flDuration);
client_print(pPlayer, print_chat, "You have an effect active for %.2f seconds!", flDuration);
```

To deactivate the effect:

```pawn
PlayerEffect_Set(pPlayer, "example-effect", false);
client_print(pPlayer, print_chat, "Your effect has been removed.");
```

### 🔍 Querying Effect State

Check if a player has an effect active using `PlayerEffect_Get`.

```pawn
if (PlayerEffect_Get(pPlayer, "example-effect")) {
  client_print(pPlayer, print_chat, "You have the example effect active.");
} else {
  client_print(pPlayer, print_chat, "You do not have the example effect active.");
}
```

Retrieve effect end time and duration:

```pawn
new Float:flEndTime = PlayerEffect_GetEndtime(pPlayer, "example-effect");
new Float:flDuration = PlayerEffect_GetDuration(pPlayer, "example-effect");

client_print(pPlayer, print_chat, "Effect ends in %.2f seconds (duration: %.2f).", flEndTime - get_gametime(), flDuration);
```

## 🧩 Example: Moongravity Effect

This example demonstrates implementing a "moongravity" effect using the API.

```pawn
#include <api_player_effects>

#define EFFECT_ID "moongravity"

#define GRAVITATIONAL_ACCELERATION_EARTH 9.807
#define GRAVITATIONAL_ACCELERATION_MOON 1.62
#define MOON_GRAVITY GRAVITATIONAL_ACCELERATION_MOON / GRAVITATIONAL_ACCELERATION_EARTH

#define EFFECT_DURATION 10.0

public plugin_init() {
  register_plugin("Moongravity Effect", "1.0", "Author");

  PlayerEffect_Register(EFFECT_ID, "@Effect_Invoke", "@Effect_Revoke", "icon_moongravity", {64, 64, 255});

  register_clcmd("say /moon", "Command_ApplyMoongravity");
}

@Effect_Invoke(const this) {
  set_pev(this, pev_gravity, MOON_GRAVITY);
  client_print(this, print_chat, "Moongravity activated! Enjoy reduced gravity.");
}

@Effect_Revoke(const this) {
  set_pev(this, pev_gravity, 1.0);
  client_print(this, print_chat, "Moongravity deactivated. Back to normal gravity.");
}

public Command_ApplyMoongravity(const pPlayer) {
  PlayerEffect_Set(pPlayer, EFFECT_ID, true, EFFECT_DURATION);
  client_print(pPlayer, print_chat, "Moongravity effect applied for %.2f seconds!", EFFECT_DURATION);

  return PLUGIN_HANDLED;
}
```

---

## 📖 API Reference

See [`api_player_effects.inc`](include/api_player_effects.inc) and [`api_player_effects_const.inc`](include/api_player_effects_const.inc) for all available natives and constants.
