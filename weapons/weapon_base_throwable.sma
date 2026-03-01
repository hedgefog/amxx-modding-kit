#pragma semicolon 1

#include <amxmodx>
#include <engine>
#include <fakemeta>
#include <hamsandwich>
#include <xs>

#include <api_custom_weapons>

#include <weapon_base_throwable_const>

#define IS_PLAYER(%1) (%1 >= 1 && %1 <= MaxClients)
#define METHOD(%1) Weapon_BaseThrowable_Method_%1
#define MEMBER(%1) Weapon_BaseThrowable_Member_%1

#define DEFAULT_PROJECTILE_CLASSNAME "grenade"

public plugin_precache() {
  CW_RegisterClass(Weapon_BaseThrowable, _, true);
  CW_ImplementClassMethod(Weapon_BaseThrowable, CW_Method_Create, "@Weapon_Create");
  CW_ImplementClassMethod(Weapon_BaseThrowable, CW_Method_Deploy, "@Weapon_Deploy");
  CW_ImplementClassMethod(Weapon_BaseThrowable, CW_Method_Idle, "@Weapon_Idle");
  CW_ImplementClassMethod(Weapon_BaseThrowable, CW_Method_PrimaryAttack, "@Weapon_PrimaryAttack");
  CW_ImplementClassMethod(Weapon_BaseThrowable, CW_Method_GetMaxSpeed, "@Weapon_GetMaxSpeed");
  CW_ImplementClassMethod(Weapon_BaseThrowable, CW_Method_CanDrop, "@Weapon_CanDrop");
  CW_ImplementClassMethod(Weapon_BaseThrowable, CW_Method_Holster, "@Weapon_Holster");
  CW_ImplementClassMethod(Weapon_BaseThrowable, CW_Method_ShouldIdle, "@Weapon_ShouldIdle");

  CW_RegisterClassVirtualMethod(Weapon_BaseThrowable, METHOD(ReleaseThrow), "@Weapon_ReleaseThrow");
  CW_RegisterClassVirtualMethod(Weapon_BaseThrowable, METHOD(Throw), "@Weapon_Throw");
  CW_RegisterClassVirtualMethod(Weapon_BaseThrowable, METHOD(SpawnProjectile), "@Weapon_SpawnProjectile");
}

public plugin_init() {
  register_plugin("[Weapon] Base Throwable", "1.0.0", "Hedgehog Fog");
}

@Weapon_Create(const this) {
  CW_CallBaseMethod();

  CW_SetMember(this, CW_Member_iMaxClip, -1);
  CW_SetMember(this, CW_Member_iClip, -1);
  CW_SetMember(this, CW_Member_iMaxPrimaryAmmo, -1);
  CW_SetMember(this, CW_Member_iDefaultAmmo, 1);
  CW_SetMember(this, CW_Member_iFlags, ITEM_FLAG_LIMITINWORLD | ITEM_FLAG_EXHAUSTIBLE);
  CW_SetMember(this, CW_Member_bExhaustible, true);

  CW_SetMember(this, MEMBER(flThrowPitch), 125.0);
  CW_SetMember(this, MEMBER(flThrowForce), 500.0);
  CW_SetMember(this, MEMBER(bRedeploy), false);
  CW_SetMember(this, MEMBER(flThrowDuration), 0.5);
  CW_SetMember(this, MEMBER(bThrowOnHolster), false);
}

@Weapon_Idle(const this) {
  CW_CallBaseMethod();

  static pPlayer; pPlayer = get_ent_data_entity(this, "CBasePlayerItem", "m_pPlayer");

  if (!is_user_connected(pPlayer)) return;

  static Float:flStartThrow; flStartThrow = CW_GetMember(this, MEMBER(flStartThrow));
  static Float:flReleaseThrow; flReleaseThrow = CW_GetMember(this, MEMBER(flReleaseThrow));

  if (flStartThrow && !flReleaseThrow) {
    CW_SetMember(this, MEMBER(flReleaseThrow), flReleaseThrow = get_gametime());
  }

  if (flStartThrow) {
    CW_CallMethod(this, METHOD(Throw));
    return;
  }
  
  if (flReleaseThrow > 0.0) {
    CW_CallMethod(this, METHOD(ReleaseThrow));
    return;
  }

  if (CW_GetMember(this, MEMBER(bRedeploy))) {
    CW_CallNativeMethod(this, CW_Method_Deploy);
    return;
  }
}

