#pragma semicolon 1

#include <amxmodx>
#include <amxmisc>
#include <fakemeta>
#include <hamsandwich>

#include <command_util>

/*--------------------------------[ Constants ]--------------------------------*/

#define COSMETIC_CLASSNAME "_cosmetic"
#define MAX_ENTITIES 2048

/*--------------------------------[ Plugin State ]--------------------------------*/

new Float:g_flGameTime = 0.0;

/*--------------------------------[ Player State ]--------------------------------*/

new Trie:g_itPlayerCosmetics[MAX_PLAYERS + 1];
new Float:g_rgflPlayerNextRenderingUpdate[MAX_PLAYERS + 1];
new bool:g_rgbEntityIsCosmetic[MAX_ENTITIES + 1] = { false, ... };

/*--------------------------------[ Plugin Initialization ]--------------------------------*/

public plugin_precache() {
  register_forward(FM_OnFreeEntPrivateData, "FMHook_OnFreeEntPrivateData");
}

public plugin_init() {
  register_plugin("[API] Player Cosmetics", "1.0.0", "Hedgehog Fog");

  RegisterHam(Ham_Think, "info_target", "HamHook_Target_Think", .Post = 0);

  register_concmd("player_cosmetic_equip", "Command_Equip", ADMIN_CVAR);
  register_concmd("player_cosmetic_unequip", "Command_Unequip", ADMIN_CVAR);
}

public plugin_natives() {
  register_library("api_player_cosmetics");
  register_native("PlayerCosmetic_Equip", "Native_Equip");
  register_native("PlayerCosmetic_Unequip", "Native_Unequip");
  register_native("PlayerCosmetic_IsEquipped", "Native_IsEquipped");
  register_native("PlayerCosmetic_GetEntity", "Native_GetEntity");
}

/*--------------------------------[ Client Forwards ]--------------------------------*/

public server_frame() {
  g_flGameTime = get_gametime();
}

public client_connect(pPlayer) {
  g_itPlayerCosmetics[pPlayer] = TrieCreate();
  g_rgflPlayerNextRenderingUpdate[pPlayer] = g_flGameTime;
}

public client_disconnected(pPlayer) {
  for (new TrieIter:iIterator = TrieIterCreate(g_itPlayerCosmetics[pPlayer]); !TrieIterEnded(iIterator); TrieIterNext(iIterator)) {
    static pCosmetic; TrieIterGetCell(iIterator, pCosmetic);
    @PlayerCosmetic_Destroy(pCosmetic);
  }

  TrieDestroy(g_itPlayerCosmetics[pPlayer]);
}

/*--------------------------------[ Natives ]--------------------------------*/

public Native_Equip(const iPluginId, const iArgc) {
  new pPlayer = get_param(1);
  new iModelIndex = get_param(2);

  return @Player_EquipCosmetic(pPlayer, iModelIndex);
}

public Native_Unequip(const iPluginId, const iArgc) {
  new pPlayer = get_param(1);
  new iModelIndex = get_param(2);

  return @Player_UnequipCosmetic(pPlayer, iModelIndex);
}

public Native_IsEquipped(const iPluginId, const iArgc) {
  new pPlayer = get_param(1);
  new iModelIndex = get_param(2);

  return @Player_IsCosmeticEquipped(pPlayer, iModelIndex);
}

public Native_GetEntity(const iPluginId, const iArgc) {
  new pPlayer = get_param(1);
  new iModelIndex = get_param(2);

  return @Player_GetCosmeticEntity(pPlayer, iModelIndex);
}

/*--------------------------------[ Commands ]--------------------------------*/

public Command_Equip(const pPlayer, const iLevel, const iCId) {
  if (!cmd_access(pPlayer, iLevel, iCId, 2)) return PLUGIN_HANDLED;

  static szTarget[32]; read_argv(1, szTarget, charsmax(szTarget));
  static szModel[256]; read_argv(2, szModel, charsmax(szModel));

  new iTarget = CMD_RESOLVE_TARGET(szTarget);
  new iModelIndex = engfunc(EngFunc_ModelIndex, szModel);

  for (new pTarget = 1; pTarget <= MaxClients; ++pTarget) {
    if (CMD_SHOULD_TARGET_PLAYER(pTarget, iTarget, pPlayer)) {
      @Player_EquipCosmetic(pTarget, iModelIndex);
    }
  }

  return PLUGIN_HANDLED;
}

public Command_Unequip(const pPlayer, const iLevel, const iCId) {
  if (!cmd_access(pPlayer, iLevel, iCId, 2)) return PLUGIN_HANDLED;

  static szTarget[32]; read_argv(1, szTarget, charsmax(szTarget));
  static szModel[256]; read_argv(2, szModel, charsmax(szModel));

  new iTarget = CMD_RESOLVE_TARGET(szTarget);
  new iModelIndex = engfunc(EngFunc_ModelIndex, szModel);

  for (new pTarget = 1; pTarget <= MaxClients; ++pTarget) {
    if (CMD_SHOULD_TARGET_PLAYER(pTarget, iTarget, pPlayer)) {
      @Player_UnequipCosmetic(pTarget, iModelIndex);
    }
  }

  return PLUGIN_HANDLED;
}

/*--------------------------------[ Hooks ]--------------------------------*/

