#if defined _pm_math_included
  #endinput
#endif

#define _pm_math_included

stock Float:ApproachAngle(Float:flTarget, Float:flValue, Float:flSpeed) {
    flTarget = UTIL_AngleMod(flTarget);
    flValue = UTIL_AngleMod(flValue);
    flSpeed = floatabs(flSpeed);

    static Float:flDelta; flDelta = flTarget - flValue;

    if (flDelta < -180.0) {
      flDelta += 360.0;
    } else if (flDelta > 180.0) {
      flDelta -= 360.0;
    }

    if (flDelta > flSpeed) {
      flValue += flSpeed;
    } else if (flDelta < -flSpeed) {
      flValue -= flSpeed;
    } else { 
      flValue = flTarget;
    }

    return flValue;

    // static Float:flDelta; flDelta = UTIL_AngleDiff(flTarget, flValue);

    // flValue += floatclamp(flDelta, -flSpeed, flSpeed);

    // return UTIL_AngleMod(flValue);
}

stock Float:UTIL_AngleDiff(Float:flDestAngle, Float:flSrcAngle) {
  static Float:flDelta; flDelta = flDestAngle - flSrcAngle;

  if (flDestAngle > flSrcAngle) {
    if (flDelta >= 180.0) {
      flDelta -= 360.0;
    }
  } else {
    if (flDelta <= -180.0) {
      flDelta += 360.0;
    }
  }

  return flDelta;
}

stock Float:Approach(Float:flTarget, Float:flValue, Float:flSpeed) {
  static Float:flDelta; flDelta = flTarget - flValue;

  return flValue + floatclamp(flDelta, -flSpeed, flSpeed);
}

stock UTIL_VecAccelerate(const Float:vecVelocity[3], const Float:vecDirection[3], Float:flSpeed, Float:flAccel, Float:flFriction, Float:vecOut[3]) {
  // static Float:flFrameTime; flFrameTime = 0.01;
  static Float:flFrameTime; global_get(glb_frametime, flFrameTime);

  static Float:flCurrSpeed; flCurrSpeed = xs_vec_dot(vecVelocity, vecDirection);

  static Float:flAddSpeed; flAddSpeed = flSpeed - flCurrSpeed;
  if (flAddSpeed <= 0) return;

  static Float:flAccelSpeed; flAccelSpeed = floatmin(flAccel * flFrameTime * flSpeed * flFriction, flAddSpeed);

  xs_vec_add_scaled(vecOut, vecDirection, flAccelSpeed, vecOut);
}

#define anglemod UTIL_AngleMod

stock Float:UTIL_AngleMod(Float:flAngle) {
  return (360.0/65536) * (floatround(flAngle * (65536.0/360.0), floatround_floor) & 65535);
}

stock NormalizeAngles(const Float:vecAngles[]) {
  // Normalize angles
  for (new i = 0; i < 3; i++) {
    if (vecAngles[i] > 180.0) {
      vecAngles[i] -= 360.0;
    } else if (vecAngles[i] < -180.0) {
      vecAngles[i] += 360.0;
    }
  }
}

stock AngleMatrix(const Float:vecAngles[3], Float:rgMatrix[3][4]) {
  static Float:cp; cp = floatcos(vecAngles[0], degrees);
  static Float:sp; sp = floatsin(vecAngles[0], degrees);
  static Float:cy; cy = floatcos(vecAngles[1], degrees);
  static Float:sy; sy = floatsin(vecAngles[1], degrees);
  static Float:cr; cr = floatcos(-vecAngles[2], degrees);
  static Float:sr; sr = floatsin(-vecAngles[2], degrees);
  static Float:crcy; crcy = cr * cy;
  static Float:crsy; crsy = cr * sy;
  static Float:srcy; srcy = sr * cy;
  static Float:srsy; srsy = sr * sy;

  // matrix = (YAW * PITCH) * ROLL

  rgMatrix[0][0] = cp * cy;
  rgMatrix[1][0] = cp * sy;
  rgMatrix[2][0] = -sp;

  rgMatrix[0][1] = (sp * srcy) + crsy;
  rgMatrix[1][1] = (sp * srsy) - crcy;
  rgMatrix[2][1] = sr * cp;

  rgMatrix[0][2] = (sp * crcy) - srsy;
  rgMatrix[1][2] = (sp * crsy) + srcy;
  rgMatrix[2][2] = cr * cp;

  rgMatrix[0][3] = 0.0;
  rgMatrix[1][3] = 0.0;
  rgMatrix[2][3] = 0.0;
}

stock V_swap(&Float:v1, &Float:v2) {
  static Float:tmp;
  tmp = v1;
  v1 = v2;
  v2 = tmp;
}

stock Float:Lerp(Float:flValue, Float:flTarget, Float:flTime) {
  return flValue + (flTarget - flValue) * flTime;
}

stock VecLerp(Float:vecValue[3], Float:vecTarget[3], Float:flTime, Float:vecOut[3]) {
	// flTime = floatclamp(flTime, 0.0, 1.0);
	vecOut[0] = vecValue[0] + (vecTarget[0] - vecValue[0]) * flTime;
	vecOut[1] = vecValue[1] + (vecTarget[1] - vecValue[1]) * flTime;
	vecOut[2] = vecValue[2] + (vecTarget[2] - vecValue[2]) * flTime;
}
