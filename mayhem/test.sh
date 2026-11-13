#!/usr/bin/env bash
#
# mayhem/test.sh — RUN this repo's OWN functional test suite (already built by mayhem/build.sh).
# exit 0 = pass. EDIT per repo. PATCH-grade oracle: after an agent patches the source, the grader
# rebuilds (build.sh) then runs this. DELETE this file if the repo has no meaningful tests.
#
# IMPORTANT:
#  * Must assert BEHAVIOR/OUTPUT, not just exit status. The oracle has to check asserted values /
#    golden-output diffs / known-answer results — so a PATCH that "fixes" a bug by making the program
#    exit(0) (or any no-op) FAILS here. Running inputs and checking only "exit 0 / didn't crash" is
#    NOT a functional test (it's trivially reward-hackable) — use the project's real assertion suite.
#  * Do NOT build here — mayhem/build.sh already compiled the test suite (with the project's normal
#    flags). This script only RUNS the pre-built tests and reports counts. If the test runner is
#    missing, that's a build.sh bug — fail loudly rather than silently rebuilding.
#  * REQUIRED OUTPUT — a CTRF (https://ctrf.io) summary so Mayhem/the PATCH grader reads the counts:
#      - writes a CTRF JSON report to ${CTRF_REPORT:-$SRC/ctrf-report.json}, and
#      - prints a one-line `CTRF {...}` marker to stdout (same JSON, compact).
#    Only `results.summary` (with tests/passed/failed/pending/skipped/other) is required.
#    Use the emit_ctrf helper below; it computes tests = passed+failed+skipped and sets the exit
#    code (0 iff failed==0). Map your framework's output to passed/failed/skipped.
set -uo pipefail
[ -n "${SOURCE_DATE_EPOCH:-}" ] || unset SOURCE_DATE_EPOCH
: "${MAYHEM_JOBS:=$(nproc)}"   # build parallelism; env-overridable, falls back to nproc (use -j"$MAYHEM_JOBS")
cd "$SRC"

# emit_ctrf <tool> <passed> <failed> [skipped] [pending] [other]
# Writes a CTRF report (file + stdout `CTRF {...}` marker) and returns non-zero iff failed>0.
emit_ctrf() {
  local tool="$1" passed="$2" failed="$3" skipped="${4:-0}" pending="${5:-0}" other="${6:-0}"
  local tests=$(( passed + failed + skipped + pending + other ))
  cat > "${CTRF_REPORT:-$SRC/ctrf-report.json}" <<JSON
{
  "results": {
    "tool": { "name": "$tool" },
    "summary": {
      "tests": $tests,
      "passed": $passed,
      "failed": $failed,
      "pending": $pending,
      "skipped": $skipped,
      "other": $other
    }
  }
}
JSON
  printf 'CTRF {"results":{"tool":{"name":"%s"},"summary":{"tests":%d,"passed":%d,"failed":%d,"pending":%d,"skipped":%d,"other":%d}}}\n' \
    "$tool" "$tests" "$passed" "$failed" "$pending" "$skipped" "$other"
  [ "$failed" -eq 0 ]
}

# SIPp's own gtest suite (src/*.cpp under #ifdef GTEST), built by build.sh with normal flags.
RUNNER=build-tests/sipp_unittest
KAT=build-tests/kat
for b in "$RUNNER" "$KAT"; do
  [ -x "$b" ] || { echo "missing $b: mayhem/build.sh did not build it" >&2; emit_ctrf "sipp-gtest" 0 1 0; exit 1; }
done

OUT=$(mktemp); trap 'rm -f "$OUT"' EXIT
"$RUNNER" >"$OUT" 2>&1
RAN=$(sed -n 's/^\[==========\] \([0-9][0-9]*\) tests\{0,1\} from .* ran\..*/\1/p' "$OUT" | tail -1)
PASSED=$(sed -n 's/^\[  PASSED  \] \([0-9][0-9]*\) tests\{0,1\}\..*/\1/p' "$OUT" | tail -1)
FAILED=$(sed -n 's/^\[  FAILED  \] \([0-9][0-9]*\) tests\{0,1\}, listed below.*/\1/p' "$OUT" | tail -1)
SKIPPED=$(sed -n 's/^\[  SKIPPED \] \([0-9][0-9]*\) tests\{0,1\}, listed below.*/\1/p' "$OUT" | tail -1)
PASSED=${PASSED:-0}; FAILED=${FAILED:-0}; SKIPPED=${SKIPPED:-0}
if [ -z "$RAN" ] || [ "$RAN" -lt 100 ]; then
  # The suite did not run to its summary (a crash, an early exit(0)), or ran far fewer tests than it has.
  tail -20 "$OUT" >&2
  FAILED=$((FAILED + 1))
fi

# Known-answer probes through the project's own parsers: values fixed by RFC 6455 / 7616 / 3261.
KAT_PASS=0; KAT_FAIL=0
expect() {  # expect <name> <expected> <actual>
  if [ "$2" = "$3" ]; then KAT_PASS=$((KAT_PASS + 1)); else
    KAT_FAIL=$((KAT_FAIL + 1)); echo "KAT FAIL $1: expected [$2] got [$3]" >&2; fi
}

