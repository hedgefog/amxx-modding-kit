#include <amxmodx>
#include <amxmisc>
#include <fakemeta>
#include <hamsandwich>

#tryinclude <reapi>

#if !defined _reapi_included
  #tryinclude <orpheu>
  #if defined _orpheu_included
    ;
  #endif
#endif

#pragma semicolon 1

#define IS_NULLSTR(%1) (%1[0] == 0)

#define NATIVE_ERROR_NOT_CONNECTED(%1) log_error(AMX_ERR_NATIVE, "User %d is not connected", %1)

#define MAX_SEQUENCES 101

new bool:g_bIsCStrike = false;
new g_iszSubModelClassname = 0;

new g_rgszDefaultPlayerModel[MAX_PLAYERS + 1][32];
new g_rgszCurrentPlayerModel[MAX_PLAYERS + 1][256];
new g_rgszCustomPlayerModel[MAX_PLAYERS + 1][256];
new g_rgiPlayerAnimationIndex[MAX_PLAYERS + 1];
new g_rgszPlayerAnimExtension[MAX_PLAYERS + 1][32];
new g_rgpPlayerSubModel[MAX_PLAYERS + 1];
new bool:g_rgbPlayerUseCustomModel[MAX_PLAYERS + 1];
new Float:g_rgflPlayerNextModelUpdate[MAX_PLAYERS + 1];

new Trie:g_itPlayerSequenceModelIndexes = Invalid_Trie;
new Trie:g_itPlayerSequences = Invalid_Trie;

public plugin_precache() {
  g_bIsCStrike = !!cstrike_running();
  g_iszSubModelClassname = engfunc(EngFunc_AllocString, "info_target");
  g_itPlayerSequenceModelIndexes = TrieCreate();
  g_itPlayerSequences = TrieCreate();
}

public plugin_init() {
  register_plugin("[API] Player Model", "1.1.0", "Hedgehog Fog");

  register_forward(FM_SetClientKeyValue, "FMHook_SetClientKeyValue");
  register_forward(FM_UpdateClientData, "FMHook_UpdateClientData");

  RegisterHamPlayer(Ham_Spawn, "HamHook_Player_Spawn_Post", .Post = 1);

  #if defined _reapi_included
    RegisterHookChain(RG_CBasePlayer_SetAnimation, "HC_Player_SetAnimation");
  #elseif defined _orpheu_included
    OrpheuRegisterHook(OrpheuGetFunction("SetAnimation", "CBasePlayer"), "OrpheuHook_Player_SetAnimation", OrpheuHookPre);
  #endif

  register_message(get_user_msgid("ClCorpse"), "Message_ClCorpse");
}

public plugin_natives() {
  register_library("api_player_model");
  register_native("PlayerModel_Get", "Native_GetPlayerModel");
  register_native("PlayerModel_GetCurrent", "Native_GetCurrentPlayerModel");
  register_native("PlayerModel_GetEntity", "Native_GetPlayerEntity");
  register_native("PlayerModel_HasCustom", "Native_HasCustomPlayerModel");
  register_native("PlayerModel_Set", "Native_SetPlayerModel");
  register_native("PlayerModel_Reset", "Native_ResetPlayerModel");
  register_native("PlayerModel_Update", "Native_UpdatePlayerModel");
  register_native("PlayerModel_UpdateAnimation", "Native_UpdatePlayerAnimation");
  register_native("PlayerModel_SetSequence", "Native_SetPlayerSequence");
  register_native("PlayerModel_PrecacheAnimation", "Native_PrecacheAnimation");
}

public plugin_end() {
  TrieDestroy(g_itPlayerSequenceModelIndexes);
  TrieDestroy(g_itPlayerSequences);
}

// ANCHOR: Natives

public Native_GetPlayerModel(const iPluginId, const iArgc) {
  new pPlayer = get_param(1);

  if (!is_user_connected(pPlayer)) {
    NATIVE_ERROR_NOT_CONNECTED(pPlayer);
    return;
  }

  set_string(2, g_rgszCustomPlayerModel[pPlayer], get_param(3));
}

public Native_GetCurrentPlayerModel(const iPluginId, const iArgc) {
  new pPlayer = get_param(1);

  if (!is_user_connected(pPlayer)) {
    NATIVE_ERROR_NOT_CONNECTED(pPlayer);
    return;
  }
  
  set_string(2, g_rgszCurrentPlayerModel[pPlayer], get_param(3));
}

