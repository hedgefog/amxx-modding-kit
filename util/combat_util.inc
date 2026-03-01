#if defined _combat_util_included
  #endinput
#endif
#define _combat_util_included

#include <amxmodx>
#include <engine>
#include <fakemeta>
#include <xs>
#tryinclude <reapi>
#tryinclude <function_pointer>

#if !defined MAX_ITEM_TYPES
  #define MAX_ITEM_TYPES 6 // hud item selection slots
#endif

enum {
  STEP_CONCRETE = 0,
  STEP_METAL,
  STEP_DIRT,
  STEP_VENT,
  STEP_GRATE,
  STEP_TILE,
  STEP_SLOSH,
  STEP_WADE,
  STEP_LADDER,
  STEP_SNOW
};

stock UTIL_SparkShower(const Float:vecOrigin[3], const Float:vecAngles[3], const &pOwner = 0) {
  static iszClassname = 0;
  if (!iszClassname) {
    iszClassname = engfunc(EngFunc_AllocString, "spark_shower");
  }

  static pSparkShower; pSparkShower = engfunc(EngFunc_CreateNamedEntity, iszClassname);
  if (!pSparkShower) return;

  engfunc(EngFunc_SetOrigin, pSparkShower, vecOrigin);
  set_pev(pSparkShower, pev_angles, vecAngles);
  set_pev(pSparkShower, pev_owner, pOwner);
  dllfunc(DLLFunc_Spawn, pSparkShower);
}

stock UTIL_GrenadeExplosion(const Float:vecOrigin[3], Float:flDamage) {
  static iExplosionModelIndex = 0;
  if (!iExplosionModelIndex) {
    iExplosionModelIndex = engfunc(EngFunc_ModelIndex, "sprites/zerogxplode.spr");
  }

  static iWaterExplosionModelIndex = 0;
  if (!iWaterExplosionModelIndex) {
    iWaterExplosionModelIndex = engfunc(EngFunc_ModelIndex, "sprites/WXplo1.spr");
  }
  
  static iModelIndex; iModelIndex = engfunc(EngFunc_PointContents, vecOrigin) == CONTENTS_WATER ? iWaterExplosionModelIndex : iExplosionModelIndex;

  static iScale; iScale = clamp(floatround((flDamage - 50.0) * 0.60), 8, 255);

  engfunc(EngFunc_MessageBegin, MSG_PAS, SVC_TEMPENTITY, vecOrigin, 0);
  write_byte(TE_EXPLOSION);
  engfunc(EngFunc_WriteCoord, vecOrigin[0]);
  engfunc(EngFunc_WriteCoord, vecOrigin[1]);
  engfunc(EngFunc_WriteCoord, vecOrigin[2]);
  write_short(iModelIndex);
  write_byte(iScale);
  write_byte(15);
  write_byte(TE_EXPLFLAG_NONE);
  message_end();
}

stock UTIL_GrenadeSmoke(const &pGrenade) {
  static Float:vecOrigin[3]; pev(pGrenade, pev_origin, vecOrigin);
  static Float:flDamage; pev(pGrenade, pev_dmg, flDamage);

  if (engfunc(EngFunc_PointContents, vecOrigin) == CONTENTS_WATER) {
    static const Float:vecSize[3] = {64.0, 64.0, 64.0};
    static Float:vecMins[3]; xs_vec_sub(vecOrigin, vecSize, vecMins);
    static Float:vecMaxs[3]; xs_vec_add(vecOrigin, vecSize, vecMaxs);

    UTIL_Bubbles(vecMins, vecMaxs, 100);
  } else {
    static iModelIndex = 0;
    if (!iModelIndex) {
      iModelIndex = engfunc(EngFunc_ModelIndex, "sprites/steam1.spr");
    }

    static Float:flRadius; flRadius = (flDamage - 50.0) * 0.80;
    if (flRadius < 8.0) {
      flRadius = 9.0;
    }
      
    engfunc(EngFunc_MessageBegin, MSG_PAS, SVC_TEMPENTITY, vecOrigin, 0);
    write_byte(TE_SMOKE);
    engfunc(EngFunc_WriteCoord, vecOrigin[0]);
    engfunc(EngFunc_WriteCoord, vecOrigin[1]);
    engfunc(EngFunc_WriteCoord, vecOrigin[2]);
    write_short(iModelIndex);
    write_byte(floatround(flRadius)); // scale * 10
    write_byte(12); // framerate
    message_end();
  }
}

stock UTIL_Bubbles(const Float:vecMins[3], const Float:vecMaxs[3], iAmount) {
  static Float:vecMid[3];
  for (new i = 0; i < 3; ++i) {
    vecMid[i] = (vecMins[i] + vecMaxs[i]) * 0.5;
  }

  static Float:flHeight; flHeight = UTIL_WaterLevel(vecMid, vecMid[2], vecMid[2] + 1024.0) - vecMins[2];

  static iModelIndex = 0;
  if (!iModelIndex) {
    iModelIndex = engfunc(EngFunc_ModelIndex, "sprites/bubble.spr");
  }

  engfunc(EngFunc_MessageBegin, MSG_PAS, SVC_TEMPENTITY, vecMid, 0);
  write_byte(TE_BUBBLES);
  engfunc(EngFunc_WriteCoord, vecMins[0]);
  engfunc(EngFunc_WriteCoord, vecMins[1]);
  engfunc(EngFunc_WriteCoord, vecMins[2]);
  engfunc(EngFunc_WriteCoord, vecMaxs[0]);
  engfunc(EngFunc_WriteCoord, vecMaxs[1]);
  engfunc(EngFunc_WriteCoord, vecMaxs[2]);
  engfunc(EngFunc_WriteCoord, flHeight);
  write_short(iModelIndex);
  write_byte(iAmount);
  write_coord(8);
  message_end();
}

stock UTIL_DecalTrace(const &pTrace, iDecal) {
  if (iDecal < 0) return;

  static Float:flFraction; get_tr2(pTrace, TR_flFraction, flFraction);
  if (flFraction == 1.0) return;

  // Only decal BSP models
  static pHit; pHit = get_tr2(pTrace, TR_pHit);
  if (pHit != FM_NULLENT) {
    if (pHit && !ExecuteHam(Ham_IsBSPModel, pHit)) return;
  } else {
    pHit = 0;
  }

  static iMessage; iMessage = TE_DECAL;
  if (pHit) {
    if (iDecal > 255) {
      iMessage = TE_DECALHIGH;
      iDecal -= 256;
    }
  } else {
    iMessage = TE_WORLDDECAL;
    if (iDecal > 255) {
      iMessage = TE_WORLDDECALHIGH;
      iDecal -= 256;
    }
  }

  static Float:vecEndPos[3]; get_tr2(pTrace, TR_vecEndPos, vecEndPos);

  engfunc(EngFunc_MessageBegin, MSG_BROADCAST, SVC_TEMPENTITY, vecEndPos, 0);
  write_byte(iMessage);
  engfunc(EngFunc_WriteCoord, vecEndPos[0]);
  engfunc(EngFunc_WriteCoord, vecEndPos[1]);
  engfunc(EngFunc_WriteCoord, vecEndPos[2]);
  write_byte(iDecal);

  if (pHit) {
    write_short(pHit);
  }

  message_end();
}

