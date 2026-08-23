#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# s3-conformance.sh — run the S3 plugin against a real MinIO server in Docker.
#
# WHY THIS IS NOT IN CI: ci.yml runs on macos-26 GitHub runners, which have no Docker. So this is a
# local gate, run by hand. If you are reading this because the suite "does not run in CI", that is
# deliberate and not a defect.
#
# WHAT IT ADDS OVER Tests/PCPluginHostTests/Fixtures/s3server.py: the fixture verifies SigV4 by
# recomputing it the same way the plugin computes it, so a shared misunderstanding would pass both.
# MinIO is an independent implementation — its own signature check, its own multipart assembly, its
# own error codes. That is the part a fixture cannot give.
#
# Usage: Tools/s3-conformance.sh            # start MinIO, run the suite, tear down
#        PC_S3_KEEP=1 Tools/s3-conformance.sh   # leave the container running afterwards
set -euo pipefail
cd "$(dirname "$0")/.."

CONTAINER="pc-s3-conformance"
IMAGE="${PC_S3_MINIO_IMAGE:-minio/minio}"
ACCESS_KEY="peachconformance"
SECRET_KEY="peachconformance-secret"

if ! command -v docker >/dev/null 2>&1; then
  echo "docker is not installed — this suite needs it. Skipping." >&2
  exit 0
fi
if ! docker info >/dev/null 2>&1; then
  echo "docker is installed but not running (try: colima start). Skipping." >&2
  exit 0
fi

# A free port, taken the usual way: bind one and let go. Nothing else on this machine is racing us.
PORT="$(python3 - <<'PY'
import socket
s = socket.socket()
s.bind(("127.0.0.1", 0))
print(s.getsockname()[1])
s.close()
PY
)"

cleanup() {
  if [ "${PC_S3_KEEP:-0}" = "1" ]; then
    echo "==> Leaving $CONTAINER running on port $PORT (PC_S3_KEEP=1)"
    return
  fi
  docker rm -f "$CONTAINER" >/dev/null 2>&1 || true
}
trap cleanup EXIT

docker rm -f "$CONTAINER" >/dev/null 2>&1 || true
echo "==> Starting MinIO on 127.0.0.1:$PORT"
docker run -d --rm --name "$CONTAINER" \
  -p "127.0.0.1:$PORT:9000" \
  -e "MINIO_ROOT_USER=$ACCESS_KEY" \
  -e "MINIO_ROOT_PASSWORD=$SECRET_KEY" \
  "$IMAGE" server /data >/dev/null

# Poll rather than sleep a guessed amount: a fixed wait is either slow or occasionally short, and
# "occasionally short" reads as the plugin failing to connect.
echo -n "==> Waiting for MinIO"
for _ in $(seq 1 120); do
  if curl -fsS -o /dev/null "http://127.0.0.1:$PORT/minio/health/live" 2>/dev/null; then
    echo " up"
    break
  fi
  echo -n "."
  sleep 0.5
done
if ! curl -fsS -o /dev/null "http://127.0.0.1:$PORT/minio/health/live" 2>/dev/null; then
  echo
  echo "MinIO never became healthy. Container log:" >&2
  docker logs "$CONTAINER" 2>&1 | tail -30 >&2
  exit 1
fi

echo "==> Running S3ConformanceTests"
# MinIO is reached by IP and port, so it can only do path-style addressing — there is no wildcard
# name to put a bucket in front of.
#
# Handed over in a FILE rather than the environment, and that is not a style choice. PCPluginHostTests
# is a host-less unit-test bundle, so neither a plain `export` nor xcodebuild's TEST_RUNNER_ prefix
# reaches the process the tests run in — both were tried, MinIO started, and all eight tests skipped
# while the script reported success. A file the test reads has no plumbing to get wrong.
xcodegen generate >/dev/null
mkdir -p build
cat > build/s3-conformance.env <<ENV
PC_S3_DOCKER=1
PC_S3_ENDPOINT=http://127.0.0.1:$PORT
PC_S3_REGION=us-east-1
PC_S3_ACCESS_KEY=$ACCESS_KEY
PC_S3_SECRET_KEY=$SECRET_KEY
PC_S3_PATH_STYLE=1
ENV
trap 'cleanup; rm -f build/s3-conformance.env' EXIT
LOG="$(mktemp -t s3-conformance)"
set +e
xcodebuild -project PeachCommander.xcodeproj -scheme AllTests -derivedDataPath build \
  -only-testing:PCPluginHostTests/S3ConformanceTests \
  test >"$LOG" 2>&1
STATUS=$?
set -e
grep -E "Test Case|error:|\*\* TEST|Executed .* tests" "$LOG" || true

# A suite that skipped everything is not a pass. Without this the script's own success meant nothing:
# it would report green with MinIO running and not a single request made to it.
# Both output shapes: xcodebuild used to print "Test Case '-[X y]' passed (0.1 seconds)" and now
# prints "Test case 'X.y()' passed on 'My Mac - xctest (123)' (0.1 seconds)". Counting only the old one
# made this report zero tests on a run that was entirely green — and since zero is treated as a
# failure, the script cried wolf instead of lying, which is the better half of the two.
PASSED="$(grep -cE "' passed (on |\()" "$LOG" || true)"
SKIPPED="$(grep -cE "' skipped (on |\()" "$LOG" || true)"
echo "==> passed=$PASSED skipped=$SKIPPED"
if [ "$PASSED" -eq 0 ]; then
  echo "FAILED: no conformance test actually ran (skipped=$SKIPPED)." >&2
  echo "        build/s3-conformance.env is how the settings reach the tests; check it exists." >&2
  echo "Full log: $LOG" >&2
  exit 1
fi
if [ "$STATUS" -ne 0 ]; then
  echo "FAILED: xcodebuild exited $STATUS. Full log: $LOG" >&2
  exit "$STATUS"
fi
rm -f "$LOG"
echo "==> Conformance suite green against MinIO"
