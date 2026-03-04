#pragma semicolon 1

#include <amxmodx>
#include <engine>
#include <fakemeta>
#include <hamsandwich>
#include <xs>

#include <function_pointer>

#include <api_entity_selection_const>

#define LOG_PREFIX "[Entity Selection]"

#define LOG_ERROR(%1,%0) log_amx(LOG_PREFIX + " ERROR! " + %1, %0)
#define LOG_WARNING(%1,%0) log_amx(LOG_PREFIX + " WARNING! " + %1, %0)
#define LOG_INFO(%1,%0) log_amx(LOG_PREFIX + " " + %1, %0)
#define LOG_FATAL_ERROR(%1,%0) log_error(AMX_ERR_NATIVE, LOG_PREFIX + " " + %1, %0)

#define IS_PLAYER(%1) (%1 >= 1 && %1 <= MaxClients)

#define ERROR_FUNCTION_NOT_FOUND "Cannot find function ^"%s^" in plugin %d!"
#define ERROR_NOT_VALID_SELECTION "Selection %d is not valid selection handle!"

#define MAX_SELECTIONS 256
#define INVALID_SELECTION_ID -1

const Float:SelectionGroundOffset = 1.0;

new const g_szTrailModel[] = "sprites/laserbeam.spr";

new g_pTrace;
new g_iMaxEntities = 0;
new Float:g_flGameTime = 0.0;

new g_rgiSelectionId[MAX_SELECTIONS];
new Selection_Flags:g_rgiSelectionFlags[MAX_SELECTIONS];
new bool:g_rgbSelectionStarted[MAX_SELECTIONS];
new g_rgpSelectionPlayer[MAX_SELECTIONS];
new g_rgpSelectionPointerEntity[MAX_SELECTIONS];
new Function:g_rgfnSelectionThinkCallback[MAX_SELECTIONS];
new Function:g_rgfnSelectionFilterCallback[MAX_SELECTIONS];
new Array:g_rgirgSelectionEntities[MAX_SELECTIONS];
new Float:g_rgvecSelectionCursor[MAX_SELECTIONS][3];
new Float:g_rgvecSelectionStart[MAX_SELECTIONS][3];
new Float:g_rgvecSelectionEnd[MAX_SELECTIONS][3];
new g_rgrgSelectionColor[MAX_SELECTIONS][3];
new g_rgiSelectionBrightness[MAX_SELECTIONS];
new Float:g_rgflSelectionNextThink[MAX_SELECTIONS];
new Float:g_rgflSelectionThinkTime[MAX_SELECTIONS];

public plugin_precache() {
  g_pTrace = create_tr2();
  g_iMaxEntities = global_get(glb_maxEntities);

  for (new iId = 0; iId < MAX_SELECTIONS; ++iId) {
    g_rgiSelectionId[iId] = INVALID_SELECTION_ID;
  }

  precache_model(g_szTrailModel);
}

public plugin_init() {
  register_plugin("[API] Entity Selection", "1.0.1", "Hedgehog Fog");

  register_forward(FM_OnFreeEntPrivateData, "FMHook_OnFreeEntPrivateData");
}

public plugin_end() {
  free_tr2(g_pTrace);

  for (new iId = 0; iId < MAX_SELECTIONS; ++iId) {
    if (g_rgiSelectionId[iId] == INVALID_SELECTION_ID) continue;
    Selection_Free(iId);
  }
}

public plugin_natives() {
  register_library("api_entity_selection");

  register_native("EntitySelection_Create", "Native_CreateSelection");
  register_native("EntitySelection_Destroy", "Native_DestroySelection");

  register_native("EntitySelection_Start", "Native_StartSelection");
  register_native("EntitySelection_End", "Native_EndSelection");
  register_native("EntitySelection_IsStarted", "Native_IsSelectionStarted");

  register_native("EntitySelection_GetPlayer", "Native_GetSelectionPlayer");
  register_native("EntitySelection_SetPlayer", "Native_SetSelectionPlayer");
  
  register_native("EntitySelection_GetFlags", "Native_GetSelectionFlags");
  register_native("EntitySelection_SetFlags", "Native_SetSelectionFlags");

  register_native("EntitySelection_SetThinkTime", "Native_SetSelectionThinkTime");
  
  register_native("EntitySelection_SetThinkCallback", "Native_SetSelectionThinkCallback");
  register_native("EntitySelection_SetFilterCallback", "Native_SetSelectionFilterCallback");

  register_native("EntitySelection_GetPointerEntity", "Native_GetSelectionPointerEntity");
  register_native("EntitySelection_SetPointerEntity", "Native_SetSelectionPointerEntity");
  
  register_native("EntitySelection_GetColor", "Native_GetSelectionColor");
  register_native("EntitySelection_SetColor", "Native_SetSelectionColor");
  
  register_native("EntitySelection_GetBrightness", "Native_GetSelectionBrightness");
  register_native("EntitySelection_SetBrightness", "Native_SetSelectionBrightness");
  
  register_native("EntitySelection_GetSize", "Native_GetSelectionSize");
  register_native("EntitySelection_GetEntity", "Native_GetSelectionEntity");

  register_native("EntitySelection_GetCursorPos", "Native_GetSelectionCursorPos");
  register_native("EntitySelection_SetCursorPos", "Native_SetSelectionCursorPos");

  register_native("EntitySelection_GetStartPos", "Native_GetSelectionStartPos");
  register_native("EntitySelection_GetEndPos", "Native_GetSelectionEndPos");

  register_native("EntitySelection_GetCursorYaw", "Native_GetSelectionCursorYaw");
  register_native("EntitySelection_SetCursorYaw", "Native_SetSelectionCursorYaw");
}

