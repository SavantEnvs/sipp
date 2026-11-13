// Known-answer probe for mayhem/test.sh: prints what SIPp's parsers compute so
// the script can compare it to values fixed by RFC 6455 / RFC 7616 / RFC 3261.
// Built with the project's normal flags (no sanitizers) next to the gtest suite.
#include "auth.hpp"
#include "sip_parser.hpp"
#include "urlcoder.hpp"
#include "websocket.hpp"

#include <iostream>
#include <iterator>
#include <optional>
#include <string>
#include <string.h>

int main(int argc, char **argv)
{
    if (argc < 2) {
        return 2;
    }
    std::string cmd = argv[1];
    std::string in((std::istreambuf_iterator<char>(std::cin)), std::istreambuf_iterator<char>());

    if (cmd == "wskey" && argc == 2) {
        std::cout << WebSocket::accept_key(in) << "\n";
    } else if (cmd == "verify" && argc == 6) {
        // verify <user> <password> <method> <body>, the Authorization header on stdin
        std::cout << verifyAuthHeader(argv[2], argv[3], argv[4], in, argv[5]) << "\n";
    } else if (cmd == "authparam" && argc == 3) {
        std::cout << getAuthParameter(argv[2], in) << "\n";
    } else if (cmd == "sip" && argc == 2) {
        const char *m = in.c_str();
        std::cout << "call-id=" << get_call_id(m) << "\n";
        std::optional<std::string_view> tag = get_peer_tag(m);
        std::cout << "tag=" << (tag ? std::string(*tag) : "<none>") << "\n";
        std::cout << "cseq=" << get_cseq_value(m) << "\n";
        std::cout << "code=" << get_reply_code(m) << "\n";
        std::cout << "via=" << get_header_content(m, "Via:").view() << "\n";
        std::cout << "first=" << get_first_line(m) << "\n";
    } else if (cmd == "urlencode" && argc == 2) {
        std::cout << url_encode(in) << "\n";
    } else if (cmd == "urldecode" && argc == 2) {
        std::cout << url_decode(in) << "\n";
    } else {
        return 2;
    }
    return 0;
}