stock UTIL_BulletSmoke(const &pTrace) {
  static Float:vecSrc[3]; get_tr2(pTrace, TR_vecEndPos, vecSrc);

  static Float:vecEnd[3];
  get_tr2(pTrace, TR_vecPlaneNormal, vecEnd);
  xs_vec_mul_scalar(vecEnd, 2.5, vecEnd);
  xs_vec_add(vecSrc, vecEnd, vecEnd);

  static iModelIndex = 0;
  if (!iModelIndex) {
    iModelIndex = engfunc(EngFunc_ModelIndex, "sprites/smokepuff.spr");
  }

  // engfunc(EngFunc_MessageBegin, MSG_PAS, SVC_TEMPENTITY, vecEnd, 0);
  // write_byte(TE_EXPLOSION);
  // engfunc(EngFunc_WriteCoord, vecEnd[0]);
  // engfunc(EngFunc_WriteCoord, vecEnd[1]);
  // engfunc(EngFunc_WriteCoord, vecEnd[2] - 10.0);
  // write_short(iModelIndex);
  // write_byte(2);
  // write_byte(50);
  // write_byte(TE_EXPLFLAG_NODLIGHTS | TE_EXPLFLAG_NOSOUND | TE_EXPLFLAG_NOPARTICLES);
  // message_end();

  engfunc(EngFunc_MessageBegin, MSG_PAS, SVC_TEMPENTITY, vecEnd, 0);
  write_byte(TE_SPRITE);
  engfunc(EngFunc_WriteCoord, vecEnd[0]);
  engfunc(EngFunc_WriteCoord, vecEnd[1]);
  engfunc(EngFunc_WriteCoord, vecEnd[2]);
  write_short(iModelIndex);
  write_byte(5);
  write_byte(25);
  message_end();
}

stock UTIL_MakeDecal(const &pTrace, const &pEntity, iDecalIndex, bool:bGunshotDecal = true) {
  static Float:flFraction; get_tr2(pTrace, TR_flFraction, flFraction);
  if (flFraction >= 1.0) return;

  static vecOrigin[3]; get_tr2(pTrace, TR_vecEndPos, vecOrigin);
  static pHit; pHit = get_tr2(pTrace, TR_pHit);

  if (pHit == FM_NULLENT) {
    pHit = 0;
  }

  if(pHit) {
    emessage_begin(MSG_BROADCAST, SVC_TEMPENTITY);
    ewrite_byte(iDecalIndex > 255 ? TE_DECALHIGH : TE_DECAL);
    engfunc(EngFunc_WriteCoord, vecOrigin[0]);
    engfunc(EngFunc_WriteCoord, vecOrigin[1]);
    engfunc(EngFunc_WriteCoord, vecOrigin[2]);
    ewrite_byte(iDecalIndex > 255 ? iDecalIndex - 256 : iDecalIndex);
    ewrite_short(pHit);
    emessage_end();
  } else {
    emessage_begin(MSG_BROADCAST, SVC_TEMPENTITY);
    ewrite_byte(iDecalIndex > 255 ? TE_WORLDDECALHIGH : TE_WORLDDECAL);
    engfunc(EngFunc_WriteCoord, vecOrigin[0]);
    engfunc(EngFunc_WriteCoord, vecOrigin[1]);
    engfunc(EngFunc_WriteCoord, vecOrigin[2]);
    ewrite_byte(iDecalIndex > 255 ? iDecalIndex - 256 : iDecalIndex);
    emessage_end();
  }

  if (bGunshotDecal) {
    message_begin(MSG_BROADCAST, SVC_TEMPENTITY);
    write_byte(TE_GUNSHOTDECAL);
    engfunc(EngFunc_WriteCoord, vecOrigin[0]);
    engfunc(EngFunc_WriteCoord, vecOrigin[1]);
    engfunc(EngFunc_WriteCoord, vecOrigin[2]);
    write_short(pEntity);
    write_byte(iDecalIndex);
    message_end();
  }
}

stock UTIL_BubbleTrail(const Float:vecFrom[3], const Float:vecTo[3], iAmount) {
  static Float:flHeight; flHeight = UTIL_WaterLevel(vecFrom, vecFrom[2], vecFrom[2] + 256.0) - vecFrom[2];

  if (flHeight < 8.0) {
    flHeight = UTIL_WaterLevel(vecTo, vecTo[2], vecTo[2] + 256.0);
    flHeight = flHeight - vecTo[2];

    if (flHeight < 8.0) return;

    flHeight = flHeight + vecTo[2] - vecFrom[2];
  }

  iAmount = min(iAmount, 255);

  static iModelIndex;
  if (!iModelIndex) {
    iModelIndex = engfunc(EngFunc_ModelIndex, "sprites/bubble.spr");
  }

  engfunc(EngFunc_MessageBegin, MSG_BROADCAST, SVC_TEMPENTITY, vecFrom, 0);
  write_byte(TE_BUBBLETRAIL);
  engfunc(EngFunc_WriteCoord, vecFrom[0]);
  engfunc(EngFunc_WriteCoord, vecFrom[1]);
  engfunc(EngFunc_WriteCoord, vecFrom[2]);
  engfunc(EngFunc_WriteCoord, vecTo[0]);
  engfunc(EngFunc_WriteCoord, vecTo[1]);
  engfunc(EngFunc_WriteCoord, vecTo[2]);
  engfunc(EngFunc_WriteCoord, flHeight);
  write_short(iModelIndex);
  write_byte(iAmount);
  write_coord(8);
  message_end();
}

stock UTIL_ExplosionDecalTrace(const &pTrace) {
  static const rgszDecals[][] = { "{scorch1", "{scorch2", "{scorch3" };

  UTIL_DecalTrace(pTrace, engfunc(EngFunc_DecalIndex, rgszDecals[random(sizeof(rgszDecals))]));
}

stock UTIL_DebrisSound(const &pEntity) {
  static const rgszSounds[][] = { "weapons/debris1.wav", "weapons/debris2.wav", "weapons/debris3.wav" };

  emit_sound(pEntity, CHAN_VOICE, rgszSounds[random(sizeof(rgszSounds))], 0.55, ATTN_NORM, 0, PITCH_NORM);
}

