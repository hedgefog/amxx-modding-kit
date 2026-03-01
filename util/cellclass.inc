#if defined _classes_included
  #endinput
#endif

#define _classes_included

// #define __cls_DEBUG

#include <amxmodx>
#include <cellstruct>
#include <function_pointer>

#if !defined CLASS_METHOD_CALL_STACK_SIZE
  #define CLASS_METHOD_CALL_STACK_SIZE 1024
#endif

#if !defined CLASS_METHOD_MAX_NAME_LENGTH
  #define CLASS_METHOD_MAX_NAME_LENGTH 64
#endif

#if !defined CLASS_METHOD_MAX_ARGUMENTS
  #define CLASS_METHOD_MAX_ARGUMENTS 32
#endif

#if !defined CLASS_CALL_BUFFER_SIZE
  #define CLASS_CALL_BUFFER_SIZE 16384
#endif

#if !defined CLASS_METHODS_CACHE_SIZE
  #define CLASS_METHODS_CACHE_SIZE 64
#endif

#if !defined CLASS_CACHE_SIZE
  #define CLASS_CACHE_SIZE 128
#endif

#if !defined CLASS_INSTANCE_CACHE_SIZE
  #define CLASS_INSTANCE_CACHE_SIZE 2048
#endif

// Default argument values

#define __cls_LOG_ERROR(%1,%0) log_amx(" ERROR! " + %1, %0)

#define __cls_DefaultValue_Cell 0
#define __cls_DefaultValue_String NULL_STRING

#define __cls_MethodParamOffset(%1) (%1 * _:__cls_MethodParamData)

#define __cls_MAX_CALLS_NUM_RECORD 0xffff
#define __cls_MIN_CALLS_TO_CACHE 0xff

#define __cls_MIN(%1,%2) %1 < %2 ? %1 : %2
#define __cls_MAX(%1,%2) %1 > %2 ? %1 : %2
#define __cls_CLEAR_STR(%1) %1 [0] = 0
#define __cls_IS_EMPTY_STR(%1) %1[0] == 0

enum Class {
  Invalid_Class = _:Invalid_Struct
};

enum ClassInstance {
  Invalid_ClassInstance = _:Invalid_Struct
};

enum ClassDataType {
  ClassDataType_Invalid = -1,
  ClassDataType_Cell,
  ClassDataType_String,
  ClassDataType_Array,

  //! Reference types are unstable, use them at your own risk
  ClassDataType_CellRef,
  ClassDataType_StringRef,
  ClassDataType_ArrayRef,

  ClassDataType_ParamsCellArray,
  ClassDataType_Variadic
};


// Internal structures

enum __cls_InternalMethod {
  __cls_InternalMethod_Constructor = 0,
  __cls_InternalMethod_Destructor
};

enum __cls_MethodType {
  __cls_MethodType_Invalid = -1,
  __cls_MethodType_Method,
  __cls_MethodType_Virtual,
  // __cls_MethodType_Getter,
  // __cls_MethodType_Setter
};

enum __cls_Data {
  __cls_Data_Invalid = -1,
  Class:__cls_Data_Base,
  __cls_Data_InternalMethods[__cls_InternalMethod],
  Trie:__cls_Data_Members,
  Trie:__cls_Data_Methods,
  __cls_Data_RootClass,
  __cls_Data_RootClassDepth,
  // Trie:__cls_Data_Setters,
  // Trie:__cls_Data_Getters
};

enum __cls_MethodParamData {
  ClassDataType:__cls_MethodParamData_Type = 0,
  __cls_MethodParamData_Size
};

enum __cls_MethodData {
  __cls_MethodData_Name[CLASS_METHOD_MAX_NAME_LENGTH],
  Class:__cls_MethodData_Class,
  __cls_MethodData_Function,
  __cls_MethodData_VariadicParams,
  __cls_MethodType:__cls_MethodData_Type,
  __cls_MethodData_ParamTypesNum,
  __cls_MethodData_CallsNum,
  __cls_MethodData_ParamTypes[__cls_MethodParamOffset(CLASS_METHOD_MAX_ARGUMENTS + 1)]
};

enum __cls_RefType {
  __cls_RefType_None,
  __cls_RefType_Arg,
  __cls_RefType_NativeArg
}

enum __cls_InstanceData {
  Class:__cls_InstanceData_Class,
  Trie:__cls_InstanceData_Members
};

enum __cls_InstanceCache {
  ClassInstance:__cls_InstanceCache_Instance,
  any:__cls_InstanceCache_Value
};

// Error messages
#define __cls_err_NotImplementedMethod "Method ^"%s^" is not implemented!"
#define __cls_err_AddMethodWithoutFunctionPointer "Cannot add unimplemented method ^"%s^"!"
#define __cls_err_MethodAlreadyRegistered "Method ^"%s^" is already registered for the class!"
#define __cls_err_VMethodArgumentsMismatch "Arguments mismatch in the overridden virtual method ^"%s^"! Expected %d, got %d."
#define __cls_err_ClassIdNotFound "Class with id %d is not registered!"
#define __cls_err_MethodNotFound "Method ^"%s^" is not registered for the instance (%d)!"
#define __cls_err_CallMethodOutsideContext "Calling a method is not allowed outside of the execution context!"
#define __cls_err_ClassHasNoBaseClass "Cannot call base method of class without base class!"
// #define __cls_err_MethodNotFoundInBaseClass "Cannot find method ^"%s^" in base class!"
#define __cls_err_MaxCallStackSizeExceeded "Maximum call stack size exceeded!"
#define __cls_err_ClassMethodCallEndWithoutStart "Call ClassInstanceCallMethodEnd but method call is not started!"
#define __cls_err_NumberOfParametersExceeded "Number of argument(s) to call ^"%s^" exceeded! Expected %d, got %d."
#define __cls_err_MissingRequiredArguments "Missing required argument(s) to call ^"%s^"! Expected %d, got %d."
#define __cls_err_InvalidParamType "Invalid parameter type at position %d for call method %s. Expected: ^"%s^" got ^"%s^"!"
#define __cls_err_FailedToCallMethodFunction "Failed to call method ^"%s^" function!"
#define __cls_err_CannotForkNotRelatedDifferentBaseClass "Cannot fork class with base class not related to original base class."

stock const __cls_ParamTypeNames[ClassDataType][64] = {
  "Cell",
  "String",
  "Array",
  "CellRef",
  "StringRef",
  "ArrayRef",
  "ParamsCellArray",
  "..."
};

// Fast pseudo-stack implementation
static stock Class:__cls_callstack_class[CLASS_METHOD_CALL_STACK_SIZE];
static stock ClassInstance:__cls_callstack_pInstance[CLASS_METHOD_CALL_STACK_SIZE];
static stock Struct:__cls_callstack_sMethod[CLASS_METHOD_CALL_STACK_SIZE];
static stock __cls_callstack_iBufferPos[CLASS_METHOD_CALL_STACK_SIZE];
static stock __cls_callstack_iLastRefArg[CLASS_METHOD_CALL_STACK_SIZE];
static stock __cls_callstack_size = 0;

// Variables to store info between Begin and End method calls
static stock Class:__cls_call_class = Invalid_Class;
static stock ClassInstance:__cls_call_pInstance = Invalid_ClassInstance;
static stock Struct:__cls_call_sMethod = Invalid_Struct;
static stock __cls_call_iBufferPos = 0;
static stock __cls_call_iLastRefArg = -1;
static stock __cls_call_iParamTypesNum = 0;
static stock __cls_call_iRequiredParamsNum = 0;
static stock __cls_call_iParamsNum = 0;

// Cache
static stock __cls_cache_InstanceClass[__cls_InstanceCache] = { Invalid_ClassInstance, Invalid_Class };
// static stock __cls_cache_InstanceMethods[__cls_InstanceCache] = { Invalid_ClassInstance, Invalid_Trie };
static stock __cls_cache_InstanceMembers[__cls_InstanceCache] = { Invalid_ClassInstance, Invalid_Trie };
// static stock __cls_cache_InstanceGetters[__cls_InstanceCache] = { Invalid_ClassInstance, Invalid_Trie };
// static stock __cls_cache_InstanceSetters[__cls_InstanceCache] = { Invalid_ClassInstance, Invalid_Trie };

// Buffer used to store native calls arguments
static stock any:__cls_rgBuffer[CLASS_CALL_BUFFER_SIZE];
static stock __cls_iBufferSize = 0;

static stock __cls_rgCachedMethods[CLASS_METHODS_CACHE_SIZE][__cls_MethodData];
static stock Struct:__cls_rgCachedMethodPointers[CLASS_METHODS_CACHE_SIZE];
static stock __cls_iCachedMethodsNum = 0;
static stock __cls_iCallsNumRecord = 0;
static stock __cls_iCallsToCache = 0;

static stock __cls_rgCachedClasses[CLASS_CACHE_SIZE][__cls_Data];
static stock Struct:__cls_rgCachedClassPointers[CLASS_CACHE_SIZE];
static stock __cls_iCachedClassesNum = 0;

static stock __cls_rgCachedClassInstances[CLASS_INSTANCE_CACHE_SIZE][__cls_InstanceData];
static stock Struct:__cls_rgCachedClassInstancePointers[CLASS_INSTANCE_CACHE_SIZE] = { Invalid_Struct, ... };

public __cls__() {
  new void[1];
  callfunc_push_int(void[0]);
  callfunc_push_intrf(void[0]);
  callfunc_push_array(void, 0);
  callfunc_push_str(void);
}

/*--------------------------------[ Internal Preprocessor Functions] --------------------------------*/

#define __cls_IS_CACHED_HANDLE(%1) (_:%1 < _:Invalid_Struct)
#define __cls_HANDLE_TO_CACHE_INDEX(%1) (-(_:%1 + 1) + _:Invalid_Struct)
#define __cls_CACHE_INDEX_TO_HANDLE(%1) any:(-(%1 - _:Invalid_Struct) - 1)

#define __cls_RESOLVE_CLASS_POINTER(%1) (\
  __cls_IS_CACHED_HANDLE(%1)\
    ? __cls_rgCachedClassPointers[__cls_HANDLE_TO_CACHE_INDEX(%1)]\
    : Struct:%1\
)

#define __cls_RESOLVE_METHOD_POINTER(%1) (\
  __cls_IS_CACHED_HANDLE(%1)\
    ? __cls_rgCachedMethodPointers[__cls_HANDLE_TO_CACHE_INDEX(%1)]\
    : Struct:%1\
)

#define __cls_GET_CLASS_DATA(%1,%2) any:(\
  __cls_IS_CACHED_HANDLE(%1)\
    ? __cls_rgCachedClasses[__cls_HANDLE_TO_CACHE_INDEX(%1)][%2]\
    : StructGetCell(Struct:%1, %2)\
)

#define __cls_GET_CLASS_DATA_NESTED(%1,%2,%3) any:(\
  __cls_IS_CACHED_HANDLE(%1)\
    ? __cls_rgCachedClasses[__cls_HANDLE_TO_CACHE_INDEX(%1)][%2][%3]\
    : StructGetCell(Struct:%1, %2, %3)\
)

#define __cls_SET_CLASS_DATA(%1,%2,%3) \
  if (__cls_IS_CACHED_HANDLE(%1)) {\
    __cls_rgCachedClasses[__cls_HANDLE_TO_CACHE_INDEX(%1)][%2] = %3;\
    StructSetCell(__cls_rgCachedClassPointers[__cls_HANDLE_TO_CACHE_INDEX(%1)], %2, %3);\
  } else StructSetCell(Struct:%1, %2, %3)

#define __cls_GET_INSTANCE_DATA(%1,%2) any:(\
  __cls_IS_CACHED_HANDLE(%1)\
    ? __cls_rgCachedClassInstances[__cls_HANDLE_TO_CACHE_INDEX(%1)][%2]\
    : StructGetCell(Struct:%1, %2)\
)

#define __cls_SET_INSTANCE_DATA(%1,%2,%3) \
  if (__cls_IS_CACHED_HANDLE(%1)) {\
    __cls_rgCachedClassInstances[__cls_HANDLE_TO_CACHE_INDEX(%1)][%2] = %3;\
    StructSetCell(__cls_rgCachedClassInstancePointers[__cls_HANDLE_TO_CACHE_INDEX(%1)], %2, %3);\
  } else StructSetCell(Struct:%1, %2, %3)

