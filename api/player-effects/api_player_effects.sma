#pragma semicolon 1

#include <amxmodx>
#include <amxmisc>
#include <fakemeta>
#include <hamsandwich>

#tryinclude <api_rounds>
#include <command_util>
#include <function_pointer>

#include <api_player_effects_const>

#define MAX_EFFECTS 32

#define BIT(%0) (1<<(%0))

new gmsgStatusIcon;

new Trie:g_itEffectsIds = Invalid_Trie;
new g_rgszEffectIds[MAX_EFFECTS];
new Function:g_rgfnEffectInvokeFunction[MAX_EFFECTS];
new Function:g_rgfnEffectRevokeFunction[MAX_EFFECTS];
new g_rgszEffectIcon[MAX_EFFECTS][32];
new g_rgrgiEffectIconColor[MAX_EFFECTS][3];
new g_iEffectsNum = 0;

// -1.0 = unlimited
new Float:g_rgrgflPlayerEffectDuration[MAX_PLAYERS + 1][MAX_EFFECTS];
new Float:g_rgrgflPlayerEffectEnd[MAX_PLAYERS + 1][MAX_EFFECTS];

public plugin_precache() {
  g_itEffectsIds = TrieCreate();
}

public plugin_init() {
  register_plugin("[API] Player Effects", "1.0.0", "Hedgehog Fog");

  RegisterHamPlayer(Ham_Killed, "HamHook_Player_Killed", .Post = 0);

  register_concmd("player_effect_set", "Command_Set", ADMIN_CVAR);

  gmsgStatusIcon = get_user_msgid("StatusIcon");

  set_task(0.1, "Task_Update", .flags = "b");
}

public plugin_end() {
  TrieDestroy(g_itEffectsIds);
}

public plugin_natives() {
  register_library("api_player_effects");
  register_native("PlayerEffect_Register", "Native_Register");
  register_native("PlayerEffect_Set", "Native_SetPlayerEffect");
  register_native("PlayerEffect_Get", "Native_GetPlayerEffect");
  register_native("PlayerEffect_GetEndtime", "Native_GetPlayerEffectEndTime");
  register_native("PlayerEffect_GetDuration", "Native_GetPlayerEffectDuration");
}

public Native_Register(const iPluginId, const iArgc) {
  new szId[32]; get_string(1, szId, charsmax(szId));
  new szInvokeFunction[32]; get_string(2, szInvokeFunction, charsmax(szInvokeFunction));
  new szRevokeFunction[32]; get_string(3, szRevokeFunction, charsmax(szRevokeFunction));
  new szIcon[32]; get_string(4, szIcon, charsmax(szIcon));
  new rgiIconColor[3]; get_array(5, rgiIconColor, sizeof(rgiIconColor));

  new Function:fnInvokeFunction = get_func_pointer(szInvokeFunction, iPluginId);
  new Function:fnRevokeFunction = get_func_pointer(szRevokeFunction, iPluginId);

  return Effect_Register(szId, fnInvokeFunction, fnRevokeFunction, szIcon, rgiIconColor);
}

public Native_SetPlayerEffect(const iPluginId, const iArgc) {
  new pPlayer = get_param(1);
  new szEffectId[32]; get_string(2, szEffectId, charsmax(szEffectId));

  new iEffectId = -1;
  if (!TrieGetCell(g_itEffectsIds, szEffectId, iEffectId)) return false;

  new bool:bValue = bool:get_param(3);
  new Float:flDuration = get_param_f(4);
  new bool:bExtend = bool:get_param(5);

  return @Player_SetEffect(pPlayer, iEffectId, bValue, flDuration, bExtend, PlayerEffect_Revoke_Native);
}

public bool:Native_GetPlayerEffect(const iPluginId, const iArgc) {
  new pPlayer = get_param(1);
  new szEffectId[32]; get_string(2, szEffectId, charsmax(szEffectId));

  new iEffectId = -1;
  if (!TrieGetCell(g_itEffectsIds, szEffectId, iEffectId)) return false;

  return @Player_GetEffect(pPlayer, iEffectId);
}

public Float:Native_GetPlayerEffectEndTime(const iPluginId, const iArgc) {
  new pPlayer = get_param(1);
  new szEffectId[32]; get_string(2, szEffectId, charsmax(szEffectId));

  new iEffectId = -1;
  if (!TrieGetCell(g_itEffectsIds, szEffectId, iEffectId)) return 0.0;

  return g_rgrgflPlayerEffectEnd[pPlayer][iEffectId];
}

