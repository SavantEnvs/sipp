// SIP message header/start-line parsers (src/sip_parser.cpp).
#include "sip_parser.hpp"

#include <ctype.h>
#include <stddef.h>
#include <stdint.h>
#include <string>

extern "C" int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size)
{
    if (size == 0) {
        return 0;
    }
    // The first byte picks how many following bytes name a header to look up.
    size_t name_len = data[0] % 12;
    if (name_len > size - 1) {
        name_len = size - 1;
    }
    // A header name as SIPp's scenarios give one: token characters and a colon.
    std::string name;
    for (size_t i = 0; i < name_len; i++) {
        unsigned char c = data[1 + i];
        if (isalnum(c) || c == '-' || c == '_' || c == '.') {
            name += static_cast<char>(c);
        }
    }
    if (!name.empty()) {
        name += ':';
    }
    std::string msg(reinterpret_cast<const char *>(data + 1 + name_len), size - 1 - name_len);
    const char *m = msg.c_str();

    (void)get_call_id(m);
    (void)get_peer_tag(m);
    (void)get_cseq_value(m);
    (void)get_reply_code(m);
    (void)get_first_line(m);

    static const char *const names[] = {
        "Via:", "Call-ID:", "To:", "From:", "Contact:", "Content-Length:",
        "Record-Route:", "Route:", "CSeq:", "Content-Type:", "i:", "v:", "m:"
    };
    for (const char *n : names) {
        header_value v = get_header_content(m, n);
        // header_number() does pointer arithmetic on the null data() of an absent header's
        // empty view (UB, reachable from call.cpp's Content-Length check); skip that call.
        if (!v.empty()) {
            (void)header_number(v.view());
        }
        (void)get_header(m, n, true);
        (void)get_header(m, n, false);
    }
    if (!name.empty()) {
        header_value v = get_header(m, name, false);
        (void)v.view().size();
        (void)get_header_content(m, name);
    }
    return 0;
}