/*--------------------------------[ Natives ]--------------------------------*/

public Native_CreateSelection(const iPluginId, const iArgc) {
  static pPlayer; pPlayer = get_param(1);

  new iId = FindFreeSelection();
  if (iId == INVALID_SELECTION_ID) {
    LOG_ERROR("Failed to create new selection!", 0);
    return INVALID_SELECTION_ID;
  }

  Selection_Init(iId);
  g_rgpSelectionPlayer[iId] = pPlayer ? pPlayer : FM_NULLENT;
  g_rgpSelectionPointerEntity[iId] = pPlayer ? pPlayer : FM_NULLENT;

  return iId;
}

public Native_DestroySelection(const iPluginId, const iArgc) {
  static iId; iId = get_param_byref(1);

  if (!Selection_IsValid(iId)) {
    LOG_FATAL_ERROR(ERROR_NOT_VALID_SELECTION, iId);
    return;
  }

  Selection_Free(iId);

  set_param_byref(1, INVALID_SELECTION_ID);
}

public Native_SetSelectionThinkCallback(const iPluginId, const iArgc) {
  static iId; iId = get_param_byref(1);
  static szCallback[64]; get_string(2, szCallback, charsmax(szCallback));

  if (!Selection_IsValid(iId)) {
    LOG_FATAL_ERROR(ERROR_NOT_VALID_SELECTION, iId);
    return;
  }

  static Function:fnCallback; fnCallback = get_func_pointer(szCallback, iPluginId);
  if (fnCallback == Invalid_FunctionPointer) {
    LOG_FATAL_ERROR(ERROR_FUNCTION_NOT_FOUND, szCallback, iPluginId);
    return;
  }

  Selection_SetThinkFunction(iId, fnCallback);
}

public Native_SetSelectionFilterCallback(const iPluginId, const iArgc) {
  static iId; iId = get_param_byref(1);
  static szCallback[64]; get_string(2, szCallback, charsmax(szCallback));

  if (!Selection_IsValid(iId)) {
    LOG_FATAL_ERROR(ERROR_NOT_VALID_SELECTION, iId);
    return;
  }

  static Function:fnCallback; fnCallback = get_func_pointer(szCallback, iPluginId);
  if (fnCallback == Invalid_FunctionPointer) {
    LOG_FATAL_ERROR(ERROR_FUNCTION_NOT_FOUND, szCallback, iPluginId);
    return;
  }

  Selection_SetFilterFunction(iId, fnCallback);
}

public Native_SetSelectionColor(const iPluginId, const iArgc) {
  static iId; iId = get_param_byref(1);
  
  get_array(2, g_rgrgSelectionColor[iId], 3);
}

public Native_GetSelectionColor(const iPluginId, const iArgc) {
  static iId; iId = get_param_byref(1);

  set_array(2, g_rgrgSelectionColor[iId], 3);
}

public Native_SetSelectionBrightness(const iPluginId, const iArgc) {
  static iId; iId = get_param_byref(1);
  static iBrightness; iBrightness = get_param(2);

  g_rgiSelectionBrightness[iId] = iBrightness;
}

public Native_GetSelectionBrightness(const iPluginId, const iArgc) {
  static iId; iId = get_param_byref(1);

  return g_rgiSelectionBrightness[iId];
}

public Native_GetSelectionPlayer(const iPluginId, const iArgc) {
  static iId; iId = get_param_byref(1);

  if (!Selection_IsValid(iId)) {
    LOG_FATAL_ERROR(ERROR_NOT_VALID_SELECTION, iId);
    return 0;
  }

  return g_rgpSelectionPlayer[iId]; 
}

public Native_SetSelectionPlayer(const iPluginId, const iArgc) {
  static iId; iId = get_param_byref(1);
  static pPlayer; pPlayer = get_param(2);

  if (!Selection_IsValid(iId)) {
    LOG_FATAL_ERROR(ERROR_NOT_VALID_SELECTION, iId);
    return;
  }

  g_rgpSelectionPlayer[iId] = pPlayer ? pPlayer : FM_NULLENT;
}

public Native_GetSelectionPointerEntity(const iPluginId, const iArgc) {
  static iId; iId = get_param_byref(1);

  if (!Selection_IsValid(iId)) {
    LOG_FATAL_ERROR(ERROR_NOT_VALID_SELECTION, iId);
    return FM_NULLENT;
  }

  return g_rgpSelectionPointerEntity[iId]; 
}

public Native_SetSelectionPointerEntity(const iPluginId, const iArgc) {
  static iId; iId = get_param_byref(1);
  static pCursor; pCursor = get_param(2);

  if (!Selection_IsValid(iId)) {
    LOG_FATAL_ERROR(ERROR_NOT_VALID_SELECTION, iId);
    return;
  }

  g_rgpSelectionPointerEntity[iId] = pCursor ? pCursor : FM_NULLENT;
}

