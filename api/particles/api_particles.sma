#pragma semicolon 1

#include <amxmodx>
#include <amxmisc>
#include <engine>
#include <fakemeta>
#include <hamsandwich>
#include <xs>

#include <function_pointer>

#include <api_particles_const>

#define BIT(%0) (1<<(%0))

#define PARTICLE_CLASSNAME "_particle"

#define GET_PARTICLE_ID(%1) (%1 < sizeof(g_rgiEntityParticleId) ? g_rgiEntityParticleId[%1] : -1)

#define UPDATE_RATE 0.01
#define VISIBILITY_UPDATE_RATE 0.25

#define MAX_ENTITIES 2024
#define MAX_EFFECTS 64
#define MAX_SYSTEMS 512
#define MAX_PARTICLES 4096
#define MAX_HOOKS_PER_EFFECT 8

enum PositionVars {
  Float:PositionVars_Origin[3],
  Float:PositionVars_Angles[3],
  Float:PositionVars_Velocity[3]
};

enum _:ParticleEffect {
  bool:ParticleEffect_Used,
  ParticleEffect_Id[32],
  ParticleEffect_EmitAmount,
  Float:ParticleEffect_EmitRate,
  Float:ParticleEffect_ParticleLifeTime,
  Float:ParticleEffect_VisibilityDistance,
  ParticleEffect_MaxParticles,
  ParticleEffectFlag:ParticleEffect_Flags,
  ParticleEffect_HooksNum[ParticleEffectHook]
};

enum _:ParticleSystem {
  bool:ParticleSystem_Used,
  ParticleSystem_EffectId,
  bool:ParticleSystem_Active,
  Float:ParticleSystem_EffectSpeed,
  ParticleSystem_ParentEntity,
  Float:ParticleSystem_CreatedTime,
  ParticleSystem_VisibilityBits,
  Float:ParticleSystem_KillTime,
  Array:ParticleSystem_Particles,
  Float:ParticleSystem_NextEmit,
  Float:ParticleSystem_NextVisibilityUpdate,
  Float:ParticleSystem_LastThink,
  Trie:ParticleSystem_Members,
  ParticleSystem_PositionVars[PositionVars]
};

enum _:Particle {
  bool:Particle_Used,
  Particle_Index,
  Particle_BatchIndex,
  Particle_Entity,
  Float:Particle_CreatedTime,
  Float:Particle_KillTime,
  Float:Particle_LastThink,
  Particle_SystemId,
  bool:Particle_Attached,
  Particle_PositionVars[PositionVars],
  Particle_AbsPositionVars[PositionVars]
};

new g_pCvarEnabled;
new bool:g_bEnabled;

new g_iszParticleClassName;
new g_pTrace;
new Float:g_flGameTime = 0.0;

new Float:g_flNextSystemsUpdate;
new g_pfwfmAddToFullPackPost;

// Effects storage
new Trie:g_itEffectsIds = Invalid_Trie;
new g_rgEffects[MAX_EFFECTS][ParticleEffect];
new Function:g_rgEffectHooks[MAX_EFFECTS][ParticleEffectHook][MAX_HOOKS_PER_EFFECT];
new Float:g_rgvecPlayerEyePosition[MAX_PLAYERS + 1][3];
new g_iPlayerConnectedBits = 0;
new g_iEffectsNum = 0;

// Systems storage
new g_rgsSystem[MAX_SYSTEMS][ParticleSystem];
new g_iSystemsNum = 0;

// Particles storage (global pool)
new g_rgParticles[MAX_PARTICLES][Particle];
new g_iParticlesNum = 0;

new g_rgiEntityParticleId[MAX_ENTITIES + 1] = { -1, ... };

public plugin_precache() {
  g_flNextSystemsUpdate = 0.0;
  g_itEffectsIds = TrieCreate();
  g_iszParticleClassName = engfunc(EngFunc_AllocString, "info_target");
  g_pTrace = create_tr2();
}

public plugin_init() {
  register_plugin("[API] Particles", "1.0.0", "Hedgehog Fog");

  g_pCvarEnabled = register_cvar("particles", "1");
  bind_pcvar_num(g_pCvarEnabled, g_bEnabled);
  hook_cvar_change(g_pCvarEnabled, "CvarHook_Enabled");

  register_forward(FM_OnFreeEntPrivateData, "FMHook_OnFreeEntPrivateData");
  
  register_concmd("particle_create", "Command_Create", ADMIN_CVAR);
}

public plugin_natives() {
  register_library("api_particles");

  register_native("ParticleEffect_Register", "Native_RegisterParticleEffect");
  register_native("ParticleEffect_RegisterHook", "Native_RegisterParticleEffectHook");

  register_native("ParticleSystem_Create", "Native_CreateParticleSystem");
  register_native("ParticleSystem_Destroy", "Native_DestroyParticleSystem");
  register_native("ParticleSystem_Activate", "Native_ActivateParticleSystem");
  register_native("ParticleSystem_Deactivate", "Native_DeactivateParticleSystem");
  register_native("ParticleSystem_GetEffectSpeed", "Native_GetParticleSystemEffectSpeed");
  register_native("ParticleSystem_SetEffectSpeed", "Native_SetParticleSystemEffectSpeed");
  register_native("ParticleSystem_GetCreatedTime", "Native_GetParticleSystemCreatedTime");
  register_native("ParticleSystem_GetKillTime", "Native_GetParticleSystemKillTime");
  register_native("ParticleSystem_GetLastThinkTime", "Native_GetParticleSystemLastThink");
  register_native("ParticleSystem_GetVisibilityBits", "Native_GetParticleSystemVisibilityBits");
  register_native("ParticleSystem_GetOrigin", "Native_GetParticleSystemOrigin");
  register_native("ParticleSystem_SetOrigin", "Native_SetParticleSystemOrigin");
  register_native("ParticleSystem_GetAngles", "Native_GetParticleSystemAngles");
  register_native("ParticleSystem_SetAngles", "Native_SetParticleSystemAngles");
  register_native("ParticleSystem_GetParentEntity", "Native_GetParticleSystemParentEntity");
  register_native("ParticleSystem_SetParentEntity", "Native_SetParticleSystemParentEntity");
  register_native("ParticleSystem_GetEffect", "Native_GetParticleSystemEffect");
  register_native("ParticleSystem_SetEffect", "Native_SetParticleSystemEffect");
  register_native("ParticleSystem_HasMember", "Native_HasMember");
  register_native("ParticleSystem_DeleteMember", "Native_DeleteMember");
  register_native("ParticleSystem_GetMember", "Native_GetMember");
  register_native("ParticleSystem_SetMember", "Native_SetMember");
  register_native("ParticleSystem_GetMemberVec", "Native_GetMemberVec");
  register_native("ParticleSystem_SetMemberVec", "Native_SetMemberVec");
  register_native("ParticleSystem_GetMemberString", "Native_GetMemberString");
  register_native("ParticleSystem_SetMemberString", "Native_SetMemberString");

  register_native("Particle_GetIndex", "Native_GetParticleIndex");
  register_native("Particle_GetBatchIndex", "Native_GetParticleBatchIndex");
  register_native("Particle_GetEntity", "Native_GetParticleEntity");
  register_native("Particle_GetSystem", "Native_GetParticleSystem");
  register_native("Particle_GetCreatedTime", "Native_GetParticleCreatedTime");
  register_native("Particle_GetKillTime", "Native_GetParticleKillTime");
  register_native("Particle_GetLastThink", "Native_GetParticleLastThink");
  register_native("Particle_GetOrigin", "Native_GetParticleOrigin");
  register_native("Particle_SetOrigin", "Native_SetParticleOrigin");
  register_native("Particle_GetAngles", "Native_GetParticleAngles");
  register_native("Particle_SetAngles", "Native_SetParticleAngles");
  register_native("Particle_GetVelocity", "Native_GetParticleVelocity");
  register_native("Particle_SetVelocity", "Native_SetParticleVelocity");
}

