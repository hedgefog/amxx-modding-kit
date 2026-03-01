#pragma semicolon 1

#include <amxmodx>
#include <amxmisc>
#include <engine>
#include <fakemeta>
#include <hamsandwich>
#include <xs>

#include <command_util>

#define IS_PLAYER(%1) (%1 >= 1 && %1 <= MaxClients)
#define MAX_ENTITIES 2048

#define EF_FORCEVISIBILITY 2048
#define EF_OWNER_VISIBILITY 4096
#define EF_OWNER_NO_VISIBILITY 8192

#define MAX(%1,%2) (%1 > %2 ? %1 : %2)

new gmsgFog;

new g_pfwPlayerCheatingDetected = 0;
new g_pfwPlayerViewRangeChanged = 0;

new g_pfwfmCheckVisibility = 0;

new Float:g_rgflPlayerViewRange[MAX_PLAYERS + 1];
new g_rgiPlayerNativeFogColor[MAX_PLAYERS + 1][3];
new Float:g_rgflPlayerNativeFogDensity[MAX_PLAYERS + 1];
new Float:g_rgflPlayerNextCvarCheck[MAX_PLAYERS + 1];
new g_rgiPlayerViewRangeBits = 0;

new Float:g_rgflEntityVisibilityRadius[MAX_ENTITIES + 1];
new bool:g_rgbEntityHasBspModel[MAX_ENTITIES + 1];
new g_rgiEntityVisibilityMask[MAX_ENTITIES + 1];

new Float:g_rgflEntityNextPlayerVisibilityUpdate[MAX_ENTITIES + 1][MAX_PLAYERS + 1];

new Float:g_flGameTime = 0.0;

public plugin_precache() {
  register_forward(FM_Spawn, "FMHook_Spawn", 0);
  register_forward(FM_SetModel, "FMHook_SetModel_Post", 1);
}

public plugin_init() {
  register_plugin("[API] Player View Range", "0.9.0", "Hedgehog Fog");
  
  gmsgFog = get_user_msgid("Fog");

  register_message(gmsgFog, "Message_Fog");

  register_concmd("player_viewrange_set", "Command_SetPlayerViewRange", ADMIN_CVAR);
  register_concmd("player_viewrange_reset", "Command_ResetPlayerViewRange", ADMIN_CVAR);

  g_pfwPlayerCheatingDetected = CreateMultiForward("PlayerViewRange_OnCheatingDetected", ET_IGNORE, FP_CELL);
  g_pfwPlayerViewRangeChanged = CreateMultiForward("PlayerViewRange_OnChange", ET_IGNORE, FP_CELL, FP_FLOAT);
}

public plugin_natives() {
  register_library("api_player_viewrange");
  register_native("PlayerViewRange_Get", "Native_GetPlayerViewRange");
  register_native("PlayerViewRange_Set", "Native_SetPlayerViewRange");
  register_native("PlayerViewRange_Reset", "Native_ResetPlayerViewRange");
  register_native("PlayerViewRange_Update", "Native_UpdatePlayerViewRange");
}

public Command_SetPlayerViewRange(const pPlayer, const iLevel, const iCId) {
  if (!cmd_access(pPlayer, iLevel, iCId, 2)) return PLUGIN_HANDLED;

  static szTarget[32]; read_argv(1, szTarget, charsmax(szTarget));
  new Float:flValue = read_argv_float(2);

  new iTarget = CMD_RESOLVE_TARGET(szTarget);

  for (new pTarget = 1; pTarget <= MaxClients; ++pTarget) {
    if (!CMD_SHOULD_TARGET_PLAYER(pTarget, iTarget, pPlayer)) continue;
    @Player_SetViewRange(pTarget, flValue);
  }

  return PLUGIN_HANDLED;
}

public Command_ResetPlayerViewRange(const pPlayer, const iLevel, const iCId) {
  if (!cmd_access(pPlayer, iLevel, iCId, 1)) return PLUGIN_HANDLED;

  static szTarget[32]; read_argv(1, szTarget, charsmax(szTarget));

  new iTarget = CMD_RESOLVE_TARGET(szTarget);

  for (new pTarget = 1; pTarget <= MaxClients; ++pTarget) {
    if (!CMD_SHOULD_TARGET_PLAYER(pTarget, iTarget, pPlayer)) continue;
    @Player_SetViewRange(pTarget, -1.0);
  }

  return PLUGIN_HANDLED;
}