public Native_StartSelection(const iPluginId, const iArgc) {
  static iId; iId = get_param_byref(1);

  if (!Selection_IsValid(iId)) {
    LOG_FATAL_ERROR(ERROR_NOT_VALID_SELECTION, iId);
    return;
  }

  if (g_rgbSelectionStarted[iId]) {
    LOG_FATAL_ERROR("Cannot start selection! Selection is already started!", 0);
    return;
  }

  Selection_Start(iId);
}

public bool:Native_IsSelectionStarted(const iPluginId, const iArgc) {
  static iId; iId = get_param_byref(1);

  if (!Selection_IsValid(iId)) {
    LOG_FATAL_ERROR(ERROR_NOT_VALID_SELECTION, iId);
    return false;
  }

  return g_rgbSelectionStarted[iId];
}

public Native_SetSelectionFlags(const iPluginId, const iArgc) {
  static iId; iId = get_param_byref(1);
  static Selection_Flags:iFlags; iFlags = Selection_Flags:get_param(2);

  if (!Selection_IsValid(iId)) {
    LOG_FATAL_ERROR(ERROR_NOT_VALID_SELECTION, iId);
    return;
  }

  g_rgiSelectionFlags[iId] = iFlags;
}

public Native_SetSelectionThinkTime(const iPluginId, const iArgc) {
  static iId; iId = get_param_byref(1);
  static Float:flThinkTime; flThinkTime = get_param_f(2);

  if (!Selection_IsValid(iId)) {
    LOG_FATAL_ERROR(ERROR_NOT_VALID_SELECTION, iId);
    return;
  }

  g_rgflSelectionThinkTime[iId] = flThinkTime;
}

public Selection_Flags:Native_GetSelectionFlags(const iPluginId, const iArgc) {
  static iId; iId = get_param_byref(1);

  if (!Selection_IsValid(iId)) {
    LOG_FATAL_ERROR(ERROR_NOT_VALID_SELECTION, iId);
    return Selection_Flag_None;
  }

  return g_rgiSelectionFlags[iId];
}

public Native_EndSelection(const iPluginId, const iArgc) {
  static iId; iId = get_param_byref(1);

  if (!Selection_IsValid(iId)) {
    LOG_FATAL_ERROR(ERROR_NOT_VALID_SELECTION, iId);
    return;
  }

  if (!g_rgbSelectionStarted[iId]) {
    LOG_FATAL_ERROR("Cannot end selection! Selection is not started!", 0);
    return;
  }

  Selection_End(iId);
}

public Native_GetSelectionEntity(const iPluginId, const iArgc) {
  static iId; iId = get_param_byref(1);
  static iIndex; iIndex = get_param(2);

  if (!Selection_IsValid(iId)) {
    LOG_FATAL_ERROR(ERROR_NOT_VALID_SELECTION, iId);
    return FM_NULLENT;
  }

  if (g_rgirgSelectionEntities[iId] == Invalid_Array) return FM_NULLENT;

  return ArrayGetCell(g_rgirgSelectionEntities[iId], iIndex);
}

public Native_GetSelectionSize(const iPluginId, const iArgc) {
  static iId; iId = get_param_byref(1);

  if (!Selection_IsValid(iId)) {
    LOG_FATAL_ERROR(ERROR_NOT_VALID_SELECTION, iId);
    return 0;
  }

  if (g_rgirgSelectionEntities[iId] == Invalid_Array) return 0;
  
  return ArraySize(g_rgirgSelectionEntities[iId]);
}

public Native_GetSelectionStartPos(const iPluginId, const iArgc) {
  static iId; iId = get_param_byref(1);

  if (!Selection_IsValid(iId)) {
    LOG_FATAL_ERROR(ERROR_NOT_VALID_SELECTION, iId);
    return;
  }

  set_array_f(2, g_rgvecSelectionStart[iId], 3);
}

public Native_GetSelectionEndPos(const iPluginId, const iArgc) {
  static iId; iId = get_param_byref(1);

  if (!Selection_IsValid(iId)) {
    LOG_FATAL_ERROR(ERROR_NOT_VALID_SELECTION, iId);
    return;
  }

  set_array_f(2, g_rgvecSelectionEnd[iId], 3);
}

public Float:Native_GetSelectionCursorYaw(const iPluginId, const iArgc) {
  // static iId; iId = get_param_byref(1);

  // if (!Selection_IsValid(iId)) {
  //   LOG_FATAL_ERROR(ERROR_NOT_VALID_SELECTION, iId);
  //   return 0.0;
  // }

  // return iId[Selection_CursorYaw];
}

public Native_SetSelectionCursorYaw(const iPluginId, const iArgc) {
  // static iId; iId = get_param_byref(1);
  // static Float:flYaw; flYaw = get_param_f(2);

  // if (!Selection_IsValid(iId)) {
  //   LOG_FATAL_ERROR(ERROR_NOT_VALID_SELECTION, iId);
  //   return;
  // }

  // iId[Selection_CursorYaw] = flYaw;
}

