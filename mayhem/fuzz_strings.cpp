// URL coding and address/string helpers (src/urlcoder.cpp, src/strings.cpp).
#include "strings.hpp"
#include "urlcoder.hpp"

#include <fuzzer/FuzzedDataProvider.h>
#include <stddef.h>
#include <stdint.h>
#include <string>

extern "C" int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size)
{
    FuzzedDataProvider fdp(data, size);
    int offset = fdp.ConsumeIntegralInRange<int>(0, 80);
    int width = fdp.ConsumeIntegralInRange<int>(1, 120);
    std::string s = fdp.ConsumeRemainingBytesAsString();

    std::string enc = url_encode(s);
    (void)url_decode(enc);
    (void)url_decode(s);

    int port = 0;
    (void)get_host_and_port(s.c_str(), &port);
    (void)wrap(s.c_str(), offset, width);
    for (char c : s) {
        (void)get_decimal_from_hex(c);
    }
    return 0;
}
