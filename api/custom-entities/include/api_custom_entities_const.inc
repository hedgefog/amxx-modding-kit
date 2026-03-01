#if defined _api_custom_entities_const_included
  #endinput
#endif
#define _api_custom_entities_const_included

#define CE_BASE_CLASSNAME "info_target"

#define CE_MAX_NAME_LENGTH 64
#define CE_MAX_MEMBER_NAME_LENGTH 64
#define CE_MAX_METHOD_NAME_LENGTH 64
#define CE_MAX_CALLBACK_NAME_LENGTH 64

#define CE_Class_Null "ce_null"
#define CE_Class_Base "ce_base"
#define CE_Class_BaseItem "ce_baseitem"
#define CE_Class_BaseMonster "ce_basemonster"
#define CE_Class_BaseProp "ce_baseprop"
#define CE_Class_BaseTrigger "ce_basetrigger"
#define CE_Class_BaseBsp "ce_basebsp"

enum CE { CE_InvalidHandler = -1 };
enum { CE_IGNORED = 0, CE_HANDLED, CE_OVERRIDE, CE_SUPERCEDE };
enum { CE_Type_Invalid = -1, CE_Type_Cell, CE_Type_String, CE_Type_Array, CE_Type_Vector, CE_Type_CellRef };

enum CEMemberType {
  CEMemberType_Invalid = -1,
  CEMemberType_Cell,
  CEMemberType_Float,
  CEMemberType_String,
  CEMemberType_Vector
};

enum CE_Method {
  CE_Method_Invalid = -1,

  /*--------------------------------[ Base methods ]--------------------------------*/

  /**
   * Called when an entity instance is allocated.
   *
   * @noreturn
   */
  CE_Method_Create,

  /**
   * Called when an entity instance is about to be destroyed.
   *
   * @noreturn
   */
  CE_Method_Destroy,

  /**
   * Called when a new key-value pair is obtained during entity setup.
   *
   * @param szKey The key name
   * @param szValue The value string
   *
   * @noreturn
   */
  CE_Method_KeyValue,

  /**
   * Called when an entity is initialized (on first spawn).
   *
   * @noreturn
   */
  CE_Method_SpawnInit,

  /**
   * Called during entity spawn.
   *
   * @noreturn
   */
  CE_Method_Spawn,

  /**
   * Called when entity variables are reset (on first spawn).
   *
   * @noreturn
   */
  CE_Method_ResetVariables,

  /**
   * Called during entity physics initialization.
   *
   * @noreturn
   */
  CE_Method_InitPhysics,

  /**
   * Called during entity model initialization.
   *
   * @noreturn
   */
  CE_Method_InitModel,

  /**
   * Called during entity size initialization.
   *
   * @noreturn
   */
  CE_Method_InitSize,

  /**
   * Called when an entity is touched by another entity.
   *
   * @param pToucher The entity that touched this entity
   *
   * @noreturn
   */
  CE_Method_Touch,

  /**
   * Called when an entity is thinking.
   *
   * @noreturn
   */
  CE_Method_Think,

  /**
   * Called to check if an entity can be picked up.
   *
   * @param pToucher The entity attempting to pick up this entity
   *
   * @return true if the entity can be picked up, false otherwise
   */
  CE_Method_CanPickup,

  /**
   * Called when a player touches an item entity.
   *
   * @param pToucher The entity attempting to pick up this entity
   *
   * @noreturn
   */
  CE_Method_Pickup,

  /**
   * Called to check if an entity can be triggered.
   *
   * @param pToucher The entity attempting to trigger this entity
   *
   * @return true if the entity can be triggered, false otherwise
   */
  CE_Method_CanTrigger,

  /**
   * Called when an entity is triggered.
   *
   * @param pToucher The entity that triggered this entity
   *
   * @noreturn
   */
  CE_Method_Trigger,

  /**
   * Called when an entity is restarting.
   *
   * @noreturn
   */
  CE_Method_Restart,

  /**
   * Called when an entity is being killed.
   *
   * @param pKiller The entity that killed this entity
   * @param iShouldGib Whether the entity should gib
   *
   * @noreturn
   */
  CE_Method_Killed,

  /**
   * Called to check if the entity's master is triggered.
   *
   * @param pActivator The activator entity
   *
   * @return true if the master is triggered, false otherwise
   */
  CE_Method_IsMasterTriggered,

  /**
   * Called to get the entity's object capabilities.
   *
   * @return Object capabilities flags
   */
  CE_Method_ObjectCaps,

  /**
   * Called to get the entity's blood color.
   *
   * @return Blood color value
   */
  CE_Method_BloodColor,

  /**
   * Called when an entity is used.
   *
   * @param pCaller The entity that called the use
   * @param pActivator The activator entity
   * @param iUseType The type of use
   * @param flValue The use value
   *
   * @noreturn
   */
  CE_Method_Use,

  /**
   * Called when an entity is blocked by another entity.
   *
   * @param pOther The blocking entity
   *
   * @noreturn
   */
  CE_Method_Blocked,

  /**
   * Called to get the entity's delay value.
   *
   * @return The delay value as a float
   */
  CE_Method_GetDelay,

  /**
   * Called to get the entity's classification.
   *
   * @return Classification value
   */
  CE_Method_Classify,

