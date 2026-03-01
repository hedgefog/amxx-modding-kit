#if defined _entity_fire_const_included
  #endinput
#endif
#define _entity_fire_const_included

#define ENTITY_FIRE "fire"

stock const Entity_Fire_Member_flNextParticlesEffect[] = "flNextParticlesEffect";
stock const Entity_Fire_Member_flNextLightEffect[] = "flNextLightEffect";
stock const Entity_Fire_Member_flNextSound[] = "flNextSound";
stock const Entity_Fire_Member_flNextDamage[] = "flNextDamage";
stock const Entity_Fire_Member_flNextSizeUpdate[] = "flNextSizeUpdate";
stock const Entity_Fire_Member_flNextWaterCheck[] = "flNextWaterCheck";
stock const Entity_Fire_Member_flNextSpreadThink[] = "flNextSpreadThink";
stock const Entity_Fire_Member_flDamage[] = "flDamage";
stock const Entity_Fire_Member_vecEffectOrigin[] = "vecEffectOrigin";
stock const Entity_Fire_Member_bAllowSpread[] = "bAllowSpread";
stock const Entity_Fire_Member_bDamaged[] = "bDamaged";
stock const Entity_Fire_Member_flSpreadRange[] = "flSpreadRange";
stock const Entity_Fire_Member_bAllowStacking[] = "bAllowStacking";

stock const Entity_Fire_Method_Sound[] = "Sound";
stock const Entity_Fire_Method_StopSound[] = "StopSound";
stock const Entity_Fire_Method_UpdateEffectVars[] = "UpdateEffectVars";
stock const Entity_Fire_Method_ParticlesEffect[] = "ParticlesEffect";
stock const Entity_Fire_Method_LightEffect[] = "LightEffect";
stock const Entity_Fire_Method_Spread[] = "Spread";
stock const Entity_Fire_Method_CanSpread[] = "CanSpread";
stock const Entity_Fire_Method_SpreadThink[] = "SpreadThink";
stock const Entity_Fire_Method_UpdateSize[] = "UpdateSize";
stock const Entity_Fire_Method_CanIgnite[] = "CanIgnite";
stock const Entity_Fire_Method_Damage[] = "Damage";
stock const Entity_Fire_Method_InWater[] = "InWater";
stock const Entity_Fire_Method_CreateChild[] = "CreateChild";
stock const Entity_Fire_Method_Attach[] = "Attach";