public plugin_end() {
  for (new iSystem = 0; iSystem < g_iSystemsNum; ++iSystem) {
    if (!g_rgsSystem[iSystem][ParticleSystem_Used]) continue;

    @ParticleSystem_Destroy(iSystem);
  }

  TrieDestroy(g_itEffectsIds);
  free_tr2(g_pTrace);
}

/*--------------------------------[ Natives ]--------------------------------*/

public Native_RegisterParticleEffect(const iPluginId, const iArgc) {
  new szName[32]; get_string(1, szName, charsmax(szName));
  new Float:flEmitRate = get_param_f(2);
  new Float:flParticleLifeTime = get_param_f(3);
  new iMaxParticles = get_param(4);
  new iEmitAmount = get_param(5);
  new Float:flVisibilityDistance = get_param_f(6);
  new ParticleEffectFlag:iFlags = ParticleEffectFlag:get_param(7);

  if (TrieKeyExists(g_itEffectsIds, szName)) {
    log_error(AMX_ERR_NATIVE, "Particle effect ^"%s^" is already registered.", szName);
    return INVALID_HANDLE;
  }

  return @ParticleEffect_Create(szName, flEmitRate, flParticleLifeTime, flVisibilityDistance, iMaxParticles, iEmitAmount, iFlags);
}

public Native_RegisterParticleEffectHook(const iPluginId, const iArgc) {
  new szName[32]; get_string(1, szName, charsmax(szName));
  new ParticleEffectHook:iHookId = ParticleEffectHook:get_param(2);
  new szCallback[64]; get_string(3, szCallback, charsmax(szCallback));

  static iEffectId;
  if (!TrieGetCell(g_itEffectsIds, szName, iEffectId)) {
    log_error(AMX_ERR_NATIVE, "[Particles] Effect ^"%s^" is not registered!", szName);
    return;
  }

  new Function:fnCallback = get_func_pointer(szCallback, iPluginId);

  if (fnCallback == Invalid_FunctionPointer) {
    log_error(AMX_ERR_NATIVE, "[Particles] Function ^"%s^" is not found!", szCallback);
    return;
  }

  new iHookIndex = g_rgEffects[iEffectId][ParticleEffect_HooksNum][iHookId];
  if (iHookIndex >= MAX_HOOKS_PER_EFFECT) {
    log_error(AMX_ERR_NATIVE, "[Particles] Max hooks limit reached for effect ^"%s^"!", szName);
    return;
  }

  g_rgEffectHooks[iEffectId][iHookId][iHookIndex] = fnCallback;
  g_rgEffects[iEffectId][ParticleEffect_HooksNum][iHookId]++;
}

public Native_CreateParticleSystem(const iPluginId, const iArgc) {
  new szName[32]; get_string(1, szName, charsmax(szName));
  new Float:vecOrigin[3]; get_array_f(2, vecOrigin, sizeof(vecOrigin));
  new Float:vecAngles[3]; get_array_f(3, vecAngles, sizeof(vecAngles));
  new pParent; pParent = get_param(4);

  new iEffectId;
  if (!TrieGetCell(g_itEffectsIds, szName, iEffectId)) {
    log_error(AMX_ERR_NATIVE, "[Particles] Effect ^"%s^" is not registered!", szName);
    return INVALID_HANDLE;
  }

  new iSystemId = @ParticleSystem_Create(iEffectId, vecOrigin, vecAngles, pParent);

  return iSystemId;
}

public Native_DestroyParticleSystem(const iPluginId, const iArgc) {
  static iSystemId; iSystemId = get_param_byref(1);

  g_rgsSystem[iSystemId][ParticleSystem_KillTime] = g_flGameTime;

  set_param_byref(1, INVALID_HANDLE);
}

public Float:Native_ActivateParticleSystem(const iPluginId, const iArgc) {
  static iSystemId; iSystemId = get_param_byref(1);

  g_rgsSystem[iSystemId][ParticleSystem_Active] = true;
}

public Float:Native_DeactivateParticleSystem(const iPluginId, const iArgc) {
  static iSystemId; iSystemId = get_param_byref(1);

  g_rgsSystem[iSystemId][ParticleSystem_Active] = false;
}

public Float:Native_GetParticleSystemEffectSpeed(const iPluginId, const iArgc) {
  static iSystemId; iSystemId = get_param_byref(1);

  return g_rgsSystem[iSystemId][ParticleSystem_EffectSpeed];
}

public Native_SetParticleSystemEffectSpeed(const iPluginId, const iArgc) {
  static iSystemId; iSystemId = get_param_byref(1);
  static Float:flSpeed; flSpeed = get_param_f(2);

  g_rgsSystem[iSystemId][ParticleSystem_EffectSpeed] = flSpeed;
}

public Float:Native_GetParticleSystemCreatedTime(const iPluginId, const iArgc) {
  static iSystemId; iSystemId = get_param_byref(1);

  return g_rgsSystem[iSystemId][ParticleSystem_CreatedTime];
}

public Float:Native_GetParticleSystemKillTime(const iPluginId, const iArgc) {
  static iSystemId; iSystemId = get_param_byref(1);

  return g_rgsSystem[iSystemId][ParticleSystem_KillTime];
}

public Native_GetParticleSystemLastThink(const iPluginId, const iArgc) {
  static iSystemId; iSystemId = get_param_byref(1);

  return _:g_rgsSystem[iSystemId][ParticleSystem_LastThink];
}

