#pragma semicolon 1

#include <amxmodx>
#include <hamsandwich>
#include <fakemeta>
#include <xs>

#define IS_PLAYER(%1) (%1 >= 1 && %1 <= MaxClients)
#define MAX(%1,%2) (%1 > %2 ? %1 : %2)
#define MIN(%1,%2) (%1 < %2 ? %1 : %2)

#define MAX_ENTITIES 2048
#define MAX_MARKERS 256

#define MARKER_CLASSNAME "__wp_marker"
#define MARKER_UPDATE_RATE 0.01
#define TRACE_IGNORE_FLAGS (IGNORE_GLASS | IGNORE_MONSTERS)
#define SCREEN_SIZE_FACTOR 1024.0
#define SPRITE_MIN_SCALE 0.004

enum _:Frame { Frame_TopLeft, Frame_TopRight, Frame_Center, Frame_BottomLeft, Frame_BottomRight };

enum MarkerPlayerData {
  bool:MarkerPlayerData_bIsVisible,
  bool:MarkerPlayerData_bShouldHide,
  Float:MarkerPlayerData_flScale,
  Float:MarkerPlayerData_flNextUpdate,
  Float:MarkerPlayerData_flLastUpdate,
  Float:MarkerPlayerData_vecOrigin[3],
  Float:MarkerPlayerData_vecAngles[3]
};

new g_pfwCreated;
new g_pfwDestroy;

new g_pfwfmUpdateClientData = 0;
new g_pfwfmCheckVisibility = 0;
new g_pfwfmAddToFullPackPost = 0;

new g_pTrace;
new g_iszInfoTargetClassname;
new bool:g_bCompensation;
new g_pCurrentPlayer = FM_NULLENT;
new Float:g_flGameTime = 0.0;

new g_rgpEntityMarkerId[MAX_ENTITIES] = { INVALID_HANDLE, ... };

new g_rgpMarkerEntities[MAX_MARKERS] = { FM_NULLENT, ... };
new g_rgrgMarkerPlayerData[MAX_MARKERS][MAX_PLAYERS + 1][MarkerPlayerData];
new g_iMarkersNum = 0;

new Float:g_rgflPlayerDelay[MAX_PLAYERS + 1];
new Float:g_rgflPlayerNextDelayUpdate[MAX_PLAYERS + 1];

/*--------------------------------[ Plugin Initialization ]--------------------------------*/

public plugin_precache() {
  g_pTrace = create_tr2();
  g_iszInfoTargetClassname = engfunc(EngFunc_AllocString, "env_sprite");

  g_pfwCreated = CreateMultiForward("WaypointMarker_OnCreated", ET_IGNORE, FP_CELL);
  g_pfwDestroy = CreateMultiForward("WaypointMarker_OnDestroy", ET_IGNORE, FP_CELL);
}

public plugin_init() {
  register_plugin("[API] Waypoint Markers", "1.0.0", "Hedgehog Fog");

  register_forward(FM_OnFreeEntPrivateData, "FMHook_OnFreeEntPrivateData", 0);

  bind_pcvar_num(create_cvar("waypoint_marker_compensation", "1"), g_bCompensation);
}

public plugin_natives() {
  register_library("api_waypoint_markers");
  register_native("WaypointMarker_Create", "Native_CreateMarker");
  register_native("WaypointMarker_SetVisible", "Native_SetVisible");
}

public plugin_end() {
  free_tr2(g_pTrace);
}

public server_frame() {
  g_flGameTime = get_gametime();
}

/*--------------------------------[ Natives ]--------------------------------*/

