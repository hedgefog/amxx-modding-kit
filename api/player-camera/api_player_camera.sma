#pragma semicolon 1

#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>
#include <xs>

#define BIT(%0) (1<<(%0))
#define IS_PLAYER(%1) (%1 >= 1 && %1 <= MaxClients)

new g_szCameraModel[] = "models/rpgrocket.mdl";

new g_pCamera = FM_NULLENT;

new g_pTrace;

new g_iPlayerCameraBits = 0;
new Float:g_rgflPlayerCameraDistance[MAX_PLAYERS + 1];
new Float:g_rgflPlayerCameraAngles[MAX_PLAYERS + 1][3];
new Float:g_rgflPlayerCameraOffset[MAX_PLAYERS + 1][3];
new bool:g_rgbPlayerCameraAxisLock[MAX_PLAYERS + 1][3];
new Float:g_rgflPlayerCameraThinkDelay[MAX_PLAYERS + 1];
new Float:g_rgflPlayerCameraNextThink[MAX_PLAYERS + 1];
new Float:g_rgflPlayerCameraDamping[MAX_PLAYERS + 1];
new g_rgpPlayerTargetEntity[MAX_PLAYERS + 1];

new Float:g_rgvecPlayerCameraCurrentOrigin[MAX_PLAYERS + 1][3];
new Float:g_rgvecPlayerCameraCurrentAngles[MAX_PLAYERS + 1][3];

new g_pCurrentPlayer = FM_NULLENT;
new Float:g_flGameTime = 0.0;

new g_pfwfmUpdateClientData = 0;
new g_pfwfmCheckVisibility = 0;
new g_pfwfmAddToFullPackPost = 0;

new g_pfwActivate;
new g_pfwDeactivate;
new g_pfwActivated;
new g_pfwDeactivated;

public plugin_precache() {
  g_pTrace = create_tr2();

  precache_model(g_szCameraModel);
}

public plugin_init() {
  register_plugin("[API] Player Camera", "1.0.0", "Hedgehog Fog");

  RegisterHamPlayer(Ham_Spawn, "HamHook_Player_Spawn_Post", .Post = 1);

  g_pfwActivate = CreateMultiForward("PlayerCamera_OnActivate", ET_STOP, FP_CELL);
  g_pfwDeactivate = CreateMultiForward("PlayerCamera_OnDeactivate", ET_STOP, FP_CELL);
  g_pfwActivated = CreateMultiForward("PlayerCamera_OnActivated", ET_IGNORE, FP_CELL);
  g_pfwDeactivated = CreateMultiForward("PlayerCamera_OnDeactivated", ET_IGNORE, FP_CELL);
}

public plugin_natives() {
  register_library("api_player_camera");
  register_native("PlayerCamera_Activate", "Native_Activate");
  register_native("PlayerCamera_Deactivate", "Native_Deactivate");
  register_native("PlayerCamera_Update", "Native_Update");
  register_native("PlayerCamera_IsActive", "Native_IsActive");
  register_native("PlayerCamera_SetOffset", "Native_SetOffset");
  register_native("PlayerCamera_SetAngles", "Native_SetAngles");
  register_native("PlayerCamera_SetDistance", "Native_SetDistance");
  register_native("PlayerCamera_SetAxisLock", "Native_SetAxisLock");
  register_native("PlayerCamera_SetThinkDelay", "Native_SetThinkDelay");
  register_native("PlayerCamera_SetTargetEntity", "Native_SetTargetEntity");
  register_native("PlayerCamera_SetDamping", "Native_SetDamping");
  register_native("PlayerCamera_GetOrigin", "Native_GetOrigin");
}

public plugin_end() {
  free_tr2(g_pTrace);
}

public bool:Native_Activate(const iPluginId, const iArgc) {
  new pPlayer = get_param(1);

  SetPlayerCamera(pPlayer, true);
}

public Native_Deactivate(const iPluginId, const iArgc) {
  new pPlayer = get_param(1);

  SetPlayerCamera(pPlayer, false);
}

public Native_Update(const iPluginId, const iArgc) {
  new pPlayer = get_param(1);

  if (g_iPlayerCameraBits & BIT(pPlayer & 31)) {
    @Player_CameraThink(pPlayer);
  }
}

public Native_IsActive(const iPluginId, const iArgc) {
  new pPlayer = get_param(1);

  return !!(g_iPlayerCameraBits & BIT(pPlayer & 31));
}