public Native_GetSelectionCursorPos(const iPluginId, const iArgc) {
  static iId; iId = get_param_byref(1);

  if (!Selection_IsValid(iId)) {
    LOG_FATAL_ERROR(ERROR_NOT_VALID_SELECTION, iId);
    return;
  }

  Selection_CalculateCursorPos(iId);

  set_array_f(2, g_rgvecSelectionCursor[iId], 3);
}

public Native_SetSelectionCursorPos(const iPluginId, const iArgc) {
  static iId; iId = get_param_byref(1);
  static Float:vecOrigin[3]; get_array_f(2, vecOrigin, 3);

  if (!Selection_IsValid(iId)) {
    LOG_FATAL_ERROR(ERROR_NOT_VALID_SELECTION, iId);
    return;
  }

  xs_vec_copy(vecOrigin, g_rgvecSelectionCursor[iId]);
}

/*--------------------------------[ Hooks ]--------------------------------*/

public server_frame() {
  g_flGameTime = get_gametime();

  for (new iId = 0; iId < MAX_SELECTIONS; ++iId) {
    if (g_rgiSelectionId[iId] == INVALID_SELECTION_ID) continue;

    if (!g_rgbSelectionStarted[iId]) {
      if (~g_rgiSelectionFlags[iId] & Selection_Flag_AlwaysThink) continue;
    }

    Selection_Think(iId);
}
}

/*--------------------------------[ Hooks ]--------------------------------*/

public FMHook_OnFreeEntPrivateData(pEntity) {
  if (!pev_valid(pEntity)) return;

  for (new iId = 0; iId < MAX_SELECTIONS; ++iId) {
    if (g_rgiSelectionId[iId] == INVALID_SELECTION_ID) continue;
    Selection_RemoveEntity(iId, pEntity);
  }
}

/*--------------------------------[ Selection Methods ]--------------------------------*/

bool:Selection_IsValid(const iId) {
  return iId < MAX_SELECTIONS && g_rgiSelectionId[iId] != INVALID_SELECTION_ID;
}

Selection_Init(const iId) {
  g_rgiSelectionId[iId] = iId;
  g_rgiSelectionFlags[iId] = Selection_Flag_None;
  g_rgpSelectionPlayer[iId] = FM_NULLENT;
  g_rgbSelectionStarted[iId] = false;
  g_rgpSelectionPointerEntity[iId] = FM_NULLENT;
  g_rgfnSelectionThinkCallback[iId] = Invalid_FunctionPointer;
  g_rgfnSelectionFilterCallback[iId] = Invalid_FunctionPointer;
  g_rgrgSelectionColor[iId][0] = 255;
  g_rgrgSelectionColor[iId][1] = 255;
  g_rgrgSelectionColor[iId][2] = 255;
  g_rgiSelectionBrightness[iId] = 255;
  g_rgirgSelectionEntities[iId] = ArrayCreate();
  g_rgflSelectionNextThink[iId] = g_flGameTime;
}

Selection_Free(const iId) {  
  if (g_rgirgSelectionEntities[iId] != Invalid_Array) {
    ArrayDestroy(g_rgirgSelectionEntities[iId]);
  }

  g_rgiSelectionId[iId] = INVALID_SELECTION_ID;
}

Selection_SetThinkFunction(const iId, Function:fnCallback) {
  g_rgfnSelectionThinkCallback[iId] = fnCallback;
}

Selection_SetFilterFunction(const iId, Function:fnCallback) {
  g_rgfnSelectionFilterCallback[iId] = fnCallback;
}

Selection_Start(const iId) {
  Selection_CalculateCursorPos(iId);

  xs_vec_copy(g_rgvecSelectionCursor[iId], g_rgvecSelectionStart[iId]);

  ArrayClear(g_rgirgSelectionEntities[iId]);

  g_rgbSelectionStarted[iId] = true;
  g_rgflSelectionNextThink[iId] = g_flGameTime;
}

Selection_End(const iId) {
  if (!g_rgbSelectionStarted[iId]) return;

  xs_vec_copy(g_rgvecSelectionCursor[iId], g_rgvecSelectionEnd[iId]);

  UTIL_NormalizeBox(g_rgvecSelectionStart[iId], g_rgvecSelectionEnd[iId]);

  static Float:flMinz; flMinz = floatmin(
    TracePointHeight(g_rgvecSelectionEnd[iId], -8192.0),
    TracePointHeight(g_rgvecSelectionStart[iId], -8192.0)
  );

  static Float:flMaxZ; flMaxZ = floatmax(
    TracePointHeight(g_rgvecSelectionEnd[iId], 8192.0),
    TracePointHeight(g_rgvecSelectionStart[iId], 8192.0)
  );

  g_rgvecSelectionStart[iId][2] = flMinz;
  g_rgvecSelectionEnd[iId][2] = flMaxZ;

  Selection_FindEntities(iId);

  g_rgbSelectionStarted[iId] = false;
}

Selection_Think(const iId) {
  if (g_rgflSelectionNextThink[iId] > g_flGameTime) return;

  Selection_CalculateCursorPos(iId);

  if (~g_rgiSelectionFlags[iId] & Selection_Flag_DontDraw) {
    Selection_DrawSelection(iId);
  }

  if (g_rgfnSelectionThinkCallback[iId] != Invalid_FunctionPointer) {
    callfunc_begin_p(g_rgfnSelectionThinkCallback[iId]);
    callfunc_push_int(iId);
    callfunc_end();
  }

  g_rgflSelectionNextThink[iId] = g_flGameTime + g_rgflSelectionThinkTime[iId];
}

