#pragma semicolon 1

#include <amxmodx>
#include <hamsandwich>
#include <fakemeta>
#include <xs>

#define IS_ZERO_VECTOR(%1) (!(%1[0] || %1[1] || %1[2]))

#define PLAYER_PREVENT_CLIMB (1<<5)

#define PLAYER_DUCKING_MULTIPLIER 0.333
#define PLAYER_STATIONARY_MULTIPLIER 0.5
#define PLAYER_JUMP_FORCE 268.3281572999748

#define DIZZINESS_THINK_RATE 0.01
#define DIZZINESS_ANGLE_HANDLE_SPEED 100.0
#define DIZZINESS_ANGLE_HANDLE_SPEED_MIN 50.0
#define DIZZINESS_ANGLE_HANDLE_SPEED_MAX 150.0
#define DIZZINESS_BLINK_TRANSITION_DURATION 0.75
#define DIZZINESS_BLINK_TRANSITION_DURATION_MIN 0.25
#define DIZZINESS_BLINK_TRANSITION_DURATION_MAX 1.0
#define DIZZINESS_PUSH_FORCE_MIN 10.0
#define DIZZINESS_PUSH_FORCE_MAX 40.0
#define DIZZINESS_BLINK_DURATION_MIN 0.1
#define DIZZINESS_BLINK_DURATION_MAX 1.0
#define DIZZINESS_BLINK_RATE_MIN 1.0
#define DIZZINESS_BLINK_RATE_MAX 10.0
#define DIZZINESS_PUNCH_ANGLE_MIN 20.0
#define DIZZINESS_PUNCH_ANGLE_MAX 75.0

new gmsgScreenFade;

new Float:g_flGameTime = 0.0;

new Float:g_flPushRateMin = 0.0;
new Float:g_flPushRateMax = 0.0;
new Float:g_flPushForce = 0.0;
new Float:g_flBlinkDuration = 0.0;
new Float:g_flRandomBlinkRate = 0.0;
new Float:g_flMinStrengthToBlink = 0.0;
new Float:g_flPunchAngleFeedback = 0.0;
new bool:g_bPushPreventClimb = false;

new Float:g_rgflPlayerDizzinessNextThink[MAX_PLAYERS + 1];
new Float:g_rgflPlayerDizzinessStrength[MAX_PLAYERS + 1];
new Float:g_rgflPlayerNextPushTargetUpdate[MAX_PLAYERS + 1];
new Float:g_rgvecPlayerPushVelocityTarget[MAX_PLAYERS + 1][3];
new Float:g_rgflPlayerMovementSpeed[MAX_PLAYERS + 1];
new Float:g_rgvecPlayerPushVelocityAcc[MAX_PLAYERS + 1][3];
new Float:g_rgflPlayerLastPushThink[MAX_PLAYERS + 1];
new Float:g_rgflPlayerNextPushThink[MAX_PLAYERS + 1];
new Float:g_rgflPlayerNextBlink[MAX_PLAYERS + 1];
new Float:g_rgflPlayerReleaseClimbBlock[MAX_PLAYERS + 1];

public plugin_init() {
  register_plugin("[API] Player Dizziness", "1.1.1", "Hedgehog Fog");

  RegisterHamPlayer(Ham_Player_Jump, "HamHook_Player_Jump_Post", .Post = 1);
  RegisterHamPlayer(Ham_Player_PreThink, "HamHook_Player_PreThink_Post", .Post = 1);

  bind_pcvar_float(create_cvar("dizziness_push_force", "150.0"), g_flPushForce);
  bind_pcvar_float(create_cvar("dizziness_push_rate_min", "0.5"), g_flPushRateMin);
  bind_pcvar_float(create_cvar("dizziness_push_rate_max", "1.0"), g_flPushRateMax);
  bind_pcvar_num(create_cvar("dizziness_push_prevent_climb", "1"), g_bPushPreventClimb);
  bind_pcvar_float(create_cvar("dizziness_blink_duration", "0.1"), g_flBlinkDuration);
  bind_pcvar_float(create_cvar("dizziness_blink_rate", "3.0"), g_flRandomBlinkRate);
  bind_pcvar_float(create_cvar("dizziness_blink_min_strength", "0.5"), g_flMinStrengthToBlink);
  bind_pcvar_float(create_cvar("dizziness_punch_angle_feedback", "45.0"), g_flPunchAngleFeedback);

  gmsgScreenFade = get_user_msgid("ScreenFade");
}

