---
name: amxx-modding-kit-api-player-effects
description: Guide for Player Effects API enabling timed effects with invoke/revoke lifecycle and state management.
---

# Player Effects API

Timed player effects system with registration, invoke/revoke callbacks, and automatic expiration.

For complete API documentation, see [README.md](https://github.com/hedgefog/amxx-modding-kit/api/player-effects/README.md).

---

## Registering Effects

Register effects in `plugin_init`:

```pawn
#define EFFECT_SPEED_BOOST "speed-boost"
#define EFFECT_INVINCIBILITY "invincibility"

public plugin_init() {
  register_plugin("Player Effects", "1.0", "Author");
  
  // Register with invoke and revoke callbacks
  PlayerEffect_Register(
    EFFECT_SPEED_BOOST,
    "Callback_Effect_SpeedBoost_Invoke",
    "Callback_Effect_SpeedBoost_Revoke",
    "icon_speed",        // Optional icon
    {0, 255, 0}          // Optional color (RGB)
  );
  
  PlayerEffect_Register(
    EFFECT_INVINCIBILITY,
    "Callback_Effect_Invincibility_Invoke",
    "Callback_Effect_Invincibility_Revoke"
  );
}
```

---

## Invoke/Revoke Callbacks

```pawn
public Callback_Effect_SpeedBoost_Invoke(const pPlayer) {
  set_pev(pPlayer, pev_maxspeed, 400.0);
  client_print(pPlayer, print_chat, "Speed boost activated!");
}

public Callback_Effect_SpeedBoost_Revoke(const pPlayer) {
  set_pev(pPlayer, pev_maxspeed, 250.0);
  client_print(pPlayer, print_chat, "Speed boost expired.");
}

public Callback_Effect_Invincibility_Invoke(const pPlayer) {
  set_pev(pPlayer, pev_takedamage, DAMAGE_NO);
  client_print(pPlayer, print_chat, "Invincibility activated!");
}

public Callback_Effect_Invincibility_Revoke(const pPlayer) {
  set_pev(pPlayer, pev_takedamage, DAMAGE_AIM);
  client_print(pPlayer, print_chat, "Invincibility expired.");
}
```

---

## Applying Effects

### Activate Effect

```pawn
// Apply effect with duration (seconds)
PlayerEffect_Set(pPlayer, EFFECT_SPEED_BOOST, true, 10.0);

// Apply effect permanently (no auto-expire)
PlayerEffect_Set(pPlayer, EFFECT_INVINCIBILITY, true, 0.0);
```

### Deactivate Effect

```pawn
// Remove effect immediately
PlayerEffect_Set(pPlayer, EFFECT_SPEED_BOOST, false);
```

---

## Querying Effect State

```pawn
// Check if effect is active
if (PlayerEffect_Get(pPlayer, EFFECT_SPEED_BOOST)) {
  // Effect is active
}

// Get effect end time
new Float:flEndTime = PlayerEffect_GetEndtime(pPlayer, EFFECT_SPEED_BOOST);

// Get effect duration
new Float:flDuration = PlayerEffect_GetDuration(pPlayer, EFFECT_SPEED_BOOST);

// Calculate remaining time
new Float:flRemaining = flEndTime - get_gametime();
```

---

## Common Pattern: Powerup Item

```pawn
#define EFFECT_MOONGRAVITY "moongravity"
#define MOON_GRAVITY 0.165

public plugin_init() {
  PlayerEffect_Register(EFFECT_MOONGRAVITY, "Callback_Effect_Moon_Invoke", "Callback_Effect_Moon_Revoke", "icon_moon", {64, 64, 255});
  register_clcmd("say /moon", "Command_MoonGravity");
}

public Callback_Effect_Moon_Invoke(const pPlayer) {
  set_pev(pPlayer, pev_gravity, MOON_GRAVITY);
  client_print(pPlayer, print_chat, "Moon gravity activated!");
}

public Callback_Effect_Moon_Revoke(const pPlayer) {
  set_pev(pPlayer, pev_gravity, 1.0);
  client_print(pPlayer, print_chat, "Gravity normalized.");
}

public Command_MoonGravity(const pPlayer) {
  PlayerEffect_Set(pPlayer, EFFECT_MOONGRAVITY, true, 10.0);
  return PLUGIN_HANDLED;
}
```

---

## Common Pattern: Stacking Effects

```pawn
// Check if already has effect before applying
if (!PlayerEffect_Get(pPlayer, EFFECT_SPEED_BOOST)) {
  PlayerEffect_Set(pPlayer, EFFECT_SPEED_BOOST, true, 5.0);
} else {
  // Extend duration by getting current end time and adding more
  new Float:flCurrentEnd = PlayerEffect_GetEndtime(pPlayer, EFFECT_SPEED_BOOST);
  new Float:flNewDuration = (flCurrentEnd - get_gametime()) + 5.0;
  PlayerEffect_Set(pPlayer, EFFECT_SPEED_BOOST, true, flNewDuration);
}
```

---

## Checklist

- [ ] Register effects with unique IDs
- [ ] Implement invoke callback to apply effect
- [ ] Implement revoke callback to remove effect
- [ ] Use duration 0.0 for permanent effects
- [ ] Consider effect stacking/extension logic
- [ ] Clean up effects on player death/disconnect
