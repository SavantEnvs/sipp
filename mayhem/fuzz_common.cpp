// Globals and stubs the SIPp objects need when sipp.cpp (main) is not linked,
// as src/sipp_unittest.cpp supplies them for the gtest binary.
#define GLOBALS_FULL_DEFINITION
#include "sipp.hpp"

#include <stdlib.h>

void sipp_exit(int rc, int, int)
{
    exit(rc);
}

void sipp_fuzz_init()
{
    static bool done = false;
    if (done) {
        return;
    }
    done = true;
    globalVariables = new AllocVariableTable(nullptr);
    userVariables = new AllocVariableTable(globalVariables);
    main_scenario = new scenario(0, 0);
}