stock UTIL_RadiusDamage(const Float:vecOrigin[3], const &pInflictor, const &pAttacker, Float:flDamage, Float:flRadius, iClassIgnore, iDamageBits) {
  #pragma unused iClassIgnore

  static rgpEntities[512];
  static iEntitiesNum; iEntitiesNum = 0;

  // in case grenade is lying on the ground
  static Float:vecSrc[3]; xs_vec_set(vecSrc, vecOrigin[0], vecOrigin[1], vecOrigin[2] + 1.0);
  static Float:flFalloff; flFalloff = flRadius ? (flDamage / flRadius) : 1.0;
  static bool:bInWater; bInWater = (engfunc(EngFunc_PointContents, vecSrc) == CONTENTS_WATER);
  static pRealAttacker; pRealAttacker = pAttacker ? pAttacker : pInflictor;

  static pEntity; pEntity = 0;

  while ((pEntity = engfunc(EngFunc_FindEntityInSphere, pEntity, vecSrc, flRadius)) != 0) {
    if (!pev_valid(pEntity)) continue;
    if (pev(pEntity, pev_takedamage) == DAMAGE_NO) continue;
    if (pEntity >= 1 && pEntity <= MaxClients) {
      #if defined _reapi_included
        if (!rg_is_player_can_takedamage(pEntity, pRealAttacker)) continue;
      #endif
    }

    static iWaterLevel; iWaterLevel = pev(pEntity, pev_waterlevel);

    if (bInWater && iWaterLevel == 0) continue;
    if (!bInWater && iWaterLevel == 3) continue;

    rgpEntities[iEntitiesNum++] = pEntity;
    if (iEntitiesNum >= sizeof(rgpEntities)) break;
  }

  new pTrace = create_tr2();

  for (new i = 0; i < iEntitiesNum; ++i) {
    pEntity = rgpEntities[i];

    static Float:vecSpot[3];
    ExecuteHam(Ham_Center, pEntity, vecSpot);
    engfunc(EngFunc_TraceLine, vecSrc, vecSpot, DONT_IGNORE_MONSTERS, pInflictor, pTrace);

    static Float:flFraction; get_tr2(pTrace, TR_flFraction, flFraction);

    if (flFraction != 1.0 && get_tr2(pTrace, TR_pHit) != pEntity) continue;

    if (get_tr2(pTrace, TR_StartSolid)) {
      set_tr2(pTrace, TR_vecEndPos, vecSrc);
      set_tr2(pTrace, TR_flFraction, 0.0);
      flFraction = 0.0;
    }

    static Float:vecEnd[3]; get_tr2(pTrace, TR_vecEndPos, vecEnd);

    static Float:flAdjustedDamage; flAdjustedDamage = floatmax(flDamage - (get_distance_f(vecSrc, vecEnd) * flFalloff), 0.0);

    #if defined _reapi_included
      if (flFraction != 1.0) {
        static Float:vecDir[3];
        xs_vec_sub(vecEnd, vecSrc, vecDir);
        xs_vec_normalize(vecDir, vecDir);

        rg_multidmg_clear();
        ExecuteHamB(Ham_TraceAttack, pEntity, pInflictor, flAdjustedDamage, vecDir, pTrace, iDamageBits);
        rg_multidmg_apply(pInflictor, pRealAttacker);
      } else {
        ExecuteHamB(Ham_TakeDamage, pEntity, pInflictor, pRealAttacker, flAdjustedDamage, iDamageBits);
      }
    #else
      ExecuteHamB(Ham_TakeDamage, pEntity, pInflictor, pRealAttacker, flAdjustedDamage, iDamageBits);
    #endif
  }

  free_tr2(pTrace);
}

stock Float:UTIL_WaterLevel(const Float:vecPosition[3], Float:flMinZ, Float:flMaxZ) {
  static Float:vecMidUp[3]; xs_vec_copy(vecPosition, vecMidUp);

  vecMidUp[2] = flMinZ;
  if (engfunc(EngFunc_PointContents, vecMidUp) != CONTENTS_WATER) return flMinZ;

  vecMidUp[2] = flMaxZ;
  if (engfunc(EngFunc_PointContents, vecMidUp) == CONTENTS_WATER) return flMaxZ;

  static Float:flDiff; flDiff = flMaxZ - flMinZ;
  while (flDiff > 1.0) {
    vecMidUp[2] = flMinZ + (flDiff / 2.0);

    if (engfunc(EngFunc_PointContents, vecMidUp) == CONTENTS_WATER) {
      flMinZ = vecMidUp[2];
    } else {
      flMaxZ = vecMidUp[2];
    }

    flDiff = flMaxZ - flMinZ;
  }

  return vecMidUp[2];
}

stock UTIL_FindWeaponBoxSingleItem(const &pWeaponBox) {
  static pItem; pItem = FM_NULLENT;

  for (new iSlot = 0; iSlot < 6; ++iSlot) {
    static pOtherItem; pOtherItem = get_ent_data(pWeaponBox, "CWeaponBox", "m_rgpPlayerItems", iSlot);
    if (pOtherItem == FM_NULLENT) continue;
    if (pItem != FM_NULLENT) return FM_NULLENT;
    if (get_ent_data(pOtherItem, "CBasePlayerItem", "m_pNext") != FM_NULLENT) return FM_NULLENT;

    pItem = pOtherItem;
  }

  return pItem;
}

stock UTIL_FindHullIntersection(const Float:vecSrc[3], &pTrace, const Float:vecMins[3], const Float:vecMaxs[3], const &pEntity) {
  static Float:flDistance; flDistance = 8192.0;

  static Float:rgvecMinsMaxs[2][3];

  for (new i = 0; i < 3; ++i) {
    rgvecMinsMaxs[0][i] = vecMins[i];
    rgvecMinsMaxs[1][i] = vecMaxs[i];
  }

  static Float:vecHullEnd[3]; get_tr2(pTrace, TR_vecEndPos, vecHullEnd);

  for (new i = 0; i < 3; ++i) {
    vecHullEnd[i] = vecSrc[i] + ((vecHullEnd[i] - vecSrc[i]) * 2.0);
  }

  static pTmpTrace; pTmpTrace = create_tr2();

  engfunc(EngFunc_TraceLine, vecSrc, vecHullEnd, DONT_IGNORE_MONSTERS, pEntity, pTmpTrace);

  static Float:flFraction; get_tr2(pTmpTrace, TR_flFraction, flFraction);

  if (flFraction < 1.0) {
    free_tr2(pTrace);
    pTrace = pTmpTrace;
    return;
  }

  static Float:vecEnd[3];
  for (new i = 0; i < 2; i++) {
    for (new j = 0; j < 2; j++) {
      for (new k = 0; k < 2; k++) {
        vecEnd[0] = vecHullEnd[0] + rgvecMinsMaxs[i][0];
        vecEnd[1] = vecHullEnd[1] + rgvecMinsMaxs[j][1];
        vecEnd[2] = vecHullEnd[2] + rgvecMinsMaxs[k][2];

        engfunc(EngFunc_TraceLine, vecSrc, vecEnd, DONT_IGNORE_MONSTERS, pEntity, pTmpTrace);
        get_tr2(pTmpTrace, TR_flFraction, flFraction);

        if (flFraction < 1.0) {
          static Float:vecEndPos[3]; get_tr2(pTmpTrace, TR_vecEndPos, vecEndPos);
          static Float:flThisDistance; flThisDistance = get_distance_f(vecEndPos, vecSrc);

          if (flThisDistance < flDistance) {
            UTIL_Swap(pTrace, pTmpTrace);
            flDistance = flThisDistance;
          }
        }
      }
    }
  }

  if (pTrace != pTmpTrace) {
    free_tr2(pTmpTrace);
  } else {
    free_tr2(pTrace);
  }
}

