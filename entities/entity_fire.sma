#pragma semicolon 1

#include <amxmodx>
#include <amxmisc>
#include <hamsandwich>
#include <fakemeta>
#include <xs>

#include <api_custom_entities>

#include <entity_fire_const>

#define IS_PLAYER(%1) (%1 >= 1 && %1 <= MaxClients)
#define METHOD(%1) Entity_Fire_Method_%1
#define MEMBER(%1) Entity_Fire_Member_%1

#define ENTITY_NAME ENTITY_FIRE

#define MAX_ENTITIES 2048

#define FIRE_BORDERS 2.0
#define FIRE_PADDING (FIRE_BORDERS + 16.0)
#define FIRE_THINK_RATE 0.01
#define FIRE_DAMAGE_RATE 0.5
#define FIRE_WATER_CHECK_RATE 1.0
#define FIRE_SPREAD_THINK_RATE 1.0
#define FIRE_PARTICLES_EFFECT_RATE 0.025
#define FIRE_LIGHT_EFFECT_RATE 0.05
#define FIRE_SOUND_RATE 3.0
#define FIRE_SIZE_UPDATE_RATE 1.0

new g_rgszFlameSprites[][] = {
  "sprites/bexplo.spr",
  "sprites/cexplo.spr"
};

new const g_rgszSmokeSprites[][] = {
  "sprites/black_smoke1.spr",
  "sprites/black_smoke2.spr",
  "sprites/black_smoke3.spr",
  "sprites/black_smoke4.spr"
};

new const g_rgszBurningSounds[][] = {
  "ambience/burning1.wav",
  "ambience/burning2.wav",
  "ambience/burning3.wav"
};

new g_rgiFlameModelIndex[sizeof(g_rgszFlameSprites)];
new g_rgiFlameModelFramesNum[sizeof(g_rgszFlameSprites)];
new g_rgiSmokeModelIndex[sizeof(g_rgszSmokeSprites)];
new g_rgiSmokeModelFramesNum[sizeof(g_rgszSmokeSprites)];

new Float:g_flGameTime = 0.0;
new bool:g_bIsCstrike = false;

new Float:g_rgflEntityFireDamage[MAX_ENTITIES + 1];
new Float:g_rgflEntityFireDamageTime[MAX_ENTITIES + 1];
new g_rgFireEntities[MAX_ENTITIES + 1];
new g_iFireEntitiesNum = 0;

new g_pCvarDamage;
new g_pCvarSpread;
new g_pCvarSpreadRange;
new g_pCvarLifeTime;

