#if defined _api_assets_const_included
  #endinput
#endif
#define _api_assets_const_included

#define ASSETS_MAX_ASSETS 1024
#define ASSETS_MAX_LIBRARY_ID_LENGTH 32
#define ASSETS_MAX_ASSET_ID_LENGTH 64
#define ASSET_INDEX_RANDOM -2

enum Asset_Type {
  Asset_Type_Invalid = -1,
  Asset_Type_Generic,
  Asset_Type_Model,
  Asset_Type_Sound,
  Asset_Type_Array, // Internal type for arrays of assets
  Asset_Type_Variable
};

enum Asset_Variable_Type {
  Asset_Variable_Type_Invalid = -1,
  Asset_Variable_Type_String,
  Asset_Variable_Type_Integer,
  Asset_Variable_Type_Float,
  Asset_Variable_Type_Bool,
  Asset_Variable_Type_Vector
};