stock UTIL_SendWeaponAnim(pWeapon, iAnim, iBody = -1) {
  static pPlayer; pPlayer = get_ent_data_entity(pWeapon, "CBasePlayerItem", "m_pPlayer");

  UTIL_SendPlayerWeaponAnim(pPlayer, pWeapon, iAnim, iBody);

  for (new pSpectator = 1; pSpectator <= MaxClients; pSpectator++) {
    if (pSpectator == pPlayer) continue;
    if (!is_user_connected(pSpectator)) continue;
    if (pev(pSpectator, pev_iuser1) != OBS_IN_EYE) continue;
    if (pev(pSpectator, pev_iuser2) != pPlayer) continue;

    UTIL_SendPlayerWeaponAnim(pSpectator, pWeapon, iAnim, iBody);
  }
}

stock UTIL_SendPlayerWeaponAnim(pPlayer, pWeapon, iAnim, iBody = -1) {
  if (iBody == -1) {
    iBody = pev(pWeapon, pev_body);
  }

  set_pev(pPlayer, pev_weaponanim, iAnim);

  if (!is_user_bot(pPlayer)) {
    emessage_begin(MSG_ONE, SVC_WEAPONANIM, _, pPlayer);
    ewrite_byte(iAnim);
    ewrite_byte(iBody);
    emessage_end();
  }
}

stock UTIL_FindPlayerItemByClassname(pPlayer, const szClassname[]) {
  for (new iSlot = 0; iSlot < MAX_ITEM_TYPES; iSlot++) {
    static pItem; pItem = get_ent_data_entity(pPlayer, "CBasePlayer", "m_rgpPlayerItems", iSlot);

    if (pItem == FM_NULLENT) continue;

    while (pItem != FM_NULLENT) {
      static szCurrentItemClassname[64]; pev(pItem, pev_classname, szCurrentItemClassname, charsmax(szCurrentItemClassname));

      if (equal(szCurrentItemClassname, szClassname)) return pItem;

      pItem = get_ent_data_entity(pItem, "CBasePlayerItem", "m_pNext");
    }
  }

  return FM_NULLENT;
}

stock UTIL_FindPlayerItemById(pPlayer, iWeaponId) {
  for (new iSlot = 0; iSlot < MAX_ITEM_TYPES; iSlot++) {
    static pItem; pItem = get_ent_data_entity(pPlayer, "CBasePlayer", "m_rgpPlayerItems", iSlot);

    if (pItem == FM_NULLENT) continue;

    while (pItem != FM_NULLENT) {
      if (iWeaponId == get_ent_data(pItem, "CBasePlayerItem", "m_iId")) return pItem;

      pItem = get_ent_data_entity(pPlayer, "CBasePlayerItem", "m_pNext");
    }
  }

  return FM_NULLENT;
}

stock bool:UTIL_SelectItem(pPlayer, const szClassname[]) {
  new pItem = UTIL_FindPlayerItemByClassname(pPlayer, szClassname);
  if (pItem == FM_NULLENT) return false;

  new pActiveItem = get_ent_data_entity(pPlayer, "CBasePlayer", "m_pActiveItem");
  if (pItem == pActiveItem) return false;

  UTIL_ResetAutoAim(pPlayer);

  if (pActiveItem != FM_NULLENT) {
    ExecuteHamB(Ham_Item_Holster, pActiveItem, 0);
  }

  set_ent_data_entity(pPlayer, "CBasePlayer", "m_pLastItem", pActiveItem);
  set_ent_data_entity(pPlayer, "CBasePlayer", "m_pActiveItem", (pActiveItem = pItem));

  if (pActiveItem != FM_NULLENT) {
    ExecuteHamB(Ham_Item_Deploy, pActiveItem);
    ExecuteHamB(Ham_Item_UpdateItemInfo, pActiveItem);
  }

  return true;
}

stock UTIL_ResetAutoAim(pPlayer) {
  static Float:vecAutoAim[3]; get_ent_data_vector(pPlayer, "CBasePlayer", "m_vecAutoAim", vecAutoAim);

  if (vecAutoAim[0] != 0 || vecAutoAim[1] != 0) {
    set_ent_data_vector(pPlayer, "CBasePlayer", "m_vecAutoAim", Float:{0.0, 0.0, 0.0});
    engfunc(EngFunc_CrosshairAngle, pPlayer, 0, 0);
  }

  set_ent_data(pPlayer, "CBasePlayer", "m_fOnTarget", false);
}

stock bool:UTIL_EjectWeaponBrass(const &pWeapon, iModelIndex, iSoundType = 0, iLifeTime = 25, const Float:vecOffset[] = { 0.0, 0.0, 0.0 }, const Float:vecSpeed[] = { 0.0, 0.0, 0.0 }, bool:bInverseHand = false) {
  if (!iModelIndex) return false;
  
  static pPlayer; pPlayer = get_ent_data_entity(pWeapon, "CBasePlayerItem", "m_pPlayer");

  static Float:vecAngles[3]; pev(pPlayer, pev_angles, vecAngles);
  static Float:vecUp[3]; angle_vector(vecAngles, ANGLEVECTOR_UP, vecUp);
  static Float:vecForward[3]; angle_vector(vecAngles, ANGLEVECTOR_FORWARD, vecForward);
  static Float:vecRight[3]; angle_vector(vecAngles, ANGLEVECTOR_RIGHT, vecRight);
  static Float:vecSrc[3]; ExecuteHam(Ham_Player_GetGunPosition, pPlayer, vecSrc);
  static Float:vecVelocity[3]; pev(pPlayer, pev_velocity, vecVelocity);

  if (bInverseHand) {
    xs_vec_neg(vecRight, vecRight);
  }

  for (new i = 0; i < 3; ++i) {
    vecSrc[i] += (vecRight[i] * vecOffset[0]) + (vecUp[i] * vecOffset[1]) + (vecForward[i] * vecOffset[2]);
  }

  for (new i = 0; i < 3; ++i) {
    vecVelocity[i] += (vecRight[i] * vecSpeed[0]) + (vecUp[i] * vecSpeed[1]) + (vecForward[i] * vecSpeed[2]);
  }

  engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, vecSrc, 0);
  write_byte(TE_MODEL);
  engfunc(EngFunc_WriteCoord, vecSrc[0]);
  engfunc(EngFunc_WriteCoord, vecSrc[1]);
  engfunc(EngFunc_WriteCoord, vecSrc[2]);
  engfunc(EngFunc_WriteCoord, vecVelocity[0]);
  engfunc(EngFunc_WriteCoord, vecVelocity[1]);
  engfunc(EngFunc_WriteCoord, vecVelocity[2]);
  engfunc(EngFunc_WriteAngle, vecAngles[1]);
  write_short(iModelIndex);
  write_byte(iSoundType);
  write_byte(iLifeTime);
  message_end();

  return true;
}

