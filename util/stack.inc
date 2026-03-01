#if defined _stack_included
  #endinput
#endif

#define _stack_included

#define STACK_DEFINE(%1,%2) static __stack_%1_size = 0; static any:__stack_%1_data[%2]
#define STACK_PUSH(%1,%2) __stack_%1_data[__stack_%1_size++] = %2
#define STACK_POP(%1) __stack_%1_data[--__stack_%1_size]
#define STACK_READ(%1) __stack_%1_data[__stack_%1_size - 1]
#define STACK_PATCH(%1,%2) __stack_%1_data[__stack_%1_size - 1] = %2
#define STACK_SIZE(%1) __stack_%1_size
#define STACK_EMPTY(%1) !__stack_%1_size