public Native_CreateMarker(const iPluginId, const iArgc) {
  new szModel[MAX_RESOURCE_PATH_LENGTH]; get_string(1, szModel, charsmax(szModel));
  new Float:vecOrigin[3]; get_array_f(2, vecOrigin, sizeof(vecOrigin));
  new Float:flScale = get_param_f(3);
  new Float:vecSize[3]; get_array_f(4, vecSize, 2);

  vecSize[2] = MAX(vecSize[0], vecSize[1]);

  new pMarker = @Marker_Create();
  if (pMarker == FM_NULLENT) return FM_NULLENT;

  engfunc(EngFunc_SetModel, pMarker, szModel);
  dllfunc(DLLFunc_Spawn, pMarker);
  set_pev(pMarker, pev_scale, flScale);
  set_pev(pMarker, pev_size, vecSize);
  engfunc(EngFunc_SetOrigin, pMarker, vecOrigin);

  return pMarker;
}

public Native_SetVisible(const iPluginId, const iArgc) {
  new pMarker = get_param(1);
  new pPlayer = get_param(2);
  new bool:bValue = bool:get_param(3);

  @Marker_SetVisible(pMarker, pPlayer, bValue);
}

/*--------------------------------[ Hooks ]--------------------------------*/

public FMHook_UpdateClientData(const pPlayer) {
  g_pCurrentPlayer = pPlayer;

  if (g_rgflPlayerNextDelayUpdate[pPlayer] <= g_flGameTime) {
    if (g_bCompensation) {
      static iPing, iLoss; get_user_ping(pPlayer, iPing, iLoss);
      g_rgflPlayerDelay[pPlayer] = float(iPing) / 1000.0;
    } else {
      g_rgflPlayerDelay[pPlayer] = 0.0;
    }

    g_rgflPlayerNextDelayUpdate[pPlayer] = g_flGameTime + 0.1;
  }

  for (new iMarker = 0; iMarker < g_iMarkersNum; ++iMarker) {
    @Marker_Calculate(g_rgpMarkerEntities[iMarker], pPlayer, g_rgflPlayerDelay[pPlayer]);
  }
}

public FMHook_CheckVisibility(const pEntity) {
  if (g_pCurrentPlayer != FM_NULLENT && g_rgpEntityMarkerId[pEntity] != INVALID_HANDLE) {
    static iId; iId = g_rgpEntityMarkerId[pEntity];
    static bool:bValue; bValue = g_rgrgMarkerPlayerData[iId][g_pCurrentPlayer][MarkerPlayerData_bIsVisible] && !g_rgrgMarkerPlayerData[iId][g_pCurrentPlayer][MarkerPlayerData_bShouldHide];

    forward_return(FMV_CELL, bValue);

    return FMRES_SUPERCEDE;
  }

  return FMRES_IGNORED;
}

public FMHook_AddToFullPack_Post(const es, const e, const pEntity, const pHost, const iHostFlags, const iPlayer, const iSetFlags) {
  if (!IS_PLAYER(pHost)) return FMRES_IGNORED;

  static iId; iId = g_rgpEntityMarkerId[pEntity];
  if (iId != INVALID_HANDLE) {
    if (!g_rgrgMarkerPlayerData[iId][pHost][MarkerPlayerData_bIsVisible]) return FMRES_SUPERCEDE;
    if (g_rgrgMarkerPlayerData[iId][pHost][MarkerPlayerData_bShouldHide]) return FMRES_SUPERCEDE;

    set_es(es, ES_Origin, g_rgrgMarkerPlayerData[iId][pHost][MarkerPlayerData_vecOrigin]);
    set_es(es, ES_Angles, g_rgrgMarkerPlayerData[iId][pHost][MarkerPlayerData_vecAngles]);
    set_es(es, ES_Scale, g_rgrgMarkerPlayerData[iId][pHost][MarkerPlayerData_flScale]);
    set_es(es, ES_AimEnt, 0);

    return FMRES_HANDLED;
  }

  return FMRES_IGNORED;
}

public FMHook_OnFreeEntPrivateData(const pEntity) {
  if (g_rgpEntityMarkerId[pEntity] != INVALID_HANDLE) {
    @Marker_Free(pEntity);
  }
}

