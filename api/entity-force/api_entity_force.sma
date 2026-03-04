#pragma semicolon 1

#include <amxmodx>
#include <hamsandwich>
#include <fakemeta>
#include <xs>

#include <api_entity_force_const>

#define MAX_ENTITIES 2048
#define PLAYER_PREVENT_CLIMB (1<<5)

#define IS_PLAYER(%1) (%1 >= 1 && %1 <= MaxClients)

enum AxisForceMode {
  AxisForceMode_Ignore,
  AxisForceMode_Add,
  AxisForceMode_Set
};

new g_pTrace;

new g_pfwEntityAddForce;
new g_pfwEntityApplyForce;

new Float:g_flGameTime = 0.0;
new Float:g_rgvecEntityForce[MAX_ENTITIES + 1][3];
new AxisForceMode:g_rgrgEntityAxisForceMode[MAX_ENTITIES + 1][3];

new Float:g_rgflPlayerReleaseClimbBlock[MAX_PLAYERS + 1];

public plugin_precache() {
  g_pTrace = create_tr2();
}

public plugin_init() {
  register_plugin("[API] Entity Force", "1.0.1", "Hedgehog Fog");

  register_forward(FM_Think, "FMHook_Think");

  RegisterHamPlayer(Ham_Spawn, "HamHook_Player_Spawn_Post", .Post = 1);
  RegisterHamPlayer(Ham_Player_PreThink, "HamHook_Player_PostThink", .Post = 0);

  g_pfwEntityAddForce = CreateMultiForward("EntityForce_OnForceAdd", ET_IGNORE, FP_CELL, FP_ARRAY, FP_CELL);
  g_pfwEntityApplyForce = CreateMultiForward("EntityForce_OnForceApply", ET_IGNORE, FP_CELL, FP_ARRAY);
}

public plugin_natives() {
  register_library("api_entity_force");

  register_native("EntityForce_Add", "Native_AddEntityForce");
  register_native("EntityForce_Apply", "Native_ApplyEntityForce");
  register_native("EntityForce_Clear", "Native_ClearEntityForce");
  register_native("EntityForce_AddFromEntity", "Native_AddEntityForceFromEntity");
  register_native("EntityForce_AddFromOrigin", "Native_AddEntityForceFromOrigin");
  register_native("EntityForce_AddFromBBox", "Native_AddEntityForceFromBBox");
  register_native("EntityForce_TransferMomentum", "Native_TransferMomentum");
}

public plugin_end() {
  free_tr2(g_pTrace);
}

public server_frame() {
  g_flGameTime = get_gametime();
}

public Native_AddEntityForce(const iPluginId, const iArgc) {
  static pEntity; pEntity = get_param(1);
  static Float:vecForce[3]; get_array_f(2, vecForce, sizeof(vecForce));
  static EntityForce_Flags:iFlags; iFlags = EntityForce_Flags:get_param(3);

  @Entity_AddForce(pEntity, vecForce, iFlags);
}

public Native_ApplyEntityForce(const iPluginId, const iArgc) {
  static pEntity; pEntity = get_param(1);

  @Entity_ApplyForce(pEntity);
}

public Native_ClearEntityForce(const iPluginId, const iArgc) {
  static pEntity; pEntity = get_param(1);

  @Entity_ClearForce(pEntity);
}

public Native_AddEntityForceFromEntity(const iPluginId, const iArgc) {
  static pEntity; pEntity = get_param(1);
  static pOtherEntity; pOtherEntity = get_param(2);
  static Float:flForce; flForce = get_param_f(3);
  static EntityForce_Flags:iFlags; iFlags = EntityForce_Flags:get_param(4);

  @Entity_AddForceFromEntity(pEntity, flForce, pOtherEntity, iFlags);
}

public Native_AddEntityForceFromOrigin(const iPluginId, const iArgc) {
  static pEntity; pEntity = get_param(1);
  static Float:vecOrigin[3]; get_array_f(2, vecOrigin, sizeof(vecOrigin));
  static Float:flForce; flForce = get_param_f(3);
  static EntityForce_Flags:iFlags; iFlags = EntityForce_Flags:get_param(4);

  @Entity_AddForceFromOrigin(pEntity, flForce, vecOrigin, iFlags);
}