public Native_GetPlayerEntity(const iPluginId, const iArgc) {
  new pPlayer = get_param(1);

  if (!is_user_connected(pPlayer)) {
    NATIVE_ERROR_NOT_CONNECTED(pPlayer);
    return FM_NULLENT;
  }

  if (g_rgpPlayerSubModel[pPlayer] != FM_NULLENT && !(pev(g_rgpPlayerSubModel[pPlayer], pev_effects) & EF_NODRAW)) {
    return g_rgpPlayerSubModel[pPlayer];
  }

  return pPlayer;
}

public bool:Native_HasCustomPlayerModel(const iPluginId, const iArgc) {
  new pPlayer = get_param(1);

  if (!is_user_connected(pPlayer)) {
    NATIVE_ERROR_NOT_CONNECTED(pPlayer);
    return false;
  }

  return g_rgbPlayerUseCustomModel[pPlayer];
}

public Native_SetPlayerModel(const iPluginId, const iArgc) {
  new pPlayer = get_param(1);

  if (!is_user_connected(pPlayer)) {
    NATIVE_ERROR_NOT_CONNECTED(pPlayer);
    return;
  }

  get_string(2, g_rgszCustomPlayerModel[pPlayer], charsmax(g_rgszCustomPlayerModel[]));
}

public Native_ResetPlayerModel(const iPluginId, const iArgc) {
  new pPlayer = get_param(1);

  if (!is_user_connected(pPlayer)) {
    NATIVE_ERROR_NOT_CONNECTED(pPlayer);
    return;
  }

  @Player_ResetModel(pPlayer);
}

public Native_UpdatePlayerModel(const iPluginId, const iArgc) {
  new pPlayer = get_param(1);
  
  if (!is_user_connected(pPlayer)) {
    NATIVE_ERROR_NOT_CONNECTED(pPlayer);
    return;
  }

  @Player_UpdateCurrentModel(pPlayer);
}

public Native_UpdatePlayerAnimation(const iPluginId, const iArgc) {
  new pPlayer = get_param(1);

  if (!is_user_connected(pPlayer)) {
    NATIVE_ERROR_NOT_CONNECTED(pPlayer);
    return;
  }

  @Player_UpdateAnimationModel(pPlayer);
}

public Native_SetPlayerSequence(const iPluginId, const iArgc) {
  new pPlayer = get_param(1);

  if (!is_user_connected(pPlayer)) {
    NATIVE_ERROR_NOT_CONNECTED(pPlayer);
    return 0;
  }

  static szSequence[MAX_RESOURCE_PATH_LENGTH]; get_string(2, szSequence, charsmax(szSequence));

  return @Player_SetSequence(pPlayer, szSequence);
}

public Native_PrecacheAnimation(const iPluginId, const iArgc) {
  static szAnimation[MAX_RESOURCE_PATH_LENGTH];
  get_string(1, szAnimation, charsmax(szAnimation));

  return PrecachePlayerAnimation(szAnimation);
}

// ANCHOR: Hooks and Forwards

public client_connect(pPlayer) {
  copy(g_rgszCustomPlayerModel[pPlayer], charsmax(g_rgszCustomPlayerModel[]), NULL_STRING);
  copy(g_rgszDefaultPlayerModel[pPlayer], charsmax(g_rgszDefaultPlayerModel[]), NULL_STRING);
  copy(g_rgszCurrentPlayerModel[pPlayer], charsmax(g_rgszCurrentPlayerModel[]), NULL_STRING);
  copy(g_rgszPlayerAnimExtension[pPlayer], charsmax(g_rgszPlayerAnimExtension[]), NULL_STRING);
  g_rgiPlayerAnimationIndex[pPlayer] = 0;
  g_rgbPlayerUseCustomModel[pPlayer] = false;
  g_rgflPlayerNextModelUpdate[pPlayer] = 0.0;
  g_rgpPlayerSubModel[pPlayer] = FM_NULLENT;
}

public client_disconnected(pPlayer) {
  if (g_rgpPlayerSubModel[pPlayer] != FM_NULLENT) {
    @PlayerSubModel_Destroy(g_rgpPlayerSubModel[pPlayer]);
    g_rgpPlayerSubModel[pPlayer] = FM_NULLENT;
  }
}