/*--------------------------------[ Methods ]--------------------------------*/

@Marker_Create() {
  new iId = g_iMarkersNum;
  new this = engfunc(EngFunc_CreateNamedEntity, g_iszInfoTargetClassname);

  set_pev(this, pev_classname, MARKER_CLASSNAME);
  set_pev(this, pev_scale, 1.0);
  set_pev(this, pev_rendermode, kRenderTransAdd);
  set_pev(this, pev_renderamt, 255.0);
  set_pev(this, pev_movetype, MOVETYPE_NOCLIP);
  set_pev(this, pev_solid, SOLID_NOT);
  // set_pev(this, pev_spawnflags, SF_SPRITE_STARTON);
  set_pev(this, pev_animtime, g_flGameTime);
  set_pev(this, pev_framerate, 1.0);

  g_rgpEntityMarkerId[this] = iId;
  g_rgpMarkerEntities[iId] = this;

  g_iMarkersNum++;

  ExecuteForward(g_pfwCreated, _, this);

  UpdateHooks();

  return this ? this : FM_NULLENT;
}

@Marker_Free(const &this) {
  ExecuteForward(g_pfwDestroy, _, this);

  new iId = g_rgpEntityMarkerId[this];

  g_rgpMarkerEntities[iId] = g_rgpMarkerEntities[g_iMarkersNum - 1];
  g_rgpMarkerEntities[g_iMarkersNum - 1] = FM_NULLENT;
  g_iMarkersNum--;
  g_rgpEntityMarkerId[this] = INVALID_HANDLE;

  new pNewMarker = g_rgpMarkerEntities[iId];
  if (pNewMarker != FM_NULLENT) {
    g_rgpEntityMarkerId[pNewMarker] = iId;
  }

  UpdateHooks();
}

@Marker_SetVisible(const &this, const &pPlayer, bool:bValue) {
  if (!pPlayer) {
    for (new pPlayer = 1; pPlayer <= MaxClients; ++pPlayer) {
      @Marker_SetVisible(this, pPlayer, bValue);
    }

    return;
  }

  if (!IS_PLAYER(pPlayer)) return;

  new iId = g_rgpEntityMarkerId[this];

  g_rgrgMarkerPlayerData[iId][pPlayer][MarkerPlayerData_bIsVisible] = bValue;
}

