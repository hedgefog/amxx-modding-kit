#pragma semicolon 1

#include <amxmodx>

#include <api_player_effects>
#include <api_player_dizziness>

#define EFFECT_ID "dizziness"

public plugin_init() {
  register_plugin("[Player Effect] Dizziness", "1.0.0", "Hedgehog Fog");

  PlayerEffect_Register(EFFECT_ID, "Callback_Effect_Invoke", "Callback_Effect_Revoke");
}

public Callback_Effect_Invoke(const pPlayer) {
  PlayerDizziness_Set(pPlayer, 1.0);
}

public Callback_Effect_Revoke(const pPlayer) {
  PlayerDizziness_Set(pPlayer, 0.0);
}
