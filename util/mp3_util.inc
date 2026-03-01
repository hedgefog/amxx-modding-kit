#if defined _mp3_util_included
  #endinput
#endif

#define _mp3_util_included

enum __mp3util_FrameHeader {
  Header_Version,
  Header_Layer,
  Header_HasCRC,
  Header_Bitrate_kbps,
  Header_Samplerate,
  Header_Padding,
  Header_ChannelMode
};

enum __mp3util_IDIdentifier {
  IDIdentifier_Invalid = -1,
  IDIdentifier_Title,
  IDIdentifier_Artist,
  IDIdentifier_Album,
  IDIdentifier_Year
};

stock bool:MP3_GetInfo(
  const szPath[],
  &Float:flDuration = 0.0,
  szTitle[] = "",
  iTitleMaxLen = 0,
  szArtist[] = "",
  iArtistMaxLen = 0,
  szAlbum[] = "",
  iAlbumMaxLen = 0,
  &iYear = 0
) {
  flDuration = 0.0;

  new pFile = fopen(szPath, "rb", true);

  if (!pFile) {
    pFile = fopen(szPath, "rb", true, "DEFAULTGAME");
  }

  if (!pFile) return false;

  new szType[4];
  fread_blocks(pFile, szType, charsmax(szType), BLOCK_BYTE);
  szType[3] = 0;

  // Skip ID3v2 header
  if (equal(szType, "ID3")) {
    new iMajorVersion; fread(pFile, iMajorVersion, BLOCK_BYTE);

    // Skip minor version
    fseek(pFile, BLOCK_BYTE, SEEK_CUR);

    new iHeaderFlags; fread(pFile, iHeaderFlags, BLOCK_BYTE);
    new iSize = __mp3util_ReadSynchSafe28(pFile);

    new iPosition = ftell(pFile);

    __mp3util__ReadID3v2Meta(pFile, iMajorVersion, iHeaderFlags, iSize, szTitle, iTitleMaxLen, szArtist, iArtistMaxLen, szAlbum, iAlbumMaxLen, iYear);

    fseek(pFile, iPosition + iSize, SEEK_SET);

    if (iHeaderFlags & 0x10 && iMajorVersion >= 4) {
      fseek(pFile, 10 * BLOCK_BYTE, SEEK_CUR);
    }
  }

  new rgHeader[__mp3util_FrameHeader];
  new iHeaderPos = __mp3util_FindFrameHeader(pFile, rgHeader);
  new iTotalSamples = 0;
  new iSampleRate = 0;

  if (iHeaderPos) {
    fseek(pFile, iHeaderPos, SEEK_SET);

    while (!feof(pFile)) {
      new iFramePos = ftell(pFile);

      if (!__mp3util_ParseFrameHeader(pFile, rgHeader)) {
        fseek(pFile, BLOCK_BYTE, SEEK_CUR);
        break;
      }

      if (feof(pFile)) break;

      new iBitrate = rgHeader[Header_Bitrate_kbps] * 1000;

      new iFrameSize = (
        rgHeader[Header_Version] == 1
          ? (144 * iBitrate) / rgHeader[Header_Samplerate] + rgHeader[Header_Padding]
          : (72 * iBitrate) / rgHeader[Header_Samplerate] + rgHeader[Header_Padding]
      );

      if (iFrameSize <= 0) break;

      iTotalSamples += (rgHeader[Header_Version] == 1) ? 1152 : 576;
      iSampleRate = rgHeader[Header_Samplerate];

      fseek(pFile, iFramePos + iFrameSize, SEEK_SET);
    }
  }

  fclose(pFile);

  if (iTotalSamples <= 0) return false;
  if (iSampleRate <= 0) return false;

  flDuration = float(iTotalSamples) / float(iSampleRate);

  return true;
}