public Native_GetParticleSystemVisibilityBits(const iPluginId, const iArgc) {
  static iSystemId; iSystemId = get_param_byref(1);

  return g_rgsSystem[iSystemId][ParticleSystem_VisibilityBits];
}

public Native_GetParticleSystemOrigin(const iPluginId, const iArgc) {
  static iSystemId; iSystemId = get_param_byref(1);

  set_array_f(2, g_rgsSystem[iSystemId][ParticleSystem_PositionVars][PositionVars_Origin], 3);
}

public Native_SetParticleSystemOrigin(const iPluginId, const iArgc) {
  static iSystemId; iSystemId = get_param_byref(1);
  get_array_f(2, g_rgsSystem[iSystemId][ParticleSystem_PositionVars][PositionVars_Origin], 3);
}

public Native_GetParticleSystemAngles(const iPluginId, const iArgc) {
  static iSystemId; iSystemId = get_param_byref(1);

  set_array_f(2, g_rgsSystem[iSystemId][ParticleSystem_PositionVars][PositionVars_Angles], 3);
}

public Native_SetParticleSystemAngles(const iPluginId, const iArgc) {
  static iSystemId; iSystemId = get_param_byref(1);
  get_array_f(2, g_rgsSystem[iSystemId][ParticleSystem_PositionVars][PositionVars_Angles], 3);
}

public Native_GetParticleSystemParentEntity(const iPluginId, const iArgc) {
  static iSystemId; iSystemId = get_param_byref(1);
  
  return g_rgsSystem[iSystemId][ParticleSystem_ParentEntity];
}

public Native_SetParticleSystemParentEntity(const iPluginId, const iArgc) {
  static iSystemId; iSystemId = get_param_byref(1);
  static pParent; pParent = get_param(2);

  g_rgsSystem[iSystemId][ParticleSystem_ParentEntity] = pParent;
}

public Native_GetParticleSystemEffect(const iPluginId, const iArgc) {
  static iSystemId; iSystemId = get_param_byref(1);

  static iEffectId; iEffectId = g_rgsSystem[iSystemId][ParticleSystem_EffectId];

  set_string(2, g_rgEffects[iEffectId][ParticleEffect_Id], get_param(3));
}

public Native_SetParticleSystemEffect(const iPluginId, const iArgc) {
  static iSystemId; iSystemId = get_param_byref(1);
  static szName[32]; get_string(2, szName, charsmax(szName));

  static iEffectId;
  if (!TrieGetCell(g_itEffectsIds, szName, iEffectId)) {
    log_error(AMX_ERR_NATIVE, "[Particles] Effect ^"%s^" is not registered!", szName);
    return;
  }

  g_rgsSystem[iSystemId][ParticleSystem_EffectId] = iEffectId;
}

public bool:Native_HasMember(const iPluginId, const iArgc) {
  static iSystemId; iSystemId = get_param_byref(1);
  static szMember[PARTICLE_MAX_MEMBER_LENGTH]; get_string(2, szMember, charsmax(szMember));

  static Trie:itMembers; itMembers = g_rgsSystem[iSystemId][ParticleSystem_Members];

  return TrieKeyExists(itMembers, szMember);
}

public Native_DeleteMember(const iPluginId, const iArgc) {
  static iSystemId; iSystemId = get_param_byref(1);
  static szMember[PARTICLE_MAX_MEMBER_LENGTH]; get_string(2, szMember, charsmax(szMember));

  static Trie:itMembers; itMembers = g_rgsSystem[iSystemId][ParticleSystem_Members];

  TrieDeleteKey(itMembers, szMember);
}

public any:Native_GetMember(const iPluginId, const iArgc) {
  static iSystemId; iSystemId = get_param_byref(1);
  static szMember[PARTICLE_MAX_MEMBER_LENGTH]; get_string(2, szMember, charsmax(szMember));

  static Trie:itMembers; itMembers = g_rgsSystem[iSystemId][ParticleSystem_Members];

  static iValue;
  if (!TrieGetCell(itMembers, szMember, iValue)) return 0;

  return iValue;
}

public Native_SetMember(const iPluginId, const iArgc) {
  static iSystemId; iSystemId = get_param_byref(1);
  static szMember[PARTICLE_MAX_MEMBER_LENGTH]; get_string(2, szMember, charsmax(szMember));
  static iValue; iValue = get_param(3);

  static Trie:itMembers; itMembers = g_rgsSystem[iSystemId][ParticleSystem_Members];

  TrieSetCell(itMembers, szMember, iValue);
}

public bool:Native_GetMemberVec(const iPluginId, const iArgc) {
  static iSystemId; iSystemId = get_param_byref(1);
  static szMember[PARTICLE_MAX_MEMBER_LENGTH]; get_string(2, szMember, charsmax(szMember));

  static Trie:itMembers; itMembers = g_rgsSystem[iSystemId][ParticleSystem_Members];

  static Float:vecValue[3];
  if (!TrieGetArray(itMembers, szMember, vecValue, 3)) return false;

  set_array_f(3, vecValue, sizeof(vecValue));

  return true;
}

public Native_SetMemberVec(const iPluginId, const iArgc) {
  static iSystemId; iSystemId = get_param_byref(1);
  static szMember[PARTICLE_MAX_MEMBER_LENGTH]; get_string(2, szMember, charsmax(szMember));
  static Float:vecValue[3]; get_array_f(3, vecValue, sizeof(vecValue));

  static Trie:itMembers; itMembers = g_rgsSystem[iSystemId][ParticleSystem_Members];
  TrieSetArray(itMembers, szMember, vecValue, 3);
}

public bool:Native_GetMemberString(const iPluginId, const iArgc) {
  static iSystemId; iSystemId = get_param_byref(1);
  static szMember[PARTICLE_MAX_MEMBER_LENGTH]; get_string(2, szMember, charsmax(szMember));

  static Trie:itMembers; itMembers = g_rgsSystem[iSystemId][ParticleSystem_Members];

  static szValue[128];
  if (!TrieGetString(itMembers, szMember, szValue, charsmax(szValue))) return false;

  set_string(3, szValue, get_param(4));

  return true;
}

public Native_SetMemberString(const iPluginId, const iArgc) {
  static iSystemId; iSystemId = get_param_byref(1);
  static szMember[PARTICLE_MAX_MEMBER_LENGTH]; get_string(2, szMember, charsmax(szMember));
  static szValue[128]; get_string(3, szValue, charsmax(szValue));

  static Trie:itMembers; itMembers = g_rgsSystem[iSystemId][ParticleSystem_Members];
  TrieSetString(itMembers, szMember, szValue);
}

