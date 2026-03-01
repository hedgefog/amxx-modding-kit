#if defined _callfunc_included
	#endinput
#endif

#define _callfunc_included

#include <amxmodx>

#if !defined CALLFUNC_BUFFER_SIZE
  #define CALLFUNC_BUFFER_SIZE 4096
#endif

#if !defined CALLFUNC_MAX_ARGUMENTS
  #define CALLFUNC_MAX_ARGUMENTS 32
#endif

enum CFP {
  CFP_Invalid = -1,
  CFP_Cell,
  CFP_String,
  CFP_Array,
  CFP_CellRef,
  CFP_StringRef,
  CFP_ArrayRef
};

enum __fncall_ArgHeader { CFP:__fncall_ArgHeader_Type, __fncall_ArgHeader_Size };

static stock any:__fncall_rgiTypes[CALLFUNC_MAX_ARGUMENTS];
static stock any:__fncall_rgiTypesSize[CALLFUNC_MAX_ARGUMENTS];
static stock __fncall_iTypesNum = 0;

public __callfunc__() {
  new void[1];
  callfunc_push_int(void[0]);
  callfunc_push_intrf(void[0]);
  callfunc_push_array(void, 0);
  callfunc_push_str(void);
}

stock callfunc_prepare_arg_types(any:...) {
  static i, iArgsNum;

  __fncall_iTypesNum = 0;

  #emit LCTRL 5
  #emit ADD.C 8
  #emit LOAD.I
  #emit SHR.C.pri 2  
  #emit STOR.pri iArgsNum

  for (i = 0; i < iArgsNum; ++i) {
    #emit CONST.pri __fncall_rgiTypes
    #emit MOVE.alt
    #emit LOAD.pri __fncall_iTypesNum
    #emit IDXADDR
    #emit MOVE.alt
    #emit PUSH.alt

    #emit LCTRL 5
    #emit ADD.C 12
    #emit LOAD.alt i
    #emit SHL.C.alt 2
    #emit ADD
    #emit LOAD.I
    #emit LOAD.I

    #emit POP.alt
    #emit STOR.I

    switch (__fncall_rgiTypes[__fncall_iTypesNum]) {
      case CFP_Array, CFP_ArrayRef, CFP_StringRef: {
        #emit CONST.pri __fncall_rgiTypesSize
        #emit MOVE.alt
        #emit LOAD.pri __fncall_iTypesNum
        #emit IDXADDR
        #emit MOVE.alt
        #emit PUSH.alt

        #emit LOAD.pri i
        #emit ADD.C 1
        #emit SHL.C.pri 2
        #emit MOVE.alt
        #emit LCTRL 5
        #emit ADD.C 12
        #emit ADD
        #emit LOAD.I
        #emit LOAD.I

        #emit POP.alt
        #emit STOR.I

        i++;
      }
    }

    __fncall_iTypesNum++;
  }
}

stock callfunc_set_arg_types(arg, CFP:type, size = 1) {
  __fncall_rgiTypes[arg] = type;
  __fncall_rgiTypesSize[arg] = size;

  if (__fncall_iTypesNum < arg + 1) {
    __fncall_iTypesNum = arg + 1;
  }
}

stock callfunc_push_arg_types(CFP:type, size = 1) {
  __fncall_rgiTypes[__fncall_iTypesNum] = type;
  __fncall_rgiTypesSize[__fncall_iTypesNum] = size;
  __fncall_iTypesNum++;
}

stock callfunc_call(func, plugin = -1, any:...) {
  static iFrameSize, iArgsNum, arg, bCopyback, iArraySize;
  new iArgAddr;

  callfunc_begin_i(func, plugin);

  // Get number of bytes in the method call frame
  #emit LCTRL 5
  #emit CONST.alt 8
  #emit ADD
  #emit LOAD.I
  #emit STOR.pri iFrameSize

  // Calculate number of arguments
  #emit LOAD.pri iFrameSize
  #emit SHR.C.pri 2
  #emit CONST.alt 2
  #emit SUB
  #emit STOR.pri iArgsNum

  // Get address of the first argument
  #emit LCTRL 5
  #emit CONST.alt 20
  #emit ADD
  #emit STOR.S.pri iArgAddr

  for (arg = 0; arg < iArgsNum; ++arg) {
    if (arg >= __fncall_iTypesNum) break;

    switch (__fncall_rgiTypes[arg]) {
      case CFP_Cell: {
        // Push Argument
        #emit LOAD.S.pri iArgAddr
        #emit LOAD.I
        #emit LOAD.I
        #emit PUSH.pri

        // Push number of argument bytes
        #emit PUSH.C 4

        // Call function
        #emit SYSREQ.C callfunc_push_int
        #emit STACK 8
      }
      case CFP_CellRef: {
        // Push Argument
        #emit LOAD.S.pri iArgAddr
        #emit LOAD.I
        #emit PUSH.pri

        // Push number of argument bytes
        #emit PUSH.C 4

        // Call function
        #emit SYSREQ.C callfunc_push_intrf
        #emit STACK 8
      }
      case CFP_String: {
        // Push "bCopyback" argument
        #emit PUSH.C 0

        // Push Argument
        #emit LOAD.S.pri iArgAddr
        #emit LOAD.I
        #emit PUSH.pri

        // Push number of argument bytes
        #emit PUSH.C 8

        // Call function
        #emit SYSREQ.C callfunc_push_str
        #emit STACK 12
      }
      case CFP_Array, CFP_ArrayRef, CFP_StringRef: {
        bCopyback = __fncall_rgiTypes[arg] != CFP_Array;
        iArraySize = __fncall_rgiTypesSize[arg];

        // Push "bCopyback" argument
        #emit LOAD.pri bCopyback
        #emit PUSH.pri

        // Push "array_size" argument
        #emit LOAD.pri iArraySize
        #emit PUSH.pri

        // Push Argument
        #emit LOAD.S.pri iArgAddr
        #emit LOAD.I
        #emit PUSH.pri

        // Push number of argument bytes
        #emit PUSH.C 12

        // Call function
        #emit SYSREQ.C callfunc_push_array
        #emit STACK 16
      }
      default: {
        abort(AMX_ERR_PARAMS, "NOT SUPPORTED TYPE");
      }
    }

    #emit LOAD.S.pri iArgAddr
    #emit CONST.alt 4
    #emit ADD
    #emit STOR.S.pri iArgAddr
  }

  return callfunc_end();
}