#define __cls_GET_METHOD_NAME(%1,%2)\
  if (__cls_IS_CACHED_HANDLE(%1))\
    copy(%2, charsmax(%2), __cls_rgCachedMethods[__cls_HANDLE_TO_CACHE_INDEX(%1)][__cls_MethodData_Name]);\
  else\
    StructGetString(Struct:%1, __cls_MethodData_Name, %2, charsmax(%2))

#define __cls_GET_METHOD_DATA(%1,%2) any:(\
  __cls_IS_CACHED_HANDLE(%1)\
    ? __cls_rgCachedMethods[__cls_HANDLE_TO_CACHE_INDEX(%1)][%2]\
    : StructGetCell(Struct:%1, %2)\
)

#define __cls_SET_METHOD_DATA(%1,%2,%3) \
  if (__cls_IS_CACHED_HANDLE(%1)) __cls_rgCachedMethods[__cls_HANDLE_TO_CACHE_INDEX(%1)][%2] = %3;\
  else StructSetCell(%1, %2, %3)

#define __cls_GET_METHOD_PARAM_TYPE(%1,%2) ClassDataType:(\
  __cls_IS_CACHED_HANDLE(%1)\
    ? __cls_rgCachedMethods[__cls_HANDLE_TO_CACHE_INDEX(%1)][__cls_MethodData_ParamTypes][(__cls_MethodParamOffset(%2) + _:__cls_MethodParamData_Type)]\
    : StructGetCell(Struct:%1, __cls_MethodData_ParamTypes, (__cls_MethodParamOffset(%2) + _:__cls_MethodParamData_Type))\
)

#define __cls_GET_METHOD_PARAM_SIZE(%1,%2) (\
  __cls_IS_CACHED_HANDLE(%1)\
    ? __cls_rgCachedMethods[__cls_HANDLE_TO_CACHE_INDEX(%1)][__cls_MethodData_ParamTypes][(__cls_MethodParamOffset(%2) + _:__cls_MethodParamData_Size)]\
    : StructGetCell(Struct:%1, __cls_MethodData_ParamTypes, (__cls_MethodParamOffset(%2) + _:__cls_MethodParamData_Size))\
)

#define __cls_IS_REF_TYPE(%1) (%1 == ClassDataType_CellRef || %1 == ClassDataType_ArrayRef || %1 == ClassDataType_StringRef)

#define __cls_BUFFER_WRITE_REF_HEADER(%1,%2)\
  __cls_rgBuffer[__cls_iBufferSize++] = %1;\
  __cls_rgBuffer[__cls_iBufferSize++] = %2

#define __cls_BUFFER_READ_REF_HEADER(%1,%2,%3)\
  %2 = __cls_rgBuffer[%1++];\
  %3 = __cls_rgBuffer[%1++]

#define __cls_CALLSTACK_PUSH() {\
  if (__cls_callstack_size >= CLASS_METHOD_CALL_STACK_SIZE) set_fail_state(__cls_err_MaxCallStackSizeExceeded);\
\
  __cls_callstack_class[__cls_callstack_size] = __cls_call_class;\
  __cls_callstack_pInstance[__cls_callstack_size] = any:__cls_call_pInstance;\
  __cls_callstack_sMethod[__cls_callstack_size] = any:__cls_call_sMethod;\
  __cls_callstack_iBufferPos[__cls_callstack_size] = __cls_call_iBufferPos;\
  __cls_callstack_iLastRefArg[__cls_callstack_size] = __cls_call_iLastRefArg;\
\
  __cls_callstack_size++;\
}

#define __cls_CALLSTACK_POP() {\
  __cls_callstack_size--;\
\
  if (__cls_callstack_size) {\
    static iLastItem; iLastItem = __cls_callstack_size - 1;\
\
    __cls_call_class = __cls_callstack_class[iLastItem];\
    __cls_call_pInstance = __cls_callstack_pInstance[iLastItem];\
    __cls_call_sMethod = __cls_callstack_sMethod[iLastItem];\
    __cls_call_iBufferPos = __cls_callstack_iBufferPos[iLastItem];\
    __cls_call_iLastRefArg = __cls_callstack_iLastRefArg[iLastItem];\
  }\
}

/*--------------------------------[ Class Functions] --------------------------------*/

stock Class:ClassCreate(const &Class:cBase = Invalid_Class) {
  new Struct:class = StructCreate(__cls_Data);
  StructSetCell(class, __cls_Data_Base, cBase);
  StructSetCell(class, __cls_Data_Members, Invalid_Trie);
  StructSetCell(class, __cls_Data_Methods, Invalid_Trie);
  // StructSetCell(class, __cls_Data_Setters, Invalid_Trie);
  // StructSetCell(class, __cls_Data_Getters, Invalid_Trie);

  if (cBase != Invalid_Class) {
    StructSetCell(class, __cls_Data_RootClass, __cls_GET_CLASS_DATA(cBase, __cls_Data_RootClass));
    StructSetCell(class, __cls_Data_RootClassDepth, __cls_GET_CLASS_DATA(cBase, __cls_Data_RootClassDepth) + 1);
  } else {
    StructSetCell(class, __cls_Data_RootClass, Invalid_Class);
    StructSetCell(class, __cls_Data_RootClassDepth, 0);
  }

  for (new __cls_InternalMethod:iInternalMethod = __cls_InternalMethod:0; iInternalMethod < __cls_InternalMethod; ++iInternalMethod) {
    StructSetCell(Struct:class, __cls_Data_InternalMethods, Invalid_Struct, iInternalMethod);
  }

  return Class:class;
}

stock Class:ClassFork(const &Class:class, const &Class:cBase) {
  new Class:cOriginalBaseClass = ClassGetBaseClass(class);
  if (cOriginalBaseClass != Invalid_Class && !ClassIs(cBase, cOriginalBaseClass)) {
    set_fail_state(__cls_err_CannotForkNotRelatedDifferentBaseClass);
    return Invalid_Class;
  }

  new Class:cNewClass = ClassCreate(cBase);

  new Trie:itMethods = __cls_GET_CLASS_DATA(class, __cls_Data_Methods);
  new Trie:itMembers = __cls_GET_CLASS_DATA(class, __cls_Data_Members);

  __cls_SET_CLASS_DATA(cNewClass, __cls_Data_Methods, __cls_CloneClassMethodsTrie(itMethods, cNewClass));
  __cls_SET_CLASS_DATA(cNewClass, __cls_Data_Members, __cls_CloneClassMembersTrie(itMembers, cNewClass));

  return cNewClass;
}

stock Trie:__cls_CloneClassMethodsTrie(const &Trie:itMethods, const &Class:class) {
  if (itMethods == Invalid_Trie) return Invalid_Trie;

  new Trie:itMethodsCopy = TrieCreate();

  new TrieIter:iMethodsIter = TrieIterCreate(itMethods);

  while (!TrieIterEnded(iMethodsIter)) {
    new szMethod[CLASS_METHOD_MAX_NAME_LENGTH]; TrieIterGetKey(iMethodsIter, szMethod, charsmax(szMethod));
    new Struct:sMethod; TrieIterGetCell(iMethodsIter, sMethod);

    new Function:func = __cls_GET_METHOD_DATA(sMethod, __cls_MethodData_Function);
    new __cls_MethodType:iType = __cls_GET_METHOD_DATA(sMethod, __cls_MethodData_Type);
    new bool:bVariadicParams = __cls_GET_METHOD_DATA(sMethod, __cls_MethodData_VariadicParams);

    new Array:irgParamTypes; irgParamTypes = ArrayCreate(_:__cls_MethodParamData, __cls_GET_METHOD_DATA(sMethod, __cls_MethodData_ParamTypesNum));
    new iParamTypesNum = __cls_GET_METHOD_DATA(sMethod, __cls_MethodData_ParamTypesNum);

    for (new iParam = 0; iParam < iParamTypesNum; ++iParam) {
      new rgParam[__cls_MethodParamData];
      rgParam[__cls_MethodParamData_Type] = StructGetCell(sMethod, __cls_MethodData_ParamTypes, __cls_MethodParamOffset(iParam) + _:__cls_MethodParamData_Type);
      rgParam[__cls_MethodParamData_Size] = StructGetCell(sMethod, __cls_MethodData_ParamTypes, __cls_MethodParamOffset(iParam) + _:__cls_MethodParamData_Size);

      ArrayPushArray(irgParamTypes, rgParam[any:0], _:__cls_MethodParamData);
    }

    new Struct:sMethodCopy = __cls_CreateMethod(class, szMethod, func, irgParamTypes, iType, bVariadicParams);

    ArrayDestroy(irgParamTypes);

    TrieSetCell(itMethodsCopy, szMethod, sMethodCopy);

    TrieIterNext(iMethodsIter);
  }

  TrieIterDestroy(iMethodsIter);

  return itMethodsCopy;
}

stock Trie:__cls_CloneClassMembersTrie(const &Trie:itMembers, const &Class:class) {
  #pragma unused class
  if (itMembers == Invalid_Trie) return Invalid_Trie;

  new Trie:itMembersCopy = Invalid_Trie;

  // TODO: Implement. Probably not possible now, because there no way to clone celltrie or check field type.

  return itMembersCopy;
}

stock ClassDestroy(&Class:class) {
  if (__cls_IS_CACHED_HANDLE(class)) {
    // Cached classes have their own methods trie, so destroy original trie before destroying methods

    new Class:cReal = Class:__cls_rgCachedClassPointers[__cls_HANDLE_TO_CACHE_INDEX(class)];

    new Trie:itMethods = __cls_GET_CLASS_DATA(cReal, __cls_Data_Methods);
    if (itMethods != Invalid_Trie) {
      TrieDestroy(itMethods);
    }
  }

  new Trie:itMethods = __cls_GET_CLASS_DATA(class, __cls_Data_Methods);

  if (itMethods != Invalid_Trie) {
    __cls_DestroyMethodsTrie(itMethods);
  }

  // new Trie:itGetters = StructGetCell(Struct:class, __cls_Data_Getters);
  // if (itGetters != Invalid_Trie) {
  //   __cls_DestroyMethodsTrie(itGetters);
  // }

  // new Trie:itSetters = StructGetCell(Struct:class, __cls_Data_Setters);
  // if (itSetters != Invalid_Trie) {
  //   __cls_DestroyMethodsTrie(itSetters);
  // }

  new Trie:itMembers = __cls_GET_CLASS_DATA(class, __cls_Data_Members);
  if (itMembers != Invalid_Trie) {
    TrieDestroy(itMembers);
  }

  for (new __cls_InternalMethod:iInternalMethod = __cls_InternalMethod:0; iInternalMethod < __cls_InternalMethod; ++iInternalMethod) {
    new Struct:sMethod = __cls_GET_CLASS_DATA_NESTED(class, __cls_Data_InternalMethods, iInternalMethod);
    if (sMethod == Invalid_Struct) continue;
    __cls_DestroyMethod(sMethod);
  }

  new Struct:sClass = __cls_RESOLVE_CLASS_POINTER(class);
  StructDestroy(sClass);

  class = Invalid_Class;
}

stock ClassDefineConstructor(const &Class:class, const Function:func) {
  new Struct:sMethod = __cls_CreateMethod(class, "CONSTRUCTOR", func);
  StructSetCell(Struct:class, __cls_Data_InternalMethods, sMethod, __cls_InternalMethod_Constructor);
}

stock ClassDefineDestructor(const &Class:class, const Function:func) {
  new Struct:sMethod = __cls_CreateMethod(class, "DESTRUCTOR", func);
  StructSetCell(Struct:class, __cls_Data_InternalMethods, sMethod, __cls_InternalMethod_Destructor);
}

