#if defined _api_player_effects_const_included
  #endinput
#endif
#define _api_player_effects_const_included

enum {
  PlayerEffect_Set_Fail = 0,
  PlayerEffect_Set_Success,
  PlayerEffect_Set_Ignored,
  PlayerEffect_Set_Extended
};

enum (<<= 1) {
  PlayerEffect_Revoke_None = 0,
  PlayerEffect_Revoke_Terminated = (1 << 0),
  PlayerEffect_Revoke_Native,
  PlayerEffect_Revoke_Command,
  PlayerEffect_Revoke_Expired,
  PlayerEffect_Revoke_Unlimited
};
