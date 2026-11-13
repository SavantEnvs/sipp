// Raw file-input target: the [keyword] message template parser used for the
// body of <send> (SendingMessage, src/message.cpp). Bad keywords ERROR() and
// exit(), so this is a file target, not libFuzzer.
#include "sipp.hpp"

#include "fuzz_common.h"
#include "message.hpp"

#include <stdio.h>
#include <string>

int main(int argc, char **argv)
{
    if (argc < 2) {
        fprintf(stderr, "usage: %s template.txt\n", argv[0]);
        return 2;
    }
    FILE *f = fopen(argv[1], "rb");
    if (!f) {
        return 2;
    }
    std::string text;
    char buf[4096];
    size_t n;
    while ((n = fread(buf, 1, sizeof buf, f)) > 0) {
        text.append(buf, n);
    }
    fclose(f);

    sipp_fuzz_init();
    SendingMessage *m = new SendingMessage(main_scenario, text.c_str(), false);
    delete m;
    return 0;
}