@Weapon_Deploy(const this) {
  CW_CallBaseMethod();
  
  CW_SetMember(this, MEMBER(flStartThrow), 0.0);
  CW_SetMember(this, MEMBER(flReleaseThrow), -1.0);
  CW_SetMember(this, MEMBER(bRedeploy), false);

  return true;
}

@Weapon_Holster(const this) {
  static pPlayer; pPlayer = get_ent_data_entity(this, "CBasePlayerItem", "m_pPlayer");

  if (!is_user_connected(pPlayer)) return false;

  if (CW_GetMember(this, MEMBER(bThrowOnHolster))) {
    if (Float:CW_GetMember(this, MEMBER(flStartThrow))) {
      CW_CallMethod(this, METHOD(Throw));
    }
  }

  CW_SetMember(this, MEMBER(flStartThrow), 0.0);
  CW_SetMember(this, MEMBER(flReleaseThrow), -1.0);

  emit_sound(pPlayer, CHAN_WEAPON, "common/null.wav", VOL_NORM, ATTN_NORM, 0, PITCH_NORM);

  return CW_CallBaseMethod();
}

@Weapon_ShouldIdle(const this) {
  static Float:flStartThrow; flStartThrow = CW_GetMember(this, MEMBER(flStartThrow));
  static Float:flReleaseThrow; flReleaseThrow = CW_GetMember(this, MEMBER(flReleaseThrow));
  static bool:bRedeploy; bRedeploy = CW_GetMember(this, MEMBER(bRedeploy));

  if (!flStartThrow) {
    if (flReleaseThrow != -1.0) return true;
    if (bRedeploy) return true;
  }

  return false;
}

@Weapon_PrimaryAttack(const this) {
  if (Float:CW_GetMember(this, MEMBER(flStartThrow))) return false;
  if (Float:CW_GetMember(this, MEMBER(flReleaseThrow)) != -1.0) return false;
  if (CW_GetMember(this, MEMBER(bRedeploy))) return false;

  static pPlayer; pPlayer = get_ent_data_entity(this, "CBasePlayerItem", "m_pPlayer");
  static iPrimaryAmmoType; iPrimaryAmmoType = CW_GetMember(this, CW_Member_iPrimaryAmmoType);

  if (iPrimaryAmmoType && iPrimaryAmmoType != -1) {
    static iPrimaryAmmo; iPrimaryAmmo = get_ent_data(pPlayer, "CBasePlayer", "m_rgAmmo", iPrimaryAmmoType);
    if (iPrimaryAmmo <= 0) return false;
  }

  CW_SetMember(this, MEMBER(flStartThrow), get_gametime());
  CW_SetMember(this, MEMBER(flReleaseThrow), 0.0);
  CW_SetMember(this, CW_Member_flTimeIdle, get_gametime());

  return true;
}

Float:@Weapon_GetMaxSpeed(const this) {
  return 250.0;
}

@Weapon_CanDrop(const this) {
  return false;
}