public Native_AddEntityForceFromBBox(const iPluginId, const iArgc) {
  static pEntity; pEntity = get_param(1);
  static Float:vecAbsMin[3]; get_array_f(2, vecAbsMin, sizeof(vecAbsMin));
  static Float:vecAbsMax[3]; get_array_f(3, vecAbsMax, sizeof(vecAbsMax));
  static Float:flForce; flForce = get_param_f(4);
  static EntityForce_Flags:iFlags; iFlags = EntityForce_Flags:get_param(5);
  static Float:flMinForce; flMinForce = get_param_f(6);
  static Float:flMaxForce; flMaxForce = get_param_f(7);
  static Float:flSoftDepthRatioMin; flSoftDepthRatioMin = get_param_f(8);
  static Float:flSoftDepthRatioMax; flSoftDepthRatioMax = get_param_f(9);

  @Entity_AddForceFromBBox(pEntity, flForce, vecAbsMin, vecAbsMax, flMinForce, flMaxForce, flSoftDepthRatioMin, flSoftDepthRatioMax, iFlags);
}

public Native_TransferMomentum(const iPluginId, const iArgc) {
  static pEntity; pEntity = get_param(1);
  static pTarget; pTarget = get_param(2);
  static Float:flRatio; flRatio = get_param_f(3);
  static EntityForce_Flags:iFlags; iFlags = EntityForce_Flags:get_param(4);

  @Entity_TransferMomentum(pEntity, pTarget, flRatio, iFlags);
}

public HamHook_Player_Spawn_Post(pPlayer) {
  @Player_ClimbPreventionThink(pPlayer);
}

public FMHook_Think(const pEntity) {
  if (!IS_PLAYER(pEntity)) {
    @Entity_ApplyForce(pEntity);
  }
}

public HamHook_Player_PostThink(const pPlayer) {
  @Entity_ApplyForce(pPlayer);
  @Player_ClimbPreventionThink(pPlayer);
}

@Entity_AddForce(const &this, const Float:vecForce[3], EntityForce_Flags:iFlags) {
  for (new iAxis = 0; iAxis < 3; ++iAxis) {
    if (iFlags & EntityForce_Flag_Overlap) {
      if (!vecForce[iAxis]) continue;
    }

    if (iFlags & EntityForce_Flag_Set) {
      g_rgvecEntityForce[this][iAxis] = vecForce[iAxis];
      g_rgrgEntityAxisForceMode[this][iAxis] = AxisForceMode_Set;
    } else {
      g_rgvecEntityForce[this][iAxis] += vecForce[iAxis];
      g_rgrgEntityAxisForceMode[this][iAxis] = AxisForceMode_Add;
    }
  }

  static ivecForce; ivecForce = PrepareArray(any:vecForce, 3, 0);

  ExecuteForward(g_pfwEntityAddForce, _, this, ivecForce, iFlags);
}

@Entity_ApplyForce(const &this) {
  static Float:vecVelocity[3]; pev(this, pev_velocity, vecVelocity);

  static Float:vecForce[3];
  static bool:bForceApplied; bForceApplied = false;

  for (new i = 0; i < 3; ++i) {
    if (g_rgrgEntityAxisForceMode[this][i] == AxisForceMode_Ignore) continue;

    if (g_rgrgEntityAxisForceMode[this][i] == AxisForceMode_Add) {
      vecForce[i] = g_rgvecEntityForce[this][i];
    } else if (g_rgrgEntityAxisForceMode[this][i] == AxisForceMode_Set) {
      vecForce[i] = g_rgvecEntityForce[this][i] - vecVelocity[i];
    }

    g_rgvecEntityForce[this][i] = 0.0;
    g_rgrgEntityAxisForceMode[this][i] = AxisForceMode_Ignore;
    bForceApplied = true;
  }

  if (!bForceApplied) return;

  // engfunc(EngFunc_AlertMessage, at_console, "Entity %d applying force: %f %f %f", this, vecForce[0], vecForce[1], vecForce[2]);

  xs_vec_add(vecVelocity, vecForce, vecVelocity);
  set_pev(this, pev_velocity, vecVelocity);

  if (IS_PLAYER(this)) {
    @Player_SetClimbPrevention(this, true);
    g_rgflPlayerReleaseClimbBlock[this] = g_flGameTime + 0.1;
  }

  static ivecForce; ivecForce = PrepareArray(any:vecForce, 3, 0);

  ExecuteForward(g_pfwEntityApplyForce, _, this, ivecForce);
}