stock Float:UTIL_GetConeVector(Float:flDegrees, Float:vecOut[3] = {0.0, 0.0, 0.0}) {
  static Float:flValue; flValue = xs_deg2rad(flDegrees / 2);

  // static Float:vecOut[3];
  vecOut[0] = flValue;
  vecOut[1] = flValue;
  vecOut[2] = flValue;

  return vecOut;
}

stock Float:UTIL_CalculateWeaponSpread(const &pWeapon, const Float:vecSpread[3], iShotsFired = 0, Float:flMovementFactor = 1.0, Float:flFirstShotModifier = 1.0, Float:flDuckFactor = 1.0, Float:flAirFactor = 1.0, Float:vecOut[3]) {
    static Float:flRatio; flRatio = 1.0;

    static pPlayer; pPlayer = get_ent_data_entity(pWeapon, "CBasePlayerItem", "m_pPlayer");
    static Float:vecVelocity[3]; pev(pPlayer, pev_velocity, vecVelocity);
    static iPlayerFlags; iPlayerFlags = pev(pPlayer, pev_flags);

    if (xs_vec_len(vecVelocity) > 0) {
        flRatio *= flMovementFactor;
    }

    if (iPlayerFlags & FL_DUCKING) {
        flRatio *= flDuckFactor;
    }

    if (~iPlayerFlags & FL_ONGROUND) {
        flRatio *= flAirFactor;
    }

    if (!iShotsFired) {
        flRatio *= flFirstShotModifier;
    }

    xs_vec_mul_scalar(vecSpread, flRatio, vecOut);

    return flRatio;
}

stock UTIL_GrenadeExplode(pEntity, Float:flDamage, const &pTrace, iDamageBits, Float:flRadius, Float:flMagnitude) {
  // static Float:flDamage; pev(pEntity, pev_dmg, flDamage);

  engfunc(EngFunc_SetModel, pEntity, NULL_STRING);
  set_pev(pEntity, pev_solid, SOLID_NOT);
  set_pev(pEntity, pev_takedamage, DAMAGE_NO);

  static Float:flFraction; get_tr2(pTrace, TR_Fraction, flFraction);
  static Float:vecPlaneNormal[3]; get_tr2(pTrace, TR_vecPlaneNormal, vecPlaneNormal);
  static Float:vecOrigin[3]; pev(pEntity, pev_origin, vecOrigin);

  if (flFraction != 1.0) {
    get_tr2(pTrace, TR_vecEndPos, vecOrigin);

    for (new i = 0; i < 3; ++i) {
        vecOrigin[i] += (vecPlaneNormal[i] * (flMagnitude ? flMagnitude : flDamage - 24.0) * 0.6);
    }

    set_pev(pEntity, pev_origin, vecOrigin);
  }

  UTIL_GrenadeExplosion(vecOrigin, flDamage);

  // CSoundEnt::InsertSound ( bits_SOUND_COMBAT, pev->origin, NORMAL_EXPLOSION_VOLUME, 3.0 );
  new pOwner = pev(pEntity, pev_owner);

  set_pev(pEntity, pev_owner, 0);

  UTIL_RadiusDamage(vecOrigin, pEntity, pOwner, flDamage, flRadius ? flRadius : flDamage * 3.5, CLASS_NONE, iDamageBits);

  UTIL_ExplosionDecalTrace(pTrace);
  UTIL_DebrisSound(pEntity);

  set_pev(pEntity, pev_effects, pev(pEntity, pev_effects) | EF_NODRAW);

  // SetThink( &CGrenade::Smoke );
  // GrenadeSmoke(vecOrigin, flDamage);

  set_pev(pEntity, pev_velocity, NULL_VECTOR);
  set_pev(pEntity, pev_nextthink, get_gametime() + 0.1);

  if (PointContents(vecOrigin) != CONTENTS_WATER) {
    new iSparkCount = random(4);
    for (new i = 0; i < iSparkCount; ++i) {
      UTIL_SparkShower(vecOrigin, vecPlaneNormal);
    }
  }
}

#define CHAR_TEX_CONCRETE 'C'
#define CHAR_TEX_METAL 'M'
#define CHAR_TEX_DIRT 'D'
#define CHAR_TEX_VENT 'V'
#define CHAR_TEX_GRATE 'G'
#define CHAR_TEX_TILE 'T'
#define CHAR_TEX_SLOSH 'S'
#define CHAR_TEX_WOOD 'W'
#define CHAR_TEX_COMPUTER 'P'
#define CHAR_TEX_GRASS 'X'
#define CHAR_TEX_GLASS 'Y'
#define CHAR_TEX_FLESH 'F'
#define CHAR_TEX_SNOW 'N'

stock UTIL_ArmorRicochet(const Float:vecOrigin[3], iScale = 10) {
  engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, vecOrigin, 0);
  write_byte(TE_ARMOR_RICOCHET);
  engfunc(EngFunc_WriteCoord, vecOrigin[0]);
  engfunc(EngFunc_WriteCoord, vecOrigin[1]);
  engfunc(EngFunc_WriteCoord, vecOrigin[2]);
  write_byte(iScale);
  message_end();
}

stock UTIL_Sparks(const Float:vecOrigin[3]) {
  engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, vecOrigin, 0);
  write_byte(TE_SPARKS);
  engfunc(EngFunc_WriteCoord, vecOrigin[0]);
  engfunc(EngFunc_WriteCoord, vecOrigin[1]);
  engfunc(EngFunc_WriteCoord, vecOrigin[2]);
  message_end();
}

stock UTIL_MapTextureTypeStepType(chTextureType) {
  switch (chTextureType) {
    case CHAR_TEX_CONCRETE: return STEP_CONCRETE;
    case CHAR_TEX_METAL: return STEP_METAL;
    case CHAR_TEX_DIRT: return STEP_DIRT;
    case CHAR_TEX_VENT: return STEP_VENT;
    case CHAR_TEX_GRATE: return STEP_GRATE;
    case CHAR_TEX_TILE: return STEP_TILE;
    case CHAR_TEX_SLOSH: return STEP_SLOSH;
    case CHAR_TEX_SNOW: return STEP_SNOW;
  }

  return STEP_CONCRETE;
}

stock Float:UTIL_MapTextureTypeVolume(chTextureType) {
  switch (chTextureType) {
    case CHAR_TEX_CONCRETE: return 0.5;
    case CHAR_TEX_METAL: return 0.5;
    case CHAR_TEX_DIRT: return 0.55;
    case CHAR_TEX_VENT: return 0.7;
    case CHAR_TEX_GRATE: return 0.5;
    case CHAR_TEX_TILE: return 0.5;
    case CHAR_TEX_SLOSH: return 0.5;
  }

  return 0.0;
}

stock UTIL_FireTargets(const szTargetName[], const pActivator, const pCaller, iUseType, Float:flValue) {
  if (equal(szTargetName, NULL_STRING)) return;

  static pTarget; pTarget = FM_NULLENT;
  while ((pTarget = engfunc(EngFunc_FindEntityByString, pTarget, "targetname", szTargetName)) != 0) {
    if (pTarget && !(pev(pTarget, pev_flags) & FL_KILLME)) {
      ExecuteHamB(Ham_Use, pTarget, pCaller, pActivator, iUseType, flValue);
    }
  }
}