public plugin_natives() {
  register_library("api_player_dizziness");
  register_native("PlayerDizziness_Set", "Native_SetPlayerDizziness");
  register_native("PlayerDizziness_Get", "Native_GetPlayerDizziness");
}

public Native_SetPlayerDizziness(const iPluginId, const iArgc) {
  new pPlayer = get_param(1);
  new Float:flValue = get_param_f(2);
  
  g_rgflPlayerDizzinessStrength[pPlayer] = floatclamp(flValue, 0.0, 10.0);

  if (g_rgflPlayerReleaseClimbBlock[pPlayer]) {
    @Player_SetClimbPrevention(pPlayer, false);
    g_rgflPlayerReleaseClimbBlock[pPlayer] = 0.0;
  }
}

public Float:Native_GetPlayerDizziness(const iPluginId, const iArgc) {
  new pPlayer = get_param(1);

  return g_rgflPlayerDizzinessStrength[pPlayer];
}

public client_connect(pPlayer) {
  g_rgflPlayerDizzinessNextThink[pPlayer] = 0.0;
  g_rgflPlayerDizzinessStrength[pPlayer] = 0.0;
  g_rgflPlayerNextPushTargetUpdate[pPlayer] = 0.0;
  g_rgflPlayerLastPushThink[pPlayer] = 0.0;
  g_rgflPlayerNextPushThink[pPlayer] = 0.0;
  g_rgflPlayerNextBlink[pPlayer] = 0.0;

  xs_vec_set(g_rgvecPlayerPushVelocityTarget[pPlayer], 0.0, 0.0, 0.0);
  xs_vec_set(g_rgvecPlayerPushVelocityAcc[pPlayer], 0.0, 0.0, 0.0);
}

public server_frame() {
  g_flGameTime = get_gametime();
}

public HamHook_Player_PreThink_Post(const pPlayer) {
  if (g_flGameTime >= g_rgflPlayerDizzinessNextThink[pPlayer]) {
    @Player_DizzinessThink(pPlayer);
    g_rgflPlayerDizzinessNextThink[pPlayer] = g_flGameTime + DIZZINESS_THINK_RATE;
  }
}

public HamHook_Player_Jump_Post(const pPlayer) {
  if (pev(pPlayer, pev_flags) & FL_ONGROUND && ~pev(pPlayer, pev_oldbuttons) & IN_JUMP) {
    if (g_rgflPlayerDizzinessStrength[pPlayer] > 0.1) {
      @Player_Jump(pPlayer);
      return HAM_SUPERCEDE;
    }
  }

  return HAM_HANDLED;
}

@Player_DizzinessThink(const &this) {
  if (g_rgflPlayerDizzinessStrength[this] <= 0.0) return;
  if (pev(this, pev_flags) & FL_FROZEN) return;
  if (!is_user_alive(this)) return;

  @Player_ClimbPreventionThink(this);
  @Player_BlinkThink(this);
  @Player_MovementThink(this);
  @Player_CameraFeedbackThink(this);
}

