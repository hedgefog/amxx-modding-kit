#if defined _api_custom_weapons_const_included
  #endinput
#endif
#define _api_custom_weapons_const_included

#define CW_MAX_NAME_LENGTH 64
#define CW_MAX_METHOD_NAME_LENGTH 64
#define CW_MAX_MEMBER_NAME_LENGTH 64
#define CW_MAX_CALLBACK_NAME_LENGTH 64
#define CW_MAX_AMMO_NAME_LENGTH 32
#define CW_MAX_AMMO_METADATA_KEY_LENGTH 64
#define CW_MAX_AMMO_GROUP_NAME_LENGTH 32

#define CW_Class_Base "base"

enum CW { CW_InvalidHandler = -1 };
enum { CW_IGNORED = 0, CW_HANDLED, CW_OVERRIDE, CW_SUPERCEDE }
enum { CW_Type_Invalid = -1, CW_Type_Cell, CW_Type_String, CW_Type_Array, CW_Type_Vector, CW_Type_CellRef };

#if !defined PLAYER_ANIM
  enum PLAYER_ANIM {
    PLAYER_IDLE,
    PLAYER_WALK,
    PLAYER_JUMP,
    PLAYER_SUPERJUMP,
    PLAYER_DIE,
    PLAYER_ATTACK1,
    PLAYER_ATTACK2,
    PLAYER_FLINCH,
    PLAYER_LARGE_FLINCH,
    PLAYER_RELOAD,
    PLAYER_HOLDBOMB
  };
#endif

enum CW_Method {
  CW_Method_Invalid = -1,

  /*--------------------------------[ Base methods ]--------------------------------*/

  /**
   * Called when an weapon instance is allocated.
   *
   * @noreturn
   */
  CW_Method_Create,

  /**
   * Called when an weapon instance is about to be destroyed.
   *
   * @noreturn
   */
  CW_Method_Destroy,

  /**
   * Returns true if the entity is a weapon.
   *
   * @return true if the entity is a weapon, false otherwise
   */
  CW_Method_IsWeapon,

  /**
   * Called when an weapon instance is spawned.
   *
   * @noreturn
   */
  CW_Method_Spawn,

  /**
   * Called during weapon instance thinking.
   *
   * @noreturn
   */ 
  CW_Method_Think,

  /**
   * Called during weapon instance pre-frame.
   *
   * @noreturn
   */
  CW_Method_PreFrame,

  /**
   * Called during weapon instance post-frame.
   *
   * @noreturn
   */
  CW_Method_PostFrame,

  /**
   * Called when an weapon instance is updating item info.
   *
   * @noreturn
   */
  CW_Method_UpdateItemInfo,

  /**
   * Called when an weapon instance is touching another entity.
   *
   * @param pToucher Toucher entity
   *
   * @noreturn
   */
  CW_Method_Touch,

  /**
   * Called when an weapon instance is checking if it should idle.
   *
   * @return true if the object should idle, false otherwise
   */
  CW_Method_ShouldIdle,

  /**
   * Called when an weapon instance is idling.
   *
   * @return true if the object should idle, false otherwise
   */
  CW_Method_Idle,

  /**
   * Called when an weapon instance is checking if it can be deployed.
   *
   * @return true if the object can be deployed, false otherwise
   */
  CW_Method_CanDeploy,

  /**
   * Called when an weapon instance is deploying.
   *
   * @return true if the object is deployed, false otherwise
   */
  CW_Method_Deploy,

  /**
   * Called when an weapon instance is checking if it can be holstered.
   *
   * @return true if the object can be holstered, false otherwise
   */
  CW_Method_CanHolster,

  /**
   * Called when an weapon instance is holstering.
   *
   * @return true if the object is holstered, false otherwise
   */
  CW_Method_Holster,

  /**
   * Called when an weapon instance is checking if it can be dropped.
   *
   * @return true if the object can be dropped, false otherwise
   */
  CW_Method_CanDrop,

  /**
   * Called when an weapon instance is dropping.
   *
   * @return true if the object was dropped, false otherwise
   */
  CW_Method_Drop,

  /**
   * Called when an weapon instance is getting the max speed.
   *
   * @return The max speed of the player using the weapon as a float
   */
  CW_Method_GetMaxSpeed,

  /**
   * Called when an weapon instance is falling.
   *
   * @noreturn
   */
  CW_Method_FallInit,

  /**
   * Called when an weapon instance is playing an animation.
   *
   * @param iAnim The animation to play
   * @param flDuration The duration of the animation
   *
   * @noreturn
   */
  CW_Method_PlayAnimation,

  /**
   * Called when an weapon instance is updating the weapon box model.
   *
   * @param pWeaponBox The weapon box entity
   *
   * @noreturn
   */
  CW_Method_UpdateWeaponBoxModel,

