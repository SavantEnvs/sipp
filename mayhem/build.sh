#!/usr/bin/env bash
#
# mayhem/build.sh — build SIPp's fuzz harnesses and its gtest oracle. Runs in the commit image
# as `mayhem` in /mayhem, offline: every dependency is an apt -dev package baked into the image.
set -euo pipefail

[ -n "${SOURCE_DATE_EPOCH:-}" ] || unset SOURCE_DATE_EPOCH

: "${SANITIZER_FLAGS=-fsanitize=address,undefined -fno-sanitize-recover=all -fno-omit-frame-pointer}"
: "${DEBUG_FLAGS:=-g -gdwarf-3}"
: "${CC:=clang}" ; : "${CXX:=clang++}" ; : "${LIB_FUZZING_ENGINE:=-fsanitize=fuzzer}"
: "${MAYHEM_JOBS:=$(nproc)}"
: "${COVERAGE_FLAGS=}"
: "${STANDALONE_FUZZ_MAIN:=/opt/mayhem/StandaloneFuzzTargetMain.c}"
export SANITIZER_FLAGS DEBUG_FLAGS CC CXX LIB_FUZZING_ENGINE MAYHEM_JOBS COVERAGE_FLAGS

cd "$SRC"

CMAKE_OPTS=(-DCMAKE_C_COMPILER="$CC" -DCMAKE_CXX_COMPILER="$CXX"
            -DUSE_SYSTEM_PUGIXML=ON -DUSE_SYSTEM_GTEST=ON
            -DUSE_PCAP=1 -DUSE_GSL=1 -DUSE_SCTP=1 -DUSE_LUA=ON)

# What the sipp target links, minus its own objects (build.ninja, LINK_LIBRARIES).
LIBS=(-ldl -lpthread -lpugixml -lncursesw -ltinfo -lrt -lresolv -lgsl -lgslcblas -lssl -lcrypto -lpcap -lsctp -llua5.4)
# The compile definitions and standard the sipp target's objects use.
DEFS=(-DHAVE_GSL -DPCAPPLAY -DUSE_LUA -DUSE_OPENSSL -DUSE_SCTP)
STD=-std=gnu++17

# 1) The oracle: SIPp's own gtest suite, plus a known-answer probe, with NORMAL flags.
cmake -S . -B build-tests "${CMAKE_OPTS[@]}" \
      -DCMAKE_C_FLAGS="$COVERAGE_FLAGS" -DCMAKE_CXX_FLAGS="$COVERAGE_FLAGS"
cmake --build build-tests -j"$MAYHEM_JOBS" --target sipp sipp_unittest

TEST_OBJS=$(ls build-tests/CMakeFiles/sipp.dir/src/*.o | grep -v '/sipp\.cpp\.o$')
# shellcheck disable=SC2086
$CXX $STD "${DEFS[@]}" $COVERAGE_FLAGS -Iinclude -Ibuild-tests -isystem /usr/include/lua5.4 \
     mayhem/kat.cpp mayhem/fuzz_common.cpp $TEST_OBJS "${LIBS[@]}" -rdynamic \
     -o build-tests/kat

# 2) The project itself, instrumented: sanitizers + SanCov (fuzzer-no-link) + DWARF 3.
FUZZ_FLAGS="$SANITIZER_FLAGS $DEBUG_FLAGS -fsanitize=fuzzer-no-link"
cmake -S . -B build-fuzz "${CMAKE_OPTS[@]}" \
      -DCMAKE_C_FLAGS="$FUZZ_FLAGS" -DCMAKE_CXX_FLAGS="$FUZZ_FLAGS"
cmake --build build-fuzz -j"$MAYHEM_JOBS" --target sipp

FUZZ_OBJS=$(ls build-fuzz/CMakeFiles/sipp.dir/src/*.o | grep -v '/sipp\.cpp\.o$')
INC=(-Iinclude -Ibuild-fuzz -Imayhem -isystem /usr/include/lua5.4)

# 3) Harnesses. The libFuzzer ones are linked twice: with the engine and with the standalone driver.
mkdir -p build-fuzz/mayhem
# shellcheck disable=SC2086
{
  $CXX $FUZZ_FLAGS $STD "${DEFS[@]}" "${INC[@]}" -c mayhem/fuzz_common.cpp -o build-fuzz/mayhem/fuzz_common.o
  $CXX $FUZZ_FLAGS -c mayhem/lsan_off.cc -o build-fuzz/mayhem/lsan_off.o
  $CC  $FUZZ_FLAGS -c "$STANDALONE_FUZZ_MAIN" -o build-fuzz/mayhem/standalone_main.o
}
COMMON_OBJS="build-fuzz/mayhem/fuzz_common.o build-fuzz/mayhem/lsan_off.o"

LIBFUZZER_TARGETS="fuzz_sip_parser fuzz_auth fuzz_websocket fuzz_strings"
RAW_TARGETS="fuzz_scenario fuzz_infile fuzz_message"

# shellcheck disable=SC2086
for t in $LIBFUZZER_TARGETS $RAW_TARGETS; do
  $CXX $FUZZ_FLAGS $STD "${DEFS[@]}" "${INC[@]}" -c "mayhem/$t.cpp" -o "build-fuzz/mayhem/$t.o"
done

# shellcheck disable=SC2086
for t in $LIBFUZZER_TARGETS; do
  $CXX $FUZZ_FLAGS $LIB_FUZZING_ENGINE "build-fuzz/mayhem/$t.o" $COMMON_OBJS $FUZZ_OBJS \
       "${LIBS[@]}" -rdynamic -o "$SRC/$t"
  $CXX $FUZZ_FLAGS "build-fuzz/mayhem/$t.o" build-fuzz/mayhem/standalone_main.o $COMMON_OBJS $FUZZ_OBJS \
       "${LIBS[@]}" -rdynamic -o "$SRC/$t-standalone"
done
# shellcheck disable=SC2086
for t in $RAW_TARGETS; do
  $CXX $FUZZ_FLAGS "build-fuzz/mayhem/$t.o" $COMMON_OBJS $FUZZ_OBJS \
       "${LIBS[@]}" -rdynamic -o "$SRC/$t"
done