static stock bool:__mp3util__ReadID3v2Meta(
  const pFile,
  iMajorVersion,
  iHeaderFlags,
  iTagSize,
  szTitle[],
  iTitleMaxLen,
  szArtist[],
  iArtistMaxLen,
  szAlbum[],
  iAlbumMaxLen,
  &iYear
) {
  szTitle[0]  = 0;
  szArtist[0] = 0;
  szAlbum[0]  = 0;

  new szYear[8];
  new iTagStart = ftell(pFile);
  new iTagEnd = iTagStart + iTagSize;

  // Extended header
  if (iMajorVersion > 2 && iHeaderFlags & 0x40) {
    new iExtSize = (iMajorVersion >= 4) ? __mp3util_ReadSynchSafe28(pFile) : __mp3util_ReadU32BE(pFile);
    if (iExtSize < 0 || (ftell(pFile) + iExtSize > iTagEnd)) return false;
    fseek(pFile, ftell(pFile) + iExtSize, SEEK_SET);
  }

  while (ftell(pFile) <= iTagEnd) {
    new id[5];
    new iFrameStart;
    new iFrameEnd;

    if (iMajorVersion > 2) {
      fread_blocks(pFile, id, 4, BLOCK_BYTE);
      id[4] = 0;

      if (!id[0] && !id[1] && !id[2] && !id[3]) break;

      new iFrameSize = ((iMajorVersion >= 4) ? __mp3util_ReadSynchSafe28(pFile) : __mp3util_ReadU32BE(pFile));

      fseek(pFile, BLOCK_BYTE, SEEK_CUR);

      new iFlag2;
      fread(pFile, iFlag2, BLOCK_BYTE);
      iFlag2 &= 0xFF;

      iFrameStart = ftell(pFile);
      iFrameEnd = iFrameStart + iFrameSize;

      if (iMajorVersion >= 4) {
        if (iFlag2 & 0x40) {
          fseek(pFile, BLOCK_BYTE, SEEK_CUR);
        }

        if ((iFlag2 & 0x04) || (iFlag2 & 0x08)) {
          fseek(pFile, iFrameEnd, SEEK_SET);
          continue;
        }

        if (iFlag2 & 0x01) {
          fseek(pFile, 4, SEEK_CUR);
        }
      } else if (iMajorVersion == 3) {
        if (iFlag2 & 0x80) {
          fseek(pFile, iFrameEnd, SEEK_SET);
          continue;
        }

        if (iFlag2 & 0x40) {
          fseek(pFile, iFrameEnd, SEEK_SET);
          continue;
        }

        if (iFlag2 & 0x20) {
          fseek(pFile, BLOCK_BYTE, SEEK_CUR);
        }
      }
    } else {
      fread_blocks(pFile, id, 3, BLOCK_BYTE);
      id[3] = 0;

      new s0, s1, s2;
      fread(pFile, s0, BLOCK_BYTE);
      fread(pFile, s1, BLOCK_BYTE);
      fread(pFile, s2, BLOCK_BYTE);

      iFrameStart = ftell(pFile);
      iFrameEnd = iFrameStart + ((s0 & 0xFF) << 16) | ((s1 & 0xFF) << 8) | (s2 & 0xFF);
    }

    if (iFrameEnd <= iFrameStart) break;
    if (iFrameEnd > iTagEnd) break;

    new iMaxLength = iFrameEnd - ftell(pFile);
    if (iMaxLength <= 0) break;

    new __mp3util_IDIdentifier:iClass = __mp3util_ResolveIDIdentifier(id, iMajorVersion);

    if (iClass != IDIdentifier_Invalid) {
      new iEncoding; fread(pFile, iEncoding, BLOCK_BYTE);

      switch (iClass) {
        case IDIdentifier_Title: __mp3util_ReadTextPayload(pFile, iEncoding, iMaxLength - 1, szTitle, iTitleMaxLen);
        case IDIdentifier_Artist: __mp3util_ReadTextPayload(pFile, iEncoding, iMaxLength - 1, szArtist, iArtistMaxLen);
        case IDIdentifier_Album: __mp3util_ReadTextPayload(pFile, iEncoding, iMaxLength - 1, szAlbum, iAlbumMaxLen);
        case IDIdentifier_Year: __mp3util_ReadTextPayload(pFile, iEncoding, iMaxLength - 1, szYear, charsmax(szYear));
        default: fseek(pFile, iFrameEnd, SEEK_SET);
      }
    } else {
      fseek(pFile, iFrameEnd, SEEK_SET);
    }

    if (szTitle[0] && szArtist[0] && szAlbum[0] && szYear[0]) break;
  }

  iYear = szYear[0] ? str_to_num(szYear) : 0;

  return (szTitle[0] || szArtist[0] || szAlbum[0] || szYear[0]);
}