stock UTIL_FindEntityInBox(const pStartEdict, const Float:vecBoxMin[3], const Float:vecBoxMax[3], iFlagMask) {
  static iMaxEntities = 0;
  if (!iMaxEntities) {
    iMaxEntities = global_get(glb_maxEntities);
  }

  for (new pEntity = (pStartEdict > 0 ? pStartEdict + 1 : 1); pEntity < iMaxEntities; ++pEntity) {
    if (pEntity <= 0) continue;
    if (!pev_valid(pEntity)) continue;
    if (iFlagMask && !(pev(pEntity, pev_flags) & iFlagMask)) continue;

    static Float:vecAbsMin[3]; pev(pEntity, pev_absmin, vecAbsMin);
    static Float:vecAbsMax[3]; pev(pEntity, pev_absmax, vecAbsMax);

    if (UTIL_BoxIntersects(vecBoxMin, vecBoxMax, vecAbsMin, vecAbsMax)) {
      return pEntity;
    }
  }

  return FM_NULLENT;
}

stock Activity:UTIL_GetSmallFlinchActivity(iHitGroup) {  
  switch (iHitGroup) {
    case HITGROUP_HEAD: return ACT_FLINCH_HEAD;
    case HITGROUP_STOMACH: return ACT_FLINCH_STOMACH;
    case HITGROUP_LEFTARM: return ACT_FLINCH_LEFTARM;
    case HITGROUP_RIGHTARM: return ACT_FLINCH_RIGHTARM;
    case HITGROUP_LEFTLEG: return ACT_FLINCH_LEFTLEG;
    case HITGROUP_RIGHTLEG: return ACT_FLINCH_RIGHTLEG;
  }

  return ACT_SMALL_FLINCH;
}

stock UITL_GetStepType(const pEntity, const chTextureType, Float:flStepHeight, bool:bOnLadder = false) {
  if (bOnLadder) return STEP_LADDER;

  static Float:vecOrigin[3]; pev(pEntity, pev_origin, vecOrigin);
  static Float:vecMins[3]; pev(pEntity, pev_mins, vecMins);

  static Float:vecKnee[3]; xs_vec_set(vecKnee, vecOrigin[0], vecOrigin[1], vecOrigin[2] - vecMins[2] + flStepHeight);
  if (engfunc(EngFunc_PointContents, vecKnee) == CONTENTS_WATER) return STEP_WADE;

  static Float:vecFeet[3]; xs_vec_set(vecFeet, vecOrigin[0], vecOrigin[1], vecOrigin[2] - vecMins[2] + (flStepHeight * 0.5));
  if (engfunc(EngFunc_PointContents, vecFeet) == CONTENTS_WATER) return STEP_SLOSH;
  
  return UTIL_MapTextureTypeStepType(chTextureType);
}

stock bool:UTIL_BoxIntersects(const Float:vecMin[3], const Float:vecMax[3], const Float:vecOtherMin[3], const Float:vecOtherMax[3]) {
  for (new i = 0; i < 3; ++i) {
    if (vecMin[i] > vecOtherMax[i]) return false;
    if (vecMax[i] < vecOtherMin[i]) return false;
  }

  return true;
}

stock bool:UTIL_IsMasterTriggered(const szMaster[], const pActivator) {
  if (!equal(szMaster, NULL_STRING)) {
    static pMaster; pMaster = engfunc(EngFunc_FindEntityByString, 0, "targetname", szMaster);

    if (pMaster && (ExecuteHam(Ham_ObjectCaps, pMaster) & FCAP_MASTER)) {
      return !!ExecuteHam(Ham_IsTriggered, pMaster, pActivator);
    }
  }

  return true;
}

stock UTIL_CatagorizeTextureType(const szTexture[]) {
  static const MAX_TEXTURENAME_LENGTH = 17;

  static szBuffer[32]; copy(szBuffer, charsmax(szBuffer), szTexture);

  // strip leading '-0' or '+0~' or '{' or '!'
  if (szBuffer[0] == '-' || szBuffer[0] == '+') {
    format(szBuffer, charsmax(szBuffer), "%s", szBuffer[2]);
  }

  if (szBuffer[0] == '{' || szBuffer[0] == '!' || szBuffer[0] == '~' || szBuffer[0] == ' ') {
    format(szBuffer, charsmax(szBuffer), "%s", szBuffer[1]);
  }

  szBuffer[MAX_TEXTURENAME_LENGTH - 1] = 0;

  return dllfunc(DLLFunc_PM_FindTextureType, szBuffer);
}

stock UTIL_GetTextureType(const &pTrace, const Float:vecSrc[3], const Float:vecEnd[3]) {
  static pHit; pHit = get_tr2(pTrace, TR_pHit);
  if (pHit == FM_NULLENT) {
    pHit = 0;
  }

  if (pHit) {
    static iClass; iClass = ExecuteHamB(Ham_Classify, pHit);
    if (iClass != CLASS_NONE && iClass != CLASS_MACHINE && iClass != CLASS_VEHICLE) {
      return CHAR_TEX_FLESH;
    }
  }

  static szTexture[32]; engfunc(EngFunc_TraceTexture, pHit, vecSrc, vecEnd, szTexture, charsmax(szTexture));

  if (equal(szTexture, NULL_STRING)) return 0;

  return UTIL_CatagorizeTextureType(szTexture);
}