stock ClassDefineMethod(const &Class:class, const szMethod[], const Function:func, bool:bVirtual = false, {ClassDataType,Array,_}:...) {
  static const iArgOffset = 4;

  new iArgc = numargs();

  new Class:sBaseClass = __cls_GET_CLASS_DATA(class, __cls_Data_Base);
  new Trie:itMethods = __cls_GetClassMethodsTrie(class, true);

  if (TrieKeyExists(itMethods, szMethod)) {
    set_fail_state(__cls_err_MethodAlreadyRegistered, szMethod);
    return;
  }

  if (func == Invalid_FunctionPointer && !bVirtual) {
    set_fail_state(__cls_err_AddMethodWithoutFunctionPointer, szMethod);
    return;
  }

  new Array:irgArgs = ArrayCreate();
  new bool:bVariadicParams = false;

  // Some arguments are used to decribe type properties, so we need to skip type check for these arguments
  new bool:bSkipTypeCheck = false;

  for (new iArg = iArgOffset; iArg < iArgc; ++iArg) {
    new any:arg = getarg(iArg);

    if (!bSkipTypeCheck) {
      switch (arg) {
        case ClassDataType_Array, ClassDataType_ArrayRef, ClassDataType_StringRef, ClassDataType_ParamsCellArray: {
          bSkipTypeCheck = true;
        }
        case ClassDataType_Variadic: {
          iArgc = iArg;
          bVariadicParams = true;
          break;
        }
      }
    } else {
      bSkipTypeCheck = false;
    }

    ArrayPushCell(irgArgs, arg);
  }

  new Array:irgParamTypes; irgParamTypes = ArrayCreate(_:__cls_MethodParamData, iArgc - iArgOffset);
  __cls_ParseParamTypes(irgArgs, irgParamTypes);

  ArrayDestroy(irgArgs);

  if (sBaseClass != Invalid_Class) {
    new Struct:sBaseMethod = __cls_FindClassMethodInHierarchy(sBaseClass, szMethod, __cls_MethodType_Method);
    if (sBaseMethod != Invalid_Struct) {
      if (__cls_GET_METHOD_DATA(sBaseMethod, __cls_MethodData_Type) == __cls_MethodType_Virtual) {
        if (!__cls_CompareParamTypes(sBaseMethod, irgParamTypes)) {
          set_fail_state(__cls_err_VMethodArgumentsMismatch, szMethod, __cls_GET_METHOD_DATA(sBaseMethod, __cls_MethodData_ParamTypesNum), ArraySize(irgParamTypes));
          return;
        }
      }
    }
  }

  new Struct:sMethod = __cls_CreateMethod(class, szMethod, func, irgParamTypes, bVirtual ? __cls_MethodType_Virtual : __cls_MethodType_Method, bVariadicParams);

  ArrayDestroy(irgParamTypes);

  TrieSetCell(itMethods, szMethod, sMethod);

  // Used to store methods trie of the real or cached class
  new Trie:itMethodsCopy = Invalid_Trie;

  if (__cls_IS_CACHED_HANDLE(class)) {
    // Get methods trie from real class
    new Class:cReal = Class:__cls_rgCachedClassPointers[__cls_HANDLE_TO_CACHE_INDEX(class)];
    itMethodsCopy = __cls_GetClassMethodsTrie(cReal, true);
  } else {
    // Get methods trie from cached class
    new iCacheId = __cls_FindClassInCache(class);
    if (iCacheId != -1) {
      new Class:cCached = Class:__cls_CACHE_INDEX_TO_HANDLE(iCacheId);
      itMethodsCopy = __cls_GetClassMethodsTrie(cCached, true);
    }
  }

  if (itMethodsCopy != Invalid_Trie) {
    TrieSetCell(itMethodsCopy, szMethod, sMethod);
  }  
}

stock Function:ClassGetMethodFunction(const &Class:class, const szMethod[]) {
    static Trie:itMethods; itMethods = __cls_GetClassMethodsTrie(class, false);

    if (itMethods == Invalid_Trie) return Invalid_FunctionPointer;

    static Struct:sMethod;
    if (!TrieGetCell(itMethods, szMethod, sMethod)) return Invalid_FunctionPointer;

    return __cls_GET_METHOD_DATA(sMethod, __cls_MethodData_Function);
}

stock Struct:ClassGetMethodPointer(const &Class:class, const szMethod[]) {
    static Trie:itMethods; itMethods = __cls_GetClassMethodsTrie(class, false);

    if (itMethods == Invalid_Trie) return Invalid_Struct;

    static Struct:sMethod;
    if (!TrieGetCell(itMethods, szMethod, sMethod)) return Invalid_Struct;

    return sMethod;
}

// stock ClassDefineSetter(const &Class:class, const szMember[], const Function:func, ClassDataType:iType, iSize = 1) {
//   __cls_DefineMemberAccessorMethod(class, szMember, func, __cls_MethodType_Setter, ClassDataType:iType, iSize);
// }

// stock ClassDefineGetter(const &Class:class, const szMember[], const Function:func, ClassDataType:iType, iSize = 1) {
//   __cls_DefineMemberAccessorMethod(class, szMember, func, __cls_MethodType_Getter, ClassDataType:iType, iSize);
// }

stock Class:ClassGetBaseClass(const &Class:class) {
  return __cls_GET_CLASS_DATA(class, __cls_Data_Base);
}

stock bool:ClassHasMetadata(const &Class:class, const szMember[]) {
  static Trie:itMembers; itMembers = __cls_GetClassMembersTrie(class, false);

  if (itMembers == Invalid_Trie) return false;

  return TrieKeyExists(itMembers, szMember);
}

stock ClassDeleteMetadata(const &Class:class, const szMember[]) {
  static Trie:itMembers; itMembers = __cls_GetClassMembersTrie(class, false);

  if (itMembers == Invalid_Trie) return;

  TrieDeleteKey(itMembers, szMember);
}

stock any:ClassGetMetadata(const &Class:class, const szMember[]) {
  static Trie:itMembers; itMembers = __cls_GetClassMembersTrie(class, false);

  if (itMembers == Invalid_Trie) return 0;

  static any:value;
  return TrieGetCell(itMembers, szMember, value) ? value : 0;
}

stock ClassSetMetadata(const &Class:class, const szMember[], any:value, bool:bReplace = true) {
  static Trie:itMembers; itMembers = __cls_GetClassMembersTrie(class, true);

  TrieSetCell(itMembers, szMember, value, bReplace);
}

stock bool:ClassGetMetadataString(const &Class:class, const szMember[], szOut[], iMaxLen) {
  static Trie:itMembers; itMembers = __cls_GetClassMembersTrie(class, false);

  if (itMembers == Invalid_Trie) return false;

  __cls_CLEAR_STR(szOut);
  return !!TrieGetString(itMembers, szMember, szOut, iMaxLen);
}

stock ClassSetMetadataString(const &Class:class, const szMember[], const szValue[], bool:bReplace = true) {
  static Trie:itMembers; itMembers = __cls_GetClassMembersTrie(class, true);

  TrieSetString(itMembers, szMember, szValue, bReplace);
}

stock bool:ClassGetMetadataArray(const &Class:class, const szMember[], any:rgOut[], iLen) {
  static Trie:itMembers; itMembers = __cls_GetClassMembersTrie(class, false);

  if (itMembers == Invalid_Trie) return false;

  return !!TrieGetArray(itMembers, szMember, rgOut, iLen);
}

stock ClassSetMetadataArray(const &Class:class, const szMember[], const any:rgValue[], iLen, bool:bReplace = true) {
  static Trie:itMembers; itMembers = __cls_GetClassMembersTrie(class, true);

  TrieSetArray(itMembers, szMember, rgValue, iLen, bReplace);
}

/*--------------------------------[ Class Instance Functions] --------------------------------*/

stock ClassInstance:ClassInstanceCreate(const &Class:class) {
  new Struct:sInstance = StructCreate(__cls_InstanceData);

  StructSetCell(sInstance, __cls_InstanceData_Class, __cls_RESOLVE_CLASS_POINTER(class));

  StructSetCell(sInstance, __cls_InstanceData_Members, Invalid_Trie);

  __cls_CallInternalMethod(ClassInstance:sInstance, __cls_InternalMethod_Constructor);

  return ClassInstance:sInstance;
}

stock ClassInstanceDestroy(&ClassInstance:pInstance) {
  __cls_CallInternalMethod(pInstance, __cls_InternalMethod_Destructor);

  if (pInstance == __cls_cache_InstanceClass[__cls_InstanceCache_Instance]) {
    __cls_cache_InstanceClass[__cls_InstanceCache_Instance] = Invalid_ClassInstance;
  }

  if (pInstance == __cls_cache_InstanceMembers[__cls_InstanceCache_Instance]) {
    __cls_cache_InstanceMembers[__cls_InstanceCache_Instance] = Invalid_ClassInstance;
  }

  // if (pInstance == __cls_cache_InstanceGetters[__cls_InstanceCache_Instance]) {
  //   __cls_cache_InstanceGetters[__cls_InstanceCache_Instance] = Invalid_ClassInstance;
  // }

  // if (pInstance == __cls_cache_InstanceSetters[__cls_InstanceCache_Instance]) {
  //   __cls_cache_InstanceSetters[__cls_InstanceCache_Instance] = Invalid_ClassInstance;
  // }

  static Trie:itMembers; itMembers = __cls_GET_INSTANCE_DATA(pInstance, __cls_InstanceData_Members);
  if (itMembers != Invalid_Trie) {
    TrieDestroy(itMembers);
  }

  if (__cls_IS_CACHED_HANDLE(pInstance)) {
    new iCacheId = __cls_HANDLE_TO_CACHE_INDEX(pInstance);

    StructDestroy(__cls_rgCachedClassInstancePointers[iCacheId]);
    __cls_rgCachedClassInstancePointers[iCacheId] = Invalid_Struct;
  } else {
    new iCacheId = __cls_FindInstanceInCache(pInstance);
    if (iCacheId != -1) {
      __cls_rgCachedClassInstancePointers[iCacheId] = Invalid_Struct;
    }
    
    StructDestroy(Struct:pInstance);
  }

  pInstance = Invalid_ClassInstance;
}

stock ClassInstance:ClassInstanceGetCurrent() {
  if (!__cls_callstack_size) {
    set_fail_state(__cls_err_CallMethodOutsideContext);
    return Invalid_ClassInstance;
  }

  return __cls_callstack_pInstance[__cls_callstack_size - 1];
}

stock Class:ClassInstanceGetCurrentClass() {
  if (!__cls_callstack_size) {
    set_fail_state(__cls_err_CallMethodOutsideContext);
    return Invalid_Class;
  }

  return __cls_callstack_class[__cls_callstack_size - 1];
}

stock any:ClassInstanceCallMethod(const &ClassInstance:pInstance, const szMethod[], const &Class:class = Invalid_Class, any:...) {
  __cls_CallMethodBegin(pInstance, szMethod, _, __cls_MethodType_Method);

  __cls_CALLSTACK_PUSH()
  __cls_PushMethodCallArgs(3);
  static any:result; result = __cls_ClassInstanceCallMethodEnd();
  __cls_CALLSTACK_POP()
  
  return result;
}

stock any:ClassInstanceCallMethodFromNative(const &ClassInstance:pInstance, const szMethod[], const &Class:class = Invalid_Class, iStartArg) {
  __cls_CallMethodBegin(pInstance, szMethod, _, __cls_MethodType_Method);

  ClassInstanceCallMethodPushNativeArgParams(iStartArg);

  __cls_CALLSTACK_PUSH()
  static any:result; result = __cls_ClassInstanceCallMethodEnd();
  __cls_CALLSTACK_POP()

  return result;
}

stock ClassInstanceCallMethodByPointer(const &ClassInstance:pInstance, const &Struct:sMethod, any:...) {
  __cls_CallMethodByPointerBegin(pInstance, sMethod);

  __cls_CALLSTACK_PUSH()
  __cls_PushMethodCallArgs(2);
  static any:result; result = __cls_ClassInstanceCallMethodEnd();
  __cls_CALLSTACK_POP()

  return result;
}

stock ClassInstanceCallBaseMethod(any:...) {
  ClassInstanceCallBaseMethodBegin();

  __cls_CALLSTACK_PUSH()
  __cls_PushMethodCallArgs(0);
  static any:result; result = __cls_ClassInstanceCallMethodEnd();
  __cls_CALLSTACK_POP()

  return result;
}

stock ClassInstanceCallMethodBegin(const &ClassInstance:pInstance, const szMethod[], const &Class:class = Invalid_Class) {
  __cls_CallMethodBegin(pInstance, szMethod, class, __cls_MethodType_Method);
}

stock ClassInstanceMethodExists(const &ClassInstance:pInstance, const szMethod[], &iParamTypesNum = 0) {
  static Class:cInstance; cInstance = __cls_GetInstanceClass(pInstance);
  
  static Struct:sMethod; sMethod = __cls_FindClassMethodInHierarchy(cInstance, szMethod, __cls_MethodType_Method);
  if (sMethod == Invalid_Struct) return false;

  iParamTypesNum = __cls_GET_METHOD_DATA(sMethod, __cls_MethodData_ParamTypesNum);

  return true;
}

