// WebSocket (RFC 6455 / RFC 7118) handshake and framing state machine
// (src/websocket.cpp), fed arbitrary bytes as a server or as a client.
#include "websocket.hpp"

#include <fuzzer/FuzzedDataProvider.h>
#include <stddef.h>
#include <stdint.h>
#include <string>

extern "C" int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size)
{
    FuzzedDataProvider fdp(data, size);
    bool server = fdp.ConsumeBool();
    size_t max_message = size_t(1) << fdp.ConsumeIntegralInRange<int>(0, 16);
    WebSocket ws(server, max_message);

    if (!server) {
        (void)ws.request("example.org", "/sip");
    }
    (void)ws.frame("INVITE sip:a@b SIP/2.0\r\n\r\n", 26);

    for (int round = 0; round < 64 && fdp.remaining_bytes() > 0; round++) {
        std::string chunk = fdp.ConsumeRandomLengthString(512);
        ws.feed(chunk.data(), chunk.size());
        for (int i = 0; i < 64; i++) {
            std::string payload, reply;
            WebSocket::Event ev = ws.next(payload, reply);
            if (ev == WebSocket::NEED_MORE) {
                break;
            }
            if (ev == WebSocket::MESSAGE) {
                (void)ws.frame(payload.data(), payload.size());
            }
            if (ev == WebSocket::CLOSED || ev == WebSocket::FAILED) {
                (void)ws.close_frame(1000);
                break;
            }
        }
    }
    std::string rest = fdp.ConsumeRemainingBytesAsString();
    (void)WebSocket::accept_key(rest);
    (void)WebSocket::is_utf8(rest.data(), rest.size());
    return 0;
}