public Float:Native_GetPlayerEffectDuration(const iPluginId, const iArgc) {
  new pPlayer = get_param(1);
  new szEffectId[32]; get_string(2, szEffectId, charsmax(szEffectId));

  new iEffectId = -1;
  if (!TrieGetCell(g_itEffectsIds, szEffectId, iEffectId)) return 0.0;

  return g_rgrgflPlayerEffectDuration[pPlayer][iEffectId];
}

/*--------------------------------[ Forwards ]--------------------------------*/

public client_disconnected(pPlayer) {
  @Player_RevokeEffects(pPlayer);
}

public Round_OnInit() {
  for (new pPlayer = 1; pPlayer <= MaxClients; ++pPlayer) @Player_RevokeEffects(pPlayer);
}

/*--------------------------------[ Hooks ]--------------------------------*/

public Command_Set(const pPlayer, const iLevel, const iCId) {
  if (!cmd_access(pPlayer, iLevel, iCId, 2)) return PLUGIN_HANDLED;

  static szTarget[32]; read_argv(1, szTarget, charsmax(szTarget));
  static szEffectId[32]; read_argv(2, szEffectId, charsmax(szEffectId));
  static szValue[32]; read_argv(3, szValue, charsmax(szValue));
  static szDuration[32]; read_argv(4, szDuration, charsmax(szDuration));

  new iEffectId = -1;
  if (!TrieGetCell(g_itEffectsIds, szEffectId, iEffectId)) return PLUGIN_HANDLED;

  new iTarget = CMD_RESOLVE_TARGET(szTarget);
  new bool:bValue = equal(szValue, NULL_STRING) ? true : bool:str_to_num(szValue);
  new Float:flDuration = equal(szDuration, NULL_STRING) ? -1.0 : str_to_float(szDuration);

  for (new pTarget = 1; pTarget <= MaxClients; ++pTarget) {
    if (!CMD_SHOULD_TARGET_PLAYER(pTarget, iTarget, pPlayer)) continue;
    @Player_SetEffect(pTarget, iEffectId, bValue, flDuration, true, PlayerEffect_Revoke_Command);
  }

  return PLUGIN_HANDLED;
}

public HamHook_Player_Killed(pPlayer) {
  @Player_RevokeEffects(pPlayer);
}

/*--------------------------------[ Methods ]--------------------------------*/

@Player_Update(const &this) {
  static Float:flGameTime; flGameTime = get_gametime();

  for (new iEffectId = 0; iEffectId < g_iEffectsNum; ++iEffectId) {
    if (!g_rgrgflPlayerEffectDuration[this][iEffectId]) continue;
    if (g_rgrgflPlayerEffectEnd[this][iEffectId] == -1.0) continue;

    if (g_rgrgflPlayerEffectEnd[this][iEffectId] <= flGameTime) {
      @Player_SetEffect(this, iEffectId, false, -1.0, false, PlayerEffect_Revoke_Expired);
    }
  }
}

bool:@Player_GetEffect(pPlayer, iEffectId) {
  if (!g_rgrgflPlayerEffectDuration[pPlayer][iEffectId]) return false;

  return true;
}