stock ClassInstanceCallBaseMethodBegin() {
  if (!__cls_callstack_size) {
    set_fail_state(__cls_err_CallMethodOutsideContext);
    return;
  }

  static Class:class; class = __cls_GET_CLASS_DATA(__cls_callstack_class[__cls_callstack_size - 1], __cls_Data_Base);
  if (class == Invalid_Class) {
    set_fail_state(__cls_err_ClassHasNoBaseClass);
    return;
  }

  static szMethod[CLASS_METHOD_MAX_NAME_LENGTH]; __cls_GET_METHOD_NAME(__cls_callstack_sMethod[__cls_callstack_size - 1], szMethod);
  static __cls_MethodType:iMethodType; iMethodType = __cls_GET_METHOD_DATA(__cls_callstack_sMethod[__cls_callstack_size - 1], __cls_MethodData_Type);

  __cls_InitMethodCall(__cls_callstack_pInstance[__cls_callstack_size - 1], szMethod, class, iMethodType);

  static Function:func; func = __cls_GetCallMethodFunctionPointer();

  if (callfunc_begin_p(func) != 1) {
    static szMethod[CLASS_METHOD_MAX_NAME_LENGTH]; __cls_GET_METHOD_NAME(__cls_call_sMethod, szMethod);
    set_fail_state(__cls_err_FailedToCallMethodFunction, szMethod);
    return;
  }
}

stock ClassInstanceCallMethodPushParamCell(any:value) {
  if (!__cls_ValidateParamPush(ClassDataType_Cell)) return;

  callfunc_push_int(value);

  __cls_call_iParamsNum++;
  __cls_iBufferSize++;
}

// TODO: Investigate why callfunc_push_intrf resets ref variable and doesn't copy the value back
stock ClassInstanceCallMethodPushParamCellRef(&any:value) {
  if (!__cls_ValidateParamPush(ClassDataType_CellRef)) return;

  callfunc_push_intrf(value);

  __cls_call_iParamsNum++;
  __cls_iBufferSize++;
}

stock ClassInstanceCallMethodPushParamString(const szValue[]) {
  if (!__cls_ValidateParamPush(ClassDataType_String)) return;

  callfunc_push_str(szValue, false);

  __cls_call_iParamsNum++;
  __cls_iBufferSize++;
}

stock ClassInstanceCallMethodPushParamArray(const any:rgValue[], iSize) {
  if (!__cls_ValidateParamPush(ClassDataType_Array)) return;

  callfunc_push_array(rgValue, iSize, false);

  __cls_call_iParamsNum++;
  __cls_iBufferSize++;
}

stock ClassInstanceCallMethodPushParamArrayRef(any:rgValue[], iSize) {
  if (!__cls_ValidateParamPush(ClassDataType_ArrayRef)) return;

  callfunc_push_array(rgValue, iSize, true);

  __cls_call_iParamsNum++;
  __cls_iBufferSize++;
}

stock ClassInstanceCallMethodPushParamStringRef(rgValue[], iMaxLen) {
  if (!__cls_ValidateParamPush(ClassDataType_StringRef)) return;

  // arrayset(rgValue, 1, iMaxLen);
  rgValue[iMaxLen + 1] = '^0';
  callfunc_push_array(rgValue, iMaxLen, true);

  __cls_call_iParamsNum++;
  __cls_iBufferSize++;
}

stock ClassInstanceCallMethodPushNativeArgParams(iStartArg, iArgc = -1) {
  if (iArgc < 0) {
    iArgc = __cls_call_iParamTypesNum - __cls_call_iParamsNum;
  } else {
    iArgc = __cls_MIN(iArgc, __cls_call_iParamTypesNum - __cls_call_iParamsNum);
  }

  static iParam;
  for (iParam = 0; iParam < iArgc; ++iParam) {
    ClassInstanceCallMethodPushNativeParam(iStartArg + iParam);
  }
}

stock ClassInstanceCallMethodPushNativeParam(iParam) {
  if (__cls_call_iParamsNum >= __cls_call_iParamTypesNum) return;

  static ClassDataType:iType; iType = __cls_GET_METHOD_PARAM_TYPE(__cls_call_sMethod, __cls_call_iParamsNum);

  if (__cls_IS_REF_TYPE(iType)) __cls_call_iLastRefArg = __cls_call_iParamsNum;

  switch (iType) {
    case ClassDataType_Cell: {
      __cls_rgBuffer[__cls_iBufferSize] = any:get_param_byref(iParam);
      callfunc_push_int(__cls_rgBuffer[__cls_iBufferSize]);
      __cls_iBufferSize++;
    }
    case ClassDataType_String: {
      __cls_rgBuffer[__cls_iBufferSize++] = 0;
      static iSize; iSize = get_string(iParam, __cls_rgBuffer[__cls_iBufferSize], charsmax(__cls_rgBuffer) - __cls_iBufferSize) + 1;
      __cls_iBufferSize += iSize;
      __cls_rgBuffer[__cls_iBufferSize - iSize - 1] = iSize;
      callfunc_push_str(__cls_rgBuffer[__cls_iBufferSize - iSize], false);
    }
    case ClassDataType_Array: {
      static iSize; iSize = __cls_GET_METHOD_PARAM_SIZE(__cls_call_sMethod, __cls_call_iParamsNum);
      get_array(iParam, __cls_rgBuffer[__cls_iBufferSize], iSize);
      callfunc_push_array(__cls_rgBuffer[__cls_iBufferSize], iSize, false);
      __cls_iBufferSize += iSize;
    }
    case ClassDataType_CellRef: {
      __cls_BUFFER_WRITE_REF_HEADER(__cls_RefType_NativeArg, iParam);
      __cls_rgBuffer[__cls_iBufferSize++] = any:get_param_byref(iParam);
      callfunc_push_intrf(__cls_rgBuffer[__cls_iBufferSize - 1]);
    }
    case ClassDataType_ArrayRef, ClassDataType_StringRef: {
      __cls_BUFFER_WRITE_REF_HEADER(__cls_RefType_NativeArg, iParam);
      static iSize; iSize = __cls_GET_METHOD_PARAM_SIZE(__cls_call_sMethod, __cls_call_iParamsNum);
      callfunc_push_array(__cls_rgBuffer[__cls_iBufferSize], iSize, true);
      __cls_iBufferSize += iSize;      
    }
  }

  __cls_call_iParamsNum++;
}

stock ClassInstanceCallMethodWithNativeParams(iStartArg, iArgc = -1) {
  if (iArgc < 0) {
    iArgc = __cls_call_iParamTypesNum - __cls_call_iParamsNum;
  } else {
    iArgc = __cls_MIN(iArgc, __cls_call_iParamTypesNum - __cls_call_iParamsNum);
  }

  static iParam;
  for (iParam = iStartArg; iParam < iStartArg + iArgc; ++iParam) {
    if (__cls_call_iParamsNum >= __cls_call_iParamTypesNum) continue;

    static ClassDataType:iType; iType = __cls_GET_METHOD_PARAM_TYPE(__cls_call_sMethod, __cls_call_iParamsNum);

    if (__cls_IS_REF_TYPE(iType)) __cls_call_iLastRefArg = __cls_call_iParamsNum;

    switch (iType) {
      case ClassDataType_Cell: {
        __cls_rgBuffer[__cls_iBufferSize] = any:get_param_byref(iParam);
        callfunc_push_int(__cls_rgBuffer[__cls_iBufferSize]);
        __cls_iBufferSize++;
      }
      case ClassDataType_String: {
        __cls_rgBuffer[__cls_iBufferSize++] = 0;
        static iSize; iSize = get_string(iParam, __cls_rgBuffer[__cls_iBufferSize], charsmax(__cls_rgBuffer) - __cls_iBufferSize) + 1;
        __cls_iBufferSize += iSize;
        __cls_rgBuffer[__cls_iBufferSize - iSize - 1] = iSize;
        callfunc_push_str(__cls_rgBuffer[__cls_iBufferSize - iSize], false);
      }
      case ClassDataType_Array: {
        static iSize; iSize = __cls_GET_METHOD_PARAM_SIZE(__cls_call_sMethod, __cls_call_iParamsNum);
        get_array(iParam, __cls_rgBuffer[__cls_iBufferSize], iSize);
        callfunc_push_array(__cls_rgBuffer[__cls_iBufferSize], iSize, false);
        __cls_iBufferSize += iSize;
      }
      case ClassDataType_CellRef: {
        __cls_BUFFER_WRITE_REF_HEADER(__cls_RefType_NativeArg, iParam);
        __cls_rgBuffer[__cls_iBufferSize++] = any:get_param_byref(iParam);
        callfunc_push_intrf(__cls_rgBuffer[__cls_iBufferSize - 1]);
      }
      case ClassDataType_ArrayRef, ClassDataType_StringRef: {
        __cls_BUFFER_WRITE_REF_HEADER(__cls_RefType_NativeArg, iParam);
        static iSize; iSize = __cls_GET_METHOD_PARAM_SIZE(__cls_call_sMethod, __cls_call_iParamsNum);
        callfunc_push_array(__cls_rgBuffer[__cls_iBufferSize], iSize, true);
        __cls_iBufferSize += iSize;      
      }
    }

    __cls_call_iParamsNum++;
  }

  __cls_CALLSTACK_PUSH()
  static any:result; result = __cls_ClassInstanceCallMethodEnd();
  __cls_CALLSTACK_POP()

  return result;
}

stock Class:ClassInstanceGetClass(const &ClassInstance:pInstance) {
  return __cls_GetInstanceClass(pInstance);
}

stock bool:ClassInstanceHasMember(const &ClassInstance:pInstance, const szMember[]) {
  static Trie:itMembers; itMembers = __cls_GetInstanceMembersTrie(pInstance, false);

  if (itMembers == Invalid_Trie) return false;

  return TrieKeyExists(itMembers, szMember);
}

stock bool:ClassInstanceDeleteMember(const &ClassInstance:pInstance, const szMember[]) {
  static Trie:itMembers; itMembers = __cls_GetInstanceMembersTrie(pInstance, false);

  if (itMembers == Invalid_Trie) return false;

  return !!TrieDeleteKey(itMembers, szMember);
}

stock any:ClassInstanceGetMember(const &ClassInstance:pInstance, const szMember[]) {
  // static Trie:itGetters; itGetters = __cls_GetInstanceGettersTrie(pInstance);

  // if (itGetters != Invalid_Trie && TrieKeyExists(itGetters, szMember)) {
  //   return __cls_CallCellGetter(pInstance, szMember);
  // }

  static Trie:itMembers; itMembers = __cls_GetInstanceMembersTrie(pInstance, false);

  if (itMembers == Invalid_Trie) return 0;

  static any:value;
  return !!TrieGetCell(itMembers, szMember, value) ? value : 0;
}

stock bool:ClassInstanceSetMember(const &ClassInstance:pInstance, const szMember[], any:value, bool:bReplace = true) {
  // static Trie:itSetters; itSetters = __cls_GetInstanceSettersTrie(pInstance);

  // if (itSetters != Invalid_Trie && TrieKeyExists(itSetters, szMember)) {
  //   __cls_CallCellSetter(pInstance, szMember, value);
  //   return;
  // }

  static Trie:itMembers; itMembers = __cls_GetInstanceMembersTrie(pInstance, true);

  return !!TrieSetCell(itMembers, szMember, value, bReplace);
}

stock bool:ClassInstanceGetMemberString(const &ClassInstance:pInstance, const szMember[], szOut[], iMaxLen) {
  // static Trie:itGetters; itGetters = __cls_GetInstanceGettersTrie(pInstance);

  // if (itGetters != Invalid_Trie && TrieKeyExists(itGetters, szMember)) {
  //   return __cls_CallStringGetter(pInstance, szMember, szOut, iMaxLen);
  // }

  static Trie:itMembers; itMembers = __cls_GetInstanceMembersTrie(pInstance, false);

  if (itMembers == Invalid_Trie) return false;

  __cls_CLEAR_STR(szOut);
  return !!TrieGetString(itMembers, szMember, szOut, iMaxLen);
}

stock bool:ClassInstanceSetMemberString(const &ClassInstance:pInstance, const szMember[], const szValue[], bool:bReplace = true) {
  // static Trie:itSetters; itSetters = __cls_GetInstanceSettersTrie(pInstance);

  // if (itSetters != Invalid_Trie && TrieKeyExists(itSetters, szMember)) {
  //   __cls_CallStringSetter(pInstance, szMember, szValue);
  //   return;
  // }

  static Trie:itMembers; itMembers = __cls_GetInstanceMembersTrie(pInstance, true);

  return !!TrieSetString(itMembers, szMember, szValue, bReplace);
}

