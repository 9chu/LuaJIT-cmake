function(luajit_build_host_tools)
    ##### Parse arguments

    set(ONE_VALUE_ARGS
        TARGET_SYS  # Windows/Linux/Darwin/iOS/PS3
        DASM_SCRIPT  # dynasm/dynasm.lua
        DASM_SOURCE  # vm_$(DASM_ARCH).dasc
        DASM_VER  # see LJ_ARCH_VERSION in lj_arch.h
        DASM_LE
        DASM_BIT64
        DASM_HASJIT
        DASM_HASFFI
        DASM_DUALNUM
        DASM_HASFPU
        DASM_SOFTFP
        DASM_NOUNWIND
        DASM_IOS
        DASM_MIPSR6
        DASM_PPC_SQRT
        DASM_PPC_ROUND
        DASM_PPC32ON64
        DASM_PPC_OPD
        DASM_PPC_OPDENV
        DASM_PPC_ELFV2
        TARGET_ARCH_AARCH64EB  # "" or "0" or "1"
        TARGET_ARCH_ENDIAN  # "" or "LUAJIT_LE" or "LUAJIT_BE"
        TARGET_ARCH_MIPSEL  # "" or "0" or "1"
        TARGET_ARCH_CELLOS_LV2  # "" or "0" or "1"
        TARGET_ARCH_HASFPU  # "0" or "1"
        TARGET_ARCH_SOFTFP  # "0" or "1"
        TARGET_ARCH_NO_UNWIND  # "" or "0" or "1"
        TARGET_LJARCH  # ".."
    )
    set(MULTI_VALUE_ARGS
        MINILUA_SOURCES
        BUILDVM_SOURCES
        BUILDVM_INCLUDES
    )
    cmake_parse_arguments(HOST_TOOL "" "${ONE_VALUE_ARGS}" "${MULTI_VALUE_ARGS}" ${ARGN})

    ##### Common compiler flags

    if(HOST_TOOL_TARGET_SYS STREQUAL "Windows")
        check_c_compiler_flag("-malign-double" HAS_ALIGN_DOUBLE)
        if(HAS_ALIGN_DOUBLE)
            set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -malign-double")
        endif()

        message(STATUS "[BuildHostTools] Targeting Windows")
        set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -DLUAJIT_OS=LUAJIT_OS_WINDOWS")
    else()
        if(HOST_TOOL_TARGET_SYS STREQUAL "Linux")
            message(STATUS "[BuildHostTools] Targeting Linux")
            set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -DLUAJIT_OS=LUAJIT_OS_LINUX")
        else()
            if(HOST_TOOL_TARGET_SYS STREQUAL "Darwin")
                message(STATUS "[BuildHostTools] Targeting OSX")
                set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -DLUAJIT_OS=LUAJIT_OS_OSX")
            else()
                if(HOST_TOOL_TARGET_SYS STREQUAL "iOS")
                    message(STATUS "[BuildHostTools] Targeting iOS")
                    set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -DLUAJIT_OS=LUAJIT_OS_OSX -DTARGET_OS_IPHONE=1")
                else()
                    message(STATUS "[BuildHostTools] Targeting Other OS (${HOST_TOOL_TARGET_SYS})")
                    set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -DLUAJIT_OS=LUAJIT_OS_OTHER")
                endif()
            endif()
        endif()
    endif()

    ##### Regenerate TARGET_ARCH macro

    set(TARGET_ARCH)

    if(HOST_TOOL_TARGET_ARCH_AARCH64EB AND HOST_TOOL_TARGET_ARCH_AARCH64EB STREQUAL "1")
        list(APPEND TARGET_ARCH "-D__AARCH64EB__=1")
    endif()
    if(HOST_TOOL_TARGET_ARCH_ENDIAN)
        if(HOST_TOOL_TARGET_ARCH_ENDIAN STREQUAL "LUAJIT_LE")
            list(APPEND TARGET_ARCH "-DLJ_ARCH_ENDIAN=LUAJIT_LE")
        elseif(HOST_TOOL_TARGET_ARCH_ENDIAN STREQUAL "LUAJIT_BE")
            list(APPEND TARGET_ARCH "-DLJ_ARCH_ENDIAN=LUAJIT_BE")
        endif()
    endif()
    if(HOST_TOOL_TARGET_ARCH_MIPSEL AND HOST_TOOL_TARGET_ARCH_MIPSEL STREQUAL "1")
        list(APPEND TARGET_ARCH "-D__MIPSEL__=1")
    endif()
    if(HOST_TOOL_TARGET_ARCH_CELLOS_LV2 AND HOST_TOOL_TARGET_ARCH_CELLOS_LV2 STREQUAL "1")
        list(APPEND TARGET_ARCH "-D__CELLOS_LV2__")
    endif()
    if(HOST_TOOL_TARGET_ARCH_HASFPU STREQUAL "1")
        list(APPEND TARGET_ARCH "-DLJ_ARCH_HASFPU=1")
    elseif(HOST_TOOL_TARGET_ARCH_HASFPU STREQUAL "0")
        list(APPEND TARGET_ARCH "-DLJ_ARCH_HASFPU=0")
    endif()
    if(HOST_TOOL_TARGET_ARCH_SOFTFP STREQUAL "1")
        list(APPEND TARGET_ARCH "-DLJ_ABI_SOFTFP=1")
    elseif(HOST_TOOL_TARGET_ARCH_SOFTFP STREQUAL "0")
        list(APPEND TARGET_ARCH "-DLJ_ABI_SOFTFP=0")
    endif()
    if(HOST_TOOL_TARGET_ARCH_NO_UNWIND AND HOST_TOOL_TARGET_ARCH_NO_UNWIND STREQUAL "1")
        list(APPEND TARGET_ARCH "-DLUAJIT_NO_UNWIND")
    endif()
    list(APPEND TARGET_ARCH "-DLUAJIT_TARGET=LUAJIT_ARCH_${HOST_TOOL_TARGET_LJARCH}")

    message(STATUS "[BuildHostTools] TARGET_ARCH: ${TARGET_ARCH}")

    ##### Build minilua

    add_executable(minilua ${HOST_TOOL_MINILUA_SOURCES})

    # check for libm
    check_library_exists(m pow "" HAS_LIBM)
    if(HAS_LIBM)
        message(STATUS "[BuildHostTools] minilua links to libm")
        target_link_libraries(minilua m)
    endif()

    ##### Build buildvm

    # flags
    set(DASM_FLAGS "-D" "VER=${HOST_TOOL_DASM_VER}")
    if(HOST_TOOL_DASM_LE)
        list(APPEND DASM_FLAGS "-D" "ENDIAN_LE")
    else()
        list(APPEND DASM_FLAGS "-D" "ENDIAN_BE")
    endif()
    if(HOST_TOOL_DASM_BIT64)
        list(APPEND DASM_FLAGS "-D" "P64")
    endif()
    if(HOST_TOOL_DASM_HASJIT)
        list(APPEND DASM_FLAGS "-D" "JIT")
    endif()
    if(HOST_TOOL_DASM_HASFFI)
        list(APPEND DASM_FLAGS "-D" "FFI")
    endif()
    if(HOST_TOOL_DASM_DUALNUM)
        list(APPEND DASM_FLAGS "-D" "DUALNUM")
    endif()
    if(HOST_TOOL_DASM_HASFPU)
        list(APPEND DASM_FLAGS "-D" "FPU")
    endif()
    if(HOST_TOOL_DASM_SOFTFP)
        list(APPEND DASM_FLAGS "-D" "HFABI")
    endif()
    if(HOST_TOOL_DASM_NOUNWIND)
        list(APPEND DASM_FLAGS "-D" "NO_UNWIND")
    endif()
    if(HOST_TOOL_TARGET_SYS STREQUAL "Windows")
        list(APPEND DASM_FLAGS "-D" "WIN")
    endif()
    if(HOST_TOOL_DASM_IOS)
        list(APPEND DASM_FLAGS "-D" "IOS")
    endif()
    if(HOST_TOOL_DASM_MIPSR6)
        list(APPEND DASM_FLAGS "-D" "MIPSR6")
    endif()
    if(HOST_TOOL_DASM_PPC_SQRT)
        list(APPEND DASM_FLAGS "-D" "SQRT")
    endif()
    if(HOST_TOOL_DASM_PPC_ROUND)
        list(APPEND DASM_FLAGS "-D" "ROUND")
    endif()
    if(HOST_TOOL_DASM_PPC32ON64)
        list(APPEND DASM_FLAGS "-D" "GPR64")
    endif()
    if(HOST_TOOL_TARGET_SYS STREQUAL "PS3")
        list(APPEND DASM_FLAGS "-D" "PPE")
    endif()
    if(HOST_TOOL_DASM_PPC_OPD)
        list(APPEND DASM_FLAGS "-D" "OPD")
    endif()
    if(HOST_TOOL_DASM_PPC_OPDENV)
        list(APPEND DASM_FLAGS "-D" "OPDENV")
    endif()
    if(HOST_TOOL_DASM_PPC_ELFV2)
        list(APPEND DASM_FLAGS "-D" "ELFV2")
    endif()

    message(STATUS "[BuildHostTools] DASM_FLAGS: ${DASM_FLAGS}")

    # buildvm_arch.h
    add_custom_command(
        OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/buildvm_arch.h"
        COMMAND
            "$<TARGET_FILE:minilua>"
            "${HOST_TOOL_DASM_SCRIPT}"
            ${DASM_FLAGS}
            -o "${CMAKE_CURRENT_BINARY_DIR}/buildvm_arch.h"
            "${HOST_TOOL_DASM_SOURCE}"
        DEPENDS "$<TARGET_FILE:minilua>" "${HOST_TOOL_DASM_SCRIPT}" "${HOST_TOOL_DASM_SOURCE}"
        VERBATIM)

    # buildvm
    add_executable(buildvm ${HOST_TOOL_BUILDVM_SOURCES} "${CMAKE_CURRENT_BINARY_DIR}/buildvm_arch.h")
    target_include_directories(buildvm PRIVATE ${CMAKE_CURRENT_BINARY_DIR} ${HOST_TOOL_BUILDVM_INCLUDES})
    target_compile_definitions(buildvm PRIVATE ${TARGET_ARCH})

    export(TARGETS minilua buildvm FILE "${CMAKE_BINARY_DIR}/LuaJITHostToolsConfig.cmake")
endfunction()
