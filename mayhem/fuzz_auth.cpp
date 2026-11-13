// HTTP/SIP digest authentication: challenge parsing, response creation and
// verification (src/auth.cpp), including the AKAv1-MD5 path.
#include "auth.hpp"

#include <fuzzer/FuzzedDataProvider.h>
#include <stddef.h>
#include <stdint.h>
#include <string>

extern "C" int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size)
{
    FuzzedDataProvider fdp(data, size);
    std::string user = fdp.ConsumeRandomLengthString(24);
    std::string password = fdp.ConsumeRandomLengthString(24);
    std::string method = fdp.ConsumeRandomLengthString(12);
    std::string uri = fdp.ConsumeRandomLengthString(40);
    std::string body = fdp.ConsumeRandomLengthString(40);
    unsigned nc = fdp.ConsumeIntegral<unsigned>();
    std::string auth = fdp.ConsumeRemainingBytesAsString();

    static const char *const params[] = {
        "realm", "nonce", "cnonce", "qop", "algorithm", "opaque", "username",
        "uri", "response", "nc", "stale", "domain"
    };
    for (const char *p : params) {
        (void)getAuthParameter(p, auth);
    }
    (void)selectAuthChallenge(auth);

    std::string result;
    (void)createAuthHeader(user, password, method.c_str(), uri, body, auth,
                           "cdc202d5123e20f62b6d676ac72cb318",
                           "b9b9",
                           "465b5ce8b199b49faa5f0a2ee238a6bc", nc, result);
    (void)createAuthHeader(user, password, method.c_str(), uri, body, selectAuthChallenge(auth),
                           "", "", "0x465b5ce8b199b49faa5f0a2ee238a6bc", nc, result);
    (void)verifyAuthHeader(user, password, method, auth, body);
    return 0;
}