public plugin_precache() {
  g_bIsCstrike = !!cstrike_running();

  for (new i = 0; i < sizeof(g_rgszFlameSprites); ++i) {
    g_rgiFlameModelIndex[i] = precache_model(g_rgszFlameSprites[i]);
    g_rgiFlameModelFramesNum[i] = engfunc(EngFunc_ModelFrames, g_rgiFlameModelIndex[i]);
  }

  for (new i = 0; i < sizeof(g_rgszSmokeSprites); ++i) {
    g_rgiSmokeModelIndex[i] = precache_model(g_rgszSmokeSprites[i]);
    g_rgiSmokeModelFramesNum[i] = engfunc(EngFunc_ModelFrames, g_rgiSmokeModelIndex[i]);
  }

  for (new i = 0; i < sizeof(g_rgszBurningSounds); ++i) {
    precache_sound(g_rgszBurningSounds[i]);
  }

  CE_RegisterClass(ENTITY_NAME);

  CE_ImplementClassMethod(ENTITY_NAME, CE_Method_Create, "@Fire_Create");
  CE_ImplementClassMethod(ENTITY_NAME, CE_Method_Destroy, "@Fire_Destroy");
  CE_ImplementClassMethod(ENTITY_NAME, CE_Method_Spawn, "@Fire_Spawn");
  CE_ImplementClassMethod(ENTITY_NAME, CE_Method_Touch, "@Fire_Touch");
  CE_ImplementClassMethod(ENTITY_NAME, CE_Method_Think, "@Fire_Think");
  CE_ImplementClassMethod(ENTITY_NAME, CE_Method_Killed, "@Fire_Killed");

  CE_RegisterClassKeyMemberBinding(ENTITY_NAME, "damage", MEMBER(flDamage), CEMemberType_Float);
  CE_RegisterClassKeyMemberBinding(ENTITY_NAME, "lifetime", CE_Member_flLifeTime, CEMemberType_Float);
  CE_RegisterClassKeyMemberBinding(ENTITY_NAME, "range", MEMBER(flSpreadRange), CEMemberType_Float);
  CE_RegisterClassKeyMemberBinding(ENTITY_NAME, "spread", MEMBER(bAllowSpread), CEMemberType_Cell);

  CE_RegisterClassMethod(ENTITY_NAME, METHOD(Sound), "@Fire_Sound");
  CE_RegisterClassMethod(ENTITY_NAME, METHOD(StopSound), "@Fire_StopSound");
  CE_RegisterClassMethod(ENTITY_NAME, METHOD(UpdateEffectVars), "@Fire_UpdateEffectVars");
  CE_RegisterClassMethod(ENTITY_NAME, METHOD(ParticlesEffect), "@Fire_ParticlesEffect");
  CE_RegisterClassMethod(ENTITY_NAME, METHOD(LightEffect), "@Fire_LightEffect");
  CE_RegisterClassMethod(ENTITY_NAME, METHOD(Spread), "@Fire_Spread", CE_Type_Cell);
  CE_RegisterClassMethod(ENTITY_NAME, METHOD(CanSpread), "@Fire_CanSpread");
  CE_RegisterClassMethod(ENTITY_NAME, METHOD(SpreadThink), "@Fire_SpreadThink");
  CE_RegisterClassMethod(ENTITY_NAME, METHOD(UpdateSize), "@Fire_UpdateSize");
  CE_RegisterClassMethod(ENTITY_NAME, METHOD(CanIgnite), "@Fire_CanIgnite", CE_Type_Cell);
  CE_RegisterClassMethod(ENTITY_NAME, METHOD(Damage), "@Fire_Damage", CE_Type_Cell);
  CE_RegisterClassMethod(ENTITY_NAME, METHOD(InWater), "@Fire_InWater");
  CE_RegisterClassMethod(ENTITY_NAME, METHOD(CreateChild), "@Fire_CreateChild");
  CE_RegisterClassMethod(ENTITY_NAME, METHOD(Attach), "@Fire_Attach", CE_Type_Cell);

  register_forward(FM_OnFreeEntPrivateData, "FMHook_OnFreeEntPrivateData");
}

public plugin_init() {
  register_plugin("[Entities] Fire", "1.0.0", "Hedgehog Fog");

  g_pCvarDamage = register_cvar("fire_damage", "5.0");
  g_pCvarSpread = register_cvar("fire_spread", "1");
  g_pCvarSpreadRange = register_cvar("fire_spread_range", "16.0");
  g_pCvarLifeTime = register_cvar("fire_life_time", "10.0");
}

public server_frame() {
  g_flGameTime = get_gametime();
}

public FMHook_OnFreeEntPrivateData(pEntity) {
  ExtinguishEntity(pEntity);
}

@Fire_Create(const this) {
  CE_CallBaseMethod();

  CE_SetMemberVec(this, CE_Member_vecMins, Float:{-16.0, -16.0, -16.0});
  CE_SetMemberVec(this, CE_Member_vecMaxs, Float:{16.0, 16.0, 16.0});
  CE_SetMember(this, CE_Member_flLifeTime, get_pcvar_float(g_pCvarLifeTime), false);

  CE_SetMemberVec(this, MEMBER(vecEffectOrigin), NULL_VECTOR);

  CE_SetMember(this, MEMBER(flDamage), get_pcvar_float(g_pCvarDamage), false);
  CE_SetMember(this, MEMBER(flSpreadRange), get_pcvar_float(g_pCvarSpreadRange), false);
  CE_SetMember(this, MEMBER(bAllowSpread), true, false);
  CE_SetMember(this, MEMBER(bAllowStacking), false, false);

  StoreFireEntity(this);
}

@Fire_Spawn(const this) {
  CE_CallBaseMethod();

  CE_SetMember(this, MEMBER(flNextParticlesEffect), g_flGameTime);
  CE_SetMember(this, MEMBER(flNextLightEffect), g_flGameTime);
  CE_SetMember(this, MEMBER(flNextSound), g_flGameTime);
  CE_SetMember(this, MEMBER(flNextDamage), g_flGameTime);
  CE_SetMember(this, MEMBER(flNextSizeUpdate), g_flGameTime);
  CE_SetMember(this, MEMBER(flNextWaterCheck), g_flGameTime);
  CE_SetMember(this, MEMBER(flNextSpreadThink), g_flGameTime);
  CE_SetMember(this, MEMBER(flDamage), Float:CE_GetMember(this, MEMBER(flDamage)));
  CE_SetMember(this, MEMBER(bDamaged), false);

  set_pev(this, pev_takedamage, DAMAGE_NO);
  set_pev(this, pev_solid, SOLID_TRIGGER);
  set_pev(this, pev_movetype, MOVETYPE_TOSS);

  set_pev(this, pev_nextthink, g_flGameTime);
}