# RFC 6455 section 1.3: the Sec-WebSocket-Accept of the sample key.
expect ws-accept "s3pPLMBiTxaQ9kYGzzhZRbK+xOo=" "$(printf 'dGhlIHNhbXBsZSBub25jZQ==' | "$KAT" wskey)"

# RFC 7616 section 3.9.1: Mufasa's digest response is accepted for his password and refused otherwise.
AUTH='Digest username="Mufasa", realm="http-auth@example.org", uri="/dir/index.html", algorithm=MD5, nonce="7ypf/xlj9XXwfDPEoM4URrv/xwf94BcCAzFZH4GiTo0v", nc=00000001, cnonce="f2/wE4q74E6zIJEtWaHKaf5wv/H5QzzpXusqGemxURZJ", qop=auth, response="8ca523f5e9506fed4657c9700eebdbec", opaque="FQhe/qaU925kfnzjCev0ciny7QMkPqMAFRtzCUYo5tdS"'
expect digest-md5-ok "1" "$(printf '%s' "$AUTH" | "$KAT" verify Mufasa 'Circle of Life' GET '')"
expect digest-md5-wrong-password "0" "$(printf '%s' "$AUTH" | "$KAT" verify Mufasa 'Circle of life' GET '')"
expect digest-md5-wrong-method "0" "$(printf '%s' "$AUTH" | "$KAT" verify Mufasa 'Circle of Life' POST '')"
AUTH256='Digest username="Mufasa", realm="http-auth@example.org", uri="/dir/index.html", algorithm=SHA-256, nonce="7ypf/xlj9XXwfDPEoM4URrv/xwf94BcCAzFZH4GiTo0v", nc=00000001, cnonce="f2/wE4q74E6zIJEtWaHKaf5wv/H5QzzpXusqGemxURZJ", qop=auth, response="753927fa0e85d155564e2e272a28d1802ca10daf4496794697cf8db5856cb6c1", opaque="FQhe/qaU925kfnzjCev0ciny7QMkPqMAFRtzCUYo5tdS"'
expect digest-sha256-ok "1" "$(printf '%s' "$AUTH256" | "$KAT" verify Mufasa 'Circle of Life' GET '')"
expect digest-sha256-wrong "0" "$(printf '%s' "$AUTH256" | "$KAT" verify Mufasa 'Circle of Death' GET '')"
expect auth-param-realm "http-auth@example.org" "$(printf '%s' "$AUTH" | "$KAT" authparam realm)"
expect auth-param-cnonce "f2/wE4q74E6zIJEtWaHKaf5wv/H5QzzpXusqGemxURZJ" "$(printf '%s' "$AUTH" | "$KAT" authparam cnonce)"

# RFC 3261 section 24.2: the INVITE and its 200 OK, read through the message parsers.
INVITE=$'INVITE sip:bob@biloxi.example.com SIP/2.0\r\nVia: SIP/2.0/UDP pc33.atlanta.example.com;branch=z9hG4bKnashds8\r\nTo: Bob <sip:bob@biloxi.example.com>\r\nFrom: Alice <sip:alice@atlanta.example.com>;tag=1928301774\r\nCall-ID: a84b4c76e66710@pc33.atlanta.example.com\r\nCSeq: 314159 INVITE\r\nContent-Length: 0\r\n\r\n'
expect sip-invite $'call-id=a84b4c76e66710@pc33.atlanta.example.com\ntag=<none>\ncseq=314159\ncode=0\nvia=SIP/2.0/UDP pc33.atlanta.example.com;branch=z9hG4bKnashds8\nfirst=INVITE sip:bob@biloxi.example.com SIP/2.0' "$(printf '%s' "$INVITE" | "$KAT" sip)"
OK200=$'SIP/2.0 200 OK\r\nVia: SIP/2.0/UDP server10.biloxi.example.com;branch=z9hG4bK4b43c2ff8.1\r\nTo: Bob <sip:bob@biloxi.example.com>;tag=a6c85cf\r\nFrom: Alice <sip:alice@atlanta.example.com>;tag=1928301774\r\nCall-ID: a84b4c76e66710@pc33.atlanta.example.com\r\nCSeq: 314159 INVITE\r\nContent-Length: 0\r\n\r\n'
expect sip-200 $'call-id=a84b4c76e66710@pc33.atlanta.example.com\ntag=a6c85cf\ncseq=314159\ncode=200\nvia=SIP/2.0/UDP server10.biloxi.example.com;branch=z9hG4bK4b43c2ff8.1\nfirst=SIP/2.0 200 OK' "$(printf '%s' "$OK200" | "$KAT" sip)"

# Percent-coding of the URL helpers.
expect url-encode 'a%20b%26c%3Dd%2F%C3%A9~' "$(printf 'a b&c=d/\xc3\xa9~' | "$KAT" urlencode)"
expect url-decode 'a b& c' "$(printf 'a%%20b%%26+c' | "$KAT" urldecode)"

emit_ctrf "sipp-gtest+kat" $((PASSED + KAT_PASS)) $((FAILED + KAT_FAIL)) "$SKIPPED"
