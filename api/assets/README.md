# 🧸 Assets API

The **Assets API** is a robust system for managing, loading and precaching assets in AMX Mod X. It allows you to organize models, sounds and generic resources in external JSON file, making your scripts cleaner, safer, and easier to maintain. The API is designed to prevent crashes from missing assets and supports dynamic asset updates without recompiling your plugins.

## 🚀 Features

- Safe and flexible asset management for models, sound, and generic files
- Precache assets with crash protection and error fallback
- Centralized asset libraries in JSON format for easy updates
- Access assets from any script using library and asset IDs
- Support for assets with multiple resources (arrays of files)
- Update asset libraries without recompiling scripts
- Helper functions for batch precaching and path retrieval

---

## ⚙️ Getting Started

### Creating a Asset Library File

Before using the Assets API, you need to create asset library `JSON` file. This file should be placed in the `addons/amxmodx/configs/assets`. Here is an example of a library file:

#### my-library.json
  ```json
  {
    "apple-model": "models/apple.mdl",
    "banana-model": { "@type": "model", "@value": "models/banana.mdl" },
    "annoying-sounds": [
      "scientist/scream1.wav",
      "scientist/scream2.wav",
      "scientist/scream3.wav",
      "scientist/scream4.wav",
      "scientist/scream5.wav"
    ]
  }
```

As you can see it's possible to use both string and object notation for storing assets. The `type` property is optional and can be used to specify the type of the asset. The `path` property is required and should contain the path to the asset. If type is not specified, the system will try to infer the type from the file extension.

Asset manager also alows you to have multiple resources for the same asset. For example, you can have list of sounds for the same asset. In this case you should use array notation for storing assets.

## 🔄 Precaching Assets

Once you have created the library file, you can precache assets from the library file using the `Asset_Precache` function. Here is an example:

```pawn
public plugin_precache() {
  Asset_Precache("my-library", "banana-model");
}
```

This code will precache the banana model from the `my-library.json` file. You can access model using `Asset_GetPath` or `Asset_GetModelIndex` functions. It also possible to pass string reference to the `Asset_Precache` function to get path of the precached asset to the passed string. The function also returns type of precached asset. Here is an example:

```pawn
new g_szBananaModel[MAX_RESOURCE_PATH_LENGTH];

public plugin_precache() {
  new Asset_Type:iType = Asset_Precache("my-library", "banana-model", g_szBananaModel, charsmax(g_szBananaModel));

  if (iType != Asset_Type_Model) {
    log_amx("Oops, banana asset is corrupted by angry scientists!");
  }
}
```

## 📚 Working with Multiple Resources

Now let's precache asset with multiple resources from the library file:

```pawn
new g_szFirstAnnoyingSound[MAX_RESOURCE_PATH_LENGTH];

public plugin_precache() {
  Asset_Precache("my-library", "annoying-sounds", g_szFirstAnnoyingSound, charsmax(g_szFirstAnnoyingSound));
}
```

Passing string reference to the `Asset_Precache` function will return only path of the first precached asset resource. To get path of all resources you can use `Asset_GetPath` function:

```pawn
new g_szAnnoyingSounds[4][MAX_RESOURCE_PATH_LENGTH];

public plugin_precache() {
  Asset_Precache("my-library", "annoying-sounds");

  new iAnnoyingSoundsNum = Asset_GetListSize("my-library", "annoying-sounds");
  for (new i = 0; i < iAnnoyingSoundsNum; ++i) {
    if (i >= sizeof(g_szAnnoyingSounds)) break;
    Asset_GetPath("my-library", "annoying-sounds", g_szAnnoyingSounds[i], charsmax(g_szAnnoyingSounds[]), i);
  }
}
```

You can also use `Asset_PrecacheList` helper function to precache assets and get all pathes at the same time:

```pawn
new g_szAnnoyingSounds[4][MAX_RESOURCE_PATH_LENGTH];
new g_iAnnoyingSoundsNum = 0;

public plugin_precache() {
  g_iAnnoyingSoundsNum = Asset_PrecacheList("my-library", "annoying-sounds", g_szAnnoyingSounds, sizeof(g_szAnnoyingSounds), charsmax(g_szAnnoyingSounds[]));

  log_amx("Loaded %d annoying sounds of angry scientists who corrupted the banana model.", g_iAnnoyingSoundsNum);
}
```

Much better now. Even if you use this function for asset with single resource it will still work but only write first resource to the passed array.

---

## 🦸 Advanced Usage

### Nested Objects

You can also use nested objects to store assets in library file. For example:

```json
{
  "models": {
    "apple": { "@type": "model", "@value": "models/apple.mdl" },
    "banana": { "@type": "model", "@value": "models/banana.mdl" }
  }
}
```
To access assets from nested objects you can use dot notation. For example:

```pawn
Asset_Precache("my-library", "models.apple");
```

### Variables

API also supports variables. You can use them to store dynamic values in library file. For example:

```json
{
  "my-float-value": 123.45,
  "my-integer-value": 42,
  "my-string-value": "Hello, world!",
  "my-bool-value": true,
  "my-vector-value1": [1.0, 2.0, 3.0],
  "my-vector-value2": { "x": 1.0, "y": 2.0, "z": 3.0 }
}
```

To access variables you can use `Asset_GetFloat`, `Asset_GetInteger`, `Asset_GetString`, `Asset_GetBool`, `Asset_GetVector` functions. For example:

```pawn
new Float:flValue = Asset_GetFloat("my-library", "my-float-value");
```

If you are trying to access integer or float variable using function for different type, the function will try to convert the value to the requested type. For example:

```pawn
new iValue = Asset_GetInteger("my-library", "my-float-value");
```

The function will return `123` because `123.45` will be rounded to `123`.

However vector and string variables cannot be converted to other types, same as other types cannot be converted to vector or string.

### Handling Missing Assets

If you try to access an asset that wasn't precached, the API will return a fallback error model or an empty string, preventing crashes:

```pawn
public plugin_precache() {
  Asset_Precache("my-library", "apple-model");
}

public plugin_init() {
  new szBananaModel[MAX_RESOURCE_PATH_LENGTH]; Asset_GetPath("my-library", "banana-model", szBananaModel, charsmax(szBananaModel));
  new iBananaModelIndex = Asset_GetModelIndex("my-library", "banana-model"); 
  
  log_amx("Banana model path: ^"%s^"; Banana ModelIndex: %d;", szBananaModel, iModelIndex);
}
```

In this case we will see message like `Banana model path "sprites/bubble.spr"; Banana ModelIndex: 40;` in the console. That's because `Asset_GetPath` and `Asset_GetModelIndex` function returns error model instead of path of the asset. The system knows about `my-library` library as we precached `apple-model` from the library.

But what if we don't precache `apple-model` from the library? Let's try to access it from the script:

```pawn
public plugin_precache() {}

public plugin_init() {
  new szBananaModel[MAX_RESOURCE_PATH_LENGTH]; Asset_GetPath("my-library", "banana-model", szBananaModel, charsmax(szBananaModel));
  new iBananaModelIndex = Asset_GetModelIndex("my-library", "banana-model"); 
  
  log_amx("[Banana] Model path: ^"%s^"; ModelIndex: %d;", szBananaModel, iBananaModelIndex);
}
```

In this case, unfortunately we will see message like `Banana model path ""; Banana ModelIndex: 40;`, because system no longer know about `my-library` library and can't resolve `banana-model` asset path. However model index is still valid and refered to the error (`buble`) model.

### Forcing Library Load

To ensure assets info is available (even if not precached) use `Asset_Library_Load` function to load the library and assets.

```pawn
public plugin_precache() {
  Asset_Library_Load("my-library");
}

public plugin_init() {
  new szBananaModel[MAX_RESOURCE_PATH_LENGTH]; Asset_GetPath("my-library", "banana-model", szBananaModel, charsmax(szBananaModel));
  new iBananaModelIndex = Asset_GetModelIndex("my-library", "banana-model"); 
  
  log_amx("Banana model path: ^"%s^"; Banana ModelIndex: %d;", szBananaModel, iModelIndex);
}
```

Now we will see message like `Banana model path "sprites/bubble.spr"; Banana ModelIndex: 40;` in the console again.

This is usefull for mods with own asset libraries. You can pre-load the libraries from the core plugin of your mod to prevent the problem with unknown assets and make the mod more modular.

## 🧩 Example: Annoying Scientists

```pawn
#include <amxmodx>
#include <fakemeta>

#include <api_assets>

new g_szBananaModel[MAX_RESOURCE_PATH_LENGTH];
new g_szAppleModel[MAX_RESOURCE_PATH_LENGTH];
new g_szAnnoyingSounds[4][MAX_RESOURCE_PATH_LENGTH];

new g_iAnnoyingSoundsNum = 0;

public plugin_precache() {
  Asset_Precache("my-library", "banana-model", g_szBananaModel, charsmax(g_szBananaModel));
  Asset_Precache("my-library", "apple-model", g_szAppleModel, charsmax(g_szAppleModel));
  g_iAnnoyingSoundsNum = Asset_PrecacheList("my-library", "annoying-sounds", g_szAnnoyingSounds, sizeof(g_szAnnoyingSounds), charsmax(g_szAnnoyingSounds[]));
}

public plugin_init() {
  register_plugin("Annoying Scientists", "1.0.0", "Hedgehog Fog");

  register_clcmd("say /banana", "Command_Banana");
}

public Command_Banana(const pPlayer) {
  static Float:vecOrigin[3]; pev(pPlayer, pev_origin, vecOrigin);

  new pBanana = @Banana_Create();
  engfunc(EngFunc_SetOrigin, pBanana, vecOrigin);

  set_task(1.0, "Task_CorruptBanana", pBanana);
}

@Banana_Create() {
  new this = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "info_target"));
  engfunc(EngFunc_SetModel, this, g_szBananaModel);
  set_pev(this, pev_solid, SOLID_TRIGGER);
  set_pev(this, pev_movetype, MOVETYPE_TOSS);
  dllfunc(DLLFunc_Spawn, this);

  return this;
}

@Banana_Corrupt(const &this) {
  engfunc(EngFunc_SetModel, this, g_szAppleModel);
}

public Task_CorruptBanana(const iTaskId) {
  new pBanana = iTaskId;

  @Banana_Corrupt(pBanana);

  emit_sound(pBanana, CHAN_VOICE, g_szAnnoyingSounds[random(g_iAnnoyingSoundsNum)], VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
  client_print(0, print_chat, "Oh no! Angry scientists have corrupted the banana!");
}
```

---

## 📖 API Reference

See [`api_assets.inc`](include/api_assets.inc) and [`api_assets_const.inc`](include/api_assets_const.inc) for all available natives and constants.
