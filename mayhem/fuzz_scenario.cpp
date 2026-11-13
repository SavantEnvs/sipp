// Raw file-input target: SIPp's XML scenario loader (src/scenario.cpp). Bad
// scenarios ERROR() and exit(), so this is a file target, not libFuzzer.
#include "sipp.hpp"

#include "fuzz_common.h"

#include <stdio.h>

int main(int argc, char **argv)
{
    if (argc < 2) {
        fprintf(stderr, "usage: %s scenario.xml\n", argv[0]);
        return 2;
    }
    sipp_fuzz_init();
    scenario *s = new scenario(argv[1], 0);
    delete s;
    return 0;
}