@Fire_Killed(const this, const pKiller, iShouldGib) {
  CE_CallMethod(this, METHOD(StopSound));

  CE_CallBaseMethod(pKiller, iShouldGib);
}

@Fire_Destroy(const this) {
  CE_CallMethod(this, METHOD(StopSound));

  DeleteFireEntity(this);

  CE_CallBaseMethod();
}

@Fire_Touch(const this, const pToucher) {
  CE_CallBaseMethod(pToucher);
  CE_CallMethod(this, METHOD(Damage), pToucher);
}

@Fire_Think(const this) {
  CE_CallBaseMethod();

  static iMoveType; iMoveType = pev(this, pev_movetype);
  static pAimEnt; pAimEnt = pev(this, pev_aiment);

  if (iMoveType == MOVETYPE_FOLLOW) {
    if (!pev_valid(pAimEnt) || pev(pAimEnt, pev_flags) & FL_KILLME || pev(pAimEnt, pev_deadflag) != DEAD_NO) {
      ExecuteHamB(Ham_Killed, this, 0, 0);
      return;
    }
  }

  if (CE_GetMember(this, MEMBER(flNextWaterCheck)) <= g_flGameTime) {
    if (CE_CallMethod(this, METHOD(InWater))) {
      ExecuteHamB(Ham_Killed, this, 0, 0);
      return;
    }

    CE_SetMember(this, MEMBER(flNextWaterCheck), g_flGameTime + FIRE_WATER_CHECK_RATE);
  }

  if (CE_GetMember(this, MEMBER(flNextSpreadThink)) <= g_flGameTime) {
    CE_CallMethod(this, METHOD(SpreadThink));
    CE_SetMember(this, MEMBER(flNextSpreadThink), g_flGameTime + FIRE_SPREAD_THINK_RATE);
  }

  /*
    Since all non-moving entities, except players, don't handle touch,
    we force a touch event the for burning entity.
  */
  if (iMoveType == MOVETYPE_FOLLOW && !IS_PLAYER(pAimEnt)) {
    static Float:vecVelocity[3]; pev(pAimEnt, pev_velocity, vecVelocity);
    if (!vector_length(vecVelocity)) {
      dllfunc(DLLFunc_Touch, this, pAimEnt);
    }
  }

  /*
    After fire has damaged to all entities we add delay before fire can deal damage to touched entities again.
    By using m_bDamaged, we avoid the issue when m_flNextDamage updates before the touch. 
  */
  if (CE_GetMember(this, MEMBER(bDamaged))) {
    static Float:flNextDamage; flNextDamage = CE_GetMember(this, MEMBER(flNextDamage));
    if (flNextDamage && flNextDamage <= g_flGameTime) {
      CE_SetMember(this, MEMBER(flNextDamage), g_flGameTime + FIRE_DAMAGE_RATE);
    }

    CE_SetMember(this, MEMBER(bDamaged), false);
  }

  if (CE_GetMember(this, MEMBER(flNextSound)) <= g_flGameTime) {
    CE_CallMethod(this, METHOD(Sound));
    CE_SetMember(this, MEMBER(flNextSound), g_flGameTime + FIRE_SOUND_RATE);
  }

  if (CE_GetMember(this, MEMBER(flNextSizeUpdate)) <= g_flGameTime) {
    CE_CallMethod(this, METHOD(UpdateSize));
    CE_SetMember(this, MEMBER(flNextSizeUpdate), g_flGameTime + FIRE_SIZE_UPDATE_RATE);
  }

  if (CE_GetMember(this, MEMBER(flNextParticlesEffect)) <= g_flGameTime) {
    // Particle effect has higher update rate, so we update effect vars before each particle effect
    CE_CallMethod(this, METHOD(UpdateEffectVars));
    CE_CallMethod(this, METHOD(ParticlesEffect));
    CE_SetMember(this, MEMBER(flNextParticlesEffect), g_flGameTime + FIRE_PARTICLES_EFFECT_RATE);
  }

  if (CE_GetMember(this, MEMBER(flNextLightEffect)) <= g_flGameTime) {
    CE_CallMethod(this, METHOD(LightEffect));
    CE_SetMember(this, MEMBER(flNextLightEffect), g_flGameTime + FIRE_LIGHT_EFFECT_RATE);
  }

  set_pev(this, pev_nextthink, g_flGameTime + FIRE_THINK_RATE);
}

