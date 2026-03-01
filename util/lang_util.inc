#if defined _lang_util_included
  #endinput
#endif

#define _lang_util_included

stock UTIL_CreateDictKey(const szValue[], const szPrefix[] = "", szOut[], iLen) {
  new iPos = 0;

  iPos += copy(szOut[iPos], iLen, szPrefix);

  for (new i = 0; szValue[i] != 0; ++i) {
    if (isalnum(szValue[i])) {
      szOut[iPos++] = char_to_upper(szValue[i]);
    } else if (szValue[i] == ' ') {
      szOut[iPos++] = '_';
    } else if (szValue[i] == '-') {
      szOut[iPos++] = '_';
    }
  }
}

stock UTIL_GetDictValue(szOut[], iMaxLength, const szKey[], const pPlayer) {
  if (!LookupLangKey(szOut, iMaxLength, szKey, pPlayer)) {
    return copy(szOut, iMaxLength, szKey);
  }

  static iPos; iPos = 0;
  while (szOut[iPos] != '^0' && iPos < iMaxLength) {
    iPos++;
  }

  return iPos;
}