public Native_GetParticleOrigin(const iPluginId, const iArgc) {
  static iParticleId; iParticleId = get_param_byref(1);

  set_array_f(2, g_rgParticles[iParticleId][Particle_PositionVars][PositionVars_Origin], 3);
}

public Native_SetParticleOrigin(const iPluginId, const iArgc) {
  static iParticleId; iParticleId = get_param_byref(1);
  get_array_f(2, g_rgParticles[iParticleId][Particle_PositionVars][PositionVars_Origin], 3);
}

public Native_GetParticleAngles(const iPluginId, const iArgc) {
  static iParticleId; iParticleId = get_param_byref(1);

  set_array_f(2, g_rgParticles[iParticleId][Particle_PositionVars][PositionVars_Angles], 3);
}

public Native_SetParticleAngles(const iPluginId, const iArgc) {
  static iParticleId; iParticleId = get_param_byref(1);

  get_array_f(2, g_rgParticles[iParticleId][Particle_PositionVars][PositionVars_Angles], 3);
}

public Native_GetParticleVelocity(const iPluginId, const iArgc) {
  static iParticleId; iParticleId = get_param_byref(1);

  set_array_f(2, g_rgParticles[iParticleId][Particle_PositionVars][PositionVars_Velocity], 3);
}

public Native_SetParticleVelocity(const iPluginId, const iArgc) {
  static iParticleId; iParticleId = get_param_byref(1);

  get_array_f(2, g_rgParticles[iParticleId][Particle_PositionVars][PositionVars_Velocity], 3);
}

public Native_GetParticleIndex(const iPluginId, const iArgc) {
  static iParticleId; iParticleId = get_param_byref(1);

  return g_rgParticles[iParticleId][Particle_Index];
}

public Native_GetParticleBatchIndex(const iPluginId, const iArgc) {
  static iParticleId; iParticleId = get_param_byref(1);

  return g_rgParticles[iParticleId][Particle_BatchIndex];
}

public Native_GetParticleEntity(const iPluginId, const iArgc) {
  static iParticleId; iParticleId = get_param_byref(1);

  return g_rgParticles[iParticleId][Particle_Entity];
}

public Native_GetParticleSystem(const iPluginId, const iArgc) {
  static iParticleId; iParticleId = get_param_byref(1);

  return g_rgParticles[iParticleId][Particle_SystemId];
}

public Float:Native_GetParticleCreatedTime(const iPluginId, const iArgc) {
  static iParticleId; iParticleId = get_param_byref(1);

  return g_rgParticles[iParticleId][Particle_CreatedTime];
}

public Float:Native_GetParticleKillTime(const iPluginId, const iArgc) {
  static iParticleId; iParticleId = get_param_byref(1);

  return g_rgParticles[iParticleId][Particle_KillTime];
}

public Float:Native_GetParticleLastThink(const iPluginId, const iArgc) {
  static iParticleId; iParticleId = get_param_byref(1);

  return g_rgParticles[iParticleId][Particle_LastThink];
}

/*--------------------------------[ Forwards ]--------------------------------*/

public server_frame() {
  g_flGameTime = get_gametime();

  if (g_bEnabled) {
    // Cache player eye positions and connected bits
    if (g_iSystemsNum) {
      for (new pPlayer = 1; pPlayer <= MaxClients; ++pPlayer) {
        if (is_user_connected(pPlayer)) {
          g_iPlayerConnectedBits |= BIT(pPlayer & 31);
          ExecuteHam(Ham_EyePosition, pPlayer, g_rgvecPlayerEyePosition[pPlayer]);
        } else {
          g_iPlayerConnectedBits &= ~BIT(pPlayer & 31);
        }
      }
    }

    if (g_flNextSystemsUpdate <= g_flGameTime) {
      UpdateSystems();
      g_flNextSystemsUpdate = g_flGameTime + UPDATE_RATE;
    }
  }
}

/*--------------------------------[ Hooks ]--------------------------------*/

public Command_Create(const pPlayer, const iLevel, const iCId) {
  if (!cmd_access(pPlayer, iLevel, iCId, 2)) return PLUGIN_HANDLED;

  static szName[32]; read_argv(1, szName, charsmax(szName));

  if (equal(szName, NULL_STRING)) return PLUGIN_HANDLED;

  static Float:vecOrigin[3]; pev(pPlayer, pev_origin, vecOrigin);
  static Float:vecAngles[3]; pev(pPlayer, pev_angles, vecAngles);

  static iEffectId;
  if (!TrieGetCell(g_itEffectsIds, szName, iEffectId)) return PLUGIN_HANDLED;

  static iSystemId; iSystemId = @ParticleSystem_Create(iEffectId, vecOrigin, vecAngles, 0);
  g_rgsSystem[iSystemId][ParticleSystem_Active] = true;

  return PLUGIN_HANDLED;
}

public FMHook_AddToFullPack_Post(const es, const e, const pEntity, const pHost, const iHostFlags, const iPlayer, const iSetFlags) {
  static iParticleId; iParticleId = GET_PARTICLE_ID(pEntity);

  if (iParticleId != -1) {
    if (!g_rgParticles[iParticleId][Particle_Used]) return FMRES_SUPERCEDE;
    
    static iSystemId; iSystemId = g_rgParticles[iParticleId][Particle_SystemId];

    if (~g_rgsSystem[iSystemId][ParticleSystem_VisibilityBits] & BIT(pHost & 31)) return FMRES_SUPERCEDE;

    return FMRES_HANDLED;
  }

  return FMRES_IGNORED;
}

public FMHook_OnFreeEntPrivateData(const pEntity) {
  if (g_rgiEntityParticleId[pEntity] != -1) {
    @Particle_Destroy(g_rgiEntityParticleId[pEntity]);
  }
}

public CvarHook_Enabled() {
  if (!get_pcvar_num(g_pCvarEnabled)) {
    FreeParticles();
  }
}

/*--------------------------------[ ParticleEffect Methods ]--------------------------------*/

@ParticleEffect_Create(const szName[], Float:flEmitRate, Float:flParticleLifeTime, Float:flVisibilityDistance, iMaxParticles, iEmitAmount, ParticleEffectFlag:iFlags) {
  new iId = g_iEffectsNum;

  copy(g_rgEffects[iId][ParticleEffect_Id], charsmax(g_rgEffects[][ParticleEffect_Id]), szName);
  g_rgEffects[iId][ParticleEffect_Used] = true;
  g_rgEffects[iId][ParticleEffect_EmitRate] = flEmitRate;
  g_rgEffects[iId][ParticleEffect_EmitAmount] = iEmitAmount;
  g_rgEffects[iId][ParticleEffect_VisibilityDistance] = flVisibilityDistance;
  g_rgEffects[iId][ParticleEffect_ParticleLifeTime] = flParticleLifeTime;
  g_rgEffects[iId][ParticleEffect_MaxParticles] = iMaxParticles;
  g_rgEffects[iId][ParticleEffect_Flags] = iFlags;

  for (new ParticleEffectHook:iHookId = ParticleEffectHook:0; iHookId < ParticleEffectHook; ++iHookId) {
    g_rgEffects[iId][ParticleEffect_HooksNum][iHookId] = 0;
  }

  TrieSetCell(g_itEffectsIds, szName, iId);

  g_iEffectsNum++;

  return iId;
}

