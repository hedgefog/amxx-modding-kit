#if defined _varargs_included
  #endinput
#endif

#define _varargs_included

#include <amxconst>

stock vararg_get_length() {
  #emit LCTRL 5
  #emit LOAD.I
  #emit ADD.C 8
  #emit LOAD.I
  #emit SHR.C.pri 2
  #emit RETN
  return 0;
}

stock any:vararg_get_raw(arg) {
  #emit LCTRL 5
  #emit LOAD.I
  #emit ADD.C 12
  #emit LOAD.S.alt arg
  #emit SHL.C.alt 2
  #emit ADD
  #emit LOAD.I
  #emit RETN

  return 0;
}

stock any:vararg_get(arg) {
  #emit LCTRL 5
  #emit LOAD.I
  #emit ADD.C 12
  #emit LOAD.S.alt arg
  #emit SHL.C.alt 2
  #emit ADD
  #emit LOAD.I
  #emit LOAD.I
  #emit RETN

  return 0;
}

stock vararg_set(arg, any:value) {
  #emit LCTRL 5
  #emit LOAD.I
  #emit ADD.C 12
  #emit LOAD.S.alt arg
  #emit SHL.C.alt 2
  #emit ADD
  #emit LOAD.I
  #emit MOVE.alt
  #emit LOAD.S.pri value
  #emit STOR.I
}

stock vararg_get_array(arg, any:dest[], size) {
  static i;
  new iInputAddr, iOutAddr;

  #emit ADDR.pri dest
  #emit LOAD.I
  #emit STOR.S.pri iOutAddr

  #emit LCTRL 5
  #emit LOAD.I
  #emit ADD.C 12
  #emit LOAD.S.alt arg
  #emit SHL.C.alt 2
  #emit ADD
  #emit LOAD.I
  #emit STOR.S.pri iInputAddr

  for (i = 0; i < size; ++i) {
    #emit LOAD.S.alt iInputAddr
    #emit LOAD.pri i
    #emit LIDX
    #emit PUSH.pri

    #emit LOAD.S.alt iOutAddr
    #emit LOAD.pri i
    #emit IDXADDR
    #emit MOVE.alt

    #emit POP.pri
    #emit STOR.I
  }

  return 1;
}

stock vararg_set_array(arg, const any:source[], size) {
  static i;
  new iOutAddr, iInputAddr;

  #emit ADDR.pri source
  #emit LOAD.I
  #emit STOR.S.pri iInputAddr

  #emit LCTRL 5
  #emit LOAD.I
  #emit ADD.C 12
  #emit LOAD.S.alt arg
  #emit SHL.C.alt 2
  #emit ADD
  #emit LOAD.I
  #emit STOR.S.pri iOutAddr

  for (i = 0; i < size; ++i) {
    #emit LOAD.S.alt iInputAddr
    #emit LOAD.pri i
    #emit LIDX
    #emit PUSH.pri

    #emit LOAD.S.alt iOutAddr
    #emit LOAD.pri i
    #emit IDXADDR
    #emit MOVE.alt

    #emit POP.pri
    #emit STOR.I
  }

  return 1;
}

stock vararg_get_string_length(arg) {
  static i, ch;
  new iAddr;

  #emit LCTRL 5
  #emit LOAD.I
  #emit ADD.C 12
  #emit LOAD.S.alt arg
  #emit SHL.C.alt 2
  #emit ADD
  #emit LOAD.I
  #emit STOR.S.pri iAddr

  for (i = 0; i <= MAX_STRING_LENGTH; ++i) {
    #emit LOAD.S.alt iAddr
    #emit LOAD.pri i
    #emit LIDX
    #emit STOR.pri ch

    if (ch == 0) return i;
  }

  return 0;
}

stock vararg_get_string(arg, dest[], maxlen) {
  static i, ch;
  new iInputAddr, iOutAddr;

  #emit ADDR.pri dest
  #emit LOAD.I
  #emit STOR.S.pri iOutAddr

  #emit LCTRL 5
  #emit LOAD.I
  #emit ADD.C 12
  #emit LOAD.S.alt arg
  #emit SHL.C.alt 2
  #emit ADD
  #emit LOAD.I
  #emit STOR.S.pri iInputAddr

  for (i = 0; i < maxlen - 1; ++i) {
    #emit LOAD.S.alt iInputAddr
    #emit LOAD.pri i
    #emit LIDX
    #emit PUSH.pri

    #emit LOAD.S.alt iOutAddr
    #emit LOAD.pri i
    #emit IDXADDR
    #emit MOVE.alt

    #emit POP.pri
    #emit STOR.I
    #emit STOR.pri ch

    if (ch == 0) break;
  }

  #emit LOAD.S.alt iOutAddr
  #emit LOAD.pri i
  #emit IDXADDR
  #emit MOVE.alt
  #emit CONST.pri 0
  #emit STOR.I

  return i;
}

stock vararg_set_string(arg, const source[], maxlen) {
  static i, ch;
  new iOutAddr, iInputAddr;

  #emit ADDR.pri source
  #emit LOAD.I
  #emit STOR.S.pri iInputAddr

  #emit LCTRL 5
  #emit LOAD.I
  #emit ADD.C 12
  #emit LOAD.S.alt arg
  #emit SHL.C.alt 2
  #emit ADD
  #emit LOAD.I
  #emit STOR.S.pri iOutAddr

  for (i = 0; i < maxlen - 1; ++i) {
    #emit LOAD.S.alt iInputAddr
    #emit LOAD.pri i
    #emit LIDX
    #emit PUSH.pri

    #emit LOAD.S.alt iOutAddr
    #emit LOAD.pri i
    #emit IDXADDR
    #emit MOVE.alt

    #emit POP.pri
    #emit STOR.I
    #emit STOR.pri ch

    if (ch == 0) break;
  }

  #emit LOAD.S.alt iOutAddr
  #emit LOAD.pri i
  #emit IDXADDR
  #emit MOVE.alt
  #emit CONST.pri 0
  #emit STOR.I

  return i;
}