bool:Selection_CalculateCursorPos(const iId) {
  static pCursor; pCursor = g_rgpSelectionPointerEntity[iId];

  if (pCursor <= 0) return false;

  static Float:vecOrigin[3];
  static Float:vecAngles[3];

  if (IS_PLAYER(pCursor)) {
    ExecuteHam(Ham_EyePosition, pCursor, vecOrigin);
    pev(pCursor, pev_v_angle, vecAngles);
  } else {
    pev(pCursor, pev_origin, vecOrigin);
    pev(pCursor, pev_angles, vecAngles); 
  }

  static Float:vecForward[3]; angle_vector(vecAngles, ANGLEVECTOR_FORWARD, vecForward);
  static Float:vecEnd[3]; xs_vec_add_scaled(vecOrigin, vecForward, 8192.0, vecEnd);

  engfunc(EngFunc_TraceLine, vecOrigin, vecEnd, DONT_IGNORE_MONSTERS, pCursor, g_pTrace);

  get_tr2(g_pTrace, TR_vecEndPos, g_rgvecSelectionCursor[iId]);
  // iId[Selection_CursorYaw] = vecAngles[1];

  // DrawLine(pCursor, vecOrigin, g_rgvecSelectionCursor[iId], {255, 0, 0}, 255);

  return true;
}

Array:Selection_FindEntities(const iId) {
  for (new pEntity = 1; pEntity <= g_iMaxEntities; ++pEntity) {
    if (!pev_valid(pEntity)) continue;
    if (!UTIL_IsEntityInBox(pEntity, g_rgvecSelectionStart[iId], g_rgvecSelectionEnd[iId])) continue;

    static bResult; bResult = true;

    if (g_rgfnSelectionFilterCallback[iId] != Invalid_FunctionPointer) {
      callfunc_begin_p(g_rgfnSelectionFilterCallback[iId]);
      callfunc_push_int(iId);
      callfunc_push_int(pEntity);
      bResult = callfunc_end();
    }

    if (bResult) {
      ArrayPushCell(g_rgirgSelectionEntities[iId], pEntity);
    }
  }
}

Selection_RemoveEntity(const iId, pEntity) {
  if (g_rgirgSelectionEntities[iId] == Invalid_Array) return;

  static iIndex; iIndex = ArrayFindValue(g_rgirgSelectionEntities[iId], pEntity);
  if (iIndex == -1) return;

  ArrayDeleteItem(g_rgirgSelectionEntities[iId], iIndex);
}

stock Float:anglemod(Float:a) {
  return (360.0/65536) * (floatround(a * (65536.0/360.0), floatround_floor) & 65535);
}