@Player_MovementThink(const &this) {
  static iFlags; iFlags = pev(this, pev_flags);
  static iMoveType; iMoveType = pev(this, pev_movetype);

  static Float:vecMovementSpeed[3]; @Player_CalculateMovementVelocity(this, vecMovementSpeed);

  if (g_rgflPlayerNextPushTargetUpdate[this] <= g_flGameTime) {
    static Float:flRate; flRate = random_float(g_flPushRateMin, g_flPushRateMax);

    @Player_UpdatePushTarget(this);
    g_rgflPlayerNextPushTargetUpdate[this] = g_flGameTime + flRate;
    
    if (g_bPushPreventClimb && flRate > 0.1) {
      @Player_SetClimbPrevention(this, true);
      g_rgflPlayerReleaseClimbBlock[this] = g_flGameTime + (flRate / 2);
    }
  }

  // If player on ground or on ladder - apply push velocity
  if ((iFlags & FL_ONGROUND) || (iMoveType == MOVETYPE_FLY)) {
    static Float:flDelta; flDelta = g_flGameTime - g_rgflPlayerLastPushThink[this];
    // static Float:vecVelocity[3]; pev(this, pev_velocity, vecVelocity);
    static Float:vecBaseVelocity[3]; pev(this, pev_basevelocity, vecBaseVelocity);

    for (new i = 0; i < 3; ++i) {
      g_rgvecPlayerPushVelocityAcc[this][i] += (g_rgvecPlayerPushVelocityTarget[this][i] - g_rgvecPlayerPushVelocityAcc[this][i]) * flDelta;
    }

    xs_vec_add(vecBaseVelocity, g_rgvecPlayerPushVelocityAcc[this], vecBaseVelocity);

    static Float:flMovementSpeed; flMovementSpeed = xs_vec_len(vecMovementSpeed);
    if (flMovementSpeed > 1.0) {
      static Float:vecMovementCompensation[3];
      xs_vec_div_scalar(vecMovementSpeed, flMovementSpeed, vecMovementCompensation);
      xs_vec_mul_scalar(vecMovementCompensation, floatmin(flMovementSpeed, xs_vec_len(g_rgvecPlayerPushVelocityAcc[this])), vecMovementCompensation);
      xs_vec_sub(vecBaseVelocity, vecMovementCompensation, vecBaseVelocity);
    }

    g_rgflPlayerMovementSpeed[this] = flMovementSpeed;

    set_pev(this, pev_basevelocity, vecBaseVelocity);
  }

  g_rgflPlayerLastPushThink[this] = g_flGameTime;
}

@Player_CameraFeedbackThink(const &this) {
  if (!g_flPunchAngleFeedback) return;

  static Float:flDizzinessStrength; flDizzinessStrength = g_rgflPlayerDizzinessStrength[this];

  static Float:vecAngles[3]; pev(this, pev_v_angle, vecAngles);
  static Float:vecVelocity[3]; pev(this, pev_velocity, vecVelocity);
  static Float:vecBaseVelocity[3]; pev(this, pev_basevelocity, vecBaseVelocity);
  static Float:flMaxMoveSpeed; flMaxMoveSpeed = @Player_GetMaxMoveSpeed(this);
  static Float:vecPunchAngle[3]; pev(this, pev_punchangle, vecPunchAngle);

  static Float:flMaxPunchAngle; flMaxPunchAngle = floatclamp(g_flPunchAngleFeedback * flDizzinessStrength, DIZZINESS_PUNCH_ANGLE_MIN, DIZZINESS_PUNCH_ANGLE_MAX);
  static Float:flAngleHandleSpeed; flAngleHandleSpeed = floatclamp(DIZZINESS_ANGLE_HANDLE_SPEED / flDizzinessStrength, DIZZINESS_ANGLE_HANDLE_SPEED_MIN, DIZZINESS_ANGLE_HANDLE_SPEED_MAX);

  vecAngles[0] = 0.0;
  vecAngles[2] = 0.0;

  static Float:vecForward[3]; angle_vector(vecAngles, ANGLEVECTOR_FORWARD, vecForward);
  static Float:vecRight[3]; angle_vector(vecAngles, ANGLEVECTOR_RIGHT, vecRight);

  flMaxMoveSpeed = floatmin(flMaxMoveSpeed, flAngleHandleSpeed);
  vecPunchAngle[0] += floatclamp(xs_vec_dot(vecVelocity, vecForward) + xs_vec_dot(vecBaseVelocity, vecForward), -flMaxMoveSpeed, flMaxMoveSpeed) / flMaxMoveSpeed * flMaxPunchAngle * DIZZINESS_THINK_RATE;
  vecPunchAngle[2] += floatclamp(xs_vec_dot(vecVelocity, vecRight) + xs_vec_dot(vecBaseVelocity, vecRight), -flMaxMoveSpeed, flMaxMoveSpeed) / flMaxMoveSpeed * flMaxPunchAngle * DIZZINESS_THINK_RATE;

  if (!IS_ZERO_VECTOR(vecPunchAngle)) {
    set_pev(this, pev_punchangle, vecPunchAngle);
  }
}

