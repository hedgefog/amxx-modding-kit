#pragma semicolon 1;

#include <amxmodx>
#include <engine>
#include <hamsandwich>
#include <fakemeta>
#include <xs>

#define BIT(%0) (1<<(%0))

new g_pTrace;

new g_rgpPlayerAttachedEntity[MAX_PLAYERS + 1];
new Float:g_rgflPlayerAttachmentDistance[MAX_PLAYERS + 1];
new Float:g_rgvecPlayerAttachmentAnglesOffset[MAX_PLAYERS + 1][3];

new g_pfwfmAddToFullPackPost = 0;
new HamHook:g_pfwhamPlayerPreThink = HamHook:0;

new g_iPlayerGrabBits = 0;

public plugin_precache() {
  g_pTrace = create_tr2();
}

public plugin_init() {
  register_plugin("[API] Entity Grab", "1.0.0", "Hedgehog Fog");

  RegisterHamPlayer(Ham_Killed, "HamHook_Player_Killed");
}

public plugin_natives() {
  register_library("api_entity_grab");
  register_native("EntityGrab_Player_AttachEntity", "Native_PlayerAttachEntity");
  register_native("EntityGrab_Player_DetachEntity", "Native_PlayerDetachEntity");
  register_native("EntityGrab_Player_GetAttachedEntity", "Native_PlayerGetAttachedEntity");
}

public plugin_end() {
  free_tr2(g_pTrace);
}

public bool:Native_PlayerAttachEntity(const iPluginId, const iArgc) {
  static pPlayer; pPlayer = get_param(1);
  static pEntity; pEntity = get_param(2);
  static Float:flDistance; flDistance = get_param_f(3);

  return @Player_AttachEntity(pPlayer, pEntity, flDistance);
}

public bool:Native_PlayerDetachEntity(const iPluginId, const iArgc) {
  static pPlayer; pPlayer = get_param(1);

  return @Player_DetachEntity(pPlayer);
}

public Native_PlayerGetAttachedEntity(const iPluginId, const iArgc) {
  static pPlayer; pPlayer = get_param(1);

  return g_rgpPlayerAttachedEntity[pPlayer];
}

public client_connect(pPlayer) {
  g_rgpPlayerAttachedEntity[pPlayer] = FM_NULLENT;
}

public client_disconnected(pPlayer) {
  @Player_DetachEntity(pPlayer);
}

public FMHook_AddToFullPack_Post(const es, const e, const pEntity, const pHost, const iHostFlags, const iPlayer, const iSetFlags) {
  if (g_rgpPlayerAttachedEntity[pHost] != pEntity) return FMRES_IGNORED;

  set_es(es, ES_Solid, SOLID_NOT);

  return FMRES_HANDLED;
}

public HamHook_Player_Killed(const pPlayer) {
  @Player_DetachEntity(pPlayer); 
}

public HamHook_Player_PreThink(const pPlayer) {
  if (g_rgpPlayerAttachedEntity[pPlayer] != FM_NULLENT) {
    @Player_GrabThink(pPlayer);
  }
}

@Player_GrabThink(const &this) {
  static pEntity; pEntity = g_rgpPlayerAttachedEntity[this];
  if (pEntity == FM_NULLENT) return;

  if (get_ent_data_entity(this, "CBasePlayer", "m_pActiveItem") != FM_NULLENT) {
    @Player_DetachEntity(this);
    return;
  }

  static Float:vecCarryOrigin[3];
  if (!@Player_TestGrab(this, pEntity, vecCarryOrigin)) {
    @Player_DetachEntity(this);
    return;
  }

  static Float:vecAngles[3]; pev(this, pev_v_angle, vecAngles);
  static Float:vecVelocity[3]; pev(this, pev_velocity, vecVelocity);

  vecAngles[0] = 0.0;
  xs_vec_add(vecAngles, g_rgvecPlayerAttachmentAnglesOffset[this], vecAngles);

  static Float:flFrameTime; global_get(glb_frametime, flFrameTime);
  static Float:flMaxMoveSpeed; flMaxMoveSpeed = 500.0 * flFrameTime;

  static Float:vecEntityOrigin[3]; pev(pEntity, pev_origin, vecEntityOrigin);
  static Float:vecMove[3]; xs_vec_sub(vecCarryOrigin, vecEntityOrigin, vecMove);

  static Float:flMoveDistance; flMoveDistance = xs_vec_len(vecMove);

  if (flMoveDistance) {
    xs_vec_add_scaled(vecEntityOrigin, vecMove, (1.0 / flMoveDistance) * floatmin(flMoveDistance, flMaxMoveSpeed), vecCarryOrigin);
    engfunc(EngFunc_SetOrigin, pEntity, vecCarryOrigin);
  }

  set_pev(pEntity, pev_angles, vecAngles);
  set_pev(pEntity, pev_velocity, vecVelocity);
}