public Native_SetOffset(const iPluginId, const iArgc) {
  new pPlayer = get_param(1);

  get_array_f(2, g_rgflPlayerCameraOffset[pPlayer], 3);
}

public Native_SetAngles(const iPluginId, const iArgc) {
  new pPlayer = get_param(1);

  get_array_f(2, g_rgflPlayerCameraAngles[pPlayer], 3);
}

public Native_SetDistance(const iPluginId, const iArgc) {
  new pPlayer = get_param(1);

  g_rgflPlayerCameraDistance[pPlayer] = get_param_f(2);
}

public Native_SetAxisLock(const iPluginId, const iArgc) {
  new pPlayer = get_param(1);

  g_rgbPlayerCameraAxisLock[pPlayer][0] = bool:get_param(2);
  g_rgbPlayerCameraAxisLock[pPlayer][1] = bool:get_param(3);
  g_rgbPlayerCameraAxisLock[pPlayer][2] = bool:get_param(4);
}

public Native_SetThinkDelay(const iPluginId, const iArgc) {
  new pPlayer = get_param(1);

  g_rgflPlayerCameraThinkDelay[pPlayer] = get_param_f(2);
}

public Native_SetTargetEntity(const iPluginId, const iArgc) {
  new pPlayer = get_param(1);

  g_rgpPlayerTargetEntity[pPlayer] = get_param(2);
}

public Native_SetDamping(const iPluginId, const iArgc) {
  new pPlayer = get_param(1);

  g_rgflPlayerCameraDamping[pPlayer] = get_param_f(2);
}

public Native_GetOrigin(const iPluginId, const iArgc) {
  new pPlayer = get_param(1);

  if (g_iPlayerCameraBits & BIT(pPlayer & 31)) {
    set_array_f(2, g_rgvecPlayerCameraCurrentOrigin[pPlayer], 3);
  } else {
    set_array_f(2, Float:{0.0, 0.0, 0.0}, 3);
  }
}

public client_connect(pPlayer) {
  @Player_ResetVariables(pPlayer);
}

public client_disconnected(pPlayer) {
  SetPlayerCamera(pPlayer, false);
}

public server_frame() {
  g_flGameTime = get_gametime();
}

public HamHook_Player_Spawn_Post(const pPlayer) {
  ReattachCamera(pPlayer);
}

public FMHook_CheckVisibility(const pEntity) {
  if (g_pCamera == pEntity) {
    forward_return(FMV_CELL, g_iPlayerCameraBits & BIT(g_pCurrentPlayer & 31) ? 1 : 0);
    return FMRES_SUPERCEDE;
  }

  return FMRES_IGNORED;
}

public FMHook_AddToFullPack_Post(const es, const e, const pEntity, const pHost, const iHostFlags, const iPlayer, const iSetFlags) {
  if (g_pCamera != pEntity) return FMRES_IGNORED;
  if (~g_iPlayerCameraBits & BIT(pHost & 31)) return FMRES_IGNORED;

  static Float:vecVelocity[3]; pev(pHost, pev_velocity, vecVelocity);

  set_es(es, ES_Origin, g_rgvecPlayerCameraCurrentOrigin[pHost]);
  set_es(es, ES_Angles, g_rgvecPlayerCameraCurrentAngles[pHost]);
  set_es(es, ES_Velocity, vecVelocity);

  return FMRES_HANDLED;
}

public FMHook_UpdateClientData(const pPlayer) {
  @Player_CameraThink(pPlayer);
  g_pCurrentPlayer = pPlayer;
}

SetPlayerCamera(const &pPlayer, bool:bValue) {
  new bool:bCurrentValue = !!(g_iPlayerCameraBits & BIT(pPlayer & 31));

  if (bCurrentValue == bValue) return;

  if (bValue) {
    if (!is_user_connected(pPlayer)) return;

    if (g_pCamera == FM_NULLENT) {
      g_pCamera = CreatePlayerCamera(pPlayer);
    }

    new iResult = 0; ExecuteForward(g_pfwActivate, iResult, pPlayer);
    if (iResult != PLUGIN_CONTINUE) return;

    g_rgflPlayerCameraNextThink[pPlayer] = 0.0;
    pev(pPlayer, pev_origin, g_rgvecPlayerCameraCurrentOrigin[pPlayer]);
    g_iPlayerCameraBits |= BIT(pPlayer & 31);

    engfunc(EngFunc_SetView, pPlayer, g_pCamera);

    @Player_CameraThink(pPlayer);

    ExecuteForward(g_pfwActivated, _, pPlayer);
  } else {
    new iResult = 0; ExecuteForward(g_pfwDeactivate, iResult, pPlayer);
    if (iResult != PLUGIN_CONTINUE) return;

    if (is_user_connected(pPlayer)) {
      engfunc(EngFunc_SetView, pPlayer, pPlayer);
    }

    ExecuteForward(g_pfwDeactivated, _, pPlayer);

    g_iPlayerCameraBits &= ~BIT(pPlayer & 31);

    @Player_ResetVariables(pPlayer);
  }

  UpdatePluginState();
}