@Marker_Calculate(const &this, const &pPlayer, Float:flDelay) {
  static iId; iId = g_rgpEntityMarkerId[this];

  if (!g_rgrgMarkerPlayerData[iId][pPlayer][MarkerPlayerData_bIsVisible]) return;
  if (g_rgrgMarkerPlayerData[iId][pPlayer][MarkerPlayerData_flNextUpdate] > g_flGameTime) return;

  if (!is_user_alive(pPlayer)) {
    g_rgrgMarkerPlayerData[iId][pPlayer][MarkerPlayerData_bShouldHide] = true;
    return;
  }

  if (is_user_bot(pPlayer)) {
    g_rgrgMarkerPlayerData[iId][pPlayer][MarkerPlayerData_bShouldHide] = true;
    return;
  }

  static Float:vecViewOrigin[3]; ExecuteHam(Ham_EyePosition, pPlayer, vecViewOrigin);

  if (g_bCompensation) {
    static Float:vecVelocity[3]; pev(pPlayer, pev_velocity, vecVelocity);
    xs_vec_add_scaled(vecViewOrigin, vecVelocity, flDelay, vecViewOrigin);
  }

  static Float:vecOrigin[3]; pev(this, pev_origin, vecOrigin);

  static iFov; iFov = get_ent_data(pPlayer, "CBasePlayer", "m_iFOV");

  // We have to fix default HL FOV, because it equal to 0 and we can't use it in calculations
  if (!iFov) iFov = 90;

  // Default view cone test functions not working for Half-Life, so we have to use this stock
  if (!UTIL_IsInViewCone(pPlayer, vecOrigin, float(iFov) / 2)) {
    g_rgrgMarkerPlayerData[iId][pPlayer][MarkerPlayerData_bShouldHide] = true;
    return;
  }

  static Float:vecAngles[3];
  xs_vec_sub(vecOrigin, vecViewOrigin, vecAngles);
  xs_vec_normalize(vecAngles, vecAngles);
  vector_to_angle(vecAngles, vecAngles);
  vecAngles[0] = -vecAngles[0];

  static Float:flDistance; flDistance = xs_vec_distance(vecViewOrigin, vecOrigin);
  static Float:vecSize[3]; pev(this, pev_size, vecSize);
  static Float:vecForward[3]; angle_vector(vecAngles, ANGLEVECTOR_FORWARD, vecForward);
  static Float:vecUp[3]; angle_vector(vecAngles, ANGLEVECTOR_UP, vecUp);
  static Float:vecRight[3]; angle_vector(vecAngles, ANGLEVECTOR_RIGHT, vecRight);
  static Float:flDistanceScale; flDistanceScale = CalculateDistanceScaleFactor(flDistance, iFov);

  static Float:rgFrame[Frame][3];
  CreateFrame(vecOrigin, vecSize[0] * flDistanceScale, vecSize[1] * flDistanceScale, vecUp, vecRight, rgFrame);
  static Float:flFraction; flFraction = TraceFrame(vecViewOrigin, rgFrame, pPlayer, rgFrame);

  static Float:flScale; pev(this, pev_scale, flScale);

  if (flFraction < 1.0) {
    static Float:flProjectionDistance; flProjectionDistance = xs_vec_distance(rgFrame[Frame_Center], vecViewOrigin);

    flScale *= CalculateDistanceScaleFactor(flProjectionDistance, iFov);

    if (flDistanceScale > 0.0) {
      flScale /= flDistanceScale;
    }

    flScale = MAX(flScale, SPRITE_MIN_SCALE);

    static Float:flDepth; flDepth = MIN((vecSize[2] / 2) * flScale, flProjectionDistance - 1.0);
    MoveFrame(rgFrame, vecForward, -flDepth, rgFrame);
  } else {
    flScale = MAX(flScale, SPRITE_MIN_SCALE);
  }

  g_rgrgMarkerPlayerData[iId][pPlayer][MarkerPlayerData_bShouldHide] = false;
  g_rgrgMarkerPlayerData[iId][pPlayer][MarkerPlayerData_flScale] = flScale;
  g_rgrgMarkerPlayerData[iId][pPlayer][MarkerPlayerData_vecOrigin] = rgFrame[Frame_Center];
  g_rgrgMarkerPlayerData[iId][pPlayer][MarkerPlayerData_vecAngles] = vecAngles;
  g_rgrgMarkerPlayerData[iId][pPlayer][MarkerPlayerData_flLastUpdate] = g_flGameTime;
  g_rgrgMarkerPlayerData[iId][pPlayer][MarkerPlayerData_flNextUpdate] = g_flGameTime + MARKER_UPDATE_RATE;
}

/*--------------------------------[ Functions ]--------------------------------*/

CreateFrame(const Float:vecOrigin[3], Float:flWidth, Float:flHeight, const Float:vecUp[3], const Float:vecRight[3], Float:rgFrameOut[Frame][3]) {
  static Float:flHalfWidth; flHalfWidth = flWidth / 2;
  static Float:flHalfHeight; flHalfHeight = flHeight / 2;

  for (new iAxis = 0; iAxis < 3; ++iAxis) {
    rgFrameOut[Frame_TopLeft][iAxis] = vecOrigin[iAxis] + (-vecRight[iAxis] * flHalfWidth) + (vecUp[iAxis] * flHalfHeight);
    rgFrameOut[Frame_TopRight][iAxis] = vecOrigin[iAxis] + (vecRight[iAxis] * flHalfWidth) + (vecUp[iAxis] * flHalfHeight);
    rgFrameOut[Frame_BottomLeft][iAxis] = vecOrigin[iAxis] + (-vecRight[iAxis] * flHalfWidth) + (-vecUp[iAxis] * flHalfHeight);
    rgFrameOut[Frame_BottomRight][iAxis] = vecOrigin[iAxis] + (vecRight[iAxis] * flHalfWidth) + (-vecUp[iAxis] * flHalfHeight);
    rgFrameOut[Frame_Center][iAxis] = vecOrigin[iAxis];
  }
}

