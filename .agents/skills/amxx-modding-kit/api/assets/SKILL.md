---
name: amxx-modding-kit-api-assets
description: Guide for Assets API usage managing models, sounds, and resources from JSON configuration files.
---

# Assets API

Configuration-driven asset management, replacing hardcoded paths with external JSON library files.

For complete API documentation, see [README.md](https://github.com/hedgefog/amxx-modding-kit/api/assets/README.md).

---

## Key Principles

1. **Never hardcode paths** - Always use `Asset_Precache` from JSON config
2. **Models need path buffers** - Pass global buffer to `Asset_Precache` for model paths
3. **Sounds usually don't need buffers** - Use `Asset_EmitSound` directly
4. **Sound arrays for `Asset_EmitSound`** - Just `Asset_Precache`, no need to store paths
5. **Sound arrays for manual `emit_sound`** - Use `Asset_PrecacheList` to get paths
6. **Config values without precaching** - Use `Asset_GetFloat`, `Asset_GetInteger`, etc.

---

## Migration from Hardcoded Paths

| Feature | Old Implementation | New Implementation |
| :--- | :--- | :--- |
| **Precaching** | `precache_model`, `precache_sound` | `Asset_Precache(Library, AssetName, ...)` |
| **Emitting Sounds** | `emit_sound` | `Asset_EmitSound(Entity, Channel, Library, AssetName, ...)` |
| **Hardcoded Paths** | `"models/w_ak47.mdl"` | `Asset_Precache` fills a global buffer |

### Before (Hardcoded)

```pawn
new const g_szModel[] = "models/w_myweapon.mdl";

public plugin_precache() {
  precache_model(g_szModel);
  precache_sound("weapons/myweapon_shoot.wav");
}

// Later in code
emit_sound(pPlayer, CHAN_WEAPON, "weapons/myweapon_shoot.wav", VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
```

### After (Configuration-driven)

```pawn
#define ASSET_LIBRARY "myplugin"
#define ASSET_WEAPON_MODEL "weapon.model"
#define ASSET_SHOOT_SOUND "weapon.shoot"

new g_szModel[MAX_RESOURCE_PATH_LENGTH];

public plugin_precache() {
  // For models, pass a buffer to retrieve the actual path from config
  Asset_Precache(ASSET_LIBRARY, ASSET_WEAPON_MODEL, g_szModel, charsmax(g_szModel));
  
  // For sounds, you usually don't need the path reference
  Asset_Precache(ASSET_LIBRARY, ASSET_SHOOT_SOUND);
}

// Later in code - use Asset_EmitSound
Asset_EmitSound(pPlayer, CHAN_WEAPON, ASSET_LIBRARY, ASSET_SHOOT_SOUND, .flVolume = VOL_NORM, .flAttenuation = ATTN_NORM);
```

---

## Asset Library Structure (JSON)

Place JSON files in `addons/amxmodx/configs/assets/`:

```json
{
  "player.model": "models/player.mdl",
  "player.sounds.hit": [
    "player/hit1.wav",
    "player/hit2.wav",
    "player/hit3.wav"
  ],
  "weapon.damage": 30.0,
  "weapon.rate": 0.125,
  "effects.glow.color": [255.0, 128.0, 0.0]
}
```

### Asset Value Types

| Type | JSON Example | Pawn Getter |
|------|--------------|-------------|
| Model | `"models/item.mdl"` | `Asset_Precache`, `Asset_GetModelIndex` |
| Sound | `"sound.wav"` or array | `Asset_Precache`, `Asset_EmitSound` |
| Float | `30.0` | `Asset_GetFloat` |
| Integer | `10` | `Asset_GetInteger` |
| Bool | `true` | `Asset_GetBool` |
| String | `"text"` | `Asset_GetString` |
| Vector | `[1.0, 2.0, 3.0]` | `Asset_GetVector` |

---

## Naming Convention

For standalone plugins, use `#define` for frequently used paths:

```pawn
#define ASSET_LIBRARY "myplugin"
#define ASSET_PLAYER_MODEL "player.model"
#define ASSET_HIT_SOUNDS "player.sounds.hit"
#define ASSET_WEAPON_DAMAGE "weapon.damage"
```

For rarely used paths, pass string literals directly:

```pawn
Asset_Precache("myplugin", "player.model", g_szPlayerModel, charsmax(g_szPlayerModel));
```

---

## Loading and Precaching

### Single Asset with Path Buffer

```pawn
new g_szPlayerModel[MAX_RESOURCE_PATH_LENGTH];

public plugin_precache() {
  Asset_Precache(ASSET_LIBRARY, ASSET_PLAYER_MODEL, g_szPlayerModel, charsmax(g_szPlayerModel));
}
```

### Sound Array (with Asset_EmitSound)

When using `Asset_EmitSound`, you don't need to store paths - just precache:

```pawn
public plugin_precache() {
  // Just precache - Asset_EmitSound handles path lookup internally
  Asset_Precache(ASSET_LIBRARY, ASSET_HIT_SOUNDS);
}

// Later - plays random sound from the list
Asset_EmitSound(pEntity, CHAN_BODY, ASSET_LIBRARY, ASSET_HIT_SOUNDS);
```

### Sound Array (with manual emit_sound)

Only use `Asset_PrecacheList` when you need the actual paths for manual `emit_sound`:

```pawn
new g_rgszHitSounds[4][MAX_RESOURCE_PATH_LENGTH];
new g_iHitSoundsNum = 0;

public plugin_precache() {
  // Store paths only if you need them for manual emit_sound
  g_iHitSoundsNum = Asset_PrecacheList(ASSET_LIBRARY, ASSET_HIT_SOUNDS, 
    g_rgszHitSounds, sizeof(g_rgszHitSounds), charsmax(g_rgszHitSounds[]));
}

// Later - manual sound emission
emit_sound(pEntity, CHAN_BODY, g_rgszHitSounds[random(g_iHitSoundsNum)], VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
```

### Force Library Load

```pawn
public plugin_precache() {
  // Load library without precaching specific assets
  // Useful for mod core plugins to ensure library is available
  Asset_Library_Load(ASSET_LIBRARY);
}
```

---

## Using Assets

### Emit Sound from Asset

```pawn
// Random from list
Asset_EmitSound(pEntity, CHAN_BODY, ASSET_LIBRARY, ASSET_HIT_SOUNDS);

// Specific sound from list (index 0)
Asset_EmitSound(pEntity, CHAN_BODY, ASSET_LIBRARY, ASSET_HIT_SOUNDS, 0);
```

### Get Model Index with Static Caching

```pawn
SomeFunction() {
  static iModelIndex = 0;
  if (!iModelIndex) {
    iModelIndex = Asset_GetModelIndex(ASSET_LIBRARY, ASSET_ENTITY_MODEL);
  }
  // Use iModelIndex...
}
```

### Get Configuration Values

```pawn
new Float:flDamage = Asset_GetFloat(ASSET_LIBRARY, "weapon.damage");
new iCount = Asset_GetInteger(ASSET_LIBRARY, "max.count");
new Float:vecColor[3]; Asset_GetVector(ASSET_LIBRARY, "glow.color", vecColor);
```

---

## Nested Asset Paths

JSON supports nested objects with dot notation access:

```json
{
  "weapons": {
    "crowbar": {
      "model": "models/v_crowbar.mdl",
      "damage": 25.0
    }
  }
}
```

```pawn
Asset_Precache(ASSET_LIBRARY, "weapons.crowbar.model");
new Float:flDamage = Asset_GetFloat(ASSET_LIBRARY, "weapons.crowbar.damage");
```

---

## Integration with Custom Entities/Weapons

### Entity Setup

```pawn
new g_szModel[MAX_RESOURCE_PATH_LENGTH];

public plugin_precache() {
  Asset_Precache(ASSET_LIBRARY, "entity.model", g_szModel, charsmax(g_szModel));
  
  CE_RegisterClass(ENTITY_NAME);
  CE_ImplementClassMethod(ENTITY_NAME, CE_Method_Create, "@Entity_Create");
}

@Entity_Create(const this) {
  CE_CallBaseMethod();
  CE_SetMemberString(this, CE_Member_szModel, g_szModel);
}
```

### Weapon Setup

```pawn
new g_szWeaponModelV[MAX_RESOURCE_PATH_LENGTH];
new g_szWeaponModelP[MAX_RESOURCE_PATH_LENGTH];
new g_szWeaponModelW[MAX_RESOURCE_PATH_LENGTH];

public plugin_precache() {
  Asset_Precache(ASSET_LIBRARY, "weapon.model.v", g_szWeaponModelV, charsmax(g_szWeaponModelV));
  Asset_Precache(ASSET_LIBRARY, "weapon.model.p", g_szWeaponModelP, charsmax(g_szWeaponModelP));
  Asset_Precache(ASSET_LIBRARY, "weapon.model.w", g_szWeaponModelW, charsmax(g_szWeaponModelW));
  
  CW_RegisterClass(WEAPON_NAME);
  // ...
}
```

---

## Checklist

- [ ] Create JSON library file in `configs/assets/`
- [ ] Use `#define` for frequently used asset paths
- [ ] Use `Asset_PrecacheList` for sound arrays
- [ ] Store paths in global variables for models
- [ ] Get model indices with static caching when needed
- [ ] Use `Asset_EmitSound` instead of `emit_sound` for config-driven sounds