@Fire_SpreadThink(const this) {
  if (!CE_CallMethod(this, METHOD(CanSpread))) return;

  static Float:vecOrigin[3]; pev(this, pev_origin, vecOrigin);
  static Float:flRange; flRange = CE_GetMember(this, MEMBER(flSpreadRange));

  if (pev(this, pev_movetype) == MOVETYPE_FOLLOW) {
    static pAimEnt; pAimEnt = pev(this, pev_aiment);
    static Float:vecSize[3]; pev(pAimEnt, pev_size, vecSize);

    flRange = floatmax(
      vecSize[2],
      floatmax(vecSize[0], vecSize[1])
    ) / 2;
  }

  static rgNearbyEntities[256];
  static iNearbyEntitiesNum; iNearbyEntitiesNum = 0;

  static pTarget; pTarget = 0;
  while ((pTarget = engfunc(EngFunc_FindEntityInSphere, pTarget, vecOrigin, flRange)) > 0) {
    if (pev(pTarget, pev_takedamage) == DAMAGE_NO) continue;
    rgNearbyEntities[iNearbyEntitiesNum++] = pTarget;

    if (iNearbyEntitiesNum >= sizeof(rgNearbyEntities)) break;
  }

  for (new i = 0; i < iNearbyEntitiesNum; ++i) {
    CE_CallMethod(this, METHOD(Spread), rgNearbyEntities[i]);
  }
}

@Fire_UpdateSize(const this) {
  if (pev(this, pev_movetype) != MOVETYPE_FOLLOW) return;

  static pAimEnt; pAimEnt = pev(this, pev_aiment);

  static szModel[256];
  static iModelStrLen;
  iModelStrLen = pev(pAimEnt, pev_model, szModel, charsmax(szModel));

  static bool:bHasModel; bHasModel = !!iModelStrLen;
  static bool:bIsBspModel; bIsBspModel = bHasModel && szModel[0] == '*';
  static bool:bIsSprite; bIsSprite = !bIsBspModel && iModelStrLen > 5 && equal(szModel[iModelStrLen - 5], ".spr");

  static Float:vecMins[3]; xs_vec_set(vecMins, 0.0, 0.0, 0.0);
  static Float:vecMaxs[3]; xs_vec_set(vecMaxs, 0.0, 0.0, 0.0);

  if (bHasModel && !bIsBspModel && !bIsSprite) {
    GetModelBoundingBox(pAimEnt, vecMins, vecMaxs, Model_CurrentSequence);
  }

  if (!xs_vec_distance(vecMins, vecMaxs)) {
    pev(pAimEnt, pev_mins, vecMins);
    pev(pAimEnt, pev_maxs, vecMaxs);
  }

  // Add fire borders (useful for fire spread)
  for (new i = 0; i < 3; ++i) {
    vecMins[i] -= FIRE_BORDERS;
    vecMaxs[i] += FIRE_BORDERS;
  }

  engfunc(EngFunc_SetSize, this, vecMins, vecMaxs);
}

bool:@Fire_CanSpread(const this) {
  if (!get_pcvar_bool(g_pCvarSpread)) return false;
  if (!CE_GetMember(this, MEMBER(bAllowSpread))) return false;

  return true;
}

@Fire_InWater(const this) {
  static Float:vecOrigin[3]; pev(this, pev_origin, vecOrigin);

  new pTarget = 0;
  while ((pTarget = engfunc(EngFunc_FindEntityInSphere, pTarget, vecOrigin, 1.0)) > 0) {
    static szTargetClassName[32];
    pev(pTarget, pev_classname, szTargetClassName, charsmax(szTargetClassName));

    if (equal(szTargetClassName, "func_water")) return true;
  }

  return false;
}