bool:@Player_TestGrab(const &this, const &pEntity, Float:vecCarryOrigin[3]) {
  static Float:vecGunPos[3]; ExecuteHamB(Ham_Player_GetGunPosition, this, vecGunPos);
  static Float:vecAngles[3]; pev(this, pev_v_angle, vecAngles);

  static Float:vecEntityMins[3]; pev(pEntity, pev_mins, vecEntityMins);
  static Float:vecEntityMaxs[3]; pev(pEntity, pev_maxs, vecEntityMaxs);

  static Float:flCarryDistance; flCarryDistance = g_rgflPlayerAttachmentDistance[this] + @Player_GetCarryDistance(this, pEntity);

  // Ignore Pitch
  vecAngles[0] = 0.0;

  angle_vector(vecAngles, ANGLEVECTOR_FORWARD, vecCarryOrigin);
  xs_vec_add_scaled(vecGunPos, vecCarryOrigin, flCarryDistance, vecCarryOrigin);

  static Float:vecDown[3]; xs_vec_set(vecDown, vecCarryOrigin[0], vecCarryOrigin[1], -8192.0);
  engfunc(EngFunc_TraceMonsterHull, pEntity, vecCarryOrigin, vecDown, DONT_IGNORE_MONSTERS, pEntity, g_pTrace);
  get_tr2(g_pTrace, TR_vecEndPos, vecDown);

  vecCarryOrigin[2] = floatmax(
    vecCarryOrigin[2] + vecEntityMins[2] - ((vecEntityMaxs[2] - vecEntityMins[2]) / 2),
    vecDown[2] + 16.0
  );

  static Float:vecEntityOrigin[3]; pev(pEntity, pev_origin, vecEntityOrigin);
  engfunc(EngFunc_TraceMonsterHull, pEntity, vecEntityOrigin, vecCarryOrigin, DONT_IGNORE_MONSTERS, pEntity, g_pTrace);
  get_tr2(g_pTrace, TR_vecEndPos, vecCarryOrigin);

  static Float:vecCarryOriginAdjusted[3]; xs_vec_set(vecCarryOriginAdjusted, vecCarryOrigin[0], vecCarryOrigin[1], floatclamp(vecCarryOrigin[2], vecGunPos[2] + vecEntityMins[2], vecGunPos[2] + vecEntityMaxs[2]));
  if (get_distance_f(vecCarryOriginAdjusted, vecGunPos) > flCarryDistance + 1.0) return false;

  engfunc(EngFunc_TraceMonsterHull, pEntity, vecGunPos, vecCarryOrigin, DONT_IGNORE_MONSTERS, pEntity, g_pTrace);
  static Float:flFraction; get_tr2(g_pTrace, TR_flFraction, flFraction);
  if (flFraction != 1.0) return false;

  return true;
}

@Player_GetAimOrigin(const &this, Float:flDistance, Float:vecOut[3]) {
  static Float:vecGunPos[3]; ExecuteHamB(Ham_Player_GetGunPosition, this, vecGunPos);
  static Float:vecAngles[3]; pev(this, pev_v_angle, vecAngles);

  angle_vector(vecAngles, ANGLEVECTOR_FORWARD, vecOut);

  xs_vec_add_scaled(vecGunPos, vecOut, flDistance, vecOut);
}