public FMHook_SetClientKeyValue(const pPlayer, const szInfoBuffer[], const szKey[], const szValue[]) {
  if (equal(szKey, "model")) {
    copy(g_rgszDefaultPlayerModel[pPlayer], charsmax(g_rgszDefaultPlayerModel[]), szValue);

    if (@Player_ShouldUseCurrentModel(pPlayer)) return FMRES_SUPERCEDE;

    return FMRES_HANDLED;
  }

  return FMRES_IGNORED;
}

public HamHook_Player_Spawn_Post(const pPlayer) {
  @Player_UpdateCurrentModel(pPlayer);

  return HAM_HANDLED;
}

public FMHook_UpdateClientData(const pPlayer) {
  if (g_rgpPlayerSubModel[pPlayer] != FM_NULLENT) {
    @PlayerSubModel_Think(g_rgpPlayerSubModel[pPlayer]);
  }

  if (@Player_ShouldUseCurrentModel(pPlayer)) {
    static szModel[MAX_RESOURCE_PATH_LENGTH]; get_user_info(pPlayer, "model", szModel, charsmax(szModel));

    if (!IS_NULLSTR(szModel)) {
      set_user_info(pPlayer, "model", NULL_STRING);
    }
  }

  if (!g_bIsCStrike) {
    static szModel[MAX_RESOURCE_PATH_LENGTH]; get_user_info(pPlayer, "model", szModel, charsmax(szModel));

    if (!IS_NULLSTR(szModel)) {
      copy(g_rgszDefaultPlayerModel[pPlayer], charsmax(g_rgszDefaultPlayerModel[]), szModel);
    }

    @Player_UpdateModel(pPlayer, false);
  }

  #if !defined _reapi_included && !defined _orpheu_included
    static Float:flGameTime; flGameTime = get_gametime();

    if (g_rgflPlayerNextModelUpdate[pPlayer] <= flGameTime) {
      if (is_user_alive(pPlayer)) {
        static szAnimExt[32]; get_ent_data_string(pPlayer, "CBasePlayer", "m_szAnimExtention", szAnimExt, charsmax(szAnimExt));

        if (!equal(szAnimExt, g_rgszPlayerAnimExtension[pPlayer])) {
          @Player_UpdateAnimationModel(pPlayer);
        }
      }

      g_rgflPlayerNextModelUpdate[pPlayer] = flGameTime + 0.1;
    }
  #endif

  return HAM_HANDLED;
}

#if defined _reapi_included
  public HC_Player_SetAnimation(const pPlayer) {
    @Player_UpdateAnimationModel(pPlayer);
  }
#endif

#if defined _orpheu_included
  public OrpheuHook_Player_SetAnimation(const pPlayer) {
    @Player_UpdateAnimationModel(pPlayer);
  }
#endif

public Message_ClCorpse(const iMsgId, const iMsgDest, const pPlayer) {
  new pTargetPlayer = get_msg_arg_int(12);
  if (@Player_ShouldUseCurrentModel(pTargetPlayer)) {
    set_msg_arg_string(1, g_rgszCurrentPlayerModel[pTargetPlayer]);
  }
}

// ANCHOR: Methods

@Player_UpdateAnimationModel(const &this) {
  new iAnimationIndex = 0;

  if (is_user_alive(this)) {
    static szAnimExt[32]; get_ent_data_string(this, "CBasePlayer", "m_szAnimExtention", szAnimExt, charsmax(szAnimExt));
    iAnimationIndex = GetAnimationIndexByAnimExt(szAnimExt);
  }
  
  if (iAnimationIndex != g_rgiPlayerAnimationIndex[this]) {
    g_rgiPlayerAnimationIndex[this] = iAnimationIndex;
    @Player_UpdateModel(this, !iAnimationIndex);
  }
}

