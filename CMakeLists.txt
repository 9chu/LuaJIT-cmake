# CMakeList rewrite version from Makefile of the Luajit project.
# Aim to integrate into other projects, no installation target provided.
# Created by chu <http://github.com/9chu>.
# Some code taken from LuaDist,Torch7 and luavit, contribute by Peter Drahoš, Ronan Collobert.
# Redistribution and use of this file is allowed according to the terms of the MIT license.

cmake_minimum_required(VERSION 3.1)
project(LuaJIT C ASM)

include(CheckCCompilerFlag)
include(CheckLibraryExists)

include(cmake/BuildHostTools.cmake)

##############################################################################
################################## OPTIONS  ##################################
##############################################################################

option(LUAJIT_OPTION_MORE_WARNINGS "Enable more warnings" OFF)

set(LUAJIT_OPTION_BUILD_MODE "mixed" CACHE STRING "Default build mode is mixed mode on POSIX, dynamic on Windows")
set_property(CACHE LUAJIT_OPTION_BUILD_MODE PROPERTY STRINGS "mixed" "static" "dynamic")

option(LUAJIT_OPTION_DISABLE_FFI "Permanently disable the FFI extension" OFF)
option(LUAJIT_OPTION_ENABLE_LUA52COMPAT "Enable partial 5.2 features" OFF)
option(LUAJIT_OPTION_DISABLE_JIT "Disable the JIT compiler" OFF)
set(LUAJIT_OPTION_NUMMODE "0" CACHE STRING "Some architectures (e.g. PPC) can use either single-number (1) or dual-number (2) mode")
set_property(CACHE LUAJIT_OPTION_NUMMODE PROPERTY STRINGS "0" "1" "2")
option(LUAJIT_OPTION_DISABLE_GC64 "Disable LJ_GC64 mode for x64" OFF)

option(LUAJIT_OPTION_USE_SYSMALLOC "Use the system provided memory allocator" OFF)
option(LUAJIT_OPTION_USE_VALGRIND "Run LuaJIT under Valgrind" OFF)
option(LUAJIT_OPTION_USE_GDBJIT "Enable GDBJIT support" OFF)
option(LUAJIT_OPTION_USE_APICHECK "Turn on assertions for the Lua/C API" OFF)
option(LUAJIT_OPTION_USE_ASSERT "Turn on assertions for the whole LuaJIT VM" OFF)

##############################################################################
##################################  VERSION  #################################
##############################################################################

set(MAJVER 2)
set(MINVER 1)
set(RELVER 0)
set(PREREL "-beta3")
set(VERSION ${MAJVER}.${MINVER}.${RELVER}${PREREL})

set(ABIVER "5.1")
set(NODOTABIVER 51)

message(STATUS "LuaJIT Version: ${VERSION}")

##############################################################################
#############################  COMPILER OPTIONS  #############################
##############################################################################

if(LUAJIT_OPTION_MORE_WARNINGS)
    check_c_compiler_flag("-Wextra -Wdeclaration-after-statement -Wredundant-decls -Wshadow -Wpointer-arith" HAS_MORE_WARNS)
    if(HAS_MORE_WARNS)
        set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -Wextra -Wdeclaration-after-statement -Wredundant-decls -Wshadow -Wpointer-arith")
    endif()
else()
    check_c_compiler_flag("-Wall" HAS_W_ALL)
    if(HAS_W_ALL)
        set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -Wall")
    endif()
endif()

##############################################################################
################################  BUILD MODE  ################################
##############################################################################

set(BUILDMODE "mixed")
if(LUAJIT_OPTION_BUILD_MODE STREQUAL "static")
    set(BUILDMODE "static")
elseif(LUAJIT_OPTION_BUILD_MODE STREQUAL "dynamic")
    set(BUILDMODE "dynamic")
elseif(NOT LUAJIT_OPTION_BUILD_MODE STREQUAL "mixed")
    message(FATAL_ERROR "Unexpected build mode ${LUAJIT_OPTION_BUILD_MODE}")
endif()

##############################################################################
#################################  FEATURES  #################################
##############################################################################

set(XCFLAGS)

if(LUAJIT_OPTION_DISABLE_FFI)
    message(STATUS "Disable FFI")
    list(APPEND XCFLAGS "-DLUAJIT_DISABLE_FFI")
endif()

if(LUAJIT_OPTION_ENABLE_LUA52COMPAT)
    message(STATUS "Enable Lua52 compat")
    list(APPEND XCFLAGS "-DLUAJIT_ENABLE_LUA52COMPAT")
endif()

if(LUAJIT_OPTION_DISABLE_JIT)
    message(STATUS "Disable JIT")
    list(APPEND XCFLAGS "-DLUAJIT_DISABLE_JIT")
endif()

if(LUAJIT_OPTION_NUMMODE STREQUAL "1")
    message(STATUS "Enable single-number mode")
    list(APPEND XCFLAGS "-DLUAJIT_NUMMODE=1")
elseif(LUAJIT_OPTION_NUMMODE STREQUAL "2")
    message(STATUS "Enable dual-number mode")
    list(APPEND XCFLAGS "-DLUAJIT_NUMMODE=2")
endif()

if(LUAJIT_OPTION_DISABLE_GC64)
    message(STATUS "Disable GC64")
    list(APPEND XCFLAGS "-DLUAJIT_DISABLE_GC64")
endif()

##### DEBUGGING SUPPORT

if(LUAJIT_OPTION_USE_SYSMALLOC)
    message(STATUS "Enable system malloc")
    list(APPEND XCFLAGS "-DLUAJIT_USE_SYSMALLOC")
endif()

if(LUAJIT_OPTION_USE_VALGRIND)
    message(STATUS "Enable valgrind support")
    list(APPEND XCFLAGS "-DLUAJIT_USE_VALGRIND")
endif()

if(LUAJIT_OPTION_USE_GDBJIT)
    message(STATUS "Use GDBJIT")
    list(APPEND XCFLAGS "-DLUAJIT_USE_GDBJIT")
endif()