@Player_SetEffect(pPlayer, iEffectId, bool:bValue, Float:flDuration, bool:bExtend, iRevokeBits) {
  if (bValue && !is_user_alive(pPlayer)) return PlayerEffect_Set_Fail;

  new bool:bCurrentValue = !!g_rgrgflPlayerEffectDuration[pPlayer][iEffectId];

  if (bValue == bCurrentValue) {
    if (!bValue) return PlayerEffect_Set_Fail;
    if (!bExtend) return PlayerEffect_Set_Fail;
  }

  if (bValue != bCurrentValue) {
    if (bValue) {
      if (!Effect_CallInvokeFunction(iEffectId, pPlayer, flDuration)) return PlayerEffect_Set_Fail;
    } else {
      if (g_rgrgflPlayerEffectDuration[pPlayer][iEffectId] == -1.0) {
        iRevokeBits |= PlayerEffect_Revoke_Unlimited;
      }

      if (!Effect_CallRevokeFunction(iEffectId, pPlayer, iRevokeBits)) return PlayerEffect_Set_Fail;
    }
  }

  new iResult = PlayerEffect_Set_Fail;

  static Float:flGameTime; flGameTime = get_gametime();

  if (bValue) {
    // If effect is already set and duration is not unlimited
    if (bCurrentValue && flDuration >= 0.0) {
      if (g_rgrgflPlayerEffectDuration[pPlayer][iEffectId] != -1.0) {
        if (bExtend) {
          // Extend effect duration
          g_rgrgflPlayerEffectEnd[pPlayer][iEffectId] += flDuration;
          g_rgrgflPlayerEffectDuration[pPlayer][iEffectId] += flDuration;
          iResult = PlayerEffect_Set_Extended;
        } else {
          if (g_rgrgflPlayerEffectEnd[pPlayer][iEffectId] < flGameTime + flDuration) {
            // Override effect duration
            g_rgrgflPlayerEffectEnd[pPlayer][iEffectId] = flGameTime + flDuration;
            g_rgrgflPlayerEffectDuration[pPlayer][iEffectId] = flDuration;
          } else {
            // Old effect duration is greater than new one, keep it
            iResult = PlayerEffect_Set_Ignored;
          }
        }
      } else {
        // Skip extension of unlimited effect
        iResult = PlayerEffect_Set_Ignored;
      }
    } else {
      // Set effect duration
      g_rgrgflPlayerEffectDuration[pPlayer][iEffectId] = flDuration;
      g_rgrgflPlayerEffectEnd[pPlayer][iEffectId] = flDuration == -1.0 ? -1.0 : (flGameTime + flDuration);
      iResult = PlayerEffect_Set_Success;
    }
  } else {
    // Revoke effect
    g_rgrgflPlayerEffectDuration[pPlayer][iEffectId] = 0.0;
    g_rgrgflPlayerEffectEnd[pPlayer][iEffectId] = 0.0;
    iResult = PlayerEffect_Set_Success;
  }

  if (!equal(g_rgszEffectIcon[iEffectId], NULL_STRING)) {
    message_begin(MSG_ONE, gmsgStatusIcon, _, pPlayer);
    write_byte(bValue);
    write_string(g_rgszEffectIcon[iEffectId]);

    if (bValue) {
      write_byte(g_rgrgiEffectIconColor[iEffectId][0]);
      write_byte(g_rgrgiEffectIconColor[iEffectId][1]);
      write_byte(g_rgrgiEffectIconColor[iEffectId][2]);
    }

    message_end();
  }

  return iResult;
}

@Player_RevokeEffects(pPlayer)  {
  for (new iEffectId = 0; iEffectId < g_iEffectsNum; ++iEffectId) {
    @Player_SetEffect(pPlayer, iEffectId, false, -1.0, true, PlayerEffect_Revoke_Terminated);
  }
}

/*--------------------------------[ Functions ]--------------------------------*/

Effect_Register(const szId[], const &Function:fnInvokeFunction, const &Function:fnRevokeFunction, const szIcon[], const rgiIconColor[3]) {
  new iId = g_iEffectsNum;

  copy(g_rgszEffectIds[iId], charsmax(g_rgszEffectIds[]), szId);
  g_rgfnEffectInvokeFunction[iId] = fnInvokeFunction;
  g_rgfnEffectRevokeFunction[iId] = fnRevokeFunction;
  copy(g_rgszEffectIcon[iId], charsmax(g_rgszEffectIcon[]), szIcon);
  g_rgrgiEffectIconColor[iId] = rgiIconColor;

  TrieSetCell(g_itEffectsIds, szId, iId);

  g_iEffectsNum++;

  return iId;
}

bool:Effect_CallInvokeFunction(const iId, const &pPlayer, Float:flDuration) {
  callfunc_begin_p(g_rgfnEffectInvokeFunction[iId]);
  callfunc_push_int(pPlayer);
  callfunc_push_float(flDuration);
  new iResult = callfunc_end();

  if (iResult >= PLUGIN_HANDLED) return false;

  return true;
}

bool:Effect_CallRevokeFunction(const iId, const &pPlayer, iRevokeBits = PlayerEffect_Revoke_Terminated) {
  callfunc_begin_p(g_rgfnEffectRevokeFunction[iId]);
  callfunc_push_int(pPlayer);
  callfunc_push_int(iRevokeBits);
  new iResult = callfunc_end();

  if (iResult >= PLUGIN_HANDLED) return false;

  return true;
}

/*--------------------------------[ Tasks ]--------------------------------*/

public Task_Update() {
  for (new pPlayer = 1; pPlayer <= MaxClients; ++pPlayer) {
    @Player_Update(pPlayer);
  }
}