@Player_BlinkThink(const &this) {
  static Float:flDizzinessStrength; flDizzinessStrength = g_rgflPlayerDizzinessStrength[this];

  if (!g_flRandomBlinkRate) return;
  if (g_rgflPlayerDizzinessStrength[this] < g_flMinStrengthToBlink) return;
  if (g_rgflPlayerNextBlink[this] > g_flGameTime) return;

  static Float:flBlinkTransitionDuration; flBlinkTransitionDuration = floatclamp(DIZZINESS_BLINK_TRANSITION_DURATION * flDizzinessStrength, DIZZINESS_BLINK_TRANSITION_DURATION_MIN, DIZZINESS_BLINK_TRANSITION_DURATION_MAX);
  static Float:flBlinkDuration; flBlinkDuration = floatclamp(g_flBlinkDuration * flDizzinessStrength, DIZZINESS_BLINK_DURATION_MIN, DIZZINESS_BLINK_DURATION_MAX);
  static Float:flBlinkRate; flBlinkRate = floatclamp(g_flRandomBlinkRate / flDizzinessStrength, DIZZINESS_BLINK_RATE_MIN, DIZZINESS_BLINK_RATE_MAX);

  @Player_Blink(this, flBlinkDuration, flBlinkTransitionDuration);

  g_rgflPlayerNextBlink[this] = g_flGameTime + flBlinkRate + flBlinkDuration;
}

@Player_UpdatePushTarget(const &this) {
  static Float:flMaxMoveSpeed; flMaxMoveSpeed = @Player_GetMaxMoveSpeed(this);

  static Float:flMinPushForce; flMinPushForce = DIZZINESS_PUSH_FORCE_MIN;
  static Float:flMaxPushForce; flMaxPushForce = floatmin(g_flPushForce * g_rgflPlayerDizzinessStrength[this], flMaxMoveSpeed);
  
  if (pev(this, pev_flags) & FL_DUCKING) {
    flMaxPushForce *= PLAYER_DUCKING_MULTIPLIER;
  }

  if (g_rgflPlayerMovementSpeed[this] < 10.0) {
    flMaxPushForce *= PLAYER_STATIONARY_MULTIPLIER;
  }

  flMaxPushForce = floatmin(flMaxPushForce, DIZZINESS_PUSH_FORCE_MAX);
  
  // floatclamp(g_flPushForce * g_rgflPlayerDizzinessStrength[this], flMinPushForce, floatmin(flMaxMoveSpeed, DIZZINESS_PUSH_FORCE_MAX));

  xs_vec_set(g_rgvecPlayerPushVelocityAcc[this], 0.0, 0.0, 0.0);

  static Float:flPushForce; flPushForce = random_float(flMinPushForce, flMaxPushForce);

  xs_vec_set(g_rgvecPlayerPushVelocityTarget[this], random_float(-1.0, 1.0), random_float(-1.0, 1.0), 0.0);
  xs_vec_normalize(g_rgvecPlayerPushVelocityTarget[this], g_rgvecPlayerPushVelocityTarget[this]);
  xs_vec_mul_scalar(g_rgvecPlayerPushVelocityTarget[this], flPushForce, g_rgvecPlayerPushVelocityTarget[this]);

  g_rgflPlayerLastPushThink[this] = g_flGameTime;
}