public Float:Native_GetPlayerViewRange(const iPluginId, const iArgc) {
  new pPlayer = get_param(1);

  return g_rgflPlayerViewRange[pPlayer];
}

public Native_SetPlayerViewRange(const iPluginId, const iArgc) {
  new pPlayer = get_param(1);
  new Float:flValue = get_param_f(2);

  @Player_SetViewRange(pPlayer, flValue);
}

public Native_ResetPlayerViewRange(const iPluginId, const iArgc) {
  new pPlayer = get_param(1);

  @Player_SetViewRange(pPlayer, -1.0);
}

public Native_UpdatePlayerViewRange(const iPluginId, const iArgc) {
  new pPlayer = get_param(1);

  @Player_UpdateViewRange(pPlayer);
}

public server_frame() {
  g_flGameTime = get_gametime();
}

public client_connect(pPlayer) {
  g_rgflPlayerViewRange[pPlayer] = -1.0;
  g_rgiPlayerNativeFogColor[pPlayer][0] = 0;
  g_rgiPlayerNativeFogColor[pPlayer][1] = 0;
  g_rgiPlayerNativeFogColor[pPlayer][2] = 0;
  g_rgflPlayerNativeFogDensity[pPlayer] = 0.0;
  g_rgiPlayerViewRangeBits &= ~(1 << (pPlayer & 31));
  g_rgflPlayerNextCvarCheck[pPlayer] = g_flGameTime;
}

public Message_Fog(const iMsgId, const iMsgDest, const pPlayer) {
  g_rgiPlayerNativeFogColor[pPlayer][0] = get_msg_arg_int(1);
  g_rgiPlayerNativeFogColor[pPlayer][1] = get_msg_arg_int(2);
  g_rgiPlayerNativeFogColor[pPlayer][2] = get_msg_arg_int(3);
  g_rgflPlayerNativeFogDensity[pPlayer] = Float:(
    get_msg_arg_int(4) |
    (get_msg_arg_int(5) << 8) |
    (get_msg_arg_int(6) << 16) |
    (get_msg_arg_int(7) << 24)
  );
}

public FMHook_Spawn(const pEntity) {
  g_rgflEntityVisibilityRadius[pEntity] = 0.0;
  g_rgbEntityHasBspModel[pEntity] = false;

  return FMRES_HANDLED;
}

public FMHook_SetModel_Post(const pEntity, const szModel[]) {
  g_rgflEntityVisibilityRadius[pEntity] = 0.0;
  g_rgbEntityHasBspModel[pEntity] = false;

  if (szModel[0]) {
    g_rgbEntityHasBspModel[pEntity] = szModel[0] == '*';

    if (!g_rgbEntityHasBspModel[pEntity]) {
      static Float:vecSize[3];

      static iLength; iLength = strlen(szModel);

      if (equal(szModel[iLength - 4], ".mdl")) {
        static Float:vecMins[3], Float:vecMaxs[3];
        if (GetModelBoundingBox(pEntity, vecMins, vecMaxs, 0)) {
          xs_vec_sub(vecMaxs, vecMins, vecSize);
          xs_vec_mul_scalar(vecSize, 0.5, vecSize);
        }
      }

      for (new i = 0; i < 3; i++) {
        g_rgflEntityVisibilityRadius[pEntity] = MAX(g_rgflEntityVisibilityRadius[pEntity], vecSize[i]);
      }
    }
  }

  return FMRES_HANDLED;
}

