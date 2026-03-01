#if defined _api_entity_force_included
  #endinput
#endif
#define _api_entity_force_included

#pragma reqlib api_entity_force

#include <api_entity_force_const>

/**
 * Adds force to an entity
 *
 * @param pEntity Entity index
 * @param vecForce Force vector
 * @param iFlags Flags
 *
 * @noreturn
 */
native EntityForce_Add(const pEntity, const Float:vecForce[3], const EntityForce_Flags:iFlags = EntityForce_Flag_None);

/**
 * Applies accumulated forces to an entity
 *
 * @param pEntity Entity index
 *
 * @noreturn
 */
native EntityForce_Apply(const pEntity);

/**
 * Clears accumulated forces from an entity
 *
 * @param pEntity Entity index
 *
 * @noreturn
 */
native EntityForce_Clear(const pEntity);

/**
 * Adds force to an entity directing from another entity
 *
 * @param pEntity Entity index
 * @param pPushEntity Pushing entity index
 * @param flForce Force amount
 * @param iFlags Flags
 *
 * @noreturn
 */
native EntityForce_AddFromEntity(const pEntity, const pPushEntity, const Float:flForce, const EntityForce_Flags:iFlags = EntityForce_Flag_None);

/**
 * Adds force to an entity directing from a specific origin
 *
 * @param pEntity Entity index
 * @param vecPushOrigin Origin
 * @param flForce Force amount
 * @param iFlags Flags
 *
 * @noreturn
 */
native EntityForce_AddFromOrigin(const pEntity, const Float:vecPushOrigin[3], const Float:flForce, const EntityForce_Flags:iFlags = EntityForce_Flag_None);

/**
 * Adds force to an entity based on a bounding box
 *
 * @param pEntity Entity index
 * @param vecAbsMin Bounding box min
 * @param vecAbsMax Bounding box max
 * @param flForce Force amount
 * @param iFlags Flags
 * @param flMinDepthRatio Min depth ratio
 * @param flMaxDepthRatio Max depth ratio
 * @param flSoftDepthRatioMin Soft depth ratio min
 * @param flSoftDepthRatioMax Soft depth ratio max
 *
 * @noreturn
 */
native EntityForce_AddFromBBox(
  const pEntity,
  const Float:vecAbsMin[3],
  const Float:vecAbsMax[3],
  const Float:flForce,
  const EntityForce_Flags:iFlags = EntityForce_Flag_None,
  const Float:flMinDepthRatio = 0.0,
  const Float:flMaxDepthRatio = 1.0,
  const Float:flSoftDepthRatioMin = 0.0,
  const Float:flSoftDepthRatioMax = 1.0
);

/**
 * Transfers momentum from one entity to another
 *
 * @param pEntity Source entity index
 * @param pTarget Target entity index
 * @param flRatio Transfer ratio
 * @param iFlags Flags
 *
 * @noreturn
 */
native EntityForce_TransferMomentum(const pEntity, const pTarget, const Float:flRatio = 1.0, const EntityForce_Flags:iFlags = EntityForce_Flag_None);

/**
 * Called when a force is added to an entity
 *
 * @param pEntity Entity index
 * @param vecForce Force vector
 * @param iFlags Flags
 *
 * @return Plugin behavior
 */
forward EntityForce_OnForceAdd(const pEntity, const Float:vecForce[3], EntityForce_Flags:iFlags);

/**
 * Called when accumulated forces are applied to an entity
 *
 * @param pEntity Entity index
 * @param vecForce Applied force vector
 *
 * @return Plugin behavior
 */
forward EntityForce_OnForceApply(const pEntity, const Float:vecForce[3]);
