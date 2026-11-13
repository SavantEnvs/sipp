// Raw file-input target: SIPp injection (-inf) files (src/infile.cpp). A bad
// file ERROR()s and exit()s, so this is a file target, not libFuzzer.
#include "sipp.hpp"

#include "fuzz_common.h"
#include "infile.hpp"

#include <fstream>
#include <stdio.h>
#include <string>

int main(int argc, char **argv)
{
    if (argc < 2) {
        fprintf(stderr, "usage: %s injection.csv\n", argv[0]);
        return 2;
    }
    sipp_fuzz_init();
    FileContents f(argv[1]);
    int n = f.numLines();
    for (int i = 0; i < n && i < 1000; i++) {
        (void)f.getLine(i);
        (void)f.getField(i, 0);
        (void)f.getField(i, 3);
    }
    for (int u = 0; u <= n && u < 8; u++) {
        (void)f.nextLine(u);
    }
    // index() on a PRINTF file asserts (its virtual lines outnumber the real ones), and
    // insert()/replace() ERROR() on it; and a PRINTF file may claim billions of virtual lines.
    std::string first;
    std::getline(std::ifstream(argv[1]), first);
    if (first.find("PRINTF") == std::string::npos && n <= 10000) {
        f.index(0);
        (void)f.lookup("1");
        f.insert("a;b;c");
        if (f.numLines() > 0) {
            f.replace(0, "x;y;z");
        }
    }
    return 0;
}