stock Float:UTIL_PlayTextureSound(const chTextureType, const &pTrace) {
  static Float:vecPos[3]; get_tr2(pTrace, TR_vecEndPos, vecPos);
  static pHit; pHit = get_tr2(pTrace, TR_pHit);

  static szSound[128]; copy(szSound, charsmax(szSound), NULL_STRING);
  static Float:flVolume; flVolume = 0.9;
  static Float:flVolumeBar; flVolumeBar = 0.6;
  static Float:flAttan; flAttan = ATTN_NORM;

  // // if (!g_pGameRules->PlayTextureSounds()) return 0.0;

  switch (chTextureType) {
    case CHAR_TEX_METAL: {
      flVolumeBar = 0.3;

      switch (random(2)) {
        case 0: copy(szSound, charsmax(szSound), "player/pl_metal1.wav");
        case 1: copy(szSound, charsmax(szSound), "player/pl_metal2.wav");
      }
    }
    case CHAR_TEX_DIRT: {
      flVolumeBar = 0.1;

      switch (random(3)) {
        case 0: copy(szSound, charsmax(szSound), "player/pl_dirt1.wav");
        case 1: copy(szSound, charsmax(szSound), "player/pl_dirt2.wav");
        case 2: copy(szSound, charsmax(szSound), "player/pl_dirt3.wav");
      }
    }
    case CHAR_TEX_VENT: {
      flVolume = 0.5;
      flVolumeBar = 0.3;

      copy(szSound, charsmax(szSound), "player/pl_duct1.wav");
    }
    case CHAR_TEX_GRATE: {
      flVolumeBar = 0.5;

      switch (random(2)) {
        case 0: copy(szSound, charsmax(szSound), "player/pl_grate1.wav");
        case 1: copy(szSound, charsmax(szSound), "player/pl_grate4.wav");
      }
    }
    case CHAR_TEX_TILE: {
      flVolume = 0.8;
      flVolumeBar = 0.2;

      switch (random(4)) {
        case 0: copy(szSound, charsmax(szSound), "player/pl_tile1.wav");
        case 2: copy(szSound, charsmax(szSound), "player/pl_tile2.wav");
        case 1: copy(szSound, charsmax(szSound), "player/pl_tile3.wav");
        case 3: copy(szSound, charsmax(szSound), "player/pl_tile4.wav");
      }
    }
    case CHAR_TEX_SLOSH: {
      flVolumeBar = 0.0;

      switch (random(4)) {
        case 0: copy(szSound, charsmax(szSound), "player/pl_slosh1.wav");
        case 2: copy(szSound, charsmax(szSound), "player/pl_slosh2.wav");
        case 1: copy(szSound, charsmax(szSound), "player/pl_slosh3.wav");
        case 3: copy(szSound, charsmax(szSound), "player/pl_slosh4.wav");
      }
    }
    case CHAR_TEX_SNOW: {
      flVolume = 0.7;
      flVolumeBar = 0.4;

      switch (random(4)) {
        case 0: copy(szSound, charsmax(szSound), "player/pl_snow1.wav");
        case 1: copy(szSound, charsmax(szSound), "player/pl_snow2.wav");
        case 2: copy(szSound, charsmax(szSound), "player/pl_snow3.wav");
        case 3: copy(szSound, charsmax(szSound), "player/pl_snow4.wav");
      }
    }
    case CHAR_TEX_WOOD: {
      flVolumeBar = 0.2;

      switch (random(3)) {
        case 0: copy(szSound, charsmax(szSound), "debris/wood1.wav");
        case 1: copy(szSound, charsmax(szSound), "debris/wood2.wav");
        case 2: copy(szSound, charsmax(szSound), "debris/wood3.wav");
      }
    }
    case CHAR_TEX_GLASS, CHAR_TEX_COMPUTER: {
      flVolume = 0.8;
      flVolumeBar = 0.2;

      switch (random(3)) {
        case 0: copy(szSound, charsmax(szSound), "debris/glass1.wav");
        case 1: copy(szSound, charsmax(szSound), "debris/glass2.wav");
        case 2: copy(szSound, charsmax(szSound), "debris/glass3.wav");
      }
    }
    case CHAR_TEX_FLESH: {
      flVolume = 1.0;
      flVolumeBar = 0.2;

      switch (random(2)) {
        case 0: copy(szSound, charsmax(szSound), "weapons/bullet_hit1.wav");
        case 1: copy(szSound, charsmax(szSound), "weapons/bullet_hit2.wav");
      }
    }
    default: {
      switch (random(2)) {
        case 0: copy(szSound, charsmax(szSound), "player/pl_step1.wav");
        case 1: copy(szSound, charsmax(szSound), "player/pl_step2.wav");
      }
    }
  }

  static bool:bBreakable; bBreakable = false;
  if (pHit > 0) {
    static szClassname[32]; pev(pHit, pev_classname, szClassname, charsmax(szClassname));
    bBreakable = !!equal(szClassname, "func_breakable");
  }

  if (bBreakable) {
    flVolume /= 1.5;
    flVolumeBar /= 2.0;
  } else {
    if (chTextureType == CHAR_TEX_COMPUTER) {
      static Float:flFraction; get_tr2(pTrace, TR_flFraction, flFraction);

      if (flFraction != 1.0 && random_num(0, 1)) {
        // UTIL_Sparks(vecPos);

        static Float:flVolume; flVolume = random_float(0.7 , 1.0);

        switch (random(2)) {
          case 0: engfunc(EngFunc_EmitAmbientSound, 0, vecPos, "buttons/spark5.wav", flVolume, ATTN_NORM, 0, 100);
          case 1: engfunc(EngFunc_EmitAmbientSound, 0, vecPos, "buttons/spark6.wav", flVolume, ATTN_NORM, 0, 100);
        }
      }
    }
  }

  engfunc(EngFunc_EmitAmbientSound, 0, vecPos, szSound, flVolume, flAttan, 0, 96 + random_num(0, 0xf));

  return flVolumeBar;
}

stock UTIL_GivePlayerAmmo(const &pPlayer, iAmmoId, iAmount, iMaxAmmo = -1) {
  static gmsgAmmoPickup;

  if (!gmsgAmmoPickup) {
    gmsgAmmoPickup = get_user_msgid("AmmoPickup");
  }

  new iAmmoAmount = get_ent_data(pPlayer, "CBasePlayer", "m_rgAmmo", iAmmoId);

  if (iMaxAmmo != -1) {
    if (iAmmoAmount >= iMaxAmmo) return 0;
    iAmount = min(iAmmoAmount + iAmount, iMaxAmmo) - iAmmoAmount;
  }

  if (!iAmount) return 0;

  set_ent_data(pPlayer, "CBasePlayer", "m_rgAmmo", (iAmmoAmount += iAmount), iAmmoId);

  emessage_begin(MSG_ONE, gmsgAmmoPickup, _, pPlayer);
  ewrite_byte(iAmmoId);
  ewrite_byte(iAmount);
  emessage_end();

  return iAmount;
}

stock UTIL_GetWeaponBoxItem(const &pWeaponBox) {
  static pLastItem; pLastItem = FM_NULLENT;

  for (new iSlot = 0; iSlot < 6; ++iSlot) {
    static pItem; pItem = get_ent_data_entity(pWeaponBox, "CWeaponBox", "m_rgpPlayerItems", iSlot);
    if (pItem == FM_NULLENT) continue;
    
    // No specific item found (multiple items)
    if (pLastItem != FM_NULLENT) return FM_NULLENT;

    if (get_ent_data_entity(pItem, "CBasePlayerItem", "m_pNext") != FM_NULLENT) return FM_NULLENT;

    pLastItem = pItem;
  }

  return pLastItem;
}

static stock UTIL_Swap(&any:a, &any:b) {
  static any:c;
  c = a;
  a = b;
  b = c;
}


