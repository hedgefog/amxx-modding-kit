---
name: amxx-modding-kit-api-player-model
description: Helps with Player Model API usage for managing custom player models and animations.
---

# Player Model API (`api_player_model`)

The Player Model API provides tools for managing custom player models with support for dynamic model switching and custom animation extensions.

> **Reference**: See [README.md](https://github.com/hedgefog/amxx-modding-kit/api/player-model/README.md) for complete documentation and examples.

---

## Overview

This API allows you to:
- Set and reset custom player models
- Load and manage custom animations
- Switch animation models based on weapon extension
- Set specific animation sequences

---

## Core Functions

### Set Player Model

```pawn
// Set custom model path
PlayerModel_Set(pPlayer, "models/player/custom/custom.mdl");

// Apply the model change
PlayerModel_Update(pPlayer);
```

### Reset to Default

```pawn
PlayerModel_Reset(pPlayer);
```

### Check Custom Model

```pawn
if (PlayerModel_HasCustom(pPlayer)) {
  new szModel[MAX_RESOURCE_PATH_LENGTH];
  PlayerModel_GetCurrent(pPlayer, szModel, charsmax(szModel));
  // szModel contains current custom model path
}
```

### Get Model Entity

```pawn
new pModelEntity = PlayerModel_GetEntity(pPlayer);
```

---

## Animation System

### Precache Animations

Load animations from `animations` directory during precache:

```pawn
public plugin_precache() {
  // Precaches: cstrike/animations/mymod/player.mdl
  PlayerModel_PrecacheAnimation("mymod/player.mdl");
}
```

### Set Animation Sequence

```pawn
PlayerModel_SetSequence(pPlayer, "run");
PlayerModel_SetSequence(pPlayer, "attack");
```

### Set Weapon Animation Extension

Custom animations based on weapon:

```pawn
// Sets animation to ref_aim_myweapon, crouch_aim_myweapon, etc.
static const szCustomWeaponExt[] = "myweapon";

set_ent_data_string(pPlayer, "CBasePlayer", "m_szAnimExtention", szCustomWeaponExt);
set_ent_data(pPlayer, "CBaseMonster", "m_Activity", ACT_IDLE);
rg_set_animation(pPlayer, PLAYER_IDLE);
```

---

## Common Patterns

### Role-Based Model Change

```pawn
AssignZombieRole(const pPlayer) {
  PlayerModel_Set(pPlayer, "models/player/zombie/zombie.mdl");
  PlayerModel_Update(pPlayer);
}

RemoveZombieRole(const pPlayer) {
  PlayerModel_Reset(pPlayer);
}
```

### Spawn with Custom Model

```pawn
public HamHook_Player_Spawn_Post(const pPlayer) {
  if (!is_user_alive(pPlayer)) return HAM_IGNORED;
  
  if (IsPlayerInfected(pPlayer)) {
    PlayerModel_Set(pPlayer, g_szZombieModel);
    PlayerModel_Update(pPlayer);
  }
  
  return HAM_HANDLED;
}
```

### Team-Based Models

```pawn
SetTeamModel(const pPlayer, const iTeam) {
  switch (iTeam) {
    case TEAM_RED: {
      PlayerModel_Set(pPlayer, "models/player/red_team/red.mdl");
    }
    case TEAM_BLUE: {
      PlayerModel_Set(pPlayer, "models/player/blue_team/blue.mdl");
    }
    default: {
      PlayerModel_Reset(pPlayer);
    }
  }
  
  PlayerModel_Update(pPlayer);
}
```

### Custom Weapon Animation

```pawn
// When deploying custom weapon
@Weapon_Deploy(const this) {
  CW_CallBaseMethod();
  
  static pPlayer; pPlayer = get_ent_data_entity(this, "CBasePlayerItem", "m_pPlayer");
  
  // Set custom animation extension
  set_ent_data_string(pPlayer, "CBasePlayer", "m_szAnimExtention", "customgun");
  set_ent_data(pPlayer, "CBaseMonster", "m_Activity", ACT_IDLE);
  rg_set_animation(pPlayer, PLAYER_IDLE);
}
```

---

## Animation File Creation

### Basic Structure

Animation files need these sequences:
- `dummy`, `idle1`, `crouch_idle`
- `walk`, `run`, `crouchrun`
- `jump`, `longjump`, `swim`, `treadwater`
- `gut_flinch`, `head_flinch`

### Custom Weapon Sequences

For custom weapon animations, add:
- `ref_aim_weaponname` - Standing aim
- `ref_shoot_weaponname` - Standing shoot
- `crouch_aim_weaponname` - Crouching aim
- `crouch_shoot_weaponname` - Crouching shoot

Example QC:

```
$sequence "ref_aim_myweapon" {
  "ref_aim_myweapon_blend1" 
  "ref_aim_myweapon_blend2" 
  ...
  blend XR -90 90 fps 30 loop 
}
```

### Fake Reference

Animation model requires at least one polygon. Use fake reference SMD with minimal geometry.

### Bone Protection

Use compiler like `DoomMusic's StudioMDL` with `$protected` for each bone.

---

## Integration with Roles API

```pawn
// In role assign method
@Zombie_Assign(const pPlayer) {
  PlayerRole_This_CallBaseMethod();
  
  PlayerModel_Set(pPlayer, g_szZombieModel);
  PlayerModel_Update(pPlayer);
}

// In role unassign method
@Zombie_Unassign(const pPlayer) {
  PlayerRole_This_CallBaseMethod();
  
  PlayerModel_Reset(pPlayer);
}
```

---

## Checklist

- [ ] Precache models and animations in `plugin_precache`
- [ ] Call `PlayerModel_Update` after `PlayerModel_Set`
- [ ] Reset model on role unassign or disconnect
- [ ] Use proper animation extension naming convention
- [ ] Create animation files with required sequences