stock bool:ClassInstanceGetMemberArray(const &ClassInstance:pInstance, const szMember[], any:rgOut[], iLen) {
  // static Trie:itGetters; itGetters = __cls_GetInstanceGettersTrie(pInstance);

  // if (itGetters != Invalid_Trie && TrieKeyExists(itGetters, szMember)) {
  //   return __cls_CallArrayGetter(pInstance, szMember, rgOut, iLen);
  // }

  static Trie:itMembers; itMembers = __cls_GetInstanceMembersTrie(pInstance, false);

  if (itMembers == Invalid_Trie) return false;

  return !!TrieGetArray(itMembers, szMember, rgOut, iLen);
}

stock bool:ClassInstanceSetMemberArray(const &ClassInstance:pInstance, const szMember[], const any:rgValue[], iLen, bool:bReplace = true) {
  // static Trie:itSetters; itSetters = __cls_GetInstanceSettersTrie(pInstance);

  // if (itSetters != Invalid_Trie && TrieKeyExists(itSetters, szMember)) {
  //   __cls_CallArraySetter(pInstance, szMember, rgValue, iLen);
  //   return;
  // }

  static Trie:itMembers; itMembers = __cls_GetInstanceMembersTrie(pInstance, true);

  return !!TrieSetArray(itMembers, szMember, rgValue, iLen, bReplace);
}

stock bool:ClassInstanceIsInstanceOf(const &ClassInstance:pInstance, const &Class:class) {
  static Class:cInstance; cInstance = __cls_GetInstanceClass(pInstance);

  return ClassIs(cInstance, class);
}

stock bool:ClassIs(const &Class:class, const &Class:cOther) {
  if (class == cOther) return true;

  if (__cls_GET_CLASS_DATA(class, __cls_Data_RootClass) != __cls_GET_CLASS_DATA(cOther, __cls_Data_RootClass)) {
    return false;
  }

  static iDepthDiff; iDepthDiff = __cls_GET_CLASS_DATA(class, __cls_Data_RootClassDepth) - __cls_GET_CLASS_DATA(cOther, __cls_Data_RootClassDepth);
  if (iDepthDiff < 0) return false;

  static Class:sCurrentClass; sCurrentClass = class;

  while (iDepthDiff-- > 0) {
    sCurrentClass = __cls_GET_CLASS_DATA(sCurrentClass, __cls_Data_Base);
  }

  return sCurrentClass == cOther;
}

stock bool:ClassInstanceIsRelated(const &ClassInstance:pInstance, const &ClassInstance:pOther) {
  static Class:cClass; cClass = __cls_GetInstanceClass(pInstance);
  static Class:cOtherClass; cOtherClass = __cls_GetInstanceClass(pOther);

  return __cls_GET_CLASS_DATA(cClass, __cls_Data_RootClass) == __cls_GET_CLASS_DATA(cOtherClass, __cls_Data_RootClass);
}

stock bool:ClassIsRelated(const &Class:cClass, const &Class:cOther) {
  return __cls_GET_CLASS_DATA(cClass, __cls_Data_RootClass) == __cls_GET_CLASS_DATA(cOther, __cls_Data_RootClass);
}

stock Class:ClassFindMethodClass(const &Class:class, const szMethod[]) {
  static Struct:sMethod; sMethod = __cls_FindClassMethodInHierarchy(class, szMethod, __cls_MethodType_Method); 
  if (sMethod == Invalid_Struct) return Invalid_Class;

  return __cls_GET_METHOD_DATA(sMethod, __cls_MethodData_Class);
}

/*--------------------------------[ Cached Functions ] --------------------------------*/

stock ClassInstance:ClassInstanceCache(const &ClassInstance:instance) {
  if (__cls_IS_CACHED_HANDLE(instance)) return instance;

  new iCacheId = __cls_FindInstanceInCache(instance);
  if (iCacheId != -1) return ClassInstance:__cls_CACHE_INDEX_TO_HANDLE(iCacheId);

  iCacheId = __cls_AllocInstanceCache();
  if (iCacheId == -1) return instance;

  new Class:cClass = __cls_GET_INSTANCE_DATA(instance, __cls_InstanceData_Class);
  new iClassCacheId = __cls_FindClassInCache(cClass);
  if (iClassCacheId != -1) {
    cClass = __cls_CACHE_INDEX_TO_HANDLE(iClassCacheId);
  }

  __cls_rgCachedClassInstancePointers[iCacheId] = Struct:instance;
  __cls_rgCachedClassInstances[iCacheId][__cls_InstanceData_Class] = cClass;
  __cls_rgCachedClassInstances[iCacheId][__cls_InstanceData_Members] = __cls_GET_INSTANCE_DATA(instance, __cls_InstanceData_Members);

  return ClassInstance:__cls_CACHE_INDEX_TO_HANDLE(iCacheId);
}

stock Class:ClassCache(const &Class:class) {
  if (__cls_IS_CACHED_HANDLE(class)) return class;
  if (__cls_iCachedClassesNum >= sizeof(__cls_rgCachedClasses)) return class;

  new iCacheId = __cls_FindClassInCache(class);
  if (iCacheId != -1) return Class:__cls_CACHE_INDEX_TO_HANDLE(iCacheId);

  iCacheId = __cls_iCachedClassesNum;

  new Class:cBase = __cls_GET_CLASS_DATA(class, __cls_Data_Base);

  new iBaseCacheId = __cls_FindClassInCache(cBase);
  if (iBaseCacheId != -1) {
    cBase = __cls_CACHE_INDEX_TO_HANDLE(iBaseCacheId);
  }
  
  __cls_rgCachedClassPointers[iCacheId] = Struct:class;
  __cls_rgCachedClasses[iCacheId][__cls_Data_Base] = __cls_GET_CLASS_DATA(class, __cls_Data_Base);
  __cls_rgCachedClasses[iCacheId][__cls_Data_Members] = __cls_GET_CLASS_DATA(class, __cls_Data_Members);
  __cls_rgCachedClasses[iCacheId][__cls_Data_Methods] = Invalid_Trie;
  __cls_rgCachedClasses[iCacheId][__cls_Data_RootClass] = StructGetCell(Struct:class, __cls_Data_RootClass);
  __cls_rgCachedClasses[iCacheId][__cls_Data_RootClassDepth] = StructGetCell(Struct:class, __cls_Data_RootClassDepth);
  StructGetArray(Struct:class, __cls_Data_InternalMethods, __cls_rgCachedClasses[iCacheId][__cls_Data_InternalMethods], __cls_InternalMethod);

  new Trie:itMethods = __cls_GET_CLASS_DATA(class, __cls_Data_Methods);

  // Clone class method trie for method caching
  if (itMethods != Invalid_Trie) {
    __cls_rgCachedClasses[iCacheId][__cls_Data_Methods] = __cls_CloneMethodsTrie(itMethods);
  }

  __cls_iCachedClassesNum++;

  return Class:__cls_CACHE_INDEX_TO_HANDLE(iCacheId);
}

stock Trie:__cls_CloneMethodsTrie(const &Trie:itMethods) {
  new Trie:itMethodsCopy = TrieCreate();
  
  new TrieIter:iMethodsIter = TrieIterCreate(itMethods);

  while (!TrieIterEnded(iMethodsIter)) {
    new szMethod[CLASS_METHOD_MAX_NAME_LENGTH]; TrieIterGetKey(iMethodsIter, szMethod, charsmax(szMethod));
    new Struct:sMethod; TrieIterGetCell(iMethodsIter, sMethod);

    TrieSetCell(itMethodsCopy, szMethod, sMethod);

    TrieIterNext(iMethodsIter);
  }

  TrieIterDestroy(iMethodsIter);

  return itMethodsCopy;
}

stock Struct:__cls_CacheMethod(&Struct:sMethod) {
  if (__cls_IS_CACHED_HANDLE(sMethod)) return sMethod;
  if (__cls_iCachedMethodsNum >= sizeof(__cls_rgCachedMethods)) return sMethod;

  new iCacheId = __cls_FindMethodInCache(sMethod);
  if (iCacheId != -1) return Struct:__cls_CACHE_INDEX_TO_HANDLE(iCacheId);

  iCacheId = __cls_iCachedMethodsNum;

  StructGetArray(sMethod, 0, __cls_rgCachedMethods[iCacheId], __cls_MethodData);
  __cls_rgCachedMethodPointers[iCacheId] = sMethod;

  __cls_iCachedMethodsNum++;

  return Struct:__cls_CACHE_INDEX_TO_HANDLE(iCacheId);
}

stock ClassCacheMethod(&Class:class, const szMethod[]) {
  if (!__cls_IS_CACHED_HANDLE(class)) {
    set_fail_state("Couldn't cache class methods of not cached class");
    return;
  }

  new Trie:itMethods = __cls_GET_CLASS_DATA(class, __cls_Data_Methods);

  if (itMethods == Invalid_Trie) return;

  new Struct:sMethod;
  if (!TrieGetCell(itMethods, szMethod, sMethod)) {
    set_fail_state(__cls_err_NotImplementedMethod, szMethod);
    return;
  }

  if (__cls_IS_CACHED_HANDLE(sMethod)) return;

  sMethod = __cls_CacheMethod(sMethod);

  TrieSetCell(itMethods, szMethod, sMethod);
}

static stock __cls_FindClassInCache(const &Class:class) {
  for (new iCacheId = 0; iCacheId < __cls_iCachedClassesNum; ++iCacheId) {
    if (__cls_rgCachedClassPointers[iCacheId] == Struct:class) {
      return iCacheId;
    }
  }

  return -1;
}

static stock __cls_FindMethodInCache(const &Struct:sMethod) {
  for (new iCacheId = 0; iCacheId < __cls_iCachedMethodsNum; ++iCacheId) {
    if (__cls_rgCachedMethodPointers[iCacheId] == sMethod) {
      return iCacheId;
    }
  }

  return -1;
}

static stock __cls_FindInstanceInCache(const &ClassInstance:instance) {
  for (new iCacheId = 0; iCacheId < sizeof(__cls_rgCachedClassInstancePointers); ++iCacheId) {
    if (__cls_rgCachedClassInstancePointers[iCacheId] == Struct:instance) {
      return iCacheId;
    }
  }

  return -1;
}

static stock __cls_AllocInstanceCache() {
  for (new iCacheId = 0; iCacheId < sizeof(__cls_rgCachedClassInstancePointers); ++iCacheId) {
    if (__cls_rgCachedClassInstancePointers[iCacheId] == Invalid_Struct) {
      return iCacheId;
    }
  }

  return -1;
}

/*--------------------------------[ Deprecated Functions ] --------------------------------*/

/**
 * @deprecated Use ClassDefineMethod instead
 */
// #pragma deprecated Use ClassDefineMethod instead
#define ClassAddMethod ClassDefineMethod

/*--------------------------------[ Internal Method Structure Functions] --------------------------------*/

static stock Struct:__cls_CreateMethod(Class:class, const szName[], const Function:func, Array:irgParamTypes = Invalid_Array, __cls_MethodType:iType = __cls_MethodType_Method, bool:bVariadicParams = false) {
  new Struct:sMethod = StructCreate(__cls_MethodData);
  StructSetCell(sMethod, __cls_MethodData_Class, class);
  StructSetString(sMethod, __cls_MethodData_Name, szName);
  StructSetCell(sMethod, __cls_MethodData_Function, func);
  StructSetCell(sMethod, __cls_MethodData_Type, iType);
  StructSetCell(sMethod, __cls_MethodData_VariadicParams, bVariadicParams);

  new iParamTypesNum = 0;

  if (irgParamTypes != Invalid_Array) {
    iParamTypesNum = ArraySize(irgParamTypes);

    for (new iParam = 0; iParam < iParamTypesNum; ++iParam) {
      StructSetCell(sMethod, __cls_MethodData_ParamTypes, ArrayGetCell(irgParamTypes, iParam, __cls_MethodParamData_Type), __cls_MethodParamOffset(iParam) + _:__cls_MethodParamData_Type);
      StructSetCell(sMethod, __cls_MethodData_ParamTypes, ArrayGetCell(irgParamTypes, iParam, __cls_MethodParamData_Size), __cls_MethodParamOffset(iParam) + _:__cls_MethodParamData_Size);
    }
  }

  StructSetCell(sMethod, __cls_MethodData_ParamTypesNum, iParamTypesNum);
  StructSetCell(sMethod, __cls_MethodData_CallsNum, 0);

  return sMethod;
}