  /**
   * Called to check if an entity is triggered.
   *
   * @param pActivator The activator entity
   *
   * @return true if triggered, false otherwise
   */
  CE_Method_IsTriggered,

  /**
   * Called to get the entity's toggle state.
   *
   * @return Toggle state value
   */
  CE_Method_GetToggleState,

  /**
   * Called to set the entity's toggle state.
   *
   * @param iState The new toggle state
   *
   * @noreturn
   */
  CE_Method_SetToggleState,

  /**
   * Called when an entity respawns.
   *
   * @noreturn
   */
  CE_Method_Respawn,

  /**
   * Called when an entity is trace attacked.
   *
   * @param pAttacker The attacking entity
   * @param flDamage The damage amount
   * @param vecDirection The attack direction vector
   * @param pTrace The trace result
   * @param iDamageBits The damage type bits
   *
   * @noreturn
   */
  CE_Method_TraceAttack,

  /**
   * Called when an entity takes damage.
   *
   * @param pInflictor The damage inflictor entity
   * @param pAttacker The attacking entity
   * @param flDamage The damage amount
   * @param iDamageBits The damage type bits
   *
   * @return Integer
   */
  CE_Method_TakeDamage,

  /**
   * Called to check if an entity has a linked parent.
   *
   * @return true if has linked parent, false otherwise
   */
  CE_Method_HasLinkedParent,

  /**
   * Called when an entity is activated.
   *
   * @noreturn
   */
  CE_Method_Activate,

  /**
   * Called to precache entity resources.
   *
   * @noreturn
   */
  CE_Method_Precache,

  /*--------------------------------[ Animation ]--------------------------------*/

  /**
   * Called to reset sequence information.
   *
   * @noreturn
   */
  CE_Method_ResetSequenceInfo,

  /**
   * Called to advance the animation frame.
   *
   * @param flInterval The time interval
   *
   * @noreturn
   */
  CE_Method_FrameAdvance,

  /**
   * Called to dispatch animation events.
   *
   * @param flInterval The time interval
   *
   * @noreturn
   */
  CE_Method_DispatchAnimEvents,

  /**
   * Called to handle a specific animation event.
   *
   * @param iEventId The event ID
   * @param rgOptions The event options string
   *
   * @noreturn
   */
  CE_Method_HandleAnimEvent,

  /**
   * Called to load the entity's model.
   *
   * @noreturn
   */
  CE_Method_LoadModel,

  /**
   * Called to set the entity's animation sequence.
   *
   * @param iSequence The sequence index
   * @param bForce Whether to force the sequence change
   *
   * @noreturn
   */
  CE_Method_SetSequence,

  /**
   * Called to update sequence information.
   *
   * @noreturn
   */
  CE_Method_UpdateSequenceInfo,

  /**
   * Called when an animation sequence finishes.
   *
   * @noreturn
   */
  CE_Method_FinishSequence,

  /**
   * Called to look up an activity by ID.
   *
   * @param iActivity The activity ID
   *
   * @return The sequence index for the activity
   */
  CE_Method_LookupActivity,

  /**
   * Called to look up the heaviest activity by ID.
   *
   * @param iActivity The activity ID
   *
   * @return The sequence index for the heaviest activity
   */
  CE_Method_LookupActivityHeaviest,

  /**
   * Called to get the model view offset.
   *
   * @param vecOut Buffer to store the view offset vector
   *
   * @noreturn
   */
  CE_Method_GetModelViewOfs,

  /**
   * Called to check if the entity is moving.
   *
   * @return true if moving, false otherwise
   */
  CE_Method_IsMoving
};

#define CE_Member_Id "_id"
#define CE_Member_Pointer "_ptr"
#define CE_Member_PluginId "_iPluginId"
#define CE_Member_bWorld "_bWorld"
#define CE_Member_vecOrigin "_vecOrigin"
#define CE_Member_vecAngles "_vecAngles"
#define CE_Member_szMaster "_szMaster"
#define CE_Member_szModel "_szModel"
#define CE_Member_flDelay "_flDelay"
#define CE_Member_flNextKill "_flNextKill"
#define CE_Member_flNextRespawn "_flNextRespawn"
#define CE_Member_iBloodColor "_iBloodColor"
#define CE_Member_flLifeTime "_flLifeTime"
#define CE_Member_bIgnoreRounds "_bIgnoreRounds"
#define CE_Member_flRespawnTime "_flRespawnTime"
#define CE_Member_vecMins "_vecMins"
#define CE_Member_vecMaxs "_vecMaxs"
#define CE_Member_flLastSpawn "_flLastSpawn"
#define CE_Member_szTargetname "_szTargetname"
#define CE_Member_szTarget "_szTarget"
#define CE_Member_bPicked "_bPicked"
#define CE_Member_iToggleState "_iToggleState"
#define CE_Member_bTriggered "_bTriggered"
#define CE_Member_flSequenceFrameRate "_flSequenceFrameRate"
#define CE_Member_flGroundSpeed "_flGroundSpeed"
#define CE_Member_bSequenceLoops "_bSequenceLoops"
#define CE_Member_bSequenceFinished "_bSequenceFinished"
#define CE_Member_flLastEventCheck "_flLastEventCheck"
#define CE_Member_bHandleAnimations "_bHandleAnimations"
#define CE_Member_flLastFrameAdvance "_flLastFrameAdvance"
#define CE_Member_bForceVisible "_bForceVisible"