bool:@Fire_Damage(const this, const pTarget) {
  if (!pTarget) return false;
  if (pev(pTarget, pev_takedamage) == DAMAGE_NO) return false;
  // if (pev(pTarget, pev_solid) <= SOLID_TRIGGER) return false;

  static Float:flNextDamage; flNextDamage = CE_GetMember(this, MEMBER(flNextDamage));
  static bool:bAllowStacking; bAllowStacking = CE_GetMember(this, MEMBER(bAllowStacking));

  if (flNextDamage > g_flGameTime) return false;

  static Float:flDamage; flDamage = Float:CE_GetMember(this, MEMBER(flDamage)) * FIRE_DAMAGE_RATE;

  if (g_flGameTime - g_rgflEntityFireDamageTime[pTarget] >= FIRE_DAMAGE_RATE) {
    g_rgflEntityFireDamage[pTarget] = 0.0;
    g_rgflEntityFireDamageTime[pTarget] = g_flGameTime;
  }
  
  if (!bAllowStacking) {
    /*
      This little hack is used to prevent fire damage from stacking
      In case the entity is already damaged by a fire we calculating the remaining damage to compensate.
    */
    if (g_rgflEntityFireDamage[pTarget]) {
      flDamage = floatmax(flDamage - g_rgflEntityFireDamage[pTarget], 0.0);
    }
  }

  if (flDamage) {
    static pOwner; pOwner = pev(this, pev_owner);
    static pAttacker; pAttacker = pOwner && pOwner != pTarget ? pOwner : this;
    static iDamageBits; iDamageBits = DMG_NEVERGIB | DMG_BURN;

    if (g_bIsCstrike && IS_PLAYER(pTarget)) {
      new Float:flVelocityModifier = get_ent_data_float(pTarget, "CBasePlayer", "m_flVelocityModifier");
      ExecuteHamB(Ham_TakeDamage, pTarget, this, pAttacker, flDamage, iDamageBits);
      set_ent_data_float(pTarget, "CBasePlayer", "m_flVelocityModifier", flVelocityModifier);
    } else {
      ExecuteHamB(Ham_TakeDamage, pTarget, this, pAttacker, flDamage, iDamageBits);
    }
  }

  // if (pev(this, pev_movetype) != MOVETYPE_FOLLOW) {
  //   if (@Fire_CanIgnite(this, pTarget)) {
  //     // Attach fire to the entity we damaged
  //     set_pev(this, pev_movetype, MOVETYPE_FOLLOW);
  //     set_pev(this, pev_aiment, pTarget);
  //   }
  // }
  
  if (CE_CallMethod(this, METHOD(CanSpread))) {
    CE_CallMethod(this, METHOD(Spread), pTarget);
  }

  CE_SetMember(this, MEMBER(bDamaged), true);

  if (!bAllowStacking) {
    g_rgflEntityFireDamage[pTarget] += flDamage;
  }

  return true;
}

@Fire_Spread(const this, const pTarget) {
  if (!CE_CallMethod(this, METHOD(CanIgnite), pTarget)) return;

  new pChild = CE_CallMethod(this, METHOD(CreateChild));
  if (pChild == FM_NULLENT) return;

  if (!CE_CallMethod(pChild, METHOD(Attach), pTarget)) {
    ExecuteHamB(Ham_Killed, pChild, 0, 0);
  }
}

@Fire_CreateChild(const this) {
  static Float:vecOrigin[3]; pev(this, pev_origin, vecOrigin);

  new pChild = CE_Create(ENTITY_NAME, vecOrigin);
  if (pChild == FM_NULLENT) return FM_NULLENT;

  CE_SetMember(pChild, MEMBER(flDamage), Float:CE_GetMember(this, MEMBER(flDamage)));
  CE_SetMember(pChild, MEMBER(bAllowSpread), CE_GetMember(this, MEMBER(bAllowSpread)));
  CE_SetMember(pChild, MEMBER(flSpreadRange), Float:CE_GetMember(this, MEMBER(flSpreadRange)));
  CE_SetMember(pChild, CE_Member_flLifeTime, Float:CE_GetMember(this, CE_Member_flLifeTime));

  dllfunc(DLLFunc_Spawn, pChild);

  new pOwner = pev(this, pev_owner);
  set_pev(pChild, pev_owner, pOwner);

  return pChild;
}

@Fire_Attach(const this, const pTarget) {
  if (pev(pTarget, pev_deadflag) != DEAD_NO) return false;
  if (CE_IsInstanceOf(pTarget, ENTITY_NAME)) return false;

  set_pev(this, pev_movetype, MOVETYPE_FOLLOW);
  set_pev(this, pev_aiment, pTarget);

  return true;
}