static stock bool:__mp3util_ReadTextPayload(const pFile, iEncoding, iPayloadBytes, szOut[], iMaxLen) {
  if (iPayloadBytes <= 0) {
    szOut[0] = 0;
    return false;
  }

  new iPayloadStart = ftell(pFile);

  if (iEncoding == 0 || iEncoding == 3) {
    new iSize = min(iPayloadBytes, iMaxLen - 1);

    fread_blocks(pFile, szOut, iSize, BLOCK_BYTE);
    szOut[iSize] = 0;

    for (new i = 0; szOut[i]; i++) {
      if (szOut[i] < 32) {
        szOut[i] = (szOut[i] == '^t' || szOut[i] == ' ') ? ' ' : 0;
      }
    }

    fseek(pFile, iPayloadStart + iPayloadBytes, SEEK_SET);
    return (szOut[0] != 0);
  }

  new szBuffer[256];
  new n = min(iPayloadBytes, sizeof(szBuffer));

  fread_blocks(pFile, szBuffer, n, BLOCK_BYTE);

  new iPos = 0;
  new bigEndian = false;

  switch (iEncoding) {
    case 1: {
      if (n >= 2) {
        if (szBuffer[0] == 0xFE && szBuffer[1] == 0xFF) {
          bigEndian=true;
          iPos = 2;
        } else if (szBuffer[0] == 0xFF && szBuffer[1] == 0xFE) {
          bigEndian=false;
          iPos = 2;
        }
      }
    }
    case 2: {
      bigEndian = true;
    }
  }

  new iOutPos = 0;
  while (iPos < n - 1 && iOutPos < iMaxLen - 1) {
    new hi = szBuffer[iPos] & 0xFF;
    new lo = szBuffer[iPos + 1] & 0xFF;
    new ch = bigEndian ? ((hi << 8) | lo) : ((lo << 8) | hi);

    if (!ch) break;

    szOut[iOutPos++] = (ch < 128) ? ch : '?';
    iPos += 2;
  }

  szOut[iOutPos] = 0;

  fseek(pFile, iPayloadStart + iPayloadBytes, SEEK_SET);

  return (szOut[0] != 0);
}

static stock __mp3util_FindFrameHeader(const &pFile, rgHeader[__mp3util_FrameHeader]) {
  while (!feof(pFile)) {
    new iHeaderPos = ftell(pFile);

    new iFirstByte; fread(pFile, iFirstByte, BLOCK_BYTE);
    if (feof(pFile)) return 0;

    new iSecondByte; fread(pFile, iSecondByte, BLOCK_BYTE);
    if (feof(pFile)) return 0;

    if ((iFirstByte & 0xFF) == 0xFF && ((iSecondByte & 0xFF) & 0xE0) == 0xE0) {
      fseek(pFile, iHeaderPos, SEEK_SET);

      if (__mp3util_ParseFrameHeader(pFile, rgHeader)) return iHeaderPos;
    }

    fseek(pFile, iHeaderPos + BLOCK_BYTE, SEEK_SET);
  }

  return 0;
}