  /*--------------------------------[ Combat ]--------------------------------*/

  /**
   * Called when an weapon instance is checking if it is useable.
   *
   * @return true if the object is useable, false otherwise
   */
  CW_Method_IsUseable,

  /**
   * Called when an weapon instance is checking if it can primary attack.
   *
   * @return true if the object can primary attack, false otherwise
   */
  CW_Method_CanPrimaryAttack,

  /**
   * Called when an weapon instance is primary attacking.
   *
   * @return true if the object can primary attack, false otherwise
   */
  CW_Method_PrimaryAttack,

  /**
   * Called when an weapon instance is checking if it can secondary attack.
   *
   * @return true if the object can secondary attack, false otherwise
   */
  CW_Method_CanSecondaryAttack,

  /**
   * Called when an weapon instance is secondary attacking.
   *
   * @return true if the object can secondary attack, false otherwise
   */
  CW_Method_SecondaryAttack,

  /**
   * Called when an weapon instance is checking if it can reload.
   *
   * @return true if the object can reload, false otherwise
   */
  CW_Method_CanReload,

  /**
   * Called when an weapon instance is reloading.
   *
   * @return true if the object can reload, false otherwise
   */
  CW_Method_Reload,

  /**
   * Called when an weapon instance is completing a reload.
   *
   * @noreturn
   */
  CW_Method_CompleteReload,

  /**
   * Called when an weapon instance is completing a special reload.
   *
   * @noreturn
   */
  CW_Method_CompleteSpecialReload,

  /**
   * Called when an weapon instance is getting the base accuracy.
   *
   * @return The base accuracy of the object as a float
   */
  CW_Method_GetBaseAccuracy,

  /*--------------------------------[ Player interactions ]--------------------------------*/

  /**
   * Called when an weapon instance is adding to a player.
   *
   * @param pPlayer Player entity
   *
   * @return true if the object was added to the player, false otherwise
   */
  CW_Method_AddToPlayer,

  /**
   * Called when an weapon instance is adding a duplicate.
   *
   * @param pOriginal Original weapon
   *
   * @noreturn
   */
  CW_Method_AddDuplicate,

  /**
   * Called when an weapon instance is updating client data.
   *
   * @param pPlayer Player entity
   *
   * @noreturn
   */
  CW_Method_UpdateClientData,

  /**
   * Called when an weapon instance is adding a weapon.
   *
   * @return true if the object was added to the weapon, false otherwise
   */
  CW_Method_AddWeapon,

  /*--------------------------------[ Ammo ]--------------------------------*/

  /**
   * Called when an weapon instance is extracting ammo.
   *
   * @param pWeapon Weapon entity to extract ammo from
   *
   * @return true if the object was extracted from the weapon, false otherwise
   */
  CW_Method_ExtractAmmo,

  /**
   * Called when an weapon instance is extracting clip ammo.
   *
   * @param pWeapon Weapon entity to extract clip ammo from
   *
   * @return true if the object was extracted from the weapon, false otherwise
   */
  CW_Method_ExtractClipAmmo,

  /**
   * Called when an weapon instance is adding primary ammo.
   *
   * @param iAmount Amount of ammo to add
   *
   * @noreturn
   */
  CW_Method_AddPrimaryAmmo,

  /**
   * Called when an weapon instance is adding secondary ammo.
   *
   * @param iAmount Amount of ammo to add
   *
   * @noreturn
   */
  CW_Method_AddSecondaryAmmo,

  /*--------------------------------[ Sounds ]--------------------------------*/

  /**
   * Called when an weapon instance is playing a pickup sound.
   *
   * @noreturn
   */
  CW_Method_PickupSound,

  /**
   * Called when an weapon instance is playing a pickup ammo sound.
   *
   * @noreturn
   */
  CW_Method_PickupAmmoSound,

  /**
   * Called when an weapon instance is playing a pump sound.
   *
   * @noreturn
   */
  CW_Method_PumpSound,

  /**
   * Called when an weapon instance is playing an empty sound.
   *
   * @noreturn
   */
  CW_Method_PlayEmptySound,

  /**
   * Called when an weapon instance is resetting an empty sound.
   *
   * @noreturn
   */
  CW_Method_ResetEmptySound,

  /**
   * Called when an weapon instance is playing a reload sound.
   *
   * @noreturn
   */
  CW_Method_ReloadSound,

  /*--------------------------------[ Effects ]--------------------------------*/

  /**
   * Called when an weapon instance is ejecting a brass.
   *
   * @param iModelIndex Model index of the brass
   * @param iSoundType Sound type of the brass
   *
   * @noreturn
   */
  CW_Method_EjectBrass,

