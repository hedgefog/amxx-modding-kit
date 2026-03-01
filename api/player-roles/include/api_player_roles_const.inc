#if defined _api_player_roles_const_included
  #endinput
#endif
#define _api_player_roles_const_included

#define PLAYER_ROLE_MAX_LENGTH 32
#define PLAYER_ROLE_ASSIGNMENT_GROUP_MAX_LENGTH 32
#define PLAYER_ROLE_MAX_ROLES 64
#define PLAYER_ROLE_MAX_ASSIGNMENT_GROUPS 32
#define PLAYER_ROLE_MAX_PLAYER_ROLES 32
#define PLAYER_ROLE_MAX_MEMBER_NAME_LENGTH 64
#define PLAYER_ROLE_MAX_METHOD_NAME_LENGTH 64
#define PLAYER_ROLE_MAX_CALLBACK_NAME_LENGTH 64

enum { PLAYER_ROLE_IGNORED = 0, PLAYER_ROLE_HANDLED, PLAYER_ROLE_OVERRIDE, PLAYER_ROLE_SUPERCEDE };

enum {
  PlayerRole_Type_Invalid = -1,
  PlayerRole_Type_Cell,
  PlayerRole_Type_String,
  PlayerRole_Type_Array,
  PlayerRole_Type_Vector
};

enum PlayerRole_Method {
  PlayerRole_Method_Invalid = -1,
  PlayerRole_Method_Assign,
  PlayerRole_Method_Unassign
}