@Entity_ClearForce(const &this) {
  for (new i = 0; i < 3; ++i) {
    g_rgvecEntityForce[this][i] = 0.0;
    g_rgrgEntityAxisForceMode[this][i] = AxisForceMode_Ignore;
  }
}

Float:@Entity_TransferMomentum(const &this, const &pTarget, Float:flRatio, EntityForce_Flags:iFlags) {
  static Float:vecOrigin[3]; pev(this, pev_origin, vecOrigin);
  static Float:vecVelocity[3]; pev(this, pev_velocity, vecVelocity);
  static Float:vecTargetOrigin[3]; pev(pTarget, pev_origin, vecTargetOrigin);

  static Float:vecDirection[3];
  xs_vec_sub(vecTargetOrigin, vecOrigin, vecDirection);
  xs_vec_normalize(vecDirection, vecDirection);

  static Float:vecTransferForce[3]; xs_vec_mul_scalar(vecVelocity, flRatio, vecTransferForce);

  static Float:flForce; flForce = xs_vec_dot(vecTransferForce, vecDirection);
  if (flForce <= 0.0) return 0.0;

  static Float:vecForce[3]; xs_vec_mul_scalar(vecDirection, flForce, vecForce);
  @Entity_AddForce(pTarget, vecForce, iFlags);

  xs_vec_sub(vecVelocity, vecForce, vecVelocity);
  set_pev(this, pev_velocity, vecVelocity);

  return flForce;
}

@Entity_AddForceFromEntity(const &this, Float:flForce, const &pEntity, EntityForce_Flags:iFlags) {
  static Float:vecOrigin[3]; pev(pEntity, pev_origin, vecOrigin);
  
  @Entity_AddForceFromOrigin(this, flForce, vecOrigin, iFlags);
}

@Entity_AddForceFromOrigin(const &this, Float:flForce, Float:vecSrc[3], EntityForce_Flags:iFlags) {
  static Float:vecOrigin[3]; pev(this, pev_origin, vecOrigin);

  static Float:vecForce[3];
  xs_vec_sub(vecOrigin, vecSrc, vecForce);
  xs_vec_normalize(vecForce, vecForce);
  xs_vec_mul_scalar(vecForce, flForce, vecForce);

  @Entity_AddForce(this, vecForce, iFlags);
}