public FMHook_CheckVisibility(const pEntity) {
  if (g_rgbEntityHasBspModel[pEntity]) return FMRES_IGNORED;
  if (pEntity > MAX_ENTITIES) return FMRES_IGNORED;

  new pPlayer = engfunc(EngFunc_GetCurrentPlayer) + 1;
  if (g_rgflPlayerViewRange[pPlayer] <= 0.0) return FMRES_IGNORED;

  if (g_rgflEntityNextPlayerVisibilityUpdate[pEntity][pPlayer] <= g_flGameTime) {
    static pTargetEnt; pTargetEnt = pev(pEntity, pev_movetype) == MOVETYPE_FOLLOW ? pev(pEntity, pev_aiment) : pEntity;

    if (pTargetEnt != pPlayer && entity_range(pPlayer, pTargetEnt) > g_rgflPlayerViewRange[pPlayer] + @Entity_GetVisibilityRadius(pTargetEnt)) {
      g_rgiEntityVisibilityMask[pEntity] &= ~(1 << (pPlayer & 31));
    } else {
      g_rgiEntityVisibilityMask[pEntity] |= (1 << (pPlayer & 31));
    }

    g_rgflEntityNextPlayerVisibilityUpdate[pEntity][pPlayer] = g_flGameTime + 0.1;
  }

  if (~g_rgiEntityVisibilityMask[pEntity] & (1 << (pPlayer & 31))) {
    if (!(pev(pEntity, pev_effects) & (EF_FORCEVISIBILITY | EF_OWNER_VISIBILITY | EF_OWNER_NO_VISIBILITY))) {
      forward_return(FMV_CELL, 0);
      return FMRES_SUPERCEDE;
    }
  }

  return HAM_HANDLED;
}

@Player_SetViewRange(const &this, Float:flViewRange) {
  if (g_rgflPlayerViewRange[this] == flViewRange) return;

  if (flViewRange >= 0.0) {
    g_rgiPlayerViewRangeBits |= (1 << (this & 31));
  } else {
    g_rgiPlayerViewRangeBits &= ~(1 << (this & 31));
  }

  g_rgflPlayerViewRange[this] = flViewRange;

  if (g_rgiPlayerViewRangeBits) {
    if (!g_pfwfmCheckVisibility) {
      g_pfwfmCheckVisibility = register_forward(FM_CheckVisibility, "FMHook_CheckVisibility", 0);
    }
  } else {
    unregister_forward(FM_CheckVisibility, g_pfwfmCheckVisibility, 0);
    g_pfwfmCheckVisibility = 0;
  }

  @Player_UpdateViewRange(this);

  ExecuteForward(g_pfwPlayerViewRangeChanged, _, this, flViewRange);
}

@Player_UpdateViewRange(const &this) {
  if (is_user_bot(this)) return;

  message_begin(MSG_ONE, gmsgFog, _, this);

  if (g_rgiPlayerViewRangeBits & (1 << (this & 31))) {
    new Float:flDensity = g_rgflPlayerViewRange[this] < 0.0 ? 0.0 : (1.5 / MAX(g_rgflPlayerViewRange[this], 1.0));

    write_byte(0);
    write_byte(0);
    write_byte(0);
    write_long(_:flDensity);
  } else { // reset to engine fog
    write_byte(g_rgiPlayerNativeFogColor[this][0]);
    write_byte(g_rgiPlayerNativeFogColor[this][1]);
    write_byte(g_rgiPlayerNativeFogColor[this][2]);
    write_long(_:g_rgflPlayerNativeFogDensity[this]);
  }

  message_end();

  if (g_rgiPlayerViewRangeBits & (1 << (this & 31))) {
    if (g_rgflPlayerNextCvarCheck[this] <= g_flGameTime) {
      query_client_cvar(this, "gl_fog", "Callback_QueryCvar_Fog");
      g_rgflPlayerNextCvarCheck[this] = g_flGameTime + 1.0;
    }
  }
}

Float:@Entity_GetVisibilityRadius(const &pEntity) {
  if (IS_PLAYER(pEntity)) return 72.0;

  if (!g_rgflEntityVisibilityRadius[pEntity]) {
    static Float:vecSize[3]; pev(pEntity, pev_size, vecSize);
    return MAX(MAX(vecSize[0], vecSize[1]), vecSize[2]);
  }

  return g_rgflEntityVisibilityRadius[pEntity];
}


public Callback_QueryCvar_Fog(const pPlayer, const szCvar[], const szValue[]) {
  if (!str_to_num(szValue)) {
    client_print_color(pPlayer, print_team_red, "^3Warning! ^4^"gl_fog 1^"^3 is required by the server. Please enable it in your console.");
    log_amx("Caution! Player %n has gl_fog disabled.", pPlayer);
    ExecuteForward(g_pfwPlayerCheatingDetected, _, pPlayer);
  }
}