static @ParticleEffect_ExecuteHook(const iId, ParticleEffectHook:iHook, any:context, any:...) {
  new iResult = 0;

  new iHooksNum = g_rgEffects[iId][ParticleEffect_HooksNum][iHook];
  for (new iHookIndex = 0; iHookIndex < iHooksNum; ++iHookIndex) {
    if (callfunc_begin_p(g_rgEffectHooks[iId][iHook][iHookIndex]) == 1) {
      callfunc_push_int(context);

      switch (iHook) {
        case ParticleEffectHook_Particle_EntityInit: {
          callfunc_push_int(getarg(3));
        }
      }

      iResult = max(iResult, callfunc_end());
    }
  }

  return iResult;
}

/*--------------------------------[ ParticleSystem Methods ]--------------------------------*/

AllocateSystemId() {
  for (new iSystem = 0; iSystem < g_iSystemsNum; ++iSystem) {
    if (!g_rgsSystem[iSystem][ParticleSystem_Used]) return iSystem;
  }

  return g_iSystemsNum++;
}

CalculateSystemsNum() {
  new iNum = 0;

  for (new iSystem = 0; iSystem < g_iSystemsNum; ++iSystem) {
    if (!g_rgsSystem[iSystem][ParticleSystem_Used]) continue;
    iNum++;
  }

  return iNum;
}

@ParticleSystem_Create(const iEffectId, const Float:vecOrigin[3], const Float:vecAngles[3], const pParent) {
  new iId = AllocateSystemId();

  new iMaxParticles = g_rgEffects[iEffectId][ParticleEffect_MaxParticles];

  new Array:irgParticles = ArrayCreate(1, iMaxParticles);
  for (new i = 0; i < iMaxParticles; ++i) ArrayPushCell(irgParticles, INVALID_HANDLE);

  g_rgsSystem[iId][ParticleSystem_Used] = true;
  g_rgsSystem[iId][ParticleSystem_EffectId] = iEffectId;
  g_rgsSystem[iId][ParticleSystem_ParentEntity] = pParent;
  g_rgsSystem[iId][ParticleSystem_Particles] = irgParticles;
  g_rgsSystem[iId][ParticleSystem_CreatedTime] = g_flGameTime;
  g_rgsSystem[iId][ParticleSystem_KillTime] = 0.0;
  g_rgsSystem[iId][ParticleSystem_EffectSpeed] = 1.0;
  g_rgsSystem[iId][ParticleSystem_Active] = false;
  g_rgsSystem[iId][ParticleSystem_NextEmit] = 0.0;
  g_rgsSystem[iId][ParticleSystem_NextVisibilityUpdate] = 0.0;
  g_rgsSystem[iId][ParticleSystem_Members] = TrieCreate();
  g_rgsSystem[iId][ParticleSystem_VisibilityBits] = 0;
  g_rgsSystem[iId][ParticleSystem_LastThink] = 0.0;

  xs_vec_copy(vecOrigin, g_rgsSystem[iId][ParticleSystem_PositionVars][PositionVars_Origin]);
  xs_vec_copy(vecAngles, g_rgsSystem[iId][ParticleSystem_PositionVars][PositionVars_Angles]);
  xs_vec_copy(Float:{0.0, 0.0, 0.0}, g_rgsSystem[iId][ParticleSystem_PositionVars][PositionVars_Velocity]);

  @ParticleEffect_ExecuteHook(iEffectId, ParticleEffectHook_System_Init, iId);

  if (!g_pfwfmAddToFullPackPost) {
    g_pfwfmAddToFullPackPost = register_forward(FM_AddToFullPack, "FMHook_AddToFullPack_Post", 1);
  }

  return iId;
}

@ParticleSystem_Destroy(const iId) {
  new Array:irgParticles = g_rgsSystem[iId][ParticleSystem_Particles];
  new iParticlesNum = ArraySize(irgParticles);

  @ParticleEffect_ExecuteHook(g_rgsSystem[iId][ParticleSystem_EffectId], ParticleEffectHook_System_Destroy, iId);

  for (new iParticle = 0; iParticle < iParticlesNum; ++iParticle) {
    new iParticleId = ArrayGetCell(irgParticles, iParticle);
    if (iParticleId == INVALID_HANDLE) continue;

    engfunc(EngFunc_RemoveEntity, g_rgParticles[iParticleId][Particle_Entity]);
  }

  ArrayDestroy(irgParticles);
  TrieDestroy(g_rgsSystem[iId][ParticleSystem_Members]);

  g_rgsSystem[iId][ParticleSystem_Used] = false;

  if (!CalculateSystemsNum()) {
    unregister_forward(FM_AddToFullPack, g_pfwfmAddToFullPackPost, 1);
    g_pfwfmAddToFullPackPost = 0;
  }
}

@ParticleSystem_FreeParticles(const iId) {
  new Array:irgParticles = g_rgsSystem[iId][ParticleSystem_Particles];
  new iParticlesNum = ArraySize(irgParticles);

  for (new iParticle = 0; iParticle < iParticlesNum; ++iParticle) {
    new iParticleId = ArrayGetCell(irgParticles, iParticle);
    if (iParticleId == INVALID_HANDLE) continue;

    engfunc(EngFunc_RemoveEntity, g_rgParticles[iParticleId][Particle_Entity]);

    ArraySetCell(irgParticles, iParticle, INVALID_HANDLE);
  }
}