@Entity_AddForceFromBBox(const &this, Float:flForce, const Float:vecAbsMin[3], const Float:vecAbsMax[3], Float:flForceMin, Float:flForceMax, Float:flSoftDepthRatioMin, Float:flSoftDepthRatioMax, EntityForce_Flags:iFlags) {
  static Float:vecIntersection[3]; pev(this, pev_origin, vecIntersection);
  static Float:vecToucherAbsMin[3]; pev(this, pev_absmin, vecToucherAbsMin);
  static Float:vecToucherAbsMax[3]; pev(this, pev_absmax, vecToucherAbsMax);

  // Find and check intersection point
  for (new iAxis = 0; iAxis < 3; ++iAxis) {
    if (vecIntersection[iAxis] < vecAbsMin[iAxis]) {
      vecIntersection[iAxis] = vecToucherAbsMax[iAxis];
    } else if (vecIntersection[iAxis] > vecAbsMax[iAxis]) {
      vecIntersection[iAxis] = vecToucherAbsMin[iAxis];
    }

    // If entity is outside BBox, abort
    if (vecAbsMin[iAxis] >= vecIntersection[iAxis]) return;
    if (vecAbsMax[iAxis] <= vecIntersection[iAxis]) return;
  }

  static iClosestAxis; iClosestAxis = -1;
  static Float:vecOffset[3]; xs_vec_copy(Float:{0.0, 0.0, 0.0}, vecOffset);

  // Find the closest open axis to push
  for (new iAxis = 0; iAxis < 3; ++iAxis) {
    // Calculate offset from entity to BBox sides for the axis
    static Float:rgflSideOffsets[2];
    rgflSideOffsets[0] = vecAbsMin[iAxis] - vecIntersection[iAxis];
    rgflSideOffsets[1] = vecAbsMax[iAxis] - vecIntersection[iAxis];

    // If Z axis and already found a push axis, break (prefer bottom)
    if (iAxis == 2 && iClosestAxis != -1) break;

    for (new iSide = 0; iSide < 2; ++iSide) {
      static Float:vecTarget[3];
      xs_vec_copy(vecIntersection, vecTarget);
      vecTarget[iAxis] += rgflSideOffsets[iSide];

      // Trace to check if side is open (not blocked by objects)
      engfunc(EngFunc_TraceMonsterHull, this, vecIntersection, vecTarget, IGNORE_MONSTERS | IGNORE_GLASS, this, g_pTrace);

      static Float:flFraction; get_tr2(g_pTrace, TR_flFraction, flFraction);

      // No exit, cannot push this way
      if (flFraction != 1.0) {
        rgflSideOffsets[iSide] = 0.0;
      }

      // Save minimum non-zero offset for this axis
      if (iAxis != 2) {
        if (!vecOffset[iAxis] || (rgflSideOffsets[iSide] && floatabs(rgflSideOffsets[iSide]) < floatabs(vecOffset[iAxis]))) {
          vecOffset[iAxis] = rgflSideOffsets[iSide];
        }
      } else {
        // For Z axis, prefer bottom side
        if (rgflSideOffsets[0]) {
          vecOffset[iAxis] = rgflSideOffsets[0];
        }
      }

      // Find closest axis to push
      if (vecOffset[iAxis]) {
        if (iClosestAxis == -1 || floatabs(vecOffset[iAxis]) < floatabs(vecOffset[iClosestAxis])) {
          iClosestAxis = iAxis;
        }
      }
    }
  }

  // If no open axis found, do not push
  if (iClosestAxis == -1) return;
  
  // Determine push direction (+/-)

  static Float:vecSize[3]; xs_vec_sub(vecAbsMax, vecAbsMin, vecSize);

  // Calculate depth factor (how far entity is from BBox center on push axis)
  static Float:flDepthRatio; flDepthRatio = floatclamp(
    floatabs(vecOffset[iClosestAxis]) / (vecSize[iClosestAxis] / 2),
    0.0,
    1.0
  );

  static Float:vecForce[3]; xs_vec_copy(Float:{0.0, 0.0, 0.0}, vecForce);
  
  // Check if entity is within "depth factor" region for scaled force
  static bool:bInSoftRegion; bInSoftRegion = (
    flDepthRatio >= flSoftDepthRatioMin &&
    flDepthRatio <= flSoftDepthRatioMax
  );

  static iPushDir; iPushDir = vecOffset[iClosestAxis] > 0.0 ? 1 : -1;

  if (bInSoftRegion) {
    vecForce[iClosestAxis] = floatclamp(flForce * flDepthRatio, flForceMin, flForceMax) * iPushDir;
  } else {
    vecForce[iClosestAxis] = floatclamp(flForce, flForceMin, flForceMax) * iPushDir;

    if (iFlags & EntityForce_Flag_ForceSetOutOfSoft) {
      iFlags = EntityForce_Flag_Set;
    }
  }

  @Entity_AddForce(this, vecForce, iFlags);
}

@Player_SetClimbPrevention(const &this, bool:bValue) {
  new iPlayerFlags = pev(this, pev_iuser3);

  if (bValue) {
    iPlayerFlags |= PLAYER_PREVENT_CLIMB;
  } else {
    iPlayerFlags &= ~PLAYER_PREVENT_CLIMB;
  }

  set_pev(this, pev_iuser3, iPlayerFlags);
}

@Player_ClimbPreventionThink(const &this) {
  if (g_rgflPlayerReleaseClimbBlock[this] && g_rgflPlayerReleaseClimbBlock[this] <= g_flGameTime) {
    @Player_SetClimbPrevention(this, false);
    g_rgflPlayerReleaseClimbBlock[this] = 0.0;
  }
}