bool:@Player_AttachEntity(const &this, const &pEntity, Float:flDistance) {
  static Float:vecGrabPos[3];
  if (!@Player_TestGrab(this, pEntity, vecGrabPos)) return false;

  if (g_rgpPlayerAttachedEntity[this] != FM_NULLENT) {
    @Player_DetachEntity(this);
  }

  g_rgpPlayerAttachedEntity[this] = pEntity;
  g_rgflPlayerAttachmentDistance[this] = flDistance;

  set_pev(pEntity, pev_flags, pev(pEntity, pev_flags) | FL_FROZEN);
  set_pev(pEntity, pev_movetype, MOVETYPE_FLY);

  static Float:vecAngles[3]; pev(this, pev_angles, vecAngles);
  static Float:vecEntityAngles[3]; pev(pEntity, pev_angles, vecEntityAngles);

  xs_vec_set(g_rgvecPlayerAttachmentAnglesOffset[this], 0.0, vecEntityAngles[1] - vecAngles[1], 0.0);

  static pActiveItem; pActiveItem = get_ent_data_entity(this, "CBasePlayer", "m_pActiveItem");
  if (pActiveItem != FM_NULLENT) {
    set_ent_data_entity(this, "CBasePlayer", "m_pLastItem", pActiveItem);
    ExecuteHamB(Ham_Item_Holster, pActiveItem, 0);
    set_ent_data_entity(this, "CBasePlayer", "m_pActiveItem", FM_NULLENT);
  }

  g_iPlayerGrabBits |= BIT(this & 31);

  if (!g_pfwfmAddToFullPackPost) {
    g_pfwfmAddToFullPackPost = register_forward(FM_AddToFullPack, "FMHook_AddToFullPack_Post", 1);
  }

  if (!g_pfwhamPlayerPreThink) {
    g_pfwhamPlayerPreThink = RegisterHamPlayer(Ham_Player_PreThink, "HamHook_Player_PreThink");
  } else {
    EnableHamForward(g_pfwhamPlayerPreThink);
  }

  return true;
}

bool:@Player_DetachEntity(const &this) {
  if (g_rgpPlayerAttachedEntity[this] == FM_NULLENT) return false;

  static pEntity; pEntity = g_rgpPlayerAttachedEntity[this];

  set_pev(pEntity, pev_flags, pev(pEntity, pev_flags) & ~FL_FROZEN);
  set_pev(pEntity, pev_movetype, MOVETYPE_PUSHSTEP);
  g_rgpPlayerAttachedEntity[this] = FM_NULLENT;

  static Float:vecVelocity[3]; pev(pEntity, pev_velocity, vecVelocity);
  if (!xs_vec_len(vecVelocity)) {
    set_pev(pEntity, pev_velocity, Float:{0.0, 0.0, 0.1});
  }

  if (is_user_alive(this)) {
    if (get_ent_data_entity(this, "CBasePlayer", "m_pActiveItem") == FM_NULLENT) {
      static pLastItem; pLastItem = get_ent_data_entity(this, "CBasePlayer", "m_pLastItem");
      if (pLastItem != FM_NULLENT) {
        set_ent_data_entity(this, "CBasePlayer", "m_pActiveItem", pLastItem);
        ExecuteHamB(Ham_Item_Deploy, pLastItem);
      }
    }
  }

  g_iPlayerGrabBits &= ~BIT(this & 31);

  if (!g_iPlayerGrabBits) {
    unregister_forward(FM_AddToFullPack, g_pfwfmAddToFullPackPost, 1);
    g_pfwfmAddToFullPackPost = 0;

    if (g_pfwhamPlayerPreThink) {
      DisableHamForward(g_pfwhamPlayerPreThink);
    }
  }

  return true;
}

Float:@Player_GetCarryDistance(const &this, const &pEntity) {
  static Float:flPlayerRadius; flPlayerRadius = UTIL_CalculateEntityRadius(this);
  static Float:flEntityRadius; flEntityRadius = UTIL_CalculateEntityRadius(pEntity);

  return flEntityRadius + flPlayerRadius + g_rgflPlayerAttachmentDistance[this];
}

stock Float:UTIL_CalculateEntityRadius(const &pEntity) {
  static Float:vecMins[3]; pev(pEntity, pev_mins, vecMins);
  static Float:vecMaxs[3]; pev(pEntity, pev_maxs, vecMaxs);

  vecMins[2] = 0.0; // Ignore Z axis
  vecMaxs[2] = 0.0; // Ignore Z axis

  return (get_distance_f(vecMins, vecMaxs) * 0.5);
}