static stock __cls_DestroyMethod(&Struct:sMethod) {
  new Array:irgParamTypes; irgParamTypes = __cls_GET_METHOD_DATA(sMethod, __cls_MethodData_ParamTypes);

  if (irgParamTypes != Invalid_Array) {
    ArrayDestroy(irgParamTypes);
  }

  sMethod = __cls_RESOLVE_METHOD_POINTER(sMethod);
  StructDestroy(sMethod);
}

/*--------------------------------[ Internal Define Functions] --------------------------------*/

// static stock __cls_DefineMemberAccessorMethod(const &Class:class, const szMember[], const Function:func, __cls_MethodType:iMethodType, ClassDataType:iType, iSize) {
//   if (iMethodType != __cls_MethodType_Getter && iMethodType != __cls_MethodType_Setter) return;

//   new Trie:itMethods = __cls_GetClassMethodsTrie(class, iMethodType, true);

//   new Array:irgParamTypes; irgParamTypes = ArrayCreate(_:__cls_MethodParamData, 1);

//   // Input value or output reference
//   if (iMethodType == __cls_MethodType_Setter || (iType == ClassDataType_String || iType == ClassDataType_Array)) {
//     new rgParam[__cls_MethodParamData];
    
//     if (iMethodType == __cls_MethodType_Getter) {
//       switch (iType) {
//         case ClassDataType_String: rgParam[__cls_MethodParamData_Type] = ClassDataType_StringRef;
//         case ClassDataType_Array: rgParam[__cls_MethodParamData_Type] = ClassDataType_ArrayRef;
//         default: rgParam[__cls_MethodParamData_Type] = iType;
//       }
//     } else {
//       rgParam[__cls_MethodParamData_Type] = iType
//     }

//     rgParam[__cls_MethodParamData_Size] = iSize;

//     ArrayPushArray(irgParamTypes, rgParam[any:0], _:__cls_MethodParamData);
//   }

//   // Max size for arrays and string getters
//   if (iType == ClassDataType_Array || (iType == ClassDataType_String && iMethodType == __cls_MethodType_Getter)) {
//     new rgSizeParam[__cls_MethodParamData];
//     rgSizeParam[__cls_MethodParamData_Type] = ClassDataType_Cell;
//     rgSizeParam[__cls_MethodParamData_Size] = 1;

//     ArrayPushArray(irgParamTypes, rgSizeParam[any:0], _:__cls_MethodParamData);
//   }

//   new Struct:sMethod = __cls_CreateMethod(class, szMember, func, irgParamTypes, iMethodType);

//   ArrayDestroy(irgParamTypes);

//   TrieSetCell(itMethods, szMember, sMethod);
// }

/*--------------------------------[ Internal Call Functions] --------------------------------*/

static stock __cls_InitMethodCall(const &ClassInstance:pInstance, const szMethod[], const &Class:class = Invalid_Class, __cls_MethodType:iMethodType) {
  if (class == Invalid_Class) {
      if (__cls_callstack_size && __cls_callstack_pInstance[__cls_callstack_size - 1] == pInstance) {
          __cls_call_class = __cls_callstack_class[__cls_callstack_size - 1];
      } else {
          __cls_call_class = __cls_GetInstanceClass(pInstance);
      }
  } else {
    __cls_call_class = class;
  }

  __cls_call_pInstance = pInstance;
  __cls_call_sMethod = __cls_FindClassMethodInHierarchy(__cls_call_class, szMethod, iMethodType);
  __cls_call_iParamsNum = 0;
  __cls_call_iLastRefArg = -1;
  __cls_call_iBufferPos = __cls_iBufferSize;

  if (__cls_call_sMethod == Invalid_Struct) {
    set_fail_state(__cls_err_MethodNotFound, szMethod, pInstance);
    return;
  }

  if (class == Invalid_Class && __cls_callstack_size) {
    // Check for virtual method call
    // If we are already in the execution context and the method is virual then jump to top level context
    // All Getters and Setter works like virtual methods
    if (__cls_GET_METHOD_DATA(__cls_call_sMethod, __cls_MethodData_Type) != __cls_MethodType_Method) {
      static Class:sInstanceClass; sInstanceClass = __cls_GetInstanceClass(pInstance);
      if (sInstanceClass != __cls_GET_METHOD_DATA(__cls_call_sMethod, __cls_MethodData_Class)) {
        __cls_call_sMethod = __cls_FindClassMethodInHierarchy(sInstanceClass, szMethod, iMethodType);
      }
    }
  }

  //? TODO: Optimize (probably can pass class ref inside __cls_FindClassMethodInHierarchy call)
  __cls_call_class = __cls_GET_METHOD_DATA(__cls_call_sMethod, __cls_MethodData_Class);

  // if (!__cls_IS_CACHED_HANDLE(pInstance)) {
  //   server_print("Instance %d is not cached", _:pInstance);
  // }

  // if (!__cls_IS_CACHED_HANDLE(__cls_call_class)) {
  //   server_print("Class %d is not cached", _:__cls_call_class);
  // }

  // if (!__cls_IS_CACHED_HANDLE(__cls_call_sMethod)) {
  //   server_print("Method %s is not cached (record: %d, calls: %d, calls to cache: %d)", szMethod, __cls_iCallsNumRecord, __cls_GET_METHOD_DATA(__cls_call_sMethod, __cls_MethodData_CallsNum), __cls_iCallsToCache);
  // }

  __cls_call_iParamTypesNum = __cls_GET_METHOD_DATA(__cls_call_sMethod, __cls_MethodData_ParamTypesNum);
  __cls_call_iRequiredParamsNum = __cls_call_iParamTypesNum;
}

static stock __cls_InitMethodCallByPointer(const &ClassInstance:pInstance, const &Struct:sMethod) {
  __cls_call_class = __cls_GET_METHOD_DATA(sMethod, __cls_MethodData_Class);
  __cls_call_pInstance = pInstance;
  __cls_call_sMethod = sMethod;
  __cls_call_iParamsNum = 0;
  __cls_call_iLastRefArg = -1;
  __cls_call_iBufferPos = __cls_iBufferSize;
  __cls_call_iParamTypesNum = __cls_GET_METHOD_DATA(__cls_call_sMethod, __cls_MethodData_ParamTypesNum);
  __cls_call_iRequiredParamsNum = __cls_call_iParamTypesNum;
}

static stock any:__cls_CallInternalMethod(const &ClassInstance:pInstance, __cls_InternalMethod:iMethod) {
  static Class:sInstanceClass; sInstanceClass = __cls_GetInstanceClass(pInstance);
  static Struct:sMethod; sMethod = __cls_FindClassInternalMethodInHierarchy(sInstanceClass, iMethod);

  if (sMethod == Invalid_Struct) return;

  __cls_CallMethodByPointerBegin(pInstance, sMethod);

  __cls_CALLSTACK_PUSH()
  __cls_ClassInstanceCallMethodEnd();
  __cls_CALLSTACK_POP()
}

static stock __cls_CallMethodBegin(const &ClassInstance:pInstance, const szMethod[], const &Class:class = Invalid_Class, __cls_MethodType:iMethodType = __cls_MethodType_Method) {
  __cls_InitMethodCall(pInstance, szMethod, class, iMethodType);

  if (__cls_call_sMethod == Invalid_Struct) {
    set_fail_state(__cls_err_MethodNotFound, szMethod, pInstance);
    return;
  }

  static Function:func; func = __cls_GetCallMethodFunctionPointer();

  if (callfunc_begin_p(func) != 1) {
    static szMethod[CLASS_METHOD_MAX_NAME_LENGTH]; __cls_GET_METHOD_NAME(__cls_call_sMethod, szMethod);
    set_fail_state(__cls_err_FailedToCallMethodFunction, szMethod);
    return;
  }
}

static stock __cls_CallMethodByPointerBegin(const &ClassInstance:pInstance, const &Struct:sMethod) {
  __cls_InitMethodCallByPointer(pInstance, sMethod);

  static Function:func; func = __cls_GetCallMethodFunctionPointer();

  if (callfunc_begin_p(func) != 1) {
    static szMethod[CLASS_METHOD_MAX_NAME_LENGTH]; __cls_GET_METHOD_NAME(__cls_call_sMethod, szMethod);
    set_fail_state(__cls_err_FailedToCallMethodFunction, szMethod);
    return;
  }
}

stock any:ClassInstanceCallMethodEnd() {
  __cls_CALLSTACK_PUSH()
  static any:result; result = __cls_ClassInstanceCallMethodEnd();
  __cls_CALLSTACK_POP()

  return result;
}

static stock any:__cls_ClassInstanceCallMethodEnd() {
  if (__cls_call_sMethod == Invalid_Struct) {
    set_fail_state(__cls_err_ClassMethodCallEndWithoutStart);
    return 0;
  }

  if (__cls_call_iParamsNum < __cls_call_iRequiredParamsNum) {
    static szMethod[CLASS_METHOD_MAX_NAME_LENGTH]; __cls_GET_METHOD_NAME(__cls_call_sMethod, szMethod);
    abort(AMX_ERR_PARAMS, __cls_err_MissingRequiredArguments, szMethod, __cls_call_iRequiredParamsNum, __cls_call_iParamsNum);
    return 0;
  }

  // Cache methods of cached classes based on call rate record
  if (__cls_IS_CACHED_HANDLE(__cls_call_class)) {
    if (__cls_iCachedMethodsNum < sizeof(__cls_rgCachedMethods)) {
      static iMethodCallsNum; iMethodCallsNum = __cls_GET_METHOD_DATA(__cls_call_sMethod, __cls_MethodData_CallsNum);

      if (__cls_iCallsNumRecord < __cls_MAX_CALLS_NUM_RECORD) {
        __cls_iCallsNumRecord = __cls_MAX(__cls_iCallsNumRecord, iMethodCallsNum);
        __cls_iCallsToCache = __cls_MIN_CALLS_TO_CACHE + (__cls_iCallsNumRecord / 128);
      }

      if (!__cls_IS_CACHED_HANDLE(__cls_call_sMethod) && iMethodCallsNum >= __cls_iCallsToCache) {
        new szMethod[CLASS_METHOD_MAX_NAME_LENGTH]; __cls_GET_METHOD_NAME(__cls_call_sMethod, szMethod);
        ClassCacheMethod(__cls_call_class, szMethod);
      }

      if (iMethodCallsNum < __cls_MAX_CALLS_NUM_RECORD) {
        __cls_SET_METHOD_DATA(__cls_call_sMethod, __cls_MethodData_CallsNum, iMethodCallsNum + 1);
      }
    }
  }

  __cls_LogExecution();

  static any:result; result = callfunc_end();

  if (__cls_call_iLastRefArg != -1) {
    __cls_UpdateNativeRefsFromCallBuffer();
  }

  __cls_iBufferSize = __cls_call_iBufferPos;

  return result;
}

// static stock any:__cls_CallCellGetter(const &ClassInstance:pInstance, const szMember[]) {
//   __cls_CallMethodBegin(pInstance, szMember, _, __cls_MethodType_Getter);

//   __cls_CALLSTACK_PUSH()
//   static any:result; result = __cls_ClassInstanceCallMethodEnd();
//   __cls_CALLSTACK_POP()

//   return result;
// }

// static stock any:__cls_CallArrayGetter(const &ClassInstance:pInstance, const szMember[], any:rgOut[], iSize = -1) {
//   __cls_CallMethodBegin(pInstance, szMember, _, __cls_MethodType_Getter);

//   if (iSize == -1) {
//     iSize = __cls_GET_METHOD_DATA(__cls_call_sMethod, __cls_MethodData_ParamTypes, _:__cls_MethodParamData_Size);
//   }

//   ClassInstanceCallMethodPushParamArrayRef(rgOut, iSize);
//   ClassInstanceCallMethodPushParamCell(iSize);

//   __cls_CALLSTACK_PUSH()
//   static any:result; result = __cls_ClassInstanceCallMethodEnd();
//   __cls_CALLSTACK_POP()

//   return result;
// }