@ParticleSystem_Update(const iId) {
  static iEffectId; iEffectId = g_rgsSystem[iId][ParticleSystem_EffectId];
  static Array:irgParticles; irgParticles = g_rgsSystem[iId][ParticleSystem_Particles];
  static iVisibilityBits; iVisibilityBits = g_rgsSystem[iId][ParticleSystem_VisibilityBits];
  static bool:bActive; bActive = g_rgsSystem[iId][ParticleSystem_Active];
  static iParticlesNum; iParticlesNum = ArraySize(irgParticles);
  static Float:flSpeed; flSpeed = g_rgsSystem[iId][ParticleSystem_EffectSpeed];

  static Float:flDelta; flDelta = g_flGameTime - g_rgsSystem[iId][ParticleSystem_LastThink];

  static Float:vecOrigin[3]; xs_vec_copy(g_rgsSystem[iId][ParticleSystem_PositionVars][PositionVars_Origin], vecOrigin);
  static Float:vecVelocity[3]; xs_vec_copy(g_rgsSystem[iId][ParticleSystem_PositionVars][PositionVars_Velocity], vecVelocity);
  static Float:vecAngles[3]; xs_vec_copy(g_rgsSystem[iId][ParticleSystem_PositionVars][PositionVars_Angles], vecAngles);

  xs_vec_add_scaled(vecOrigin, vecVelocity, flDelta * flSpeed, vecOrigin);
  xs_vec_copy(vecOrigin, g_rgsSystem[iId][ParticleSystem_PositionVars][PositionVars_Origin]);

  @ParticleEffect_ExecuteHook(iEffectId, ParticleEffectHook_System_Think, iId);

  // Emit particles
  if (bActive) {
    static Float:flNextEmit; flNextEmit = g_rgsSystem[iId][ParticleSystem_NextEmit];
    if (iVisibilityBits && flNextEmit <= g_flGameTime) {
      static Float:flEmitRate; flEmitRate = g_rgEffects[iEffectId][ParticleEffect_EmitRate];
      static iEmitAmount; iEmitAmount = g_rgEffects[iEffectId][ParticleEffect_EmitAmount];

      if (flEmitRate || !iParticlesNum) {
        for (new iBatchIndex = 0; iBatchIndex < iEmitAmount; ++iBatchIndex) {
          @ParticleSystem_Emit(iId, iBatchIndex);
        }
      }

      g_rgsSystem[iId][ParticleSystem_NextEmit] = g_flGameTime + (flSpeed ? (flEmitRate / flSpeed) : 0.0);
    }
  }

  for (new iParticle = 0; iParticle < iParticlesNum; ++iParticle) {
    static iParticleId; iParticleId = ArrayGetCell(irgParticles, iParticle);
    if (iParticleId == INVALID_HANDLE) continue;

    // Destroy expired particle and skip (also destroy all particles in case no one see the system or the system is deactivated)
    static Float:flKillTime; flKillTime = g_rgParticles[iParticleId][Particle_KillTime];
    if (!iVisibilityBits || !bActive || (flKillTime > 0.0 && flKillTime <= g_flGameTime)) {
      ArraySetCell(irgParticles, iParticle, INVALID_HANDLE);
      engfunc(EngFunc_RemoveEntity, g_rgParticles[iParticleId][Particle_Entity]);
      continue;
    }
    
    static Float:vecParticleOrigin[3]; xs_vec_copy(g_rgParticles[iParticleId][Particle_PositionVars][PositionVars_Origin], vecParticleOrigin);
    static Float:vecParticleVelocity[3]; xs_vec_copy(g_rgParticles[iParticleId][Particle_PositionVars][PositionVars_Velocity], vecParticleVelocity);

    xs_vec_add_scaled(vecParticleOrigin, vecParticleVelocity, flDelta * flSpeed, vecParticleOrigin);
    xs_vec_copy(vecParticleOrigin, g_rgParticles[iParticleId][Particle_PositionVars][PositionVars_Origin]);

    @ParticleEffect_ExecuteHook(iEffectId, ParticleEffectHook_Particle_Think, iParticleId);

    if (g_rgParticles[iParticleId][Particle_Attached]) {
      @ParticleSystem_UpdateParticleAbsPosition(iId, iParticleId);
    }

    @ParticleSystem_SyncParticleVars(iId, iParticleId);

    g_rgParticles[iParticleId][Particle_LastThink] = g_flGameTime;
  }

  g_rgsSystem[iId][ParticleSystem_LastThink] = g_flGameTime;
}

@ParticleSystem_Emit(const iId, iBatchIndex) {
  if (!g_rgsSystem[iId][ParticleSystem_VisibilityBits]) return;

  static iEffectId; iEffectId = g_rgsSystem[iId][ParticleSystem_EffectId];
  static Float:flSpeed; flSpeed = g_rgsSystem[iId][ParticleSystem_EffectSpeed];

  static iParticleId; iParticleId = @Particle_Create(iId, !!(g_rgEffects[iEffectId][ParticleEffect_Flags] & ParticleEffectFlag_AttachParticles));

  static Float:vecAbsOrigin[3]; @ParticleSystem_GetAbsPositionVar(iId, PositionVars_Origin, vecAbsOrigin);
  static Float:vecAbsAngles[3]; @ParticleSystem_GetAbsPositionVar(iId, PositionVars_Angles, vecAbsAngles);
  static Float:vecAbsVelocity[3]; @ParticleSystem_GetAbsPositionVar(iId, PositionVars_Velocity, vecAbsVelocity);

  xs_vec_copy(vecAbsOrigin, g_rgParticles[iParticleId][Particle_AbsPositionVars][PositionVars_Origin]);
  xs_vec_copy(vecAbsAngles, g_rgParticles[iParticleId][Particle_AbsPositionVars][PositionVars_Angles]);
  xs_vec_copy(vecAbsVelocity, g_rgParticles[iParticleId][Particle_AbsPositionVars][PositionVars_Velocity]);

  g_rgParticles[iParticleId][Particle_BatchIndex] = iBatchIndex;

  static Float:flLifeTime; flLifeTime = g_rgEffects[iEffectId][ParticleEffect_ParticleLifeTime];
  if (flLifeTime > 0.0) {
    g_rgParticles[iParticleId][Particle_KillTime] = g_flGameTime + (flLifeTime / flSpeed);
  }

  @ParticleSystem_AddParticle(iId, iParticleId);

  @ParticleEffect_ExecuteHook(iEffectId, ParticleEffectHook_Particle_Init, iParticleId);

  @Particle_InitEntity(iParticleId);


  @ParticleSystem_SyncParticleVars(iId, iParticleId);
}

@ParticleSystem_AddParticle(const iId, const iNewParticleId) {
  static Array:irgParticles; irgParticles = g_rgsSystem[iId][ParticleSystem_Particles];
  static iParticlesNum; iParticlesNum = ArraySize(irgParticles);

  static iIndex; iIndex = INVALID_HANDLE;
  static iOldParticleId; iOldParticleId = INVALID_HANDLE;

  for (new iParticle = 0; iParticle < iParticlesNum; ++iParticle) {
    static iParticleId; iParticleId = ArrayGetCell(irgParticles, iParticle);
    if (iParticleId == INVALID_HANDLE) {
      iOldParticleId = INVALID_HANDLE;
      iIndex = iParticle;
      break;
    }

    static Float:flKillTime; flKillTime = g_rgParticles[iParticleId][Particle_KillTime];
    if (iIndex == INVALID_HANDLE || flKillTime < g_rgParticles[iOldParticleId][Particle_KillTime]) {
      iIndex = iParticle;
      iOldParticleId = iParticleId;
    }
  }

  if (iOldParticleId != INVALID_HANDLE) {
    engfunc(EngFunc_RemoveEntity, g_rgParticles[iOldParticleId][Particle_Entity]);
  }

  ArraySetCell(irgParticles, iIndex, iNewParticleId);
  g_rgParticles[iNewParticleId][Particle_Index] = iIndex;
}