@Player_UpdateCurrentModel(const &this) {
  new bool:bUsedCustom = g_rgbPlayerUseCustomModel[this];
  new bool:bSetDefaultModel = false;
  new bool:bReset = IS_NULLSTR(g_rgszCurrentPlayerModel[this]);

  g_rgbPlayerUseCustomModel[this] = !IS_NULLSTR(g_rgszCustomPlayerModel[this]);

  if (g_rgbPlayerUseCustomModel[this]) {
    copy(g_rgszCurrentPlayerModel[this], charsmax(g_rgszCurrentPlayerModel[]), g_rgszCustomPlayerModel[this]);
  } else if (!IS_NULLSTR(g_rgszDefaultPlayerModel[this])) {
    format(g_rgszCurrentPlayerModel[this], charsmax(g_rgszCurrentPlayerModel[]), "models/player/%s/%s.mdl", g_rgszDefaultPlayerModel[this], g_rgszDefaultPlayerModel[this]);
    bSetDefaultModel = true;
  }

  if (!g_bIsCStrike && bSetDefaultModel) {
    set_user_info(this, "model", g_rgszDefaultPlayerModel[this]);
  } else {
    @Player_UpdateModel(this, bReset || bUsedCustom && !g_rgbPlayerUseCustomModel[this]);
  }
}

@Player_UpdateModel(const &this, bool:bForceUpdate) {
  static iSubModelModelIndex; iSubModelModelIndex = 0;

  if (bForceUpdate || @Player_ShouldUseCurrentModel(this)) {
    new iAnimationIndex = g_rgiPlayerAnimationIndex[this];
    new iModelIndex = engfunc(EngFunc_ModelIndex, g_rgszCurrentPlayerModel[this]);
    @Player_SetModelIndex(this, iAnimationIndex ? iAnimationIndex : iModelIndex);
    iSubModelModelIndex = iAnimationIndex ? iModelIndex : 0;
  }

  if (iSubModelModelIndex && g_rgpPlayerSubModel[this] == FM_NULLENT) {
    g_rgpPlayerSubModel[this] = @PlayerSubModel_Create(this);
  }

  if (g_rgpPlayerSubModel[this] != FM_NULLENT) {
    if (iSubModelModelIndex) {
      set_pev(g_rgpPlayerSubModel[this], pev_modelindex, iSubModelModelIndex);
      set_pev(g_rgpPlayerSubModel[this], pev_effects, pev(g_rgpPlayerSubModel[this], pev_effects) & ~EF_NODRAW);
    } else {
      /*
        !!!HACKHACK: Setting modelindex to 0 causes update lag and flickering during animation changes
        Using EF_NODRAW effect to prevent flickering
      */
      set_pev(g_rgpPlayerSubModel[this], pev_effects, pev(g_rgpPlayerSubModel[this], pev_effects) | EF_NODRAW);
    }
  }
}

bool:@Player_ShouldUseCurrentModel(const &this) {
  return g_rgbPlayerUseCustomModel[this] || g_rgiPlayerAnimationIndex[this];
}

@Player_ResetModel(const &this) {
  if (IS_NULLSTR(g_rgszDefaultPlayerModel[this])) return;

  copy(g_rgszCustomPlayerModel[this], charsmax(g_rgszCustomPlayerModel[]), NULL_STRING);
  copy(g_rgszCurrentPlayerModel[this], charsmax(g_rgszCurrentPlayerModel[]), NULL_STRING);
  g_rgiPlayerAnimationIndex[this] = 0;

  @Player_UpdateCurrentModel(this);
}

@Player_SetModelIndex(const &this, iModelIndex) {
  set_user_info(this, "model", NULL_STRING);
  set_pev(this, pev_modelindex, iModelIndex);

  if (g_bIsCStrike) {
    set_ent_data(this, "CBasePlayer", "m_modelIndexPlayer", iModelIndex);
  }
}

@Player_SetSequence(const &this, const szSequence[]) {
  new iAnimationIndex = GetAnimationIndexBySequence(szSequence);
  if (!iAnimationIndex) return -1;

  g_rgiPlayerAnimationIndex[this] = iAnimationIndex;
  @Player_UpdateModel(this, false);

  new iSequence = GetSequenceIndex(szSequence);
  set_pev(this, pev_sequence, iSequence);

  return iSequence;
}

@PlayerSubModel_Create(const &pPlayer) {
  new this = engfunc(EngFunc_CreateNamedEntity, g_iszSubModelClassname);
  set_pev(this, pev_movetype, MOVETYPE_FOLLOW);
  set_pev(this, pev_aiment, pPlayer);
  set_pev(this, pev_owner, pPlayer);

  return this;
}

@PlayerSubModel_Destroy(const &this) {
  set_pev(this, pev_modelindex, 0);
  set_pev(this, pev_flags, pev(this, pev_flags) | FL_KILLME);
  dllfunc(DLLFunc_Think, this);
}