static stock bool:__mp3util_ParseFrameHeader(const &pFile, rgHeader[__mp3util_FrameHeader]){
  static const bitrateTable[2][16] = {
    { 0, 32, 40, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320, 0 },
    { 0, 8, 16, 24, 32, 40, 48, 56, 64, 80, 96, 112, 128, 144, 160, 0 }
  };

  new x = __mp3util_ReadU32BE(pFile);
  if ((x & 0xFFE00000) != 0xFFE00000) return false;

  new iVersion = (x >> 19) & 0x3;
  new iLayer = (x >> 17) & 0x3;
  new iCRC = (x >> 16) & 0x1;
  new iBitrateIndex = (x >> 12) & 0xF;
  new iSampleRateIndex = (x >> 10) & 0x3;
  new iPadding  = (x >> 9) & 0x1;
  new iChannelMode  = (x >> 6) & 0x3;

  if (iVersion == 1) return false;

  new iMajorVersion = (iVersion==3) ? 1: (iVersion == 2 ? 2 : 25);
  new iLayerMap = (iLayer==1) ? 1 : (iLayer == 2 ? 2 : (iLayer == 3 ? 3 : 0));

  if (iLayerMap==0) return false;
  if (iSampleRateIndex==3) return false;

  new iSampleRate = 0;

  switch (iSampleRateIndex) {
    case 0: iSampleRate = 44100;
    case 1: iSampleRate = 48000;
    case 2: iSampleRate = 32000;
  }

  if (iMajorVersion == 2) {
    iSampleRate /= 2;
  } else if (iMajorVersion == 25) {
    iSampleRate /= 4;
  }

  if (iSampleRate == 0) return false;
  if (iLayerMap != 1) return false;

  new iBitrate = 0;
  if (iBitrateIndex != 0 && iBitrateIndex != 15){
    iBitrate = bitrateTable[iMajorVersion == 1 ? 0 : 1][iBitrateIndex];
  }

  if (iBitrate == 0) return false;

  rgHeader[Header_Version] = iMajorVersion;
  rgHeader[Header_Layer] = iLayerMap;
  rgHeader[Header_HasCRC] = (iCRC == 0);
  rgHeader[Header_Bitrate_kbps] = iBitrate;
  rgHeader[Header_Samplerate] = iSampleRate;
  rgHeader[Header_Padding] = iPadding;
  rgHeader[Header_ChannelMode] = iChannelMode;

  return true;
}

static stock __mp3util_ReadSynchSafe28(const &pFile) {
  new b0, b1, b2, b3;
  fread(pFile, b0, BLOCK_BYTE);
  fread(pFile, b1, BLOCK_BYTE);
  fread(pFile, b2, BLOCK_BYTE);
  fread(pFile, b3, BLOCK_BYTE);

  return (b0 << 21) | (b1 << 14) | (b2 << 7) | b3;
}

static stock __mp3util_ReadU32BE(const &pFile) {
  new b0, b1, b2, b3;
  fread(pFile, b0, BLOCK_BYTE);
  fread(pFile, b1, BLOCK_BYTE);
  fread(pFile, b2, BLOCK_BYTE);
  fread(pFile, b3, BLOCK_BYTE);

  return ((b0 & 0xFF) << 24) | ((b1 & 0xFF) << 16) | ((b2 & 0xFF) << 8) | (b3 & 0xFF);
}

static stock __mp3util_IDIdentifier:__mp3util_ResolveIDIdentifier(const szId[], const iVersion) {
  switch (szId[0]) {
    case 'T': {
      if (iVersion < 3) {
        if (equal(szId[1], "T2")) return IDIdentifier_Title;
        if (equal(szId[1], "P1")) return IDIdentifier_Artist;
        if (equal(szId[1], "AL")) return IDIdentifier_Album;
        if (equal(szId[1], "YE")) return IDIdentifier_Year;
      } else {
        if (equal(szId[1], "IT2")) return IDIdentifier_Title;
        if (equal(szId[1], "PE1")) return IDIdentifier_Artist;
        if (equal(szId[1], "ALB")) return IDIdentifier_Album;
        if (equal(szId[1], "YER")) return IDIdentifier_Year;
        if (equal(szId[1], "DRC")) return IDIdentifier_Year;
      }
    }
  }

  return IDIdentifier_Invalid;
}