UpdatePluginState() {
  if (g_iPlayerCameraBits) {
    if (!g_pfwfmUpdateClientData) {
      g_pfwfmUpdateClientData = register_forward(FM_UpdateClientData, "FMHook_UpdateClientData", 0);
    }

    if (!g_pfwfmCheckVisibility) {
      g_pfwfmCheckVisibility = register_forward(FM_CheckVisibility, "FMHook_CheckVisibility", 0);
    }

    if (!g_pfwfmAddToFullPackPost) {
      g_pfwfmAddToFullPackPost = register_forward(FM_AddToFullPack, "FMHook_AddToFullPack_Post", 1);
    }
  } else {
    unregister_forward(FM_UpdateClientData, g_pfwfmUpdateClientData, 0);
    g_pfwfmUpdateClientData = 0;

    unregister_forward(FM_UpdateClientData, g_pfwfmCheckVisibility, 0);
    g_pfwfmCheckVisibility = 0;

    unregister_forward(FM_UpdateClientData, g_pfwfmAddToFullPackPost, 0);
    g_pfwfmAddToFullPackPost = 0;

    engfunc(EngFunc_RemoveEntity, g_pCamera);
    g_pCamera = FM_NULLENT;
  }
}

CreatePlayerCamera(const &pPlayer) {
  static iszClassname = 0;
  if (!iszClassname) {
    iszClassname = engfunc(EngFunc_AllocString, "trigger_camera");
  }

  new pCamera = engfunc(EngFunc_CreateNamedEntity, iszClassname);

  set_pev(pCamera, pev_classname, "trigger_camera");
  set_pev(pCamera, pev_modelindex, engfunc(EngFunc_ModelIndex, g_szCameraModel));
  set_pev(pCamera, pev_owner, pPlayer);
  set_pev(pCamera, pev_solid, SOLID_NOT);
  set_pev(pCamera, pev_movetype, MOVETYPE_NOCLIP);
  set_pev(pCamera, pev_rendermode, kRenderTransTexture);

  return pCamera;
}

@Player_ResetVariables(const &this) {
  g_rgpPlayerTargetEntity[this] = this;
  g_rgflPlayerCameraDistance[this] = 200.0;
  g_rgbPlayerCameraAxisLock[this] = bool:{false, false, false};
  xs_vec_copy(Float:{0.0, 0.0, 0.0}, g_rgflPlayerCameraAngles[this]);
  xs_vec_copy(Float:{0.0, 0.0, 0.0}, g_rgflPlayerCameraOffset[this]);
  g_rgflPlayerCameraThinkDelay[this] = 0.01;
  g_rgflPlayerCameraDamping[this] = 1.0;
}