@Weapon_Throw(const this) {
  static Float:flGameTime; flGameTime = get_gametime();

  static pPlayer; pPlayer = get_ent_data_entity(this, "CBasePlayerItem", "m_pPlayer");
  static iPrimaryAmmoType; iPrimaryAmmoType = CW_GetMember(this, CW_Member_iPrimaryAmmoType);
  static Float:flThrowPitch; flThrowPitch = CW_GetMember(this, MEMBER(flThrowPitch));
  static Float:flThrowForce; flThrowForce = CW_GetMember(this, MEMBER(flThrowForce));
  static Float:flThrowDuration; flThrowDuration = CW_GetMember(this, MEMBER(flThrowDuration));

  static Float:vecAngles[3]; pev(pPlayer, pev_v_angle, vecAngles);
  static Float:vecPunchAngle[3]; pev(pPlayer, pev_punchangle, vecPunchAngle);
  static Float:vecThrowAngle[3]; xs_vec_add(vecAngles, vecPunchAngle, vecThrowAngle);

  if (vecThrowAngle[0] < 0.0) {
    vecThrowAngle[0] = -10.0 + vecThrowAngle[0] * ((90.0 - 10.0) / 90.0);
  } else {
    vecThrowAngle[0] = -10.0 + vecThrowAngle[0] * ((90.0 + 10.0) / 90.0);
  }

  // engfunc(EngFunc_MakeVectors, vecThrowAngle);

  static pProjectile; pProjectile = CW_CallMethod(this, METHOD(SpawnProjectile));

  if (pProjectile != FM_NULLENT) {
    static Float:vecForward[3]; get_global_vector(GL_v_forward, vecForward);
    static Float:flForce; flForce = flThrowForce * floatmin((90.0 - vecThrowAngle[0]) / flThrowPitch, 1.0);

    static Float:vecThrow[3];
    pev(pPlayer, pev_velocity, vecThrow);
    xs_vec_add_scaled(vecThrow, vecForward, flForce, vecThrow);

    set_pev(pProjectile, pev_velocity, xs_vec_len(vecThrow) ? vecThrow : Float:{0.0, 0.0, 1.0});
    
    static Float:vecAngles[3]; vector_to_angle(vecThrow, vecAngles);

    set_pev(pProjectile, pev_angles, vecAngles);
  } else {
    log_amx("[Base Throwable] ERROR! Failed to spawn projectile entity.");
  }

  CW_SetPlayerAnimation(pPlayer, PLAYER_ATTACK1);

  CW_SetMember(this, MEMBER(flStartThrow), 0.0);
  CW_SetMember(this, CW_Member_flNextPrimaryAttack, flGameTime + flThrowDuration);
  CW_SetMember(this, CW_Member_flNextSecondaryAttack, flGameTime + flThrowDuration);
  CW_SetMember(this, CW_Member_flTimeIdle, flGameTime + flThrowDuration);

  if (iPrimaryAmmoType && iPrimaryAmmoType != -1) {
    set_ent_data(pPlayer, "CBasePlayer", "m_rgAmmo", get_ent_data(pPlayer, "CBasePlayer", "m_rgAmmo", iPrimaryAmmoType) - 1, iPrimaryAmmoType);
  }

  return pProjectile;
}

@Weapon_SpawnProjectile(const this) {
  static pPlayer; pPlayer = get_ent_data_entity(this, "CBasePlayerItem", "m_pPlayer");
  static Float:vecForward[3]; get_global_vector(GL_v_forward, vecForward);
  static Float:vecSrc[3]; ExecuteHam(Ham_Player_GetGunPosition, pPlayer, vecSrc);

  xs_vec_add_scaled(vecSrc, vecForward, 16.0, vecSrc);

  new pProjectile = create_entity(DEFAULT_PROJECTILE_CLASSNAME);
  engfunc(EngFunc_SetOrigin, pProjectile, vecSrc);
  dllfunc(DLLFunc_Spawn, pProjectile);

  set_pev(pProjectile, pev_owner, pPlayer);

  return pProjectile;
}

@Weapon_ReleaseThrow(const this) {
  CW_SetMember(this, MEMBER(flStartThrow), 0.0);

  if (CW_CallNativeMethod(this, CW_Method_IsOutOfAmmo)) {
    ExecuteHamB(Ham_Weapon_RetireWeapon, this);
    return;
  }

  CW_SetMember(this, MEMBER(flReleaseThrow), -1.0);
  CW_SetMember(this, MEMBER(bRedeploy), true);
}