@PlayerSubModel_Think(const &this) {
  static pOwner; pOwner = pev(this, pev_owner);

  set_pev(this, pev_skin, pev(pOwner, pev_skin));
  set_pev(this, pev_body, pev(pOwner, pev_body));
  set_pev(this, pev_colormap, pev(pOwner, pev_colormap));
  set_pev(this, pev_rendermode, pev(pOwner, pev_rendermode));
  set_pev(this, pev_renderfx, pev(pOwner, pev_renderfx));
  set_pev(this, pev_effects, pev(this, pev_effects) & ~EF_NODRAW);

  static Float:flRenderAmt; pev(pOwner, pev_renderamt, flRenderAmt);
  set_pev(this, pev_renderamt, flRenderAmt);

  static rgflColor[3]; pev(pOwner, pev_rendercolor, rgflColor);
  set_pev(this, pev_rendercolor, rgflColor);
}

// ANCHOR: Functions

GetAnimationIndexByAnimExt(const szAnimExt[]) {
  if (IS_NULLSTR(szAnimExt)) return 0;

  static szSequence[32];
  static iAnimationIndex; iAnimationIndex = 0;
  
  if (!iAnimationIndex) {
    format(szSequence, charsmax(szSequence), "ref_aim_%s", szAnimExt);
    iAnimationIndex = GetAnimationIndexBySequence(szSequence);
  }

  if (!iAnimationIndex) {
    format(szSequence, charsmax(szSequence), "ref_shoot_%s", szAnimExt);
    iAnimationIndex = GetAnimationIndexBySequence(szSequence);
  }

  if (!iAnimationIndex) {
    format(szSequence, charsmax(szSequence), "ref_shoot2_%s", szAnimExt);
    iAnimationIndex = GetAnimationIndexBySequence(szSequence);
  }

  if (!iAnimationIndex) {
    format(szSequence, charsmax(szSequence), "ref_reload_%s", szAnimExt);
    iAnimationIndex = GetAnimationIndexBySequence(szSequence);
  }

  return iAnimationIndex;
}

GetAnimationIndexBySequence(const szSequence[]) {
  static iAnimationIndex;
  if (!TrieGetCell(g_itPlayerSequenceModelIndexes, szSequence, iAnimationIndex)) return 0;

  return iAnimationIndex;
}

GetSequenceIndex(const szSequence[]) {
  static iSequence;
  if (!TrieGetCell(g_itPlayerSequences, szSequence, iSequence)) return -1;

  return iSequence;
}

// Credis: HamletEagle
PrecachePlayerAnimation(const szAnim[]) {
  new szFilePath[MAX_RESOURCE_PATH_LENGTH]; format(szFilePath, charsmax(szFilePath), "animations/%s", szAnim);

  new iModelIndex = precache_model(szFilePath);

  new iFile = fopen(szFilePath, "rb", true);
  if (!iFile) return 0;
  
  // Got to "numseq" position of the studiohdr_t structure
  // https://github.com/dreamstalker/rehlds/blob/65c6ce593b5eabf13e92b03352e4b429d0d797b0/rehlds/public/rehlds/studio.h#L68
  fseek(iFile, 164, SEEK_SET);

  new iSeqNum;
  fread(iFile, iSeqNum, BLOCK_INT);

  if (iSeqNum) {
    new iSeqIndex;
    fread(iFile, iSeqIndex, BLOCK_INT);
    fseek(iFile, iSeqIndex, SEEK_SET);

    new szLabel[32];
    for (new i = 0; i < iSeqNum; i++) {
      if (i >= MAX_SEQUENCES) {
        log_amx("Warning! Sequence limit reached for ^"%s^". Max sequences %d.", szFilePath, MAX_SEQUENCES);
        break;
      }

      fread_blocks(iFile, szLabel, sizeof(szLabel), BLOCK_CHAR);
      TrieSetCell(g_itPlayerSequenceModelIndexes, szLabel, iModelIndex);
      TrieSetCell(g_itPlayerSequences, szLabel, i);

      // jump to the end of the studiohdr_t structure
      // https://github.com/dreamstalker/rehlds/blob/65c6ce593b5eabf13e92b03352e4b429d0d797b0/rehlds/public/rehlds/studio.h#L95
      fseek(iFile, 176 - sizeof(szLabel), SEEK_CUR);
    }
  }
  
  fclose(iFile);

  return iModelIndex;
}