@ParticleSystem_GetAbsPositionVar(const iId, PositionVars:iVariable, Float:vecOut[]) {
  static pParent; pParent = g_rgsSystem[iId][ParticleSystem_ParentEntity];

  if (pParent > 0) {
    pev(pParent, PositionVarsToPevMemberVec(iVariable), vecOut);
    xs_vec_add(vecOut, Float:g_rgsSystem[iId][ParticleSystem_PositionVars][iVariable], vecOut);
  } else {
    xs_vec_copy(Float:g_rgsSystem[iId][ParticleSystem_PositionVars][iVariable], vecOut);
  }
}

@ParticleSystem_SetAbsVectorVar(const iId, PositionVars:iVariable, const Float:vecValue[3]) {
  static Float:vecAbsValue[3];

  static pParent; pParent = g_rgsSystem[iId][ParticleSystem_ParentEntity];
  if (pParent > 0) {
    pev(pParent, PositionVarsToPevMemberVec(iVariable), vecAbsValue);
    xs_vec_sub(vecValue, vecAbsValue, vecAbsValue);
  } else {
    xs_vec_copy(vecValue, vecAbsValue);
  }

  xs_vec_copy(vecAbsValue, Float:g_rgsSystem[iId][ParticleSystem_PositionVars][iVariable]);
}

@ParticleSystem_UpdateVisibilityBits(const iId) {
  static iEffectId; iEffectId = g_rgsSystem[iId][ParticleSystem_EffectId];

  static Float:flVisibleDistance; flVisibleDistance = g_rgEffects[iEffectId][ParticleEffect_VisibilityDistance];
  static Float:vecAbsOrigin[3]; @ParticleSystem_GetAbsPositionVar(iId, PositionVars_Origin, vecAbsOrigin);

  new iVisibilityBits = 0;
  for (new pPlayer = 1; pPlayer <= MaxClients; ++pPlayer) {
    if (~g_iPlayerConnectedBits & BIT(pPlayer & 31)) continue;

    static Float:flDistance; flDistance = get_distance_f(vecAbsOrigin, g_rgvecPlayerEyePosition[pPlayer]);
    static Float:flFOV; pev(pPlayer, pev_fov, flFOV);

    if (flDistance > flVisibleDistance) continue;
    if (flDistance > 32.0 && !is_in_viewcone(pPlayer, vecAbsOrigin, 1)) continue;

    engfunc(EngFunc_TraceLine, g_rgvecPlayerEyePosition[pPlayer], vecAbsOrigin, IGNORE_MONSTERS, pPlayer, g_pTrace);

    static Float:flFraction; get_tr2(g_pTrace, TR_flFraction, flFraction);
    if (flFraction == 1.0) {
      iVisibilityBits |= BIT(pPlayer & 31);
    }
  }

  g_rgsSystem[iId][ParticleSystem_VisibilityBits] = iVisibilityBits;
}

@ParticleSystem_UpdateParticleAbsPosition(const iId, const iParticleId) {
  @ParticleSystem_GetAbsPositionVar(iId, PositionVars_Origin, g_rgParticles[iParticleId][Particle_AbsPositionVars][PositionVars_Origin]);
  @ParticleSystem_GetAbsPositionVar(iId, PositionVars_Angles, g_rgParticles[iParticleId][Particle_AbsPositionVars][PositionVars_Angles]);
  @ParticleSystem_GetAbsPositionVar(iId, PositionVars_Velocity, g_rgParticles[iParticleId][Particle_AbsPositionVars][PositionVars_Velocity]);
}

@ParticleSystem_SyncParticleVars(const iId, const iParticleId) {
  static Float:flSpeed; flSpeed = g_rgsSystem[iId][ParticleSystem_EffectSpeed];

  static pEntity; pEntity = g_rgParticles[iParticleId][Particle_Entity];

  static Float:vecAbsOrigin[3]; xs_vec_copy(g_rgParticles[iParticleId][Particle_AbsPositionVars][PositionVars_Origin], vecAbsOrigin);
  static Float:vecAbsAngles[3]; xs_vec_copy(g_rgParticles[iParticleId][Particle_AbsPositionVars][PositionVars_Angles], vecAbsAngles);
  static Float:vecAbsVelocity[3]; xs_vec_copy(g_rgParticles[iParticleId][Particle_AbsPositionVars][PositionVars_Velocity], vecAbsVelocity);
  static Float:vecOrigin[3]; xs_vec_copy(g_rgParticles[iParticleId][Particle_PositionVars][PositionVars_Origin], vecOrigin);
  static Float:vecAngles[3]; xs_vec_copy(g_rgParticles[iParticleId][Particle_PositionVars][PositionVars_Angles], vecAngles);
  static Float:vecVelocity[3]; xs_vec_copy(g_rgParticles[iParticleId][Particle_PositionVars][PositionVars_Velocity], vecVelocity);

  if (g_rgParticles[iParticleId][Particle_Attached]) {
    static Float:rgAngleMatrix[3][4]; UTIL_AngleMatrix(vecAbsAngles, rgAngleMatrix);

    UTIL_RotateVectorByMatrix(vecOrigin, rgAngleMatrix, vecOrigin);
    UTIL_RotateVectorByMatrix(vecVelocity, rgAngleMatrix, vecVelocity);
  }

  xs_vec_add(vecAbsOrigin, vecOrigin, vecAbsOrigin);
  xs_vec_add(vecAbsAngles, vecAngles, vecAbsAngles);
  xs_vec_add(vecAbsVelocity, vecVelocity, vecAbsVelocity);

  if (flSpeed != 1.0) {
    xs_vec_mul_scalar(vecVelocity, flSpeed, vecVelocity);
  }

  set_pev(pEntity, pev_angles, vecAbsAngles);
  set_pev(pEntity, pev_origin, vecAbsOrigin);
  set_pev(pEntity, pev_velocity, vecAbsVelocity);
}

/*--------------------------------[ Particle Methods ]--------------------------------*/

AllocateParticleId() {
  for (new iParticle = 0; iParticle < g_iParticlesNum; ++iParticle) {
    if (!g_rgParticles[iParticle][Particle_Used]) return iParticle;
  }

  return g_iParticlesNum++;
}