if(LUAJIT_OPTION_USE_APICHECK)
    message(STATUS "Use API Check")
    list(APPEND XCFLAGS "-DLUA_USE_APICHECK")
endif()

if(LUAJIT_OPTION_USE_ASSERT)
    message(STATUS "Turn on all assert")
    list(APPEND XCFLAGS "-DLUA_USE_ASSERT")
endif()

set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} ${XCFLAGS}")

##############################################################################
# Host build stage (Cross-compiling)
##############################################################################

# https://stackoverflow.com/questions/36084785/building-a-tool-immediately-so-it-can-be-used-later-in-same-cmake-run
set(LUAJIT_HOST_BUILD_STAGE OFF CACHE INTERNAL "Is host build stage? (for cross-compiling / internal usage)")
if(LUAJIT_HOST_BUILD_STAGE)
    set(LUAJIT_HOST_BUILD_OPTION_TARGET_SYS "" CACHE STRING "")
    set(LUAJIT_HOST_BUILD_OPTION_DASM_ARCH "" CACHE STRING "")
    set(LUAJIT_HOST_BUILD_OPTION_DASM_VER "" CACHE STRING "")
    option(LUAJIT_HOST_BUILD_OPTION_DASM_LE "" 0)
    option(LUAJIT_HOST_BUILD_OPTION_DASM_BIT64 "" 0)
    option(LUAJIT_HOST_BUILD_OPTION_DASM_HASJIT "" 0)
    option(LUAJIT_HOST_BUILD_OPTION_DASM_HASFFI "" 0)
    option(LUAJIT_HOST_BUILD_OPTION_DASM_DUALNUM "" 0)
    option(LUAJIT_HOST_BUILD_OPTION_DASM_HASFPU "" 0)
    option(LUAJIT_HOST_BUILD_OPTION_DASM_SOFTFP "" 0)
    option(LUAJIT_HOST_BUILD_OPTION_DASM_NOUNWIND "" 0)
    option(LUAJIT_HOST_BUILD_OPTION_DASM_IOS "" 0)
    option(LUAJIT_HOST_BUILD_OPTION_DASM_MIPSR6 "" 0)
    option(LUAJIT_HOST_BUILD_OPTION_DASM_PPC_SQRT "" 0)
    option(LUAJIT_HOST_BUILD_OPTION_DASM_PPC_ROUND "" 0)
    option(LUAJIT_HOST_BUILD_OPTION_DASM_PPC32ON64 "" 0)
    option(LUAJIT_HOST_BUILD_OPTION_DASM_PPC_OPD "" 0)
    option(LUAJIT_HOST_BUILD_OPTION_DASM_PPC_OPDENV "" 0)
    option(LUAJIT_HOST_BUILD_OPTION_DASM_PPC_ELFV2 "" 0)
    set(LUAJIT_HOST_BUILD_OPTION_TARGET_ARCH_AARCH64EB "" CACHE STRING "")
    set(LUAJIT_HOST_BUILD_OPTION_TARGET_ARCH_ENDIAN "" CACHE STRING "")
    set(LUAJIT_HOST_BUILD_OPTION_TARGET_ARCH_MIPSEL "" CACHE STRING "")
    set(LUAJIT_HOST_BUILD_OPTION_TARGET_ARCH_CELLOS_LV2 "" CACHE STRING "")
    set(LUAJIT_HOST_BUILD_OPTION_TARGET_ARCH_HASFPU "0" CACHE STRING "")
    set(LUAJIT_HOST_BUILD_OPTION_TARGET_ARCH_SOFTFP "0" CACHE STRING "")
    set(LUAJIT_HOST_BUILD_OPTION_TARGET_ARCH_NO_UNWIND "" CACHE STRING "")
    set(LUAJIT_HOST_BUILD_OPTION_TARGET_LJARCH "" CACHE STRING "")

    luajit_build_host_tools(
        TARGET_SYS "${LUAJIT_HOST_BUILD_OPTION_TARGET_SYS}"
        DASM_SCRIPT "${CMAKE_CURRENT_SOURCE_DIR}/dynasm/dynasm.lua"
        DASM_SOURCE "${CMAKE_CURRENT_SOURCE_DIR}/src/vm_${LUAJIT_HOST_BUILD_OPTION_DASM_ARCH}.dasc"
        DASM_VER "${LUAJIT_HOST_BUILD_OPTION_DASM_VER}"
        DASM_LE ${LUAJIT_HOST_BUILD_OPTION_DASM_LE}
        DASM_BIT64 ${LUAJIT_HOST_BUILD_OPTION_DASM_BIT64}
        DASM_HASJIT ${LUAJIT_HOST_BUILD_OPTION_DASM_HASJIT}
        DASM_HASFFI ${LUAJIT_HOST_BUILD_OPTION_DASM_HASFFI}
        DASM_DUALNUM ${LUAJIT_HOST_BUILD_OPTION_DASM_DUALNUM}
        DASM_HASFPU ${LUAJIT_HOST_BUILD_OPTION_DASM_HASFPU}
        DASM_SOFTFP ${LUAJIT_HOST_BUILD_OPTION_DASM_SOFTFP}
        DASM_NOUNWIND ${LUAJIT_HOST_BUILD_OPTION_DASM_NOUNWIND}
        DASM_IOS ${LUAJIT_HOST_BUILD_OPTION_DASM_IOS}
        DASM_MIPSR6 ${LUAJIT_HOST_BUILD_OPTION_DASM_MIPSR6}
        DASM_PPC_SQRT ${LUAJIT_HOST_BUILD_OPTION_DASM_PPC_SQRT}
        DASM_PPC_ROUND ${LUAJIT_HOST_BUILD_OPTION_DASM_PPC_ROUND}
        DASM_PPC32ON64 ${LUAJIT_HOST_BUILD_OPTION_DASM_PPC32ON64}
        DASM_PPC_OPD ${LUAJIT_HOST_BUILD_OPTION_DASM_PPC_OPD}
        DASM_PPC_OPDENV ${LUAJIT_HOST_BUILD_OPTION_DASM_PPC_OPDENV}
        DASM_PPC_ELFV2 ${LUAJIT_HOST_BUILD_OPTION_DASM_PPC_ELFV2}
        TARGET_ARCH_AARCH64EB "${LUAJIT_HOST_BUILD_OPTION_TARGET_ARCH_AARCH64EB}"
        TARGET_ARCH_ENDIAN "${LUAJIT_HOST_BUILD_OPTION_TARGET_ARCH_ENDIAN}"
        TARGET_ARCH_MIPSEL "${LUAJIT_HOST_BUILD_OPTION_TARGET_ARCH_MIPSEL}"
        TARGET_ARCH_CELLOS_LV2 "${LUAJIT_HOST_BUILD_OPTION_TARGET_ARCH_CELLOS_LV2}"
        TARGET_ARCH_HASFPU "${LUAJIT_HOST_BUILD_OPTION_TARGET_ARCH_HASFPU}"
        TARGET_ARCH_SOFTFP "${LUAJIT_HOST_BUILD_OPTION_TARGET_ARCH_SOFTFP}"
        TARGET_ARCH_NO_UNWIND "${LUAJIT_HOST_BUILD_OPTION_TARGET_ARCH_NO_UNWIND}"
        TARGET_LJARCH "${LUAJIT_HOST_BUILD_OPTION_TARGET_LJARCH}"
        MINILUA_SOURCES
            "${CMAKE_CURRENT_SOURCE_DIR}/src/host/minilua.c"
        BUILDVM_SOURCES
            "${CMAKE_CURRENT_SOURCE_DIR}/src/host/buildvm.c"
            "${CMAKE_CURRENT_SOURCE_DIR}/src/host/buildvm_asm.c"
            "${CMAKE_CURRENT_SOURCE_DIR}/src/host/buildvm_peobj.c"
            "${CMAKE_CURRENT_SOURCE_DIR}/src/host/buildvm_lib.c"
            "${CMAKE_CURRENT_SOURCE_DIR}/src/host/buildvm_fold.c"
        BUILDVM_INCLUDES
            "${CMAKE_CURRENT_SOURCE_DIR}/src"
    )
    return()  # finish host build stage