  /**
   * Called when an weapon instance is making a decal.
   *
   * @param pHit Hit entity
   * @param pTrace Trace result
   * @param bGunShot Whether the shot is a gun shot
   *
   * @noreturn
   */
  CW_Method_MakeDecal,

  /**
   * Called when an weapon instance is playing a bullet smoke.
   *
   * @param pHit Hit entity
   * @param pTrace Trace result
   * @param bGunShot Whether the shot is a gun shot
   *
   * @noreturn
   */
  CW_Method_BulletSmoke,

  /**
   * Called when an weapon instance is playing a bubble trail.
   *
   * @param pHit Hit entity
   * @param pTrace Trace result
   * @param bGunShot Whether the shot is a gun shot
   *
   * @noreturn
   */
  CW_Method_BubbleTrail,

  /**
   * Called when an weapon instance is playing a texture sound.
   *
   * @param pTrace Trace result
   *
   * @noreturn
   */
  CW_Method_PlayTextureSound,

  /*--------------------------------[ Default/Common behaviour ]--------------------------------*/

  /**
   * Called when an weapon instance is firing bullets.
   *
   * @param iShots Number of shots
   * @param vecSpread Spread of the bullets
   * @param flDistance Distance of the bullets
   * @param flDamage Damage of the bullets
   * @param flRangeModifier Range modifier of the bullets
   *
   * @noreturn
   */
  CW_Method_FireBullets,

  /**
   * Called when an weapon instance is deploying.
   *
   * @param szViewModel View model name
   * @param szWeaponModel Weapon model name
   * @param iAnim Animation to play
   * @param szAnimExt Animation extension
   *
   * @return true if the object was deployed, false otherwise
   */
  CW_Method_DefaultDeploy,

  /**
   * Called when an weapon instance is shooting.
   *
   * @param flDamage Damage of the bullets
   * @param flRangeModifier Range modifier of the bullets
   * @param flRate Rate of the bullets
   * @param vecSpread Spread of the bullets
   * @param iShots Number of shots
   *
   * @return true if the object was shot, false otherwise
   */
  CW_Method_DefaultShot, //  (Float:flDamage, Float:flRangeModifier, Float:flRate, Float:vecSpread[3], iShots)

  /**
   * Called when an weapon instance is reloading.
   *
   * @param iAnim Animation to play
   * @param flDelay Delay of the reload
   *
   * @return true if the object was reloaded, false otherwise
   */
  CW_Method_DefaultReload,

  /**
   * Called when an weapon instance is idling.
   *
   * @param iAnim Animation to play
   * @param iReloadEndAnim Animation to play after the reload
   * @param flDuration Duration of the idle
   * @param flReloadEndDuration Duration of the reload end
   *
   * @return true if the object was idled, false otherwise
   */
  CW_Method_DefaultShotgunIdle,

  /**
   * Called when an weapon instance is shooting.
   *
   * @param flDamage Damage of the bullets
   * @param flRangeModifier Range modifier of the bullets
   * @param flRate Rate of the bullets
   * @param flPumpDelay Delay of the pump
   * @param vecSpread Spread of the bullets
   * @param iShots Number of shots
   *
   * @return true if the object was shot, false otherwise
   */
  CW_Method_DefaultShotgunShot,

  /**
   * Called when an weapon instance is reloading.
   *
   * @param iStartAnim Start animation
   * @param iEndAnim End animation
   * @param flDelay Delay of the reload
   * @param flDuration Duration of the reload
   *
   * @return true if the object was reloaded, false otherwise
   */
  CW_Method_DefaultShotgunReload,

  /**
   * Called when an weapon instance is swinging.
   *
   * @param flDamage Damage of the swing
   * @param flRate Rate of the swing
   * @param flDistance Distance of the swing
   * @param flSmackDelay Delay of the swing
   *
   * @return true if the object was swung, false otherwise
   */
  CW_Method_DefaultSwing,

  /**
   * Called when an weapon instance is smacking.
   *
   * @return entity index of the hit entity, FM_NULLENT if no hit
   */
  CW_Method_Smack,

  /**
   * Called when an weapon instance is tracing a swing.
   *
   * @param flDistance Distance of the swing
   *
   * @noreturn
   */
  CW_Method_SmackTraceAttack,

  /**
   * Called when an weapon instance is tracing a swing.
   *
   * @param flDistance Distance of the swing
   *
   * @return entity index of the hit entity, FM_NULLENT if no hit
   */
  CW_Method_TraceSwing,

  /**
   * Called when an weapon instance is checking if it is out of ammo.
   *
   * @return true if the object is out of ammo, false otherwise
   */
  CW_Method_IsOutOfAmmo,

  /**
   * Called when an weapon instance is updating the ammo type.
   *
   * @noreturn
   */
  CW_Method_UpdateAmmoType,