Selection_DrawSelection(const iId) {
  static pPlayer; pPlayer = g_rgpSelectionPlayer[iId];
  if (!IS_PLAYER(pPlayer)) return;

  static iLifeTime; iLifeTime = max(floatround(g_rgflSelectionThinkTime[iId] * 10, floatround_ceil), 1);

  static iModelIndex = 0;
  if (!iModelIndex) {
    iModelIndex = engfunc(EngFunc_ModelIndex, g_szTrailModel);
  }

  // static Float:flYaw; flYaw = iId[Selection_CursorYaw];
  // flYaw -= 90.0;
  static Float:flHeight; flHeight = floatmax(g_rgvecSelectionStart[iId][2], g_rgvecSelectionCursor[iId][2]) + SelectionGroundOffset;

  // // client_print(pPlayer, print_center, "YAW: %f", flYaw);

  // static Float:vecSize[3]; xs_vec_sub(g_rgvecSelectionCursor[iId], g_rgvecSelectionStart[iId], vecSize);

  // static Float:vecHalfSize[3];
  // xs_vec_div_scalar(vecSize, 2.0, vecHalfSize);
  // for (new i = 0; i < 3; ++i) vecHalfSize[i] = floatabs(vecHalfSize[i]);

  // static Float:vecCenter[3];
  // for (new i = 0; i < 3; ++i) {
  //   vecCenter[i] = g_rgvecSelectionStart[iId][i] + (g_rgvecSelectionCursor[iId][i] - g_rgvecSelectionStart[iId][i]) / 2;
  // }

  // static Float:vecMin[3]; xs_vec_sub(g_rgvecSelectionStart[iId], vecCenter, vecMin);
  // static Float:vecMax[3]; xs_vec_sub(g_rgvecSelectionCursor[iId], vecCenter, vecMax);

  // static Float:rgflSquare[4][3];
  // xs_vec_set(rgflSquare[0], vecMin[0], vecMin[1], flHeight);
  // xs_vec_set(rgflSquare[1], vecMax[0], vecMin[1], flHeight);
  // xs_vec_set(rgflSquare[2], vecMax[0], vecMax[1], flHeight);
  // xs_vec_set(rgflSquare[3], vecMin[0], vecMax[1], flHeight);



  // // new Float:diagonalLength = floatsqroot(vecSize[0] * vecSize[0] + vecSize[1] * vecSize[1]);
  // // // new Float:diagonalAngle = floatatan2(vecSize[1], vecSize[0], radian) + xs_deg2rad(-flYaw);
  // // new Float:diagonalAngle = floatatan2(vecSize[1], vecSize[0], degrees);

  // // client_print(pPlayer, print_center, "ANGLE: %f", diagonalAngle);

  // // rgflSquare[1][0] = vecMin[0] + diagonalLength * floatcos(-diagonalAngle, degrees);
  // // rgflSquare[1][1] = vecMin[1] + diagonalLength * floatsin(diagonalAngle, degrees);

  // // rgflSquare[3][0] = vecMax[0] - diagonalLength * floatcos(diagonalAngle, degrees);
  // // rgflSquare[3][1] = vecMax[1] - diagonalLength * floatsin(diagonalAngle, degrees);

  // // static Float:flAspect; flAspect = vecSize[0] / vecSize[1];
  // // static Float:flYawFixed; flYawFixed = anglemod(anglemod(flYaw) + anglemod(xs_rad2deg(floatatan(floatsqroot(flAspect), radian))));

  // static Float:vecAngles[3]; xs_vec_set(vecAngles, 0.0, flYaw, 0.0);
  // static Float:rgAngleMatrix[3][4]; UTIL_AngleMatrix(vecAngles, rgAngleMatrix);
  // new Float:flDistance = floatabs(vecMax[1] - vecMin[1]) * floattan(flYaw, degrees);

  // static Float:vecDirection[3]; 
  // xs_vec_set(vecDirection, 1.0, 0.0, 0.0);
  // UTIL_RotateVectorByMatrix(vecDirection, rgAngleMatrix, vecDirection);

  // // static Float:vecPoint1[3];
  // // xs_vec_add_scaled(vecMax, vecDirection, flDistance, vecPoint1);
  // // xs_vec_add(vecPoint1, vecCenter, vecPoint1);

  // // static Float:vecPoint2[3];
  // // xs_vec_add_scaled(vecMin, vecDirection, -flDistance, vecPoint2);
  // // xs_vec_add(vecPoint2, vecCenter, vecPoint2);

  // // DrawLine(pPlayer, g_rgvecSelectionCursor[iId], vecPoint1, {255, 0, 0}, 255);
  // // DrawLine(pPlayer, vecPoint1, g_rgvecSelectionStart[iId], {255, 0, 0}, 255);
  // // DrawLine(pPlayer, g_rgvecSelectionStart[iId], vecPoint2, {255, 0, 0}, 255);
  // // DrawLine(pPlayer, vecPoint2, g_rgvecSelectionCursor[iId], {255, 0, 0}, 255);

  // // static Float:vecDirection[3]; xs_vec_sub(vecEnd, vecStart, vecDirection);

  // // static Float:flFixedYaw; flFixedYaw = float(floatround(flYaw, floatround_floor) % 90);

  // // static Float:vecRotatedDirection[3];
  // // vecRotatedDirection[0] = vecDirection[0] * floatcos(anglemod(-flFixedYaw), degrees) - vecDirection[1] * floatsin(anglemod(-flFixedYaw), degrees);
  // // vecRotatedDirection[1] = vecDirection[0] * floatsin(anglemod(-flFixedYaw), degrees) + vecDirection[1] * floatcos(anglemod(-flFixedYaw), degrees);

  // // static Float:vecEndRotated[3]; xs_vec_add(vecStart, vecRotatedDirection, vecEndRotated);
  // // static Float:vecPerpendicular[3]; xs_vec_set(vecPerpendicular, -vecRotatedDirection[1], vecRotatedDirection[0], 0.0);

  // // xs_vec_copy(vecStart, rgflSquare[0]);
  // // xs_vec_add(vecStart, vecPerpendicular, rgflSquare[1]);
  // // xs_vec_copy(vecEnd, rgflSquare[2]);
  // // xs_vec_add(vecEndRotated, vecPerpendicular, rgflSquare[3]);

  // // if (rgflSquare[1][0] > rgflSquare[3][0]) {
  // //   UTIL_FloatSwap(rgflSquare[1][0], rgflSquare[3][0]);
  // // }

  // // if (rgflSquare[1][1] < rgflSquare[3][1]) {
  // //   UTIL_FloatSwap(rgflSquare[1][1], rgflSquare[3][1]);
  // // }

  // // static Float:vecDirectionPoint[3];
  // // xs_vec_set(vecDirectionPoint, vecStart[0], vecEnd[1], 0.0);
  // // UTIL_RotateVectorByMatrix(vecDirectionPoint, rgAngleMatrix, vecDirectionPoint);

  // // static Float:vecProjection[3];
  // // xs_vec_add(vecDirectionPoint, vecCenter, vecProjection);

  // // static Float:vecAntiAngles[3]; xs_vec_set(vecAntiAngles, 0.0, flYaw, 0.0);
  // // static Float:rgAntiAngleMatrix[3][4]; UTIL_AngleMatrix(vecAntiAngles, rgAntiAngleMatrix);

  // // client_print(pPlayer, print_center, "%.3f %.3f", vecHalfSize[0], vecHalfSize[1]);

  // // static Float:vecDirection[3];
  // // xs_vec_set(vecDirection, 1.0, 1.0, 0.0);
  // // // xs_vec_normalize(vecDirection, vecDirection);
  // // UTIL_RotateVectorByMatrix(vecDirection, rgAntiAngleMatrix, vecDirection);

  // // static Float:vecOtherDirection[3];
  // // xs_vec_set(vecOtherDirection, INVALID_SELECTION_ID.0, INVALID_SELECTION_ID.0, 0.0);
  // // // xs_vec_normalize(vecOtherDirection, vecOtherDirection);
  // // UTIL_RotateVectorByMatrix(vecOtherDirection, rgAntiAngleMatrix, vecOtherDirection);

  // // for (new i = 0; i < 2; ++i) {
  // //   vecDirection[i] *= vecHalfSize[i];
  // //   vecOtherDirection[i] *= vecHalfSize[i];
  // // }

  // // static Float:rgflAbsSquare[4][3];
  // // xs_vec_set(rgflAbsSquare[0], vecHalfSize[0], vecHalfSize[1], flHeight);
  // // xs_vec_set(rgflAbsSquare[1], -vecHalfSize[0], vecHalfSize[1], flHeight);
  // // xs_vec_set(rgflAbsSquare[2], -vecHalfSize[0], -vecHalfSize[1], flHeight);
  // // xs_vec_set(rgflAbsSquare[3], vecHalfSize[0], -vecHalfSize[1], flHeight);

  // // for (new iPoint = 0; iPoint < 4; ++iPoint) {
  // //   UTIL_RotateVectorByMatrix(rgflAbsSquare[iPoint], rgAntiAngleMatrix, rgflAbsSquare[iPoint]);
  // // }

  // // xs_vec_copy(vecStart, rgflAbsSquare[0]);
  // // xs_vec_copy(vecEnd, rgflAbsSquare[2]);

  // // for (new iPoint = 0; iPoint < 4; ++iPoint) {
  // //   xs_vec_add(rgflAbsSquare[iPoint], vecCenter, rgflAbsSquare[iPoint]);
  // // }

  // // static Float:vecCenterUp[3]; xs_vec_add(vecCenter, Float:{0.0, 0.0, 128.0}, vecCenterUp);
  // // DrawLine(pPlayer, vecCenter, vecCenterUp, {0, 0, 255}, 255);

  // // static Float:vecCursorUp[3]; xs_vec_add(g_rgvecSelectionCursor[iId], Float:{0.0, 0.0, 32.0}, vecCursorUp);
  // // DrawLine(pPlayer, g_rgvecSelectionCursor[iId], vecCursorUp, {255, 0, 0}, 255);

  // // xs_vec_add(rgflAbsSquare[1], Float:{32.0, 32.0, 0.0}, rgflAbsSquare[1]);
  // // xs_vec_add(rgflAbsSquare[3], Float:{32.0, 32.0, 0.0}, rgflAbsSquare[3]);

  // // static Float:rgflAbsSquare[4][3];

  // // xs_vec_set(rgflAbsSquare[0], -vecWidth[0], -vecHeight[1], 0.0);
  
  // // xs_vec_add(vecWidth, vecCenter, vecWidth);
  // // xs_vec_add(vecHeight, vecCenter, vecHeight);

  // static Float:rgflAbsSquare[4][3];
  // for (new iPoint = 0; iPoint < 4; ++iPoint) {

  //   // if (iPoint == 0 || iPoint == 2) {
  //     xs_vec_add(rgflSquare[iPoint], vecCenter, rgflAbsSquare[iPoint]);
  //   // } else {
  //     // xs_vec_add(rgflSquare[iPoint], vecCenter, rgflAbsSquare[iPoint]);
  //     // UTIL_RotateVectorByMatrix(rgflSquare[iPoint], rgAngleMatrix, rgflAbsSquare[iPoint]);
  //     // xs_vec_add(rgflAbsSquare[iPoint], vecCenter, rgflAbsSquare[iPoint]);
  //     // xs_vec_add(rgflAbsSquare[iPoint], Float:{32.0, 32.0, 0.0}, rgflAbsSquare[iPoint]);
  //   // }
  // }

  // for (new i = 0; i < 4; ++i) {
  //   DrawLine(pPlayer, rgflAbsSquare[i], rgflAbsSquare[(i + 1) % 4], iId[Selection_Color], iId[Selection_Brightness]);
  // }

  // DrawLine(pPlayer, rgflAbsSquare[0], vecProjection, {255, 0, 0}, 255);
  // DrawLine(pPlayer, vecProjection, rgflAbsSquare[2], {255, 0, 0}, 255);

  for (new i = 0; i < 4; ++i) {
    engfunc(EngFunc_MessageBegin, MSG_ONE, SVC_TEMPENTITY, NULL_VECTOR, pPlayer);
    write_byte(TE_BEAMPOINTS);

    switch (i) {
      case 0: {
        engfunc(EngFunc_WriteCoord, g_rgvecSelectionStart[iId][0]);
        engfunc(EngFunc_WriteCoord, g_rgvecSelectionStart[iId][1]);
      }
      case 1: {
        engfunc(EngFunc_WriteCoord, g_rgvecSelectionStart[iId][0]);
        engfunc(EngFunc_WriteCoord, g_rgvecSelectionStart[iId][1]);
      }
      case 2: {
        engfunc(EngFunc_WriteCoord, g_rgvecSelectionCursor[iId][0]);
        engfunc(EngFunc_WriteCoord, g_rgvecSelectionStart[iId][1]);
      }
      case 3: {
        engfunc(EngFunc_WriteCoord, g_rgvecSelectionStart[iId][0]);
        engfunc(EngFunc_WriteCoord, g_rgvecSelectionCursor[iId][1]);
      }
    }

    engfunc(EngFunc_WriteCoord, flHeight);

    switch (i) {
      case 0: {
        engfunc(EngFunc_WriteCoord, g_rgvecSelectionStart[iId][0]);
        engfunc(EngFunc_WriteCoord, g_rgvecSelectionCursor[iId][1]);
      }
      case 1: {
        engfunc(EngFunc_WriteCoord, g_rgvecSelectionCursor[iId][0]);
        engfunc(EngFunc_WriteCoord, g_rgvecSelectionStart[iId][1]);
      }
      case 2: {
        engfunc(EngFunc_WriteCoord, g_rgvecSelectionCursor[iId][0]);
        engfunc(EngFunc_WriteCoord, g_rgvecSelectionCursor[iId][1]);
      }
      case 3: {
        engfunc(EngFunc_WriteCoord, g_rgvecSelectionCursor[iId][0]);
        engfunc(EngFunc_WriteCoord, g_rgvecSelectionCursor[iId][1]);
      }
    }

    engfunc(EngFunc_WriteCoord, flHeight);

    write_short(iModelIndex);
    write_byte(0);
    write_byte(0);
    write_byte(iLifeTime);
    write_byte(16);
    write_byte(0);
    write_byte(g_rgrgSelectionColor[iId][0]);
    write_byte(g_rgrgSelectionColor[iId][1]);
    write_byte(g_rgrgSelectionColor[iId][2]);
    write_byte(g_rgiSelectionBrightness[iId]);
    write_byte(0);
    message_end();
  }
}

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