@Fire_CanIgnite(const this, const pTarget) {
  if (pev(pTarget, pev_takedamage) == DAMAGE_NO) return false;
  if (pev(pTarget, pev_deadflag) != DEAD_NO) return false;

  // Fire entity cannot be ignited
  if (CE_IsInstanceOf(pTarget, ENTITY_NAME)) return false;

  static iMoveType; iMoveType = pev(this, pev_movetype);
  static pAimEnt; pAimEnt = pev(this, pev_aiment);
  if (iMoveType == MOVETYPE_FOLLOW && pAimEnt == pTarget) return false;

  if (IsEntityOnFire(pTarget)) return false;

  return true;
}

@Fire_Sound(const this) {
  static Float:vecSize[3]; pev(this, pev_size, vecSize);

  static Float:flVolume; flVolume = floatmin(VOL_NORM * ((vecSize[0] + vecSize[1] + vecSize[2]) / 3 / 160.0), 1.0);
  if (!flVolume) return;
  emit_sound(this, CHAN_BODY, g_rgszBurningSounds[random(sizeof(g_rgszBurningSounds))], flVolume, ATTN_NORM, 0, PITCH_NORM);
}

@Fire_StopSound(const this) {
  emit_sound(this, CHAN_BODY, "common/null.wav", VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
}

@Fire_UpdateEffectVars(const this) {
  static iMoveType; iMoveType = pev(this, pev_movetype);
  static Float:vecAbsMin[3]; pev(this, pev_absmin, vecAbsMin);
  static Float:vecAbsMax[3]; pev(this, pev_absmax, vecAbsMax);
  static Float:vecVelocity[3]; pev(iMoveType == MOVETYPE_FOLLOW ? pev(this, pev_aiment) : this, pev_velocity, vecVelocity);

  static Float:vecOrigin[3];
  for (new i = 0; i < sizeof(vecOrigin); ++i) {
    vecOrigin[i] = (
      random_float(
        floatmin(vecAbsMin[i] + FIRE_PADDING, vecAbsMax[i]),
        floatmax(vecAbsMax[i] - FIRE_PADDING, vecAbsMin[i])
      ) + (vecVelocity[i] * FIRE_PARTICLES_EFFECT_RATE)
    );
  }

  CE_SetMemberVec(this, MEMBER(vecEffectOrigin), vecOrigin);
}

@Fire_ParticlesEffect(const this) {
  static iMoveType; iMoveType = pev(this, pev_movetype);
  static Float:vecOrigin[3]; CE_GetMemberVec(this, MEMBER(vecEffectOrigin), vecOrigin);

  static Float:vecVelocity[3]; pev(iMoveType == MOVETYPE_FOLLOW ? pev(this, pev_aiment) : this, pev_velocity, vecVelocity);

  static Float:vecMins[3]; pev(this, pev_absmin, vecMins);
  static Float:vecMaxs[3]; pev(this, pev_absmax, vecMaxs);

  static Float:flAvgSize; flAvgSize = (
    ((vecMaxs[0] - FIRE_PADDING) - (vecMins[0] + FIRE_PADDING)) +
    ((vecMaxs[1] - FIRE_PADDING) - (vecMins[1] + FIRE_PADDING)) +
    ((vecMaxs[2] - FIRE_PADDING) - (vecMins[2] + FIRE_PADDING))
  ) / 3;

  flAvgSize = floatmax(flAvgSize, xs_vec_len(vecVelocity) * FIRE_PARTICLES_EFFECT_RATE * 2);

  static iScale; iScale = clamp(floatround(flAvgSize * random_float(0.0975, 0.275)), 4, 80);

  static iSmokeIndex; iSmokeIndex = random(sizeof(g_rgiFlameModelIndex));
  static iSmokeFrameRate; iSmokeFrameRate = floatround(
    g_rgiSmokeModelFramesNum[iSmokeIndex] * random_float(0.75, 1.25),
    floatround_ceil
  );

  static iFlameIndex; iFlameIndex = random(sizeof(g_rgiFlameModelIndex));
  static iFlameFrameRate; iFlameFrameRate = floatround(
    g_rgiFlameModelFramesNum[iFlameIndex] * random_float(1.25, 2.0),
    floatround_ceil
  );

  engfunc(EngFunc_MessageBegin, MSG_PAS, SVC_TEMPENTITY, vecOrigin, 0);
  write_byte(TE_EXPLOSION);
  engfunc(EngFunc_WriteCoord, vecOrigin[0]);
  engfunc(EngFunc_WriteCoord, vecOrigin[1]);
  engfunc(EngFunc_WriteCoord, vecOrigin[2]);
  write_short(g_rgiFlameModelIndex[iFlameIndex]);
  write_byte(iScale);
  write_byte(iFlameFrameRate);
  write_byte(TE_EXPLFLAG_NODLIGHTS | TE_EXPLFLAG_NOSOUND | TE_EXPLFLAG_NOPARTICLES);
  message_end();

  engfunc(EngFunc_MessageBegin, MSG_PAS, SVC_TEMPENTITY, vecOrigin, 0);
  write_byte(TE_SMOKE);
  engfunc(EngFunc_WriteCoord, vecOrigin[0]);
  engfunc(EngFunc_WriteCoord, vecOrigin[1]);
  engfunc(EngFunc_WriteCoord, vecOrigin[2]);
  write_short(g_rgiSmokeModelIndex[iSmokeIndex]);
  write_byte(iScale * 2);
  write_byte(iSmokeFrameRate);
  message_end();
}

@Fire_LightEffect(const this) {
  static const irgColor[3] = {128, 64, 0};
  static Float:vecOrigin[3]; CE_GetMemberVec(this, MEMBER(vecEffectOrigin), vecOrigin);
  static Float:vecMins[3]; pev(this, pev_absmin, vecMins);
  static Float:vecMaxs[3]; pev(this, pev_absmax, vecMaxs);
  static iLifeTime; iLifeTime = 1;

  static Float:flRadius; flRadius = 0.25 * floatmax(
    vecMaxs[2] - vecMins[2],
    floatmax(vecMaxs[0] - vecMins[0], vecMaxs[1] - vecMins[1])
  ) / 2;

  static iDecayRate; iDecayRate = floatround(flRadius);

  engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, vecOrigin, 0);
  write_byte(TE_ELIGHT);
  write_short(0);
  engfunc(EngFunc_WriteCoord, vecOrigin[0]);
  engfunc(EngFunc_WriteCoord, vecOrigin[1]);
  engfunc(EngFunc_WriteCoord, vecOrigin[2]);
  engfunc(EngFunc_WriteCoord, flRadius);
  write_byte(irgColor[0]);
  write_byte(irgColor[1]);
  write_byte(irgColor[2]);
  write_byte(iLifeTime);
  write_coord(iDecayRate);
  message_end();

  engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, vecOrigin, 0);
  write_byte(TE_DLIGHT);
  engfunc(EngFunc_WriteCoord, vecOrigin[0]);
  engfunc(EngFunc_WriteCoord, vecOrigin[1]);
  engfunc(EngFunc_WriteCoord, vecOrigin[2]);
  write_byte(floatround(flRadius));
  write_byte(irgColor[0]);
  write_byte(irgColor[1]);
  write_byte(irgColor[2]);
  write_byte(iLifeTime);
  write_byte(iDecayRate);
  message_end();
}

StoreFireEntity(const &pEntity) {
  g_rgFireEntities[g_iFireEntitiesNum++] = pEntity;
}

DeleteFireEntity(const &pEntity) {
  for (new i = 0; i < g_iFireEntitiesNum; ++i) {
    if (g_rgFireEntities[i] == pEntity) {
      g_rgFireEntities[i] = g_rgFireEntities[--g_iFireEntitiesNum];
      return;
    }
  }
}

bool:IsEntityOnFire(const &pEntity) {
  for (new i = 0; i < g_iFireEntitiesNum; ++i) {
    static pFire; pFire = g_rgFireEntities[i];

    if (pev(pFire, pev_movetype) == MOVETYPE_FOLLOW && pev(pFire, pev_aiment) == pEntity) {
      return true;
    }
  }

  return false;
}

ExtinguishEntity(const &pEntity) {
  for (new i = 0; i < g_iFireEntitiesNum; ++i) {
    static pFire; pFire = g_rgFireEntities[i];

    if (pev(pFire, pev_movetype) == MOVETYPE_FOLLOW && pev(pFire, pev_aiment) == pEntity) {
      ExecuteHamB(Ham_Killed, pEntity, 0, 0);
    }
  }
}