  /**
   * Called when an weapon instance is getting the primary ammo name.
   *
   * @param szOut Buffer to copy the value
   * @param iMaxLength Maximum size of buffer
   *
   * @noreturn
   */
  CW_Method_GetPrimaryAmmoName,

  /**
   * Called when an weapon instance is getting the secondary ammo name.
   *
   * @param szOut Buffer to copy the value
   * @param iMaxLength Maximum size of buffer
   *
   * @noreturn
   */
  CW_Method_GetSecondaryAmmoName,

  /**
   * Called when an weapon instance is checking if it is exhausted.
   *
   * @return true if the object is exhausted, false otherwise
   */
  CW_Method_IsExhausted,

  /**
   * Called when an weapon instance is getting the hit texture.
   *
   * @return The hit texture of the object
   */
  CW_Method_HitTexture
};

enum CW_AmmoHook {
  CW_AmmoHook_Invalid = -1,
  /**
   * Called when giving ammo to a player.
   *
   * @param pPlayer Player entity
   * @param iAmount Amount of ammo to give
   *
   * @noreturn
   */
  CW_AmmoHook_GiveToPlayer,
  
  /**
   * Called when extracting ammo from a weapon.
   *
   * @param pWeapon Weapon entity to extract ammo from
   * @param iAmount Amount of ammo to extract
   * @param pTargetWeapon Weapon entity to extract ammo to
   *
   * @noreturn
   */
  CW_AmmoHook_Extract,
  
  /**
   * Called when extracting clip ammo from a weapon.
   *
   * @param pWeapon Weapon entity to extract clip ammo from
   * @param iAmount Amount of clip ammo to extract
   * @param pTargetWeapon Weapon entity to extract clip ammo to
   *
   * @noreturn
   */
  CW_AmmoHook_ExtractClip,
};

// Internal members

#define CW_Member_Id "_id"
#define CW_Member_Pointer "_ptr"
#define CW_Member_PluginId "iPluginId"

// Constants members

#define CW_Member_iId "iId"
#define CW_Member_iSlot "iSlot"
#define CW_Member_iPosition "iPosition"
#define CW_Member_iFlags "iFlags"
#define CW_Member_iWeight "iWeight"
#define CW_Member_iMaxClip "iMaxClip"
#define CW_Member_iSecondaryAmmoType "iSecondaryAmmoType"
#define CW_Member_iPrimaryAmmoType "iPrimaryAmmoType"
#define CW_Member_iMaxPrimaryAmmo "iMaxPrimaryAmmo"
#define CW_Member_iMaxSecondaryAmmo "iMaxSecondaryAmmo"
#define CW_Member_szModel "szModel"
#define CW_Member_szIcon "szIcon"
#define CW_Member_iDefaultAmmo "iDefaultAmmo"
#define CW_Member_flShotDistance "flShotDistance"
#define CW_Member_bExhaustible "bExhaustible"
#define CW_Member_szPrimaryAmmo "szPrimaryAmmo"
#define CW_Member_szSecondaryAmmo "szSecondaryAmmo"
#define CW_Member_bReloadOnFire "bReloadOnFire"

// State members

#define CW_Member_iClip "iClip"
#define CW_Member_bInReload "bInReload"
#define CW_Member_flTimeIdle "flTimeIdle"
#define CW_Member_flLastFireTime "flLastFireTime"
#define CW_Member_flNextSecondaryAttack "flNextSecondaryAttack"
#define CW_Member_flNextPrimaryAttack "flNextPrimaryAttack"
#define CW_Member_flPumpTime "flPumpTime"
#define CW_Member_flNextReload "flNextReload"
#define CW_Member_flDecreaseShotsFired "flDecreaseShotsFired"
#define CW_Member_flAccuracy "flAccuracy"
#define CW_Member_bDelayFire "bDelayFire"
#define CW_Member_bFireOnEmpty "bFireOnEmpty"
#define CW_Member_iShotsFired "iShotsFired"
#define CW_Member_iSpecialReload "iSpecialReload"
#define CW_Member_bInSpecialReload "bInSpecialReload"
#define CW_Member_bPlayEmptySound "bPlayEmptySound"
#define CW_Member_bAltAttack "bAltAttack"
#define CW_Member_pSwingTrace "pSwingTrace"
#define CW_Member_vecSwing "vecSwing"
#define CW_Member_flSwingDamage "flSwingDamage"
#define CW_Member_pSwingHit "pSwingHit"
#define CW_Member_flSmackTime "flSmackTime"
#define CW_Member_chHitTextureType "chHitTextureType"
#define CW_Member_flHitDamage "flHitDamage"

// Became "true" when the weapon ammo extracted or weapon has been used
#define CW_Member_bDirty "bDirty"