// static stock any:__cls_CallStringGetter(const &ClassInstance:pInstance, const szMember[], any:rgOut[], iMaxLen) {
//   __cls_CallMethodBegin(pInstance, szMember, _, __cls_MethodType_Getter);

//   ClassInstanceCallMethodPushParamStringRef(rgOut, iMaxLen);
//   ClassInstanceCallMethodPushParamCell(iMaxLen);
//   rgOut[iMaxLen + 1] = '^0';

//   __cls_CALLSTACK_PUSH()
//   static any:result; result = __cls_ClassInstanceCallMethodEnd();
//   __cls_CALLSTACK_POP()

//   return result;
// }

// static stock __cls_CallCellSetter(const &ClassInstance:pInstance, const szMember[], any:value) {
//   __cls_CallMethodBegin(pInstance, szMember, _, __cls_MethodType_Setter);

//   ClassInstanceCallMethodPushParamCell(value);

//   __cls_CALLSTACK_PUSH()
//   __cls_ClassInstanceCallMethodEnd();
//   __cls_CALLSTACK_POP()
// }

// static stock __cls_CallArraySetter(const &ClassInstance:pInstance, const szMember[], const any:rgValue[], iSize = -1) {
//   __cls_CallMethodBegin(pInstance, szMember, _, __cls_MethodType_Setter);

//   if (iSize == -1) {
//     iSize = __cls_GET_METHOD_DATA(__cls_call_sMethod, __cls_MethodData_ParamTypes, _:__cls_MethodParamData_Size);
//   }

//   ClassInstanceCallMethodPushParamArray(rgValue, iSize);
//   ClassInstanceCallMethodPushParamCell(iSize);

//   __cls_CALLSTACK_PUSH()
//   __cls_ClassInstanceCallMethodEnd();
//   __cls_CALLSTACK_POP()
// }

// static stock __cls_CallStringSetter(const &ClassInstance:pInstance, const szMember[], const szValue[]) {
//   __cls_CallMethodBegin(pInstance, szMember, _, __cls_MethodType_Setter);

//   ClassInstanceCallMethodPushParamString(szValue);

//   __cls_CALLSTACK_PUSH()
//   __cls_ClassInstanceCallMethodEnd();
//   __cls_CALLSTACK_POP()
// }

// static stock __cls_CallMethodPushArgParam(iArg, iArgOffset) {
//   if (__cls_call_iParamsNum >= __cls_call_iParamTypesNum) return;

//   iArgOffset += __cls_GET_ARG_OFFSET(iArg, 2);

//   static ClassDataType:iType; iType = __cls_GET_METHOD_PARAM_TYPE(__cls_call_sMethod, __cls_call_iParamsNum);

//   if (__cls_IS_REF_TYPE(iType)) __cls_call_iLastRefArg = __cls_call_iParamsNum;

//   switch (iType) {
//     case ClassDataType_Cell: {
//       callfunc_push_int(any:getarg(iArgOffset));
//     }
//     case ClassDataType_String: {
//       __cls_rgBuffer[__cls_iBufferSize++] = 0;
  
//       static iSize; iSize = 0;
//       do {
//         if (__cls_iBufferSize >= charsmax(__cls_rgBuffer)) break;
//         __cls_rgBuffer[__cls_iBufferSize++] = getarg(iArgOffset, iSize++);
//       } while (__cls_rgBuffer[__cls_iBufferSize - 1] != '^0');

//       __cls_rgBuffer[__cls_iBufferSize - iSize - 1] = iSize;
  
//       callfunc_push_str(__cls_rgBuffer[__cls_iBufferSize - iSize], false);
//     }
//     case ClassDataType_Array: {
//       static iSize; iSize = __cls_GET_METHOD_PARAM_SIZE(__cls_call_sMethod, __cls_call_iParamsNum);

//       static i;
//       for (i = 0; i < iSize; ++i) {
//         if (__cls_iBufferSize >= sizeof(__cls_rgBuffer)) break;
//         __cls_rgBuffer[__cls_iBufferSize++] = any:getarg(iArgOffset, i);
//       }

//       callfunc_push_array(__cls_rgBuffer[__cls_iBufferSize - iSize], iSize, false);
//     }
//     case ClassDataType_CellRef: {
//       __cls_BUFFER_WRITE_REF_HEADER(__cls_RefType_Arg, iArg);
//       __cls_rgBuffer[__cls_iBufferSize++] = any:getarg(iArgOffset);
//       callfunc_push_intrf(__cls_rgBuffer[__cls_iBufferSize - 1]);
//     }
//     case ClassDataType_ArrayRef, ClassDataType_StringRef: {
//       __cls_BUFFER_WRITE_REF_HEADER(__cls_RefType_Arg, iArg);
//       static iSize; iSize = __cls_GET_METHOD_PARAM_SIZE(__cls_call_sMethod, __cls_call_iParamsNum);
//       callfunc_push_array(__cls_rgBuffer[__cls_iBufferSize], iSize, true);
//       __cls_iBufferSize += iSize;
//     }
//   }

//   __cls_call_iParamsNum++;
// }

static stock __cls_UpdateNativeRefsFromCallBuffer() {
  static iBufferOffset; iBufferOffset = __cls_call_iBufferPos;

  static iMethodParam;
  for (iMethodParam = 0; iMethodParam <= __cls_call_iLastRefArg; ++iMethodParam) {
    static ClassDataType:iType; iType = __cls_GET_METHOD_PARAM_TYPE(__cls_call_sMethod, iMethodParam);

    switch (iType) {
      case ClassDataType_Cell: {
        iBufferOffset++;
      }
      case ClassDataType_String: {
        static iSize; iSize = __cls_rgBuffer[iBufferOffset++];
        iBufferOffset += iSize;
      }
      case ClassDataType_Array: {
        iBufferOffset += __cls_GET_METHOD_PARAM_SIZE(__cls_call_sMethod, iMethodParam);
      }
      case ClassDataType_CellRef: {
        static __cls_RefType:iRefType, iArg; __cls_BUFFER_READ_REF_HEADER(iBufferOffset, iRefType, iArg);

        if (iRefType == __cls_RefType_NativeArg) {
          set_param_byref(iArg, __cls_rgBuffer[iBufferOffset]);
        }

        iBufferOffset++;
      }
      case ClassDataType_ArrayRef: {
        static __cls_RefType:iRefType, iArg; __cls_BUFFER_READ_REF_HEADER(iBufferOffset, iRefType, iArg);

        static iSize; iSize = __cls_GET_METHOD_PARAM_SIZE(__cls_call_sMethod, iMethodParam);

        if (iRefType == __cls_RefType_NativeArg) {
          set_array(iArg, __cls_rgBuffer[iBufferOffset], iSize);
        }

        iBufferOffset += iSize;
      }
      case ClassDataType_StringRef: {
        static __cls_RefType:iRefType, iArg; __cls_BUFFER_READ_REF_HEADER(iBufferOffset, iRefType, iArg);

        static iSize; iSize = __cls_GET_METHOD_PARAM_SIZE(__cls_call_sMethod, iMethodParam);
    
        if (iRefType == __cls_RefType_NativeArg) {
          set_string(iArg, __cls_rgBuffer[iBufferOffset], iSize);
        }

        iBufferOffset += iSize;
      }
    }
  }
}