@Player_CameraThink(const &this) {
  if (g_rgflPlayerCameraNextThink[this] > g_flGameTime) return;

  g_rgflPlayerCameraNextThink[this] = g_flGameTime + g_rgflPlayerCameraThinkDelay[this];

  if (!(g_iPlayerCameraBits & BIT(this & 31))) return;
  if (g_pCamera == FM_NULLENT) return;
  if (!is_user_alive(this)) return;

  static Float:vecOldOrigin[3]; xs_vec_copy(g_rgvecPlayerCameraCurrentOrigin[this], vecOldOrigin);

  static Float:vecOrigin[3];
  static Float:vecAngles[3];
  static Float:vecVelocity[3];  

  if (g_rgpPlayerTargetEntity[this] > 0) {
    pev(g_rgpPlayerTargetEntity[this], pev_origin, vecOrigin);
    pev(g_rgpPlayerTargetEntity[this], pev_v_angle, vecAngles);
    pev(g_rgpPlayerTargetEntity[this], pev_velocity, vecVelocity);
  } else {
    xs_vec_set(vecOrigin, 0.0, 0.0, 0.0);
    xs_vec_set(vecAngles, 0.0, 0.0, 0.0);
    xs_vec_set(vecVelocity, 0.0, 0.0, 0.0);
  }

  xs_vec_add(vecOrigin, g_rgflPlayerCameraOffset[this], vecOrigin);

  for (new iAxis = 0; iAxis < 3; ++iAxis) {
    if (g_rgbPlayerCameraAxisLock[this][iAxis]) {
      vecAngles[iAxis] = 0.0;
    }

    vecAngles[iAxis] += g_rgflPlayerCameraAngles[this][iAxis];
  }

  static Float:vecBack[3];
  angle_vector(vecAngles, ANGLEVECTOR_FORWARD, vecBack);
  xs_vec_neg(vecBack, vecBack);

  for (new i = 0; i < 3; ++i) {
    g_rgvecPlayerCameraCurrentOrigin[this][i] = vecOrigin[i] + (vecBack[i] * g_rgflPlayerCameraDistance[this]);
  }

  engfunc(EngFunc_TraceHull, vecOrigin, g_rgvecPlayerCameraCurrentOrigin[this], HULL_HEAD, IGNORE_MONSTERS, this, g_pTrace);

  static pHit; pHit = get_tr2(g_pTrace, TR_pHit);

  /*
    !!!HACKHACK: Used to prevent camera from clipping through players
    Unfortunately TraceHull doesn't ignore players even with IGNORE_MONSTERS flag
  */
  while (IS_PLAYER(pHit)) {
    static rgiPlayerSolidType[MAX_PLAYERS + 1];
    for (new pPlayer = 1; pPlayer <= MAX_PLAYERS; ++pPlayer) {
      rgiPlayerSolidType[pPlayer] = SOLID_NOT;
    }

    while (IS_PLAYER(pHit)) {
      rgiPlayerSolidType[pHit] = pev(pHit, pev_solid);

      set_pev(pHit, pev_solid, SOLID_NOT);
      engfunc(EngFunc_TraceHull, vecOrigin, g_rgvecPlayerCameraCurrentOrigin[this], HULL_HEAD, IGNORE_MONSTERS, this, g_pTrace);

      pHit = get_tr2(g_pTrace, TR_pHit);
    }

    for (new pPlayer = 1; pPlayer <= MAX_PLAYERS; ++pPlayer) {
      if (rgiPlayerSolidType[pPlayer] != SOLID_NOT) {
        set_pev(pPlayer, pev_solid, rgiPlayerSolidType[pPlayer]);
      }
    }
  }

  static Float:flFraction; get_tr2(g_pTrace, TR_flFraction, flFraction);

  if(flFraction != 1.0) { 
    for (new i = 0; i < 3; ++i) {
      g_rgvecPlayerCameraCurrentOrigin[this][i] = vecOrigin[i] + (vecBack[i] * (g_rgflPlayerCameraDistance[this] * flFraction)) + (vecVelocity[i] * 0.01);
    }
  }

  UTIL_VecLerp(vecOldOrigin, g_rgvecPlayerCameraCurrentOrigin[this], g_rgflPlayerCameraDamping[this], g_rgvecPlayerCameraCurrentOrigin[this]);

  xs_vec_copy(vecAngles, g_rgvecPlayerCameraCurrentAngles[this]);

  set_pev(g_pCamera, pev_origin, g_rgvecPlayerCameraCurrentOrigin[this]);
  set_pev(g_pCamera, pev_angles, g_rgvecPlayerCameraCurrentAngles[this]);
  set_pev(g_pCamera, pev_velocity, vecVelocity);
}

ReattachCamera(const &pPlayer) {
  if (g_pCamera == FM_NULLENT) return;
  if (!(g_iPlayerCameraBits & BIT(pPlayer & 31))) return;

  engfunc(EngFunc_SetView, pPlayer, g_pCamera);
}

stock UTIL_VecLerp(const Float:vecSrc[], const Float:vecTarget[], Float:flLerp, Float:vecOut[]) {
  flLerp = floatclamp(flLerp, 0.0, 1.0);
  vecOut[0] = vecSrc[0] + ((vecTarget[0] - vecSrc[0]) * flLerp);
  vecOut[1] = vecSrc[1] + ((vecTarget[1] - vecSrc[1]) * flLerp);
  vecOut[2] = vecSrc[2] + ((vecTarget[2] - vecSrc[2]) * flLerp);
}