endif()

##############################################################################
# Flags and options for target.
##############################################################################

set(CMAKE_REQUIRED_INCLUDES "${CMAKE_REQUIRED_INCLUDES}" "${CMAKE_CURRENT_SOURCE_DIR}/src")
set(CMAKE_REQUIRED_DEFINITIONS "${CMAKE_REQUIRED_DEFINITIONS} ${XCFLAGS}")

macro(test_target_arch_defined TEST_VAR)
    check_c_source_compiles("
#undef ${TEST_VAR}
#include \"lj_arch.h\"
#if ${TEST_VAR}
int main() { return 0; }
#else
#error \"Not defined\"
#endif
" ${TEST_VAR})
endmacro()

macro(test_target_arch_equals TEST_VAR EXPECT_VALUE)
    check_c_source_compiles("
#undef ${TEST_VAR}
#include \"lj_arch.h\"
#if ${TEST_VAR} == ${EXPECT_VALUE}
int main() { return 0; }
#else
#error \"Not defined\"
#endif
" ${TEST_VAR}_${EXPECT_VALUE})
endmacro()

set(TARGET_SYS "")
set(TARGET_ARCH)
set(TARGET_XCFLAGS "-D_FILE_OFFSET_BITS=64" "-D_LARGEFILE_SOURCE" "-U_FORTIFY_SOURCE")
set(TARGET_XLIBS)
#set(TARGET_STRIP)
#set(TARGET_XLDFLAGS)
#set(TARGET_XSHLDFLAGS)

check_library_exists(m pow "" HAS_LIBM)
if(HAS_LIBM)
    list(APPEND TARGET_XLIBS "m")
endif()

test_target_arch_defined(LJ_TARGET_X64)
if(LJ_TARGET_X64)
    set(TARGET_LJARCH "x64")
else()
    test_target_arch_defined(LJ_TARGET_X86)
    if(LJ_TARGET_X86)
        set(TARGET_LJARCH "x86")
    else()
        test_target_arch_defined(LJ_TARGET_ARM)
        if(LJ_TARGET_ARM)
            set(TARGET_LJARCH "arm")
        else()
            test_target_arch_defined(LJ_TARGET_S390X)
            if(LJ_TARGET_S390X)
                set(TARGET_LJARCH "s390x")
            else()
                test_target_arch_defined(LJ_TARGET_ARM64)
                if(LJ_TARGET_ARM64)
                    test_target_arch_defined(__AARCH64EB__)
                    if(__AARCH64EB__)
                        list(APPEND TARGET_ARCH "-D__AARCH64EB__=1")
                        set(TARGET_ARCH_AARCH64EB 1)
                    endif()
                    set(TARGET_LJARCH "arm64")
                else()
                    test_target_arch_defined(LJ_TARGET_PPC)
                    if(LJ_TARGET_PPC)
                        test_target_arch_equals(LJ_LE 1)
                        if(LJ_LE_1)
                            list(APPEND TARGET_ARCH "-DLJ_ARCH_ENDIAN=LUAJIT_LE")
                            set(TARGET_ARCH_ENDIAN "LUAJIT_LE")
                        else()
                            list(APPEND TARGET_ARCH "-DLJ_ARCH_ENDIAN=LUAJIT_BE")
                            set(TARGET_ARCH_ENDIAN "LUAJIT_BE")
                        endif()
                        set(TARGET_LJARCH "ppc")
                    else()
                        test_target_arch_defined(LJ_TARGET_MIPS)
                        if(LJ_TARGET_MIPS)
                            test_target_arch_defined(MIPSEL)
                            if(MIPSEL)
                                list(APPEND TARGET_ARCH "-D__MIPSEL__=1")
                                set(TARGET_ARCH_MIPSEL 1)
                            endif()
                            test_target_arch_defined(LJ_TARGET_MIPS64)
                            if(LJ_TARGET_MIPS64)
                                set(TARGET_LJARCH "mips64")
                            else()
                                set(TARGET_LJARCH "mips")
                            endif()
                        else()
                            message(FATAL_ERROR "Unsupported target architecture")
                        endif()
                    endif()
                endif()
            endif()
        endif()
    endif()
endif()

test_target_arch_equals(LJ_TARGET_PS3 1)
if(LJ_TARGET_PS3_1)
    set(TARGET_SYS "PS3")
    list(APPEND TARGET_ARCH "-D__CELLOS_LV2__")
    set(TARGET_ARCH_CELLOS_LV2 1)
    list(APPEND TARGET_XCFLAGS "-DLUAJIT_USE_SYSMALLOC")

    find_package(Threads REQUIRED)
    list(APPEND TARGET_XLIBS "Threads::Threads")
endif()

if(TARGET_LJARCH STREQUAL "x86")
    check_c_compiler_flag("-msse" HAS_SSE)
    if(HAS_SSE)
        list(APPEND TARGET_XCFLAGS "-msse")
    endif()

    check_c_compiler_flag("-msse2" HAS_SSE2)
    if(HAS_SSE2)
        list(APPEND TARGET_XCFLAGS "-msse2")
    endif()

    check_c_compiler_flag("-mfpmath=sse" HAS_FPMATH_SSE)
    if(HAS_FPMATH_SSE)
        list(APPEND TARGET_XCFLAGS "-mfpmath=sse")
    endif()
endif()
if(TARGET_LJARCH STREQUAL "x64")  # for lj_str_hash
    check_c_compiler_flag("-msse4.2" HAS_SSE_42)
    if(HAS_SSE_42)
        list(APPEND TARGET_XCFLAGS "-msse4.2")
    endif()
endif()

test_target_arch_equals(LJ_ARCH_HASFPU 1)
if(LJ_ARCH_HASFPU_1)
    list(APPEND TARGET_ARCH "-DLJ_ARCH_HASFPU=1")
    set(TARGET_ARCH_HASFPU 1)
else()
    list(APPEND TARGET_ARCH "-DLJ_ARCH_HASFPU=0")
    set(TARGET_ARCH_HASFPU 0)
endif()

test_target_arch_equals(LJ_ABI_SOFTFP 1)
if(LJ_ABI_SOFTFP_1)
    list(APPEND TARGET_ARCH "-DLJ_ABI_SOFTFP=1")
    set(TARGET_ARCH_SOFTFP 1)
else()
    list(APPEND TARGET_ARCH "-DLJ_ABI_SOFTFP=0")
    set(TARGET_ARCH_SOFTFP 0)
endif()

test_target_arch_equals(LJ_NO_UNWIND 1)
if(LJ_NO_UNWIND_1)
    list(APPEND TARGET_ARCH "-DLUAJIT_NO_UNWIND")
    set(TARGET_ARCH_NO_UNWIND 1)
endif()

list(APPEND TARGET_ARCH "-DLUAJIT_TARGET=LUAJIT_ARCH_${TARGET_LJARCH}")

# FIXME: handle -DLUA_ROOT, -DLUA_MULTILIB
# FIXME: since this CMakeLists doesn't handle install step, these options are ignored

##############################################################################
# Target system detection.
##############################################################################

if(TARGET_SYS STREQUAL "")
    test_target_arch_equals(LUAJIT_OS 1)
    if(LUAJIT_OS_1)
        set(TARGET_SYS "Windows")
    else()
        test_target_arch_equals(LUAJIT_OS 2)
        if(LUAJIT_OS_2)
            set(TARGET_SYS "Linux")
        else()
            test_target_arch_equals(LUAJIT_OS 3)
            if(LUAJIT_OS_3)
                set(TARGET_SYS "Darwin")
                test_target_arch_equals(LJ_TARGET_IOS 1)
                if(LJ_TARGET_IOS_1)
                    set(TARGET_SYS "iOS")
                endif()
            else()
                test_target_arch_equals(LUAJIT_OS 4)
                if(LUAJIT_OS_4)
                    set(TARGET_SYS "GNU/kFreeBSD")
                else()
                    test_target_arch_equals(LUAJIT_OS 5)
                    if(LUAJIT_OS_5)
                        test_target_arch_equals(LJ_TARGET_SOLARIS 1)
                        if(LJ_TARGET_SOLARIS_1)
                            set(TARGET_SYS "SunOS")
                        else()
                            set(TARGET_SYS "Posix")
                        endif()
                    else()
                        set(TARGET_SYS "Unknown")
                    endif()
                endif()
            endif()
        endif()
    endif()
endif()

if(TARGET_SYS STREQUAL "Windows")
#    list(APPEND TARGET_STRIP "--strip-unneeded")
#    list(APPEND TARGET_XSHLDFLAGS "-shared -Wl,--out-implib libluajit-${ABIVER}.dll.a")
else()
    check_c_compiler_flag("-fno-stack-protector" HAS_NO_STACK_PROTECTOR)
    if(HAS_NO_STACK_PROTECTOR)
        list(APPEND TARGET_XCFLAGS "-fno-stack-protector")
    endif()
    if(TARGET_SYS STREQUAL "Darwin")
#        list(APPEND TARGET_STRIP "-x")
        list(APPEND TARGET_XCFLAGS "-DLUAJIT_UNWIND_EXTERNAL")
#        list(APPEND TARGET_XSHLDFLAGS "-dynamiclib -single_module -undefined dynamic_lookup -fPIC")
    else()
        if(TARGET_SYS STREQUAL "iOS")
#            list(APPEND TARGET_STRIP "-x")
#            list(APPEND TARGET_XSHLDFLAGS "-dynamiclib -single_module -undefined dynamic_lookup -fPIC")
            if(TARGET_LJARCH "arm64")
                check_c_compiler_flag("-fno-omit-frame-pointer" HAS_NO_OMIT_FRAME_POINTER)
                if(HAS_NO_OMIT_FRAME_POINTER)
                    list(APPEND TARGET_XCFLAGS "-fno-omit-frame-pointer")
                endif()
            endif()
        else()
            test_target_arch_equals(LJ_NO_UNWIND 1)
            if(NOT LJ_NO_UNWIND_1)
                execute_process(COMMAND bash "-c"
                    "exec 2>/dev/null; echo 'extern void b(void);int a(void){b();return 0;}' | ${CMAKE_C_COMPILER} -c -x c - -o tmpunwind.o && { grep -qa -e eh_frame -e __unwind_info tmpunwind.o || grep -qU -e eh_frame -e __unwind_info tmpunwind.o; } && echo E"
                    OUTPUT_VARIABLE TARGET_TESTUNWIND)
                if(${TARGET_TESTUNWIND} MATCHES "E")
                    list(APPEND TARGET_XCFLAGS "-DLUAJIT_UNWIND_EXTERNAL")
                endif()
            endif()
            if(NOT TARGET_SYS STREQUAL "SunOS")
                if(NOT TARGET_SYS STREQUAL "PS3")
#                    list(APPEND TARGET_XLDFLAGS "-Wl,-E")
                endif()
            endif()
            if(TARGET_SYS STREQUAL "Linux")
                list(APPEND TARGET_XLIBS "dl")
            endif()
            if(TARGET_SYS STREQUAL "GNU/kFreeBSD")
                list(APPEND TARGET_XLIBS "dl")
            endif()
        endif()
    endif()
endif()

message(STATUS "TARGET_SYS: ${TARGET_SYS}")
message(STATUS "TARGET_ARCH: ${TARGET_ARCH}")
message(STATUS "TARGET_XCFLAGS: ${TARGET_XCFLAGS}")
message(STATUS "TARGET_XLIBS: ${TARGET_XLIBS}")

##############################################################################
# Files and pathnames.
##############################################################################

# Collect flags for dasm

set(DASM_ARCH "${TARGET_LJARCH}")

set(DASM_LE 0)
set(DASM_BIT64 0)
set(DASM_HASJIT 0)
set(DASM_HASFFI 0)
set(DASM_DUALNUM 0)
set(DASM_HASFPU 0)
set(DASM_SOFTFP 0)
set(DASM_NOUNWIND 0)
set(DASM_IOS 0)
set(DASM_MIPSR6 0)
set(DASM_PPC_SQRT 0)
set(DASM_PPC_ROUND 0)
set(DASM_PPC32ON64 0)
set(DASM_PPC_OPD 0)
set(DASM_PPC_OPDENV 0)
set(DASM_PPC_ELFV2 0)

test_target_arch_equals(LJ_LE 1)
if(LJ_LE_1)
    set(DASM_LE 1)
endif()

test_target_arch_equals(LJ_ARCH_BITS 64)
if(LJ_ARCH_BITS_64)
    set(DASM_BIT64 1)
endif()

test_target_arch_equals(LJ_HASJIT 1)
if(LJ_HASJIT_1)
    set(DASM_HASJIT 1)
endif()

test_target_arch_equals(LJ_HASFFI 1)
if(LJ_HASFFI_1)
    set(DASM_HASFFI 1)
endif()

test_target_arch_equals(LJ_DUALNUM 1)
if(LJ_DUALNUM_1)
    set(DASM_DUALNUM 1)
endif()

test_target_arch_equals(LJ_ARCH_HASFPU 1)
if(LJ_ARCH_HASFPU_1)
    set(DASM_HASFPU 1)
endif()

test_target_arch_equals(LJ_ABI_SOFTFP 1)
if(LJ_ABI_SOFTFP_1)
    set(DASM_SOFTFP 1)
endif()

test_target_arch_equals(LJ_NO_UNWIND 1)
if(LJ_NO_UNWIND_1)
    set(DASM_NOUNWIND 1)
endif()

if(TARGET_LJARCH STREQUAL "x64")
    test_target_arch_equals(LJ_FR2 1)
    if(NOT LJ_FR2_1)
        set(DASM_ARCH "x86")
    endif()
else()
    if(TARGET_LJARCH STREQUAL "arm")
        if(TARGET_SYS STREQUAL "iOS")
            set(DASM_IOS 1)
        endif()
    else()
        test_target_arch_defined(LJ_TARGET_MIPSR6)
        if(LJ_TARGET_MIPSR6)
            set(DASM_MIPSR6 1)
        endif()
        if(TARGET_LJARCH STREQUAL "ppc")
            test_target_arch_equals(LJ_ARCH_SQRT 1)
            if(LJ_ARCH_SQRT_1)
                set(DASM_PPC_SQRT 1)
            endif()

            test_target_arch_equals(LJ_ARCH_ROUND 1)
            if(LJ_ARCH_ROUND_1)
                set(DASM_PPC_ROUND 1)
            endif()

            test_target_arch_equals(LJ_ARCH_PPC32ON64 1)
            if(LJ_ARCH_PPC32ON64_1)
                set(DASM_PPC32ON64 1)
            endif()

            test_target_arch_equals(LJ_ARCH_PPC_OPD 1)
            if(LJ_ARCH_PPC_OPD_1)
                set(DASM_PPC_OPD 1)
            endif()

            test_target_arch_equals(LJ_ARCH_PPC_OPDENV 1)
            if(LJ_ARCH_PPC_OPDENV_1)
                set(DASM_PPC_OPDENV 1)
            endif()

            test_target_arch_equals(LJ_ARCH_PPC_ELFV2 1)
            if(LJ_ARCH_PPC_ELFV2_1)
                set(DASM_PPC_ELFV2 1)
            endif()
        endif()
    endif()
endif()

set(LJ_ARCH_VERSION "")
foreach(LJ_ARCH_VERSION_TEST 0 10 20 40 50 51 60 61 70 80)
    test_target_arch_equals(LJ_ARCH_VERSION ${LJ_ARCH_VERSION_TEST})
    if(LJ_ARCH_VERSION_${LJ_ARCH_VERSION_TEST})
        set(LJ_ARCH_VERSION "${LJ_ARCH_VERSION_TEST}")
        break()
    endif()
endforeach()

set(DASM_VER "${LJ_ARCH_VERSION}")

# buildvm output

set(LJVM_MODE "elfasm")
set(LJVM_BOUT "lj_vm.S")

if(TARGET_SYS STREQUAL "Windows")
    set(LJVM_MODE "peobj")
    set(LJVM_BOUT "lj_vm.obj")
elseif(TARGET_SYS STREQUAL "Darwin")
    set(LJVM_MODE "machasm")
elseif(TARGET_SYS STREQUAL "iOS")
    set(LJVM_MODE "machasm")
endif()

# Core sources

set(LJLIB_C
    "${CMAKE_CURRENT_SOURCE_DIR}/src/lib_base.c"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/lib_math.c"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/lib_bit.c"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/lib_string.c"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/lib_table.c"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/lib_io.c"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/lib_os.c"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/lib_package.c"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/lib_debug.c"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/lib_jit.c"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/lib_ffi.c"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/lib_buffer.c")

set(LJCORE_C
    "${CMAKE_CURRENT_SOURCE_DIR}/src/lj_assert.c"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/lj_gc.c"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/lj_err.c"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/lj_char.c"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/lj_bc.c"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/lj_obj.c"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/lj_buf.c"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/lj_str.c"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/lj_tab.c"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/lj_func.c"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/lj_udata.c"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/lj_meta.c"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/lj_debug.c"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/lj_prng.c"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/lj_state.c"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/lj_dispatch.c"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/lj_vmevent.c"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/lj_vmmath.c"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/lj_strscan.c"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/lj_strfmt.c"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/lj_strfmt_num.c"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/lj_serialize.c"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/lj_api.c"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/lj_profile.c"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/lj_lex.c"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/lj_parse.c"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/lj_bcread.c"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/lj_bcwrite.c"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/lj_load.c"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/lj_ir.c"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/lj_opt_mem.c"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/lj_opt_fold.c"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/lj_opt_narrow.c"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/lj_opt_dce.c"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/lj_opt_loop.c"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/lj_opt_split.c"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/lj_opt_sink.c"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/lj_mcode.c"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/lj_snap.c"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/lj_record.c"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/lj_crecord.c"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/lj_ffrecord.c"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/lj_asm.c"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/lj_trace.c"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/lj_gdbjit.c"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/lj_ctype.c"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/lj_cdata.c"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/lj_cconv.c"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/lj_ccall.c"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/lj_ccallback.c"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/lj_carith.c"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/lj_clib.c"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/lj_cparse.c"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/lj_lib.c"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/lj_alloc.c"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/lib_aux.c"
    ${LJLIB_C}
    "${CMAKE_CURRENT_SOURCE_DIR}/src/lib_init.c"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/lj_init.c"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/lj_str_hash.c")

set(LJVMCORE_C "${CMAKE_CURRENT_BINARY_DIR}/${LJVM_BOUT}" "${LJCORE_C}")

##############################################################################
# Build mode handling.
##############################################################################

if(TARGET_SYS STREQUAL "SunOS")
    set(BUILDMODE "static")
elseif(TARGET_SYS STREQUAL "PS3")
    set(BUILDMODE "static")
endif()

##############################################################################
# Rules for generated files.
##############################################################################

if(CMAKE_CROSSCOMPILING)
    if(LUAJIT_HOST_BUILD_COMPLETED)
        message(STATUS "[CrossCompiling] Host build cached")
    else()
        message(STATUS "[CrossCompiling] Start host build")

        set(LUAJIT_HOST_BUILD_WORKDIR "${CMAKE_CURRENT_BINARY_DIR}/HostBuild/")
        execute_process(COMMAND ${CMAKE_COMMAND} -E make_directory "${LUAJIT_HOST_BUILD_WORKDIR}")

        # run host cmake
        execute_process(COMMAND "${CMAKE_COMMAND}"
            "-E" "env" "CC=" "CXX=" "LD="  # using host default compiler, FIXME: customize?
            "${CMAKE_COMMAND}"
            "-DCMAKE_BUILD_TYPE=RelWithDebInfo"
            "-DLUAJIT_OPTION_DISABLE_FFI=${LUAJIT_OPTION_DISABLE_FFI}"
            "-DLUAJIT_OPTION_ENABLE_LUA52COMPAT=${LUAJIT_OPTION_ENABLE_LUA52COMPAT}"
            "-DLUAJIT_OPTION_DISABLE_JIT=${LUAJIT_OPTION_DISABLE_JIT}"
            "-DLUAJIT_OPTION_NUMMODE=${LUAJIT_OPTION_NUMMODE}"
            "-DLUAJIT_OPTION_DISABLE_GC64=${LUAJIT_OPTION_DISABLE_GC64}"
            "-DLUAJIT_OPTION_USE_SYSMALLOC=${LUAJIT_OPTION_USE_SYSMALLOC}"
            "-DLUAJIT_OPTION_USE_VALGRIND=${LUAJIT_OPTION_USE_VALGRIND}"
            "-DLUAJIT_OPTION_USE_GDBJIT=${LUAJIT_OPTION_USE_GDBJIT}"
            "-DLUAJIT_OPTION_USE_APICHECK=${LUAJIT_OPTION_USE_APICHECK}"
            "-DLUAJIT_OPTION_USE_ASSERT=${LUAJIT_OPTION_USE_ASSERT}"
            "-DLUAJIT_HOST_BUILD_STAGE=ON"
            "-DLUAJIT_HOST_BUILD_OPTION_TARGET_SYS=${TARGET_SYS}"
            "-DLUAJIT_HOST_BUILD_OPTION_DASM_ARCH=${DASM_ARCH}"
            "-DLUAJIT_HOST_BUILD_OPTION_DASM_VER=${DASM_VER}"
            "-DLUAJIT_HOST_BUILD_OPTION_DASM_LE=${DASM_LE}"
            "-DLUAJIT_HOST_BUILD_OPTION_DASM_BIT64=${DASM_BIT64}"
            "-DLUAJIT_HOST_BUILD_OPTION_DASM_HASJIT=${DASM_HASJIT}"
            "-DLUAJIT_HOST_BUILD_OPTION_DASM_HASFFI=${DASM_HASFFI}"
            "-DLUAJIT_HOST_BUILD_OPTION_DASM_DUALNUM=${DASM_DUALNUM}"
            "-DLUAJIT_HOST_BUILD_OPTION_DASM_HASFPU=${DASM_HASFPU}"
            "-DLUAJIT_HOST_BUILD_OPTION_DASM_SOFTFP=${DASM_SOFTFP}"
            "-DLUAJIT_HOST_BUILD_OPTION_DASM_NOUNWIND=${DASM_NOUNWIND}"
            "-DLUAJIT_HOST_BUILD_OPTION_DASM_IOS=${DASM_IOS}"
            "-DLUAJIT_HOST_BUILD_OPTION_DASM_MIPSR6=${DASM_MIPSR6}"
            "-DLUAJIT_HOST_BUILD_OPTION_DASM_PPC_SQRT=${DASM_PPC_SQRT}"
            "-DLUAJIT_HOST_BUILD_OPTION_DASM_PPC_ROUND=${DASM_PPC_ROUND}"
            "-DLUAJIT_HOST_BUILD_OPTION_DASM_PPC32ON64=${DASM_PPC32ON64}"
            "-DLUAJIT_HOST_BUILD_OPTION_DASM_PPC_OPD=${DASM_PPC_OPD}"
            "-DLUAJIT_HOST_BUILD_OPTION_DASM_PPC_OPDENV=${DASM_PPC_OPDENV}"
            "-DLUAJIT_HOST_BUILD_OPTION_DASM_PPC_ELFV2=${DASM_PPC_ELFV2}"
            "-DLUAJIT_HOST_BUILD_OPTION_TARGET_ARCH_AARCH64EB=${TARGET_ARCH_AARCH64EB}"
            "-DLUAJIT_HOST_BUILD_OPTION_TARGET_ARCH_ENDIAN=${TARGET_ARCH_ENDIAN}"
            "-DLUAJIT_HOST_BUILD_OPTION_TARGET_ARCH_MIPSEL=${TARGET_ARCH_MIPSEL}"
            "-DLUAJIT_HOST_BUILD_OPTION_TARGET_ARCH_CELLOS_LV2=${TARGET_ARCH_CELLOS_LV2}"
            "-DLUAJIT_HOST_BUILD_OPTION_TARGET_ARCH_HASFPU=${TARGET_ARCH_HASFPU}"
            "-DLUAJIT_HOST_BUILD_OPTION_TARGET_ARCH_SOFTFP=${TARGET_ARCH_SOFTFP}"
            "-DLUAJIT_HOST_BUILD_OPTION_TARGET_ARCH_NO_UNWIND=${TARGET_ARCH_NO_UNWIND}"
            "-DLUAJIT_HOST_BUILD_OPTION_TARGET_LJARCH=${TARGET_LJARCH}"
            "${CMAKE_CURRENT_SOURCE_DIR}"
            WORKING_DIRECTORY "${LUAJIT_HOST_BUILD_WORKDIR}"
            RESULT_VARIABLE LUAJIT_HOST_BUILD_RESULT)
        if(LUAJIT_HOST_BUILD_RESULT AND NOT LUAJIT_HOST_BUILD_RESULT EQUAL 0)
            message(FATAL_ERROR "[CrossCompiling] Generate host build cmake failed")
        endif()

        # build
        execute_process(COMMAND ${CMAKE_COMMAND}
            --build . -j
            WORKING_DIRECTORY "${LUAJIT_HOST_BUILD_WORKDIR}"
            RESULT_VARIABLE LUAJIT_HOST_BUILD_COMPILE_RESULT)
        if(LUAJIT_HOST_BUILD_COMPILE_RESULT AND NOT LUAJIT_HOST_BUILD_COMPILE_RESULT EQUAL 0)
            message(FATAL_ERROR "[CrossCompiling] Host build failed")
        endif()

        # Cache build info
        set(LUAJIT_HOST_BUILD_COMPLETED ON CACHE INTERNAL "")
        set(LUAJIT_HOST_BUILD_WORKDIR "${LUAJIT_HOST_BUILD_WORKDIR}" CACHE INTERNAL "")
    endif()

    # Set native tools search directory
    set(LuaJITHostTools_DIR "${LUAJIT_HOST_BUILD_WORKDIR}")

    # https://cmake.org/cmake/help/book/mastering-cmake/chapter/Cross%20Compiling%20With%20CMake.html
    find_package(LuaJITHostTools)
    if(NOT LuaJITHostTools_FOUND)
        message(FATAL_ERROR "Host building tool is required, specify -DLuaJITHostTools_DIR to find LuaJITHostToolsConfig.cmake")
    endif()
else()
    luajit_build_host_tools(
        TARGET_SYS "${TARGET_SYS}"
        DASM_SCRIPT "${CMAKE_CURRENT_SOURCE_DIR}/dynasm/dynasm.lua"
        DASM_SOURCE "${CMAKE_CURRENT_SOURCE_DIR}/src/vm_${DASM_ARCH}.dasc"
        DASM_VER "${DASM_VER}"
        DASM_LE ${DASM_LE}
        DASM_BIT64 ${DASM_BIT64}
        DASM_HASJIT ${DASM_HASJIT}
        DASM_HASFFI ${DASM_HASFFI}
        DASM_DUALNUM ${DASM_DUALNUM}
        DASM_HASFPU ${DASM_HASFPU}
        DASM_SOFTFP ${DASM_SOFTFP}
        DASM_NOUNWIND ${DASM_NOUNWIND}
        DASM_IOS ${DASM_IOS}
        DASM_MIPSR6 ${DASM_MIPSR6}
        DASM_PPC_SQRT ${DASM_PPC_SQRT}
        DASM_PPC_ROUND ${DASM_PPC_ROUND}
        DASM_PPC32ON64 ${DASM_PPC32ON64}
        DASM_PPC_OPD ${DASM_PPC_OPD}
        DASM_PPC_OPDENV ${DASM_PPC_OPDENV}
        DASM_PPC_ELFV2 ${DASM_PPC_ELFV2}
        TARGET_ARCH_AARCH64EB "${TARGET_ARCH_AARCH64EB}"
        TARGET_ARCH_ENDIAN "${TARGET_ARCH_ENDIAN}"
        TARGET_ARCH_MIPSEL "${TARGET_ARCH_MIPSEL}"
        TARGET_ARCH_CELLOS_LV2 "${TARGET_ARCH_CELLOS_LV2}"
        TARGET_ARCH_HASFPU "${TARGET_ARCH_HASFPU}"
        TARGET_ARCH_SOFTFP "${TARGET_ARCH_SOFTFP}"
        TARGET_ARCH_NO_UNWIND "${TARGET_ARCH_NO_UNWIND}"
        TARGET_LJARCH "${TARGET_LJARCH}"
        MINILUA_SOURCES
            "${CMAKE_CURRENT_SOURCE_DIR}/src/host/minilua.c"
        BUILDVM_SOURCES
            "${CMAKE_CURRENT_SOURCE_DIR}/src/host/buildvm.c"
            "${CMAKE_CURRENT_SOURCE_DIR}/src/host/buildvm_asm.c"
            "${CMAKE_CURRENT_SOURCE_DIR}/src/host/buildvm_peobj.c"
            "${CMAKE_CURRENT_SOURCE_DIR}/src/host/buildvm_lib.c"
            "${CMAKE_CURRENT_SOURCE_DIR}/src/host/buildvm_fold.c"
        BUILDVM_INCLUDES
            "${CMAKE_CURRENT_SOURCE_DIR}/src"
    )
endif()

function(add_buildvm_target)
    set(ONE_VALUE_ARGS MODE OUTPUT)
    set(MULTI_VALUE_ARGS SOURCES)
    cmake_parse_arguments(BUILDVM_TARGET "" "${ONE_VALUE_ARGS}" "${MULTI_VALUE_ARGS}" ${ARGN})

    add_custom_command(
        OUTPUT "${BUILDVM_TARGET_OUTPUT}"
        COMMAND "$<TARGET_FILE:buildvm>"
        ARGS
            "-m" "${BUILDVM_TARGET_MODE}"
            "-o" "${BUILDVM_TARGET_OUTPUT}"
            ${BUILDVM_TARGET_SOURCES}
        WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
        DEPENDS "$<TARGET_FILE:buildvm>" ${BUILDVM_TARGET_SOURCES}
        VERBATIM)
    set_source_files_properties("${BUILDVM_TARGET_OUTPUT}" PROPERTIES GENERATED TRUE)
endfunction()

add_buildvm_target(MODE "${LJVM_MODE}" OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/${LJVM_BOUT}")
add_buildvm_target(MODE "bcdef" OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/lj_bcdef.h" SOURCES ${LJLIB_C})
add_buildvm_target(MODE "ffdef" OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/lj_ffdef.h" SOURCES ${LJLIB_C})
add_buildvm_target(MODE "libdef" OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/lj_libdef.h" SOURCES ${LJLIB_C})
add_buildvm_target(MODE "recdef" OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/lj_recdef.h" SOURCES ${LJLIB_C})
add_buildvm_target(MODE "vmdef" OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/vmdef.lua" SOURCES ${LJLIB_C})
add_buildvm_target(MODE "folddef" OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/lj_folddef.h" SOURCES "${CMAKE_CURRENT_SOURCE_DIR}/src/lj_opt_fold.c")

set(BUILDVM_OUTPUTS
    "${CMAKE_CURRENT_BINARY_DIR}/${LJVM_BOUT}"
    "${CMAKE_CURRENT_BINARY_DIR}/lj_bcdef.h"
    "${CMAKE_CURRENT_BINARY_DIR}/lj_ffdef.h"
    "${CMAKE_CURRENT_BINARY_DIR}/lj_libdef.h"
    "${CMAKE_CURRENT_BINARY_DIR}/lj_recdef.h"
    "${CMAKE_CURRENT_BINARY_DIR}/vmdef.lua"
    "${CMAKE_CURRENT_BINARY_DIR}/lj_folddef.h")

if(NOT ${BUILDMODE} STREQUAL "static")
    add_library(liblua-shared SHARED ${LJVMCORE_C} ${BUILDVM_OUTPUTS})
    target_link_libraries(liblua-shared ${TARGET_XLIBS})
    target_include_directories(liblua-shared INTERFACE "${CMAKE_CURRENT_SOURCE_DIR}/src")
    target_include_directories(liblua-shared PRIVATE "${CMAKE_CURRENT_BINARY_DIR}")
    set_target_properties(liblua-shared PROPERTIES PREFIX "lib" IMPORT_PREFIX "lib" OUTPUT_NAME "lua")
    if(TARGET_SYS STREQUAL "Windows" AND NOT CYGWIN)  # FIXME: CYGWIN detect?
        target_compile_options(liblua-shared PRIVATE "-DLUA_BUILD_AS_DLL" ${TARGET_XCFLAGS})
    else()
        target_compile_options(liblua-shared PRIVATE ${TARGET_XCFLAGS})
    endif()

    add_executable(lua "${CMAKE_CURRENT_SOURCE_DIR}/src/luajit.c")
    target_link_libraries(lua liblua-shared)
endif()

if(NOT ${BUILDMODE} STREQUAL "dynamic")
    add_library(liblua-static STATIC ${LJVMCORE_C} ${BUILDVM_OUTPUTS})
    target_link_libraries(liblua-static ${TARGET_XLIBS})
    target_include_directories(liblua-static INTERFACE "${CMAKE_CURRENT_SOURCE_DIR}/src")
    target_include_directories(liblua-static PRIVATE "${CMAKE_CURRENT_BINARY_DIR}")
    set_target_properties(liblua-static PROPERTIES COMPILE_DEFINITIONS "liblua_static" OUTPUT_NAME "lua-static")
    target_compile_options(liblua-static PRIVATE ${TARGET_XCFLAGS})

    add_executable(lua-static "${CMAKE_CURRENT_SOURCE_DIR}/src/luajit.c")
    target_link_libraries(lua-static liblua-static)
endif()