static stock __cls_PushMethodCallArgs(iStartArg) {
  static iFrameSize, iArgsNum, iArg, bCopyback, iArraySize;
  new iArgAddr, iCallerAddr;

  // Get iCallerAddr frame address
  #emit LCTRL 5
  #emit LOAD.I
  #emit STOR.S.pri iCallerAddr

  // Get number of bytes in the method call frame
  #emit LOAD.S.pri iCallerAddr
  #emit CONST.alt 8
  #emit ADD
  #emit LOAD.I
  #emit STOR.pri iFrameSize

  // Calculate number of arguments
  #emit LOAD.pri iFrameSize
  #emit SHR.C.pri 2
  #emit LOAD.alt iStartArg
  #emit SUB
  #emit STOR.pri iArgsNum

  // Get address of the first argument
  #emit LOAD.S.pri iCallerAddr
  #emit CONST.alt 12
  #emit ADD
  #emit STOR.S.pri iArgAddr

  #emit LOAD.S.pri iArgAddr
  #emit LOAD.S.alt iStartArg
  #emit SHL.C.alt 2
  #emit ADD
  #emit STOR.S.pri iArgAddr

  for (iArg = 0; iArg < iArgsNum; ++iArg) {
    if (iArg >= __cls_call_iParamTypesNum) break;

    static ClassDataType:iType; iType = __cls_GET_METHOD_PARAM_TYPE(__cls_call_sMethod, __cls_call_iParamsNum);
  
    switch (iType) {
      case ClassDataType_Cell: {
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
      case ClassDataType_CellRef: {
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
      case ClassDataType_String: {
        // Push "copyback" argument
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
      case ClassDataType_Array, ClassDataType_ArrayRef, ClassDataType_StringRef: {
        bCopyback = iType != ClassDataType_Array;
        iArraySize = __cls_GET_METHOD_PARAM_SIZE(__cls_call_sMethod, __cls_call_iParamsNum);

        // Push "copyback" argument
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
    }

    // Shift argument address
    #emit LOAD.S.pri iArgAddr
    #emit CONST.alt 4
    #emit ADD
    #emit STOR.S.pri iArgAddr

    __cls_call_iParamsNum++;
  }
}

/*--------------------------------[ Internal Helpers Functions] --------------------------------*/

static stock __cls_DestroyMethodsTrie(&Trie:itMethods) {
  new TrieIter:iMethodsIter = TrieIterCreate(itMethods);

  while (!TrieIterEnded(iMethodsIter)) {
    new Struct:sMethod; TrieIterGetCell(iMethodsIter, sMethod);

    __cls_DestroyMethod(sMethod);

    TrieIterNext(iMethodsIter);
  }

  TrieIterDestroy(iMethodsIter);

  TrieDestroy(itMethods);
}

static stock __cls_ParseParamTypes(&Array:irgArgs, &Array:irgParamTypes) {
  new iArgc = ArraySize(irgArgs);

  new rgParam[__cls_MethodParamData];

  for (new iArg = 0; iArg < iArgc; ++iArg) {
    rgParam[__cls_MethodParamData_Type] = ArrayGetCell(irgArgs, iArg);
    rgParam[__cls_MethodParamData_Size] = 1;

    switch (rgParam[__cls_MethodParamData_Type]) {
      case ClassDataType_Array, ClassDataType_ArrayRef, ClassDataType_StringRef: {
        rgParam[__cls_MethodParamData_Size] = ArrayGetCell(irgArgs, ++iArg);
      }
      case ClassDataType_ParamsCellArray: {
        rgParam[__cls_MethodParamData_Size] = 0;

        new Array:irgExtraParamTypes = ArrayGetCell(irgArgs, ++iArg);
        __cls_ParseParamTypes(irgExtraParamTypes, irgParamTypes);
      }
    }

    if (rgParam[__cls_MethodParamData_Size]) {
      ArrayPushArray(irgParamTypes, rgParam[any:0], _:__cls_MethodParamData);
    }
  }
}

static stock __cls_ValidateParamPush(ClassDataType:iType) {
  if (__cls_call_iParamsNum >= __cls_call_iParamTypesNum) {
    if (__cls_GET_METHOD_DATA(__cls_call_sMethod, __cls_MethodData_VariadicParams)) {
      return 1;
    }

    static szMethod[CLASS_METHOD_MAX_NAME_LENGTH]; __cls_GET_METHOD_NAME(__cls_call_sMethod, szMethod);
    __cls_LOG_ERROR(__cls_err_NumberOfParametersExceeded, szMethod, __cls_call_iParamTypesNum, __cls_call_iParamsNum);
    return 0;
  }

  static ClassDataType:iExpectedType; iExpectedType = __cls_GET_METHOD_PARAM_TYPE(__cls_call_sMethod, __cls_call_iParamsNum);

  if (iType != iExpectedType) {
    static szMethodName[CLASS_METHOD_MAX_NAME_LENGTH]; __cls_GET_METHOD_NAME(__cls_call_sMethod, szMethodName);
    abort(AMX_ERR_PARAMS, __cls_err_InvalidParamType, __cls_call_iParamsNum, szMethodName, __cls_ParamTypeNames[iExpectedType], __cls_ParamTypeNames[iType]);
    return 0;
  }

  return 1;
}

static stock __cls_CompareParamTypes(const &Struct:sMethod, const &Array:irgParams) {  
  new iParamsNum = __cls_GET_METHOD_DATA(sMethod, __cls_MethodData_ParamTypesNum);
  new iParamsSize = ArraySize(irgParams);

  if (iParamsNum != iParamsSize) return false;

  for (new iParam = 0; iParam < iParamsNum; ++iParam) {
    new ClassDataType:iType = __cls_GET_METHOD_PARAM_TYPE(sMethod, iParam);
    if (iType != ArrayGetCell(irgParams, iParam, _:__cls_MethodParamData_Type)) return false;

    new iSize = __cls_GET_METHOD_PARAM_SIZE(sMethod, iParam);
    if (iSize != ArrayGetCell(irgParams, iParam, _:__cls_MethodParamData_Size)) return false;
  }

  return true;
}

/*--------------------------------[ Internal Find Functions] --------------------------------*/

static stock Struct:__cls_FindClassInternalMethodInHierarchy(const &Class:class, __cls_InternalMethod:iMethod) {
  static Class:sCurrentClass; sCurrentClass = class;

  do {
    static Struct:sMethod; sMethod = __cls_GET_CLASS_DATA_NESTED(sCurrentClass, __cls_Data_InternalMethods, iMethod);
    
    if (sMethod != Invalid_Struct) return sMethod;

    sCurrentClass = __cls_GET_CLASS_DATA(sCurrentClass, __cls_Data_Base);
  } while (sCurrentClass != Invalid_Class);

  return Invalid_Struct;
}

static stock Struct:__cls_FindClassMethodInHierarchy(const &Class:class, const szMethod[], __cls_MethodType:iMethodType) {
  static Class:sCurrentClass; sCurrentClass = class;

  static __cls_Data:iStructMethodsField = __cls_Data_Invalid;
  switch (iMethodType) {
    case __cls_MethodType_Method, __cls_MethodType_Virtual: {
      iStructMethodsField = __cls_Data_Methods;
    }
    // case __cls_MethodType_Getter: {
    //   iStructMethodsField = __cls_Data_Getters;
    // }
    // case __cls_MethodType_Setter: {
    //   iStructMethodsField = __cls_Data_Setters;
    // }
  }

  do {
    static Trie:itMethods; itMethods = __cls_GET_CLASS_DATA(sCurrentClass, iStructMethodsField);

    if (itMethods != Invalid_Trie) {
      static Struct:sMethod;
      if (TrieGetCell(itMethods, szMethod, sMethod)) return sMethod;
    }

    sCurrentClass = __cls_GET_CLASS_DATA(sCurrentClass, __cls_Data_Base);
  } while (sCurrentClass != Invalid_Class);

  static szName[32]; ClassGetMetadataString(Class:class, "__NAME", szName, charsmax(szName));
  __cls_DebugMessage("Cannot find method ^"%s^" in class ^"%s^"", szMethod, szName);

  return Invalid_Struct;
}

/*--------------------------------[ Internal Getter Functions] --------------------------------*/

static stock Function:__cls_GetCallMethodFunctionPointer() {
  static Function:func; func = __cls_GET_METHOD_DATA(__cls_call_sMethod, __cls_MethodData_Function);

  if (func == Invalid_FunctionPointer) {
    static szMethod[CLASS_METHOD_MAX_NAME_LENGTH]; __cls_GET_METHOD_NAME(__cls_call_sMethod, szMethod);
    set_fail_state(__cls_err_NotImplementedMethod, szMethod);
  }

  return func;
}

static stock Class:__cls_GetInstanceClass(const &ClassInstance:pInstance) {
  if (pInstance != __cls_cache_InstanceClass[__cls_InstanceCache_Instance]) {
    __cls_cache_InstanceClass[__cls_InstanceCache_Value] = __cls_GET_INSTANCE_DATA(pInstance, __cls_InstanceData_Class);
    __cls_cache_InstanceClass[__cls_InstanceCache_Instance] = pInstance;
  }

  return __cls_cache_InstanceClass[__cls_InstanceCache_Value];
}

static stock Trie:__cls_GetInstanceMembersTrie(const &ClassInstance:pInstance, bool:bWrite = false) {
  if (
    pInstance != __cls_cache_InstanceMembers[__cls_InstanceCache_Instance] ||
    (__cls_cache_InstanceMembers[__cls_InstanceCache_Value] == Invalid_Trie && bWrite)
  ) {
    __cls_cache_InstanceMembers[__cls_InstanceCache_Value] = __cls_GET_INSTANCE_DATA(pInstance, __cls_InstanceData_Members);

    if (__cls_cache_InstanceMembers[__cls_InstanceCache_Value] == Invalid_Trie && bWrite) {
      __cls_cache_InstanceMembers[__cls_InstanceCache_Value] = TrieCreate();
      __cls_SET_INSTANCE_DATA(pInstance, __cls_InstanceData_Members, __cls_cache_InstanceMembers[__cls_InstanceCache_Value]);
    }

    __cls_cache_InstanceMembers[__cls_InstanceCache_Instance] = pInstance;
  }

  return __cls_cache_InstanceMembers[__cls_InstanceCache_Value];
}

// static stock Trie:__cls_GetInstanceGettersTrie(const &ClassInstance:pInstance) {
//   if (pInstance != __cls_cache_InstanceGetters[__cls_InstanceCache_Instance]) {
//     static Class:class; class = __cls_GetInstanceClass(pInstance);
//     __cls_cache_InstanceGetters[__cls_InstanceCache_Value] = __cls_GetClassMethodsTrie(class, __cls_MethodType_Getter, false);
//     __cls_cache_InstanceGetters[__cls_InstanceCache_Instance] = pInstance;
//   }

//   return __cls_cache_InstanceGetters[__cls_InstanceCache_Value];
// }

// static stock Trie:__cls_GetInstanceSettersTrie(const &ClassInstance:pInstance) {
//   if (pInstance != __cls_cache_InstanceSetters[__cls_InstanceCache_Instance]) {
//     static Class:class; class = __cls_GetInstanceClass(pInstance);
//     __cls_cache_InstanceSetters[__cls_InstanceCache_Value] = __cls_GetClassMethodsTrie(class, __cls_MethodType_Setter, false);
//     __cls_cache_InstanceSetters[__cls_InstanceCache_Instance] = pInstance;
//   }

//   return __cls_cache_InstanceSetters[__cls_InstanceCache_Value];
// }

static stock Trie:__cls_GetClassMembersTrie(const &Class:class, bool:bWrite = false) {
  static Trie:itMembers; itMembers = __cls_GET_CLASS_DATA(class, __cls_Data_Members);

  if (itMembers == Invalid_Trie && bWrite) {
    itMembers = TrieCreate();
    __cls_SET_CLASS_DATA(class, __cls_Data_Members, itMembers);
  }

  return itMembers;
}

static stock Trie:__cls_GetClassMethodsTrie(const &Class:class, bool:bWrite = false) {
  static Trie:itMethods; itMethods = __cls_GET_CLASS_DATA(class, __cls_Data_Methods);

  if (itMethods == Invalid_Trie && bWrite) {
    itMethods = TrieCreate();

    if (__cls_IS_CACHED_HANDLE(class)) {
      __cls_rgCachedClasses[__cls_HANDLE_TO_CACHE_INDEX(class)][__cls_Data_Methods] = itMethods;
    } else {
      StructSetCell(Struct:class, __cls_Data_Methods, itMethods);
    }
  }

  return itMethods;
}

/*--------------------------------[ Internal Debug Functions] --------------------------------*/

#if defined __cls_DEBUG
  static stock __cls_LogExecution() {
    static Struct:sClass; sClass = __cls_GET_METHOD_DATA(__cls_call_sMethod, __cls_MethodData_Class);
    static szName[32]; ClassGetMetadataString(Class:sClass, "__NAME", szName, charsmax(szName));
    static szMethodName[CLASS_METHOD_MAX_NAME_LENGTH]; __cls_GET_METHOD_NAME(__cls_call_sMethod, szMethodName);

    if (__cls_IS_EMPTY_STR(szName)) {
      format(szName, charsmax(szName), "CLASS_%d", sClass);
    }

    // static iParamsNum; iParamsNum = __cls_GET_METHOD_DATA(__cls_call_sMethod, __cls_MethodData_ParamTypesNum);
    // static iBufferOffset; iBufferOffset = __cls_call_iBufferPos;

    static szArgs[4];
    // static szArgs[1024];
    // static iPos; iPos = 0;
    // static iMaxLen; iMaxLen = charsmax(szArgs);

    // static const iMaxStrLen = 16;

    // for (new iParam = 0; iParam < iParamsNum; ++iParam) {
    //   if (iParam > 0) {
    //     iPos += copy(szArgs[iPos], iMaxLen - iPos, ", ");
    //   }

    //   static ClassDataType:iParamType; iParamType = __cls_GET_METHOD_PARAM_TYPE(__cls_call_sMethod, iParam);

    //   switch (iParamType) {
    //     case ClassDataType_Cell: {
    //       iPos += format(szArgs[iPos], iMaxLen - iPos, "%d", __cls_rgBuffer[iBufferOffset]);
    //       iBufferOffset++;
    //     }
    //     case ClassDataType_String: {
    //       static iLen; iLen = __cls_rgBuffer[iBufferOffset++] - 1;

    //       iPos += copy(szArgs[iPos], iMaxLen - iPos, "^"");

    //       if (iLen > iMaxStrLen) {
    //         static iMaxSegmentLen; iMaxSegmentLen = (iMaxStrLen - 3) / 2;

    //         // server_print("STRING: %s", __cls_rgBuffer[iBufferOffset]);
    //         iPos += format(szArgs[iPos], __cls_MIN(iMaxLen - iPos, iMaxSegmentLen), "%s", __cls_rgBuffer[iBufferOffset]);
    //         iPos += copy(szArgs[iPos], iMaxLen - iPos, "...");
    //         iPos += format(szArgs[iPos], __cls_MIN(iMaxLen - iPos, iMaxSegmentLen), "%s", __cls_rgBuffer[iBufferOffset + iLen - iMaxSegmentLen]);
    //       } else {
    //         iPos += copy(szArgs[iPos], __cls_MIN(iMaxLen - iPos, iLen), __cls_rgBuffer[iBufferOffset]);
    //       }

    //       iPos += copy(szArgs[iPos], iMaxLen - iPos, "^"");

    //       iBufferOffset += iLen + 1;
    //     }
    //     case ClassDataType_Array: {
    //       static iSize; iSize = __cls_GET_METHOD_PARAM_SIZE(__cls_call_sMethod, iParam);

    //       iPos += copy(szArgs[iPos], iMaxLen - iPos, "{");

    //       for (new i = 0; i < iSize; ++i) {
    //         if (i > 0) {
    //           iPos += copy(szArgs[iPos], iMaxLen - iPos, ", ");
    //         }

    //         iPos += format(szArgs[iPos], iMaxLen - iPos, "%d", __cls_rgBuffer[iBufferOffset++]);
    //       }

    //       iPos += copy(szArgs[iPos], iMaxLen - iPos, "}");

    //       iBufferOffset += iSize;
    //     }
    //     case ClassDataType_CellRef: {
    //       iPos += copy(szArgs[iPos], iMaxLen - iPos, "&");
    //       iBufferOffset++;
    //     }
    //     case ClassDataType_ArrayRef, ClassDataType_StringRef: {
    //       iPos += copy(szArgs[iPos], iMaxLen - iPos, "[]");
    //       static iSize; iSize = __cls_GET_METHOD_PARAM_SIZE(__cls_call_sMethod, iParam);
    //       iBufferOffset += iSize;
    //     }
    //   }
    // }

    __cls_DebugMessage("[%d] %s::%s%s(%s) %d", __cls_call_pInstance, szName, __cls_IS_CACHED_HANDLE(__cls_call_sMethod) ? "^^" : "", szMethodName, szArgs, __cls_call_iBufferPos);
    // __cls_DebugMessage("[%d] %s::%s(...)", __cls_call_pInstance, szName, szMethodName);
  }

  static stock __cls_DebugMessage(const szFormat[], any:...) {
    static szMessage[MAX_FMT_LENGTH];
    vformat(szMessage, charsmax(szMessage), szFormat, 2);
    engfunc(EngFunc_AlertMessage, at_aiconsole, "%s^n", szMessage);
  }
#else
  static stock __cls_LogExecution() {}
  static stock __cls_DebugMessage(any:...) {}
#endif