Float:TraceFrame(const Float:vecViewOrigin[3], const Float:rgFrame[Frame][3], pIgnore, Float:rgFrameOut[Frame][3]) {
  static Float:flMinFraction; flMinFraction = 1.0;

  for (new iFramePoint = 0; iFramePoint < Frame; ++iFramePoint) {
    engfunc(EngFunc_TraceLine, vecViewOrigin, rgFrame[iFramePoint], TRACE_IGNORE_FLAGS, pIgnore, g_pTrace);

    static Float:flFraction; get_tr2(g_pTrace, TR_flFraction, flFraction);
    if (flFraction < flMinFraction) {
      flMinFraction = flFraction;
    }
  }

  if (flMinFraction < 1.0) {
    for (new iFramePoint = 0; iFramePoint < Frame; ++iFramePoint) {
      for (new iAxis = 0; iAxis < 3; ++iAxis) {
        rgFrameOut[iFramePoint][iAxis] = vecViewOrigin[iAxis] + ((rgFrame[iFramePoint][iAxis] - vecViewOrigin[iAxis]) * flMinFraction);
      }
    }
  }

  return flMinFraction;
}

MoveFrame(const Float:rgFrame[Frame][3], const Float:vecDirection[3], Float:flDistance, Float:rgFrameOut[Frame][3]) {
  for (new iFramePoint = 0; iFramePoint < Frame; ++iFramePoint) {
    for (new iAxis = 0; iAxis < 3; ++iAxis) {
      rgFrameOut[iFramePoint][iAxis] = rgFrame[iFramePoint][iAxis] + (vecDirection[iAxis] * flDistance);
    }
  }
}

Float:CalculateDistanceScaleFactor(Float:flDistance, iFov = 90) {
  static Float:flAngle; flAngle = floattan(xs_deg2rad(float(iFov) / 2));
  static Float:flScaleFactor; flScaleFactor = ((2 * flAngle) / SCREEN_SIZE_FACTOR) * flDistance;

  return flScaleFactor;
}

UpdateHooks() {
  if (g_iMarkersNum) {
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

    unregister_forward(FM_CheckVisibility, g_pfwfmCheckVisibility, 0);
    g_pfwfmCheckVisibility = 0;

    unregister_forward(FM_AddToFullPack, g_pfwfmAddToFullPackPost, 1);
    g_pfwfmAddToFullPackPost = 0;
  }
}

/*--------------------------------[ Stocks ]--------------------------------*/

stock bool:UTIL_IsInViewCone(const &pEntity, const Float:vecTarget[3], Float:fMaxAngle) {
  static Float:vecOrigin[3]; ExecuteHamB(Ham_EyePosition, pEntity, vecOrigin);

  static Float:vecDir[3];
  xs_vec_sub(vecTarget, vecOrigin, vecDir);
  xs_vec_normalize(vecDir, vecDir);

  static Float:vecForward[3];
  pev(pEntity, pev_v_angle, vecForward);
  angle_vector(vecForward, ANGLEVECTOR_FORWARD, vecForward);

  new Float:flAngle = xs_rad2deg(xs_acos((vecDir[0] * vecForward[0]) + (vecDir[1] * vecForward[1]), radian));

  return flAngle <= fMaxAngle;
}