stock UTIL_PlayStepSound(const pEntity, iStep, Float:flVolume, iStepLeft) {
  static iRand; iRand = random(2) + (iStepLeft * 2);
  static iSkipStep; iSkipStep = 0;

  switch (iStep) {
    case STEP_CONCRETE: {
      switch (iRand) {
        case 0: emit_sound(pEntity, CHAN_BODY, "player/pl_step1.wav", flVolume, ATTN_NORM, 0, PITCH_NORM);
        case 1: emit_sound(pEntity, CHAN_BODY, "player/pl_step3.wav", flVolume, ATTN_NORM, 0, PITCH_NORM);
        case 2: emit_sound(pEntity, CHAN_BODY, "player/pl_step2.wav", flVolume, ATTN_NORM, 0, PITCH_NORM);
        case 3: emit_sound(pEntity, CHAN_BODY, "player/pl_step4.wav", flVolume, ATTN_NORM, 0, PITCH_NORM);
      }   
    }
    case STEP_METAL: {
      switch (iRand) {
        case 0: emit_sound(pEntity, CHAN_BODY, "player/pl_metal1.wav", flVolume, ATTN_NORM, 0, PITCH_NORM);
        case 1: emit_sound(pEntity, CHAN_BODY, "player/pl_metal3.wav", flVolume, ATTN_NORM, 0, PITCH_NORM);
        case 2: emit_sound(pEntity, CHAN_BODY, "player/pl_metal2.wav", flVolume, ATTN_NORM, 0, PITCH_NORM);
        case 3: emit_sound(pEntity, CHAN_BODY, "player/pl_metal4.wav", flVolume, ATTN_NORM, 0, PITCH_NORM);
      }   
    }
    case STEP_DIRT: {
      switch (iRand) {
        case 0: emit_sound(pEntity, CHAN_BODY, "player/pl_dirt1.wav", flVolume, ATTN_NORM, 0, PITCH_NORM);
        case 1: emit_sound(pEntity, CHAN_BODY, "player/pl_dirt3.wav", flVolume, ATTN_NORM, 0, PITCH_NORM);
        case 2: emit_sound(pEntity, CHAN_BODY, "player/pl_dirt2.wav", flVolume, ATTN_NORM, 0, PITCH_NORM);
        case 3: emit_sound(pEntity, CHAN_BODY, "player/pl_dirt4.wav", flVolume, ATTN_NORM, 0, PITCH_NORM);
      }   
    }
    case STEP_VENT: {
      switch (iRand) {
        case 0: emit_sound(pEntity, CHAN_BODY, "player/pl_duct1.wav", flVolume, ATTN_NORM, 0, PITCH_NORM);
        case 1: emit_sound(pEntity, CHAN_BODY, "player/pl_duct3.wav", flVolume, ATTN_NORM, 0, PITCH_NORM);
        case 2: emit_sound(pEntity, CHAN_BODY, "player/pl_duct2.wav", flVolume, ATTN_NORM, 0, PITCH_NORM);
        case 3: emit_sound(pEntity, CHAN_BODY, "player/pl_duct4.wav", flVolume, ATTN_NORM, 0, PITCH_NORM);
      }   
    }
    case STEP_GRATE: {
      switch (iRand) {
        case 0: emit_sound(pEntity, CHAN_BODY, "player/pl_grate1.wav", flVolume, ATTN_NORM, 0, PITCH_NORM);
        case 1: emit_sound(pEntity, CHAN_BODY, "player/pl_grate3.wav", flVolume, ATTN_NORM, 0, PITCH_NORM);
        case 2: emit_sound(pEntity, CHAN_BODY, "player/pl_grate2.wav", flVolume, ATTN_NORM, 0, PITCH_NORM);
        case 3: emit_sound(pEntity, CHAN_BODY, "player/pl_grate4.wav", flVolume, ATTN_NORM, 0, PITCH_NORM);
      }   
    }
    case STEP_TILE: {
      if (!random(5)) {
        iRand = 4;
      }

      switch (iRand) {
        case 0: emit_sound(pEntity, CHAN_BODY, "player/pl_tile1.wav", flVolume, ATTN_NORM, 0, PITCH_NORM);
        case 1: emit_sound(pEntity, CHAN_BODY, "player/pl_tile3.wav", flVolume, ATTN_NORM, 0, PITCH_NORM);
        case 2: emit_sound(pEntity, CHAN_BODY, "player/pl_tile2.wav", flVolume, ATTN_NORM, 0, PITCH_NORM);
        case 3: emit_sound(pEntity, CHAN_BODY, "player/pl_tile4.wav", flVolume, ATTN_NORM, 0, PITCH_NORM);
        case 4: emit_sound(pEntity, CHAN_BODY, "player/pl_tile5.wav", flVolume, ATTN_NORM, 0, PITCH_NORM);
      }   
    }
    case STEP_SLOSH: {
      switch (iRand) {
        case 0: emit_sound(pEntity, CHAN_BODY, "player/pl_slosh1.wav", flVolume, ATTN_NORM, 0, PITCH_NORM);
        case 1: emit_sound(pEntity, CHAN_BODY, "player/pl_slosh3.wav", flVolume, ATTN_NORM, 0, PITCH_NORM);
        case 2: emit_sound(pEntity, CHAN_BODY, "player/pl_slosh2.wav", flVolume, ATTN_NORM, 0, PITCH_NORM);
        case 3: emit_sound(pEntity, CHAN_BODY, "player/pl_slosh4.wav", flVolume, ATTN_NORM, 0, PITCH_NORM);
      }   
    }
    case STEP_WADE: {
      if (iSkipStep == 0) {
        iSkipStep++;
      }

      if (iSkipStep++ == 3) {
        iSkipStep = 0;
      }

      switch (iRand) {
        case 0: emit_sound(pEntity, CHAN_BODY, "player/pl_wade1.wav", flVolume, ATTN_NORM, 0, PITCH_NORM);
        case 1: emit_sound(pEntity, CHAN_BODY, "player/pl_wade2.wav", flVolume, ATTN_NORM, 0, PITCH_NORM);
        case 2: emit_sound(pEntity, CHAN_BODY, "player/pl_wade3.wav", flVolume, ATTN_NORM, 0, PITCH_NORM);
        case 3: emit_sound(pEntity, CHAN_BODY, "player/pl_wade4.wav", flVolume, ATTN_NORM, 0, PITCH_NORM);
      }

    }
    case STEP_LADDER: {
      switch (iRand) {
        case 0: emit_sound(pEntity, CHAN_BODY, "player/pl_ladder1.wav", flVolume, ATTN_NORM, 0, PITCH_NORM);
        case 1: emit_sound(pEntity, CHAN_BODY, "player/pl_ladder3.wav", flVolume, ATTN_NORM, 0, PITCH_NORM);
        case 2: emit_sound(pEntity, CHAN_BODY, "player/pl_ladder2.wav", flVolume, ATTN_NORM, 0, PITCH_NORM);
        case 3: emit_sound(pEntity, CHAN_BODY, "player/pl_ladder4.wav", flVolume, ATTN_NORM, 0, PITCH_NORM);
      }   
    }
    case STEP_SNOW: {
      switch (iRand) {
        case 0: emit_sound(pEntity, CHAN_BODY, "player/pl_snow1.wav", flVolume, ATTN_NORM, 0, PITCH_NORM);
        case 1: emit_sound(pEntity, CHAN_BODY, "player/pl_snow3.wav", flVolume, ATTN_NORM, 0, PITCH_NORM);
        case 2: emit_sound(pEntity, CHAN_BODY, "player/pl_snow2.wav", flVolume, ATTN_NORM, 0, PITCH_NORM);
        case 3: emit_sound(pEntity, CHAN_BODY, "player/pl_snow4.wav", flVolume, ATTN_NORM, 0, PITCH_NORM);
      }
    }  
  }
}