public FMHook_OnFreeEntPrivateData(const pEntity) {
  if (g_rgbEntityIsCosmetic[pEntity]) {
    new pOwner = pev(pEntity, pev_owner);

    if (pOwner) {
      new iModelIndex = pev(pEntity, pev_modelindex);
      static szModelIndex[8]; num_to_str(iModelIndex, szModelIndex, charsmax(szModelIndex));
      new pCosmetic; TrieGetCell(g_itPlayerCosmetics[pOwner], szModelIndex, pCosmetic);

      if (pCosmetic == pEntity) {
        TrieDeleteKey(g_itPlayerCosmetics[pOwner], szModelIndex);
      }
    }

    g_rgbEntityIsCosmetic[pEntity] = false;
  }
}

public HamHook_Target_Think(const pEntity) {
  if (g_rgbEntityIsCosmetic[pEntity]) {
    @PlayerCosmetic_Think(pEntity);
  }
}

/*--------------------------------[ Player Methods ]--------------------------------*/

@Player_EquipCosmetic(const &this, iModelIndex) {
  if (g_itPlayerCosmetics[this] == Invalid_Trie) return -1;

  static szModelIndex[8]; num_to_str(iModelIndex, szModelIndex, charsmax(szModelIndex));

  new pCosmetic = FM_NULLENT;
  if (TrieKeyExists(g_itPlayerCosmetics[this], szModelIndex)) {
    TrieGetCell(g_itPlayerCosmetics[this], szModelIndex, pCosmetic);
  } else {
    pCosmetic = @PlayerCosmetic_Create(this, iModelIndex);
    if (pCosmetic != FM_NULLENT) {
      TrieSetCell(g_itPlayerCosmetics[this], szModelIndex, pCosmetic);
    }
  }

  return pCosmetic;
}

bool:@Player_UnequipCosmetic(const &this, iModelIndex) {
  if (g_itPlayerCosmetics[this] == Invalid_Trie) return false;
  
  static szModelIndex[8]; num_to_str(iModelIndex, szModelIndex, charsmax(szModelIndex));

  static pCosmetic;
  if (!TrieGetCell(g_itPlayerCosmetics[this], szModelIndex, pCosmetic)) return false;

  @PlayerCosmetic_Destroy(pCosmetic);
  TrieDeleteKey(g_itPlayerCosmetics[this], szModelIndex);

  return true;
}

bool:@Player_IsCosmeticEquipped(const &this, iModelIndex) {
  if (g_itPlayerCosmetics[this] == Invalid_Trie) return false;

  static szModelIndex[8]; num_to_str(iModelIndex, szModelIndex, charsmax(szModelIndex));

  return TrieKeyExists(g_itPlayerCosmetics[this], szModelIndex);
}

@Player_GetCosmeticEntity(const &this, iModelIndex) {
  if (g_itPlayerCosmetics[this] == Invalid_Trie) return FM_NULLENT;

  static szModelIndex[8]; num_to_str(iModelIndex, szModelIndex, charsmax(szModelIndex));

  static pCosmetic;
  if (!TrieGetCell(g_itPlayerCosmetics[this], szModelIndex, pCosmetic)) return FM_NULLENT;

  return pCosmetic;
}

/*--------------------------------[ Cosmetic Methods ]--------------------------------*/

@PlayerCosmetic_Create(const &pPlayer, iModelIndex) {
  static iszClassname = 0;
  if (!iszClassname) {
    iszClassname = engfunc(EngFunc_AllocString, "info_target");
  }

  new this = engfunc(EngFunc_CreateNamedEntity, iszClassname);
  if (this == FM_NULLENT) return FM_NULLENT;

  if (this >= sizeof(g_rgbEntityIsCosmetic)) {
    engfunc(EngFunc_RemoveEntity, this);
    return FM_NULLENT;
  }

  set_pev(this, pev_classname, COSMETIC_CLASSNAME);
  set_pev(this, pev_movetype, MOVETYPE_FOLLOW);
  set_pev(this, pev_aiment, pPlayer);
  set_pev(this, pev_owner, pPlayer);
  set_pev(this, pev_modelindex, iModelIndex);

  set_pev(this, pev_nextthink, g_flGameTime);

  g_rgbEntityIsCosmetic[this] = true;

  return this;
}

@PlayerCosmetic_Think(const &this) {
  static pOwner; pOwner = pev(this, pev_owner);
  static iRenderMode; iRenderMode = pev(pOwner, pev_rendermode);
  static iRenderFx; iRenderFx = pev(pOwner, pev_renderfx);
  static Float:flRenderAmt; pev(pOwner, pev_renderamt, flRenderAmt);
  static Float:rgflRenderColor[3]; pev(pOwner, pev_rendercolor, rgflRenderColor);

  set_pev(this, pev_rendermode, iRenderMode);
  set_pev(this, pev_renderamt, flRenderAmt);
  set_pev(this, pev_renderfx, iRenderFx);
  set_pev(this, pev_rendercolor, rgflRenderColor);

  set_pev(this, pev_nextthink, g_flGameTime + 0.1);
}

@PlayerCosmetic_Destroy(const &this) {
  set_pev(this, pev_movetype, MOVETYPE_NONE);
  set_pev(this, pev_aiment, 0);
  set_pev(this, pev_owner, 0);
  set_pev(this, pev_flags, pev(this, pev_flags) | FL_KILLME);
  dllfunc(DLLFunc_Think, this);
}