@Player_Blink(const &this, Float:flDuration, Float:flTransitionDuration) {
  static const iFlags = 0;
  static const rgiColor[3] = {0, 0, 0};
  static const iAlpha = 255;

  new iFadeTime = FixedUnsigned16(flTransitionDuration, (1<<12));
  new iHoldTime = FixedUnsigned16(flDuration, (1<<12));

  emessage_begin(MSG_ONE, gmsgScreenFade, _, this);
  ewrite_short(iFadeTime);
  ewrite_short(iHoldTime);
  ewrite_short(iFlags);
  ewrite_byte(rgiColor[0]);
  ewrite_byte(rgiColor[1]);
  ewrite_byte(rgiColor[2]);
  ewrite_byte(iAlpha);
  emessage_end();
}

@Player_Jump(const &this) {
  static Float:vecVelocity[3];
  vecVelocity[0] = random_float(-1.0, 1.0);
  vecVelocity[1] = random_float(-1.0, 1.0);
  vecVelocity[2] = 0.0;

  xs_vec_normalize(vecVelocity, vecVelocity);
  xs_vec_mul_scalar(vecVelocity, random_float(80.0, 100.0), vecVelocity);
  vecVelocity[2] = PLAYER_JUMP_FORCE - (PLAYER_JUMP_FORCE * 0.2125 * g_rgflPlayerDizzinessStrength[this]);

  set_pev(this, pev_velocity, vecVelocity);
  set_pev(this, pev_basevelocity, Float:{0.0, 0.0, 0.0});
}

Float:@Player_CalculateMovementVelocity(const &this, Float:vecOut[3]) {
  static iButtons; iButtons = pev(this, pev_button);
  static Float:flMaxMoveSpeed; flMaxMoveSpeed = @Player_GetMaxMoveSpeed(this);
  static Float:vecVelocity[3]; pev(this, pev_velocity, vecVelocity);
  static Float:vecAngles[3]; pev(this, pev_angles, vecAngles);
  static Float:vecForward[3]; angle_vector(vecAngles, ANGLEVECTOR_FORWARD, vecForward);
  static Float:vecRight[3]; angle_vector(vecAngles, ANGLEVECTOR_RIGHT, vecRight);

  static Float:vecInput[3]; xs_vec_set(vecInput, 0.0, 0.0, 0.0);

  if (iButtons & IN_FORWARD) vecInput[0] += 1.0;
  if (iButtons & IN_BACK) vecInput[0] -= 1.0;
  if (iButtons & IN_MOVERIGHT) vecInput[1] += 1.0;
  if (iButtons & IN_MOVELEFT) vecInput[1] -= 1.0;

  static Float:vecMovementDir[3];

  for (new i = 0; i < 3; ++i) {
    vecMovementDir[i] = (vecForward[i] * vecInput[0]) + (vecRight[i] * vecInput[1]);
  }

  xs_vec_normalize(vecMovementDir, vecMovementDir);

  static Float:flSpeed; flSpeed = xs_vec_dot(vecVelocity, vecMovementDir);

  xs_vec_mul_scalar(vecMovementDir, floatmin(flSpeed, flMaxMoveSpeed), vecOut);
}

Float:@Player_GetMaxMoveSpeed(const &this) {
  static Float:flSpeed; pev(this, pev_maxspeed, flSpeed);

  if (pev(this, pev_flags) & FL_DUCKING) {
    flSpeed *= PLAYER_DUCKING_MULTIPLIER;
  }

  return flSpeed;  
}

@Player_SetClimbPrevention(const &this, bool:bValue) {
  new iPlayerFlags = pev(this, pev_iuser3);

  if (bValue) {
    iPlayerFlags |= PLAYER_PREVENT_CLIMB;
  } else {
    iPlayerFlags &= ~PLAYER_PREVENT_CLIMB;
  }

  set_pev(this, pev_iuser3, iPlayerFlags);
}

@Player_ClimbPreventionThink(const &this) {
  if (g_rgflPlayerReleaseClimbBlock[this] && g_rgflPlayerReleaseClimbBlock[this] <= g_flGameTime) {
    @Player_SetClimbPrevention(this, false);
    g_rgflPlayerReleaseClimbBlock[this] = 0.0;
  }
}

stock FixedUnsigned16(Float:flValue, iScale) {
  return clamp(floatround(flValue * iScale), 0, 0xFFFF);
}