/*--------------------------------[ Functions ]--------------------------------*/

FindFreeSelection() {
  for (new iId = 0; iId < MAX_SELECTIONS; ++iId) {
    if (g_rgiSelectionId[iId] == INVALID_SELECTION_ID) return iId;
  }

  return INVALID_SELECTION_ID;
}

Float:TracePointHeight(const Float:vecOrigin[], Float:flMaxDistance) {
  static Float:vecTarget[3]; xs_vec_set(vecTarget, vecOrigin[0], vecOrigin[1], vecOrigin[2] + flMaxDistance);
  engfunc(EngFunc_TraceLine, vecOrigin, vecTarget, IGNORE_MONSTERS, 0, g_pTrace);
  get_tr2(g_pTrace, TR_vecEndPos, vecTarget);

  return vecTarget[2];
}

/*--------------------------------[ Stocks ]--------------------------------*/

stock UTIL_IsEntityInBox(const pEntity, const Float:vecBoxMin[], const Float:vecBoxMax[]) {
  static Float:vecAbsMin[3]; pev(pEntity, pev_absmin, vecAbsMin);
  static Float:vecAbsMax[3]; pev(pEntity, pev_absmax, vecAbsMax);

  for (new i = 0; i < 3; ++i) {
    if (vecAbsMin[i] > vecBoxMax[i]) return false;
    if (vecAbsMax[i] < vecBoxMin[i]) return false;
  }

  return true;
}