@Particle_Create(const iSystemId, bool:bAttached) {
  new iId = AllocateParticleId();

  g_rgParticles[iId][Particle_Used] = true;
  g_rgParticles[iId][Particle_SystemId] = iSystemId;
  g_rgParticles[iId][Particle_Index] = INVALID_HANDLE;
  g_rgParticles[iId][Particle_BatchIndex] = 0;
  g_rgParticles[iId][Particle_Entity] = FM_NULLENT;
  g_rgParticles[iId][Particle_CreatedTime] = g_flGameTime;
  g_rgParticles[iId][Particle_LastThink] = g_flGameTime;
  g_rgParticles[iId][Particle_KillTime] = 0.0;
  g_rgParticles[iId][Particle_Attached] = bAttached;

  xs_vec_set(g_rgParticles[iId][Particle_PositionVars][PositionVars_Origin], 0.0, 0.0, 0.0);
  xs_vec_set(g_rgParticles[iId][Particle_PositionVars][PositionVars_Angles], 0.0, 0.0, 0.0);
  xs_vec_set(g_rgParticles[iId][Particle_PositionVars][PositionVars_Velocity], 0.0, 0.0, 0.0);

  return iId;
}

@Particle_InitEntity(const iId) {
  new iSystemId = g_rgParticles[iId][Particle_SystemId];

  new pParticle = CreateParticleEntity(Float:{0.0, 0.0, 0.0}, Float:{0.0, 0.0, 0.0});

  g_rgParticles[iId][Particle_Entity] = pParticle;
  g_rgiEntityParticleId[pParticle] = iId;

  @ParticleEffect_ExecuteHook(g_rgsSystem[iSystemId][ParticleSystem_EffectId], ParticleEffectHook_Particle_EntityInit, iId, pParticle);
}

@Particle_Destroy(const iId) {
  new iSystemId = g_rgParticles[iId][Particle_SystemId];
  
  @ParticleEffect_ExecuteHook(g_rgsSystem[iSystemId][ParticleSystem_EffectId], ParticleEffectHook_Particle_Destroy, iId);

  new pParticle = g_rgParticles[iId][Particle_Entity];

  g_rgParticles[iId][Particle_Used] = false;
  g_rgiEntityParticleId[pParticle] = -1;
}

/*--------------------------------[ Functions ]--------------------------------*/

CreateParticleEntity(const Float:vecOrigin[3], const Float:vecAngles[3]) {
  new pEntity = engfunc(EngFunc_CreateNamedEntity, g_iszParticleClassName);
  dllfunc(DLLFunc_Spawn, pEntity);

  set_pev(pEntity, pev_classname, PARTICLE_CLASSNAME);
  set_pev(pEntity, pev_solid, SOLID_NOT);
  set_pev(pEntity, pev_movetype, MOVETYPE_NOCLIP);
  set_pev(pEntity, pev_angles, vecAngles);

  engfunc(EngFunc_SetOrigin, pEntity, vecOrigin);

  return pEntity;
}

UpdateSystems() {
  for (new iId = 0; iId < g_iSystemsNum; ++iId) {
    if (!g_rgsSystem[iId][ParticleSystem_Used]) continue;

    // Destroy expired system and skip
    static Float:flKillTime; flKillTime = g_rgsSystem[iId][ParticleSystem_KillTime];
    if (flKillTime && flKillTime <= g_flGameTime) {
      @ParticleSystem_Destroy(iId);
      continue;
    }

    @ParticleSystem_Update(iId);

    static Float:flNextVisibilityUpdate; flNextVisibilityUpdate = g_rgsSystem[iId][ParticleSystem_NextVisibilityUpdate];
    if (flNextVisibilityUpdate <= g_flGameTime) {
      @ParticleSystem_UpdateVisibilityBits(iId);
      g_rgsSystem[iId][ParticleSystem_NextVisibilityUpdate] = g_flGameTime + VISIBILITY_UPDATE_RATE;
    }
  }
}

FreeParticles() {
  for (new iSystemId = 0; iSystemId < g_iSystemsNum; ++iSystemId) {
    if (!g_rgsSystem[iSystemId][ParticleSystem_Used]) continue;
    @ParticleSystem_FreeParticles(iSystemId);
  }
}

PositionVarsToPevMemberVec(PositionVars:iVariable) {
  switch (iVariable) {
    case PositionVars_Origin: return pev_origin;
    case PositionVars_Angles: return pev_angles;
    case PositionVars_Velocity: return pev_velocity;
  }

  return INVALID_HANDLE;
}

/*--------------------------------[ Stocks ]--------------------------------*/

stock UTIL_RotateVectorByMatrix(const Float:vecValue[3], Float:rgAngleMatrix[3][4], Float:vecOut[3]) {
  static Float:vecTemp[3];

  for (new i = 0; i < 3; ++i) {
    vecTemp[i] = (vecValue[0] * rgAngleMatrix[0][i]) + (vecValue[1] * rgAngleMatrix[1][i]) + (vecValue[2] * rgAngleMatrix[2][i]);
  }

  xs_vec_copy(vecTemp, vecOut);
}

stock UTIL_AngleMatrix(const Float:vecAngles[3], Float:rgMatrix[3][4]) {
  static Float:cp; cp = floatcos(vecAngles[0], degrees);
  static Float:sp; sp = floatsin(vecAngles[0], degrees);
  static Float:cy; cy = floatcos(vecAngles[1], degrees);
  static Float:sy; sy = floatsin(vecAngles[1], degrees);
  static Float:cr; cr = floatcos(-vecAngles[2], degrees);
  static Float:sr; sr = floatsin(-vecAngles[2], degrees);
  static Float:crcy; crcy = cr * cy;
  static Float:crsy; crsy = cr * sy;
  static Float:srcy; srcy = sr * cy;
  static Float:srsy; srsy = sr * sy;

  // matrix = (YAW * PITCH) * ROLL

  rgMatrix[0][0] = cp * cy;
  rgMatrix[1][0] = cp * sy;
  rgMatrix[2][0] = -sp;

  rgMatrix[0][1] = (sp * srcy) + crsy;
  rgMatrix[1][1] = (sp * srsy) - crcy;
  rgMatrix[2][1] = sr * cp;

  rgMatrix[0][2] = (sp * crcy) - srsy;
  rgMatrix[1][2] = (sp * crsy) + srcy;
  rgMatrix[2][2] = cr * cp;

  rgMatrix[0][3] = 0.0;
  rgMatrix[1][3] = 0.0;
  rgMatrix[2][3] = 0.0;
}

stock V_swap(&Float:v1, &Float:v2) {
  static Float:tmp;
  tmp = v1;
  v1 = v2;
  v2 = tmp;
}