stock UTIL_NormalizeBox(Float:vecMin[], Float:vecMax[]) {
  for (new i = 0; i < 3; ++i) {
    if (vecMin[i] > vecMax[i]) UTIL_FloatSwap(vecMin[i], vecMax[i]);
  }
}

stock UTIL_FloatSwap(&Float:flValue, &Float:flOther) {
  static Float:flTemp;

  flTemp = flValue;
  flValue = flOther;
  flOther = flTemp;
}

// DrawLine(pPlayer, const Float:rgflStart[], Float:rgflEnd[], const rgiColor[], iBrightness) {
//     static iModelIndex; iModelIndex = engfunc(EngFunc_ModelIndex, g_szTrailModel);

//     engfunc(EngFunc_MessageBegin, MSG_ONE, SVC_TEMPENTITY, Float:{0.0, 0.0, 0.0}, pPlayer);
//     write_byte(TE_BEAMPOINTS);
//     engfunc(EngFunc_WriteCoord, rgflStart[0]);
//     engfunc(EngFunc_WriteCoord, rgflStart[1]);
//     engfunc(EngFunc_WriteCoord, rgflStart[2]);
//     engfunc(EngFunc_WriteCoord, rgflEnd[0]);
//     engfunc(EngFunc_WriteCoord, rgflEnd[1]);
//     engfunc(EngFunc_WriteCoord, rgflEnd[2]);
//     write_short(iModelIndex);
//     write_byte(0);
//     write_byte(0);
//     write_byte(1);
//     write_byte(16);
//     write_byte(0);
//     write_byte(rgiColor[0]);
//     write_byte(rgiColor[1]);
//     write_byte(rgiColor[2]);
//     write_byte(iBrightness);
//     write_byte(0);
//     message_end();
// }
