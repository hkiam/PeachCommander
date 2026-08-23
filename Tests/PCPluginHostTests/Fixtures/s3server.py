#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""A minimal S3 origin for S3PluginTests.

Speaks just enough of the S3 REST API for the plugin to connect, list buckets, list objects with a
delimiter and pagination, HEAD, GET, PUT, DELETE, batch delete, server-side copy and multipart
upload: path-style addressing only, which is what anything reached at 127.0.0.1 has to use anyway.

**It verifies SigV4 rather than accepting it.** That is the point of the file. A fixture that ignores
the Authorization header proves the plugin can talk HTTP; it proves nothing about the signer, and the
signer is where an S3 client is actually wrong — a mis-encoded key, an unsorted query, a header in
the signature that is not in the request. Here a signing bug fails every single request, loudly.

Storage is a directory tree: the top level is buckets, everything under one is objects, and a key's
slashes are real directories. A zero-byte file whose name ends in "/" cannot exist on a filesystem,
so a directory with no children stands in for a prefix marker.

Usage: s3server.py <root-dir> <port>
"""
import base64
import datetime
import email.utils
import hashlib
import hmac
import os
import re
import shutil
import sys
import urllib.parse
import xml.sax.saxutils
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

ROOT = os.path.abspath(sys.argv[1])
PORT = int(sys.argv[2])

# The one identity this server knows. The tests hand the same pair to the plugin.
ACCESS_KEY = os.environ.get("PC_S3_FIXTURE_KEY", "peachtestkey")
SECRET_KEY = os.environ.get("PC_S3_FIXTURE_SECRET", "peachtestsecret")
REGION = os.environ.get("PC_S3_FIXTURE_REGION", "us-east-1")
# Small on purpose: the tests need more than one page without creating a thousand objects.
MAX_KEYS_CAP = int(os.environ.get("PC_S3_FIXTURE_MAX_KEYS", "1000"))
# Stop answering after this many object listings, to make "the server died halfway through a paged
# directory" a thing a test can arrange rather than time. 0 = never.
DIE_AFTER_LISTINGS = int(os.environ.get("PC_S3_FIXTURE_DIE_AFTER_LISTINGS", "0"))
# Refuse this part number of every multipart upload, so that "the upload failed halfway" is a thing a
# test can arrange. An orphaned multipart is billed and invisible, so the cleanup needs proving.
FAIL_PART = int(os.environ.get("PC_S3_FIXTURE_FAIL_PART", "0"))
# Answer the first N requests of the named methods with 503, so a retry policy can be tested rather
# than assumed. The counters are written to PC_S3_FIXTURE_STATS_FILE after every request, because a
# test needs to see how many attempts actually arrived — proving that POST is NOT retried is only
# possible by counting.
FLAKY = int(os.environ.get("PC_S3_FIXTURE_FLAKY", "0"))
FLAKY_METHODS = {m.strip().upper() for m in
                 os.environ.get("PC_S3_FIXTURE_FLAKY_METHODS", "GET").split(",") if m.strip()}
STATS_FILE = os.environ.get("PC_S3_FIXTURE_STATS_FILE", "")
_counts = {}
_listings = [0]

# In-flight multipart uploads: id -> {"bucket":…, "key":…, "parts": {number: bytes}}.
# Deliberately in memory and deliberately observable through `GET /<bucket>?uploads`, which is the
# real API — so a test can prove an aborted upload left nothing behind instead of trusting that it did.
_uploads = {}
_next_upload = [1]

UNRESERVED = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"


def uri_encode(value):
    """AWS UriEncode: percent-encode everything outside RFC 3986 unreserved.

    Used for SIGNING, where the rule is strict RFC 3986 and a space is %20.
    """
    return urllib.parse.quote(value, safe=UNRESERVED)


def response_encode(value):
    """Encode a key for an `encoding-type=url` response, the way a real server does.

    Form-encoding: a space becomes "+", a literal "+" becomes "%2B". This used to be `uri_encode`,
    which meant the fixture encoded exactly the way the plugin decoded — so both were wrong together
    and no test could see it. A real MinIO server returns `odd +name=v~1.txt` as
    `odd+%2Bname%3Dv%7E1.txt`, and that difference is what the Docker conformance suite found.
    """
    return urllib.parse.quote_plus(value, safe="")


def esc(s):
    return xml.sax.saxutils.escape(s)


def iso8601(stamp):
    """The listing timestamp format, with the milliseconds the real service always sends."""
    return datetime.datetime.fromtimestamp(stamp, datetime.timezone.utc).strftime(
        "%Y-%m-%dT%H:%M:%S.000Z")


def hmac_sha256(key, message):
    return hmac.new(key, message.encode("utf-8"), hashlib.sha256).digest()


def signing_key(date_stamp):
    k = hmac_sha256(("AWS4" + SECRET_KEY).encode("utf-8"), date_stamp)
    k = hmac_sha256(k, REGION)
    k = hmac_sha256(k, "s3")
    return hmac_sha256(k, "aws4_request")


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, fmt, *args):
        pass   # the test reads results, not a request log

    # ---- plumbing -----------------------------------------------------------------------------

    def _is_ping(self):
        """A readiness probe from the test harness, not traffic.

        It has to be distinguishable, because the harness polls until it gets a 200 — and against a
        server configured to answer 503 a few times, the probe would eat exactly the transient
        failures the plugin was supposed to see. That happened: a retry test measured 101 requests and
        a successful listing, because the probe had used the whole budget up.
        """
        return (self.headers.get("x-fixture-ping") or "") != ""

    def _count(self):
        """Record this request, and say whether it should be failed as transient."""
        _counts[self.command] = _counts.get(self.command, 0) + 1
        _counts["ALL"] = _counts.get("ALL", 0) + 1
        if STATS_FILE:
            try:
                with open(STATS_FILE, "w") as handle:
                    for key in sorted(_counts):
                        handle.write("%s=%d\n" % (key, _counts[key]))
            except OSError:
                pass
        if not FLAKY or self.command not in FLAKY_METHODS:
            return False
        return _counts.get("flaky:" + self.command, 0) < FLAKY

    def _flake(self):
        """Answer 503 and record that we did."""
        _counts["flaky:" + self.command] = _counts.get("flaky:" + self.command, 0) + 1
        self._error(503, "SlowDown", "please reduce your request rate")

    def _body(self):
        """Always read the body. An unread one desynchronises the keep-alive connection."""
        length = int(self.headers.get("Content-Length") or 0)
        return self.rfile.read(length) if length else b""

    def _send(self, code, body=b"", content_type="application/xml", extra=None, head_only=False):
        self.send_response(code)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        for k, v in (extra or {}).items():
            self.send_header(k, v)
        self.end_headers()
        if body and not head_only:
            self.wfile.write(body)

    def _error(self, code, s3code, message, extra_elements=""):
        body = (
            '<?xml version="1.0" encoding="UTF-8"?>'
            "<Error><Code>%s</Code><Message>%s</Message>%s"
            "<RequestId>FIXTURE</RequestId></Error>"
        ) % (esc(s3code), esc(message), extra_elements)
        self._send(code, body.encode("utf-8"), head_only=(self.command == "HEAD"))

    # ---- SigV4 verification -------------------------------------------------------------------

    def _raw_path_and_query(self):
        """The path exactly as sent, and the query string, without decoding either.

        Decoding and re-encoding would hide the very bug this server exists to catch: a client that
        encodes a key differently from the way it signs it.
        """
        if "?" in self.path:
            path, query = self.path.split("?", 1)
        else:
            path, query = self.path, ""
        return path, query

    def _canonical_query(self, query):
        if not query:
            return ""
        pairs = []
        for part in query.split("&"):
            if not part:
                continue
            if "=" in part:
                name, value = part.split("=", 1)
            else:
                name, value = part, ""
            # Re-encode from the decoded form so that a client which under-encodes is still measured
            # against the canonical form, and therefore fails.
            pairs.append((uri_encode(urllib.parse.unquote(name)),
                          uri_encode(urllib.parse.unquote(value))))
        pairs.sort()
        return "&".join("%s=%s" % p for p in pairs)

    def _verify_signature(self, body):
        """Return None when the request is properly signed, or an (http, code, message) tuple."""
        auth = self.headers.get("Authorization")
        if not auth:
            # Unsigned. Allowed only for reads, which is what a public bucket is.
            if self.command in ("GET", "HEAD"):
                return None
            return (403, "AccessDenied", "anonymous writes are not allowed")

        if not auth.startswith("AWS4-HMAC-SHA256 "):
            return (400, "InvalidRequest", "unsupported authorization scheme")
        fields = {}
        for item in auth[len("AWS4-HMAC-SHA256 "):].split(","):
            if "=" in item:
                k, v = item.strip().split("=", 1)
                fields[k] = v
        credential = fields.get("Credential", "")
        signed_headers = fields.get("SignedHeaders", "")
        provided = fields.get("Signature", "")
        parts = credential.split("/")
        if len(parts) != 5:
            return (403, "AuthorizationHeaderMalformed", "bad credential scope")
        key_id, date_stamp, region, service, terminator = parts
        if key_id != ACCESS_KEY:
            return (403, "InvalidAccessKeyId", "no such access key")
        if region != REGION:
            # The real service answers this way and puts the right region in the body, which is what
            # lets a client retry there instead of guessing.
            return (400, "AuthorizationHeaderMalformed",
                    "the region is wrong; expecting '%s'" % REGION,)
        if service != "s3" or terminator != "aws4_request":
            return (403, "AuthorizationHeaderMalformed", "bad credential scope")

        amz_date = self.headers.get("x-amz-date") or ""
        payload_hash = self.headers.get("x-amz-content-sha256") or ""
        if not amz_date or not payload_hash:
            return (400, "InvalidRequest", "x-amz-date and x-amz-content-sha256 are required")

        # The body really must hash to what was signed, otherwise "signed" means nothing.
        if payload_hash != "UNSIGNED-PAYLOAD":
            actual = hashlib.sha256(body).hexdigest()
            if actual != payload_hash:
                return (400, "XAmzContentSHA256Mismatch",
                        "the body does not hash to x-amz-content-sha256")

        path, query = self._raw_path_and_query()
        canonical_headers = ""
        for name in signed_headers.split(";"):
            if name == "host":
                value = self.headers.get("Host") or ""
            else:
                value = self.headers.get(name)
                if value is None:
                    return (403, "SignatureDoesNotMatch",
                            "signed header '%s' is not in the request" % name)
            canonical_headers += "%s:%s\n" % (name, value.strip())

        canonical_request = "\n".join([
            self.command,
            path,
            self._canonical_query(query),
            canonical_headers,
            signed_headers,
            payload_hash,
        ])
        scope = "%s/%s/s3/aws4_request" % (date_stamp, REGION)
        string_to_sign = "\n".join([
            "AWS4-HMAC-SHA256",
            amz_date,
            scope,
            hashlib.sha256(canonical_request.encode("utf-8")).hexdigest(),
        ])
        expected = hmac.new(signing_key(date_stamp),
                            string_to_sign.encode("utf-8"), hashlib.sha256).hexdigest()
        if not hmac.compare_digest(expected, provided):
            return (403, "SignatureDoesNotMatch",
                    "the signature does not match; canonical request was:\n" + canonical_request)
        return None

    # ---- addressing ---------------------------------------------------------------------------

    def _target(self):
        """(bucket, key) for this request, path-style. Either may be None/empty."""
        path, _ = self._raw_path_and_query()
        decoded = urllib.parse.unquote(path)
        trimmed = decoded.lstrip("/")
        if not trimmed:
            return None, ""
        if "/" in trimmed:
            bucket, key = trimmed.split("/", 1)
            return bucket, key
        return trimmed, ""

    def _query(self):
        _, query = self._raw_path_and_query()
        return urllib.parse.parse_qs(query, keep_blank_values=True)

    def _prune(self, path, bucket):
        """Remove `path`'s directory, and its now-empty parents, up to the bucket root.

        The fixture stores a prefix marker as an empty directory, because a file whose name ends in
        "/" cannot exist. That representation reads correctly and *writes* wrongly: deleting the last
        object out of a folder left an empty directory behind, which `_walk_keys` then reported as a
        marker — so a folder that had just been deleted was still listed, and so was the source of a
        folder that had just been moved. Real S3 has no marker unless one was created, so an emptied
        prefix simply stops existing. Pruning here is what makes the two agree.
        """
        base = os.path.join(ROOT, bucket)
        current = os.path.dirname(path)
        while current.startswith(base + os.sep):
            try:
                if os.listdir(current):
                    return
                os.rmdir(current)
            except OSError:
                return
            current = os.path.dirname(current)

    def _local(self, bucket, key):
        """The file behind (bucket, key), or None when it would leave the served tree."""
        target = os.path.abspath(os.path.join(ROOT, bucket, key)) if bucket else ROOT
        if target != ROOT and not target.startswith(ROOT + os.sep):
            return None
        return target

    # ---- verbs --------------------------------------------------------------------------------

    def do_GET(self):
        self._handle(head_only=False)

    def do_HEAD(self):
        self._handle(head_only=True)

    def _handle(self, head_only):
        body = self._body()
        if self._is_ping():
            return self._send(200, b"", head_only=head_only)
        problem = self._verify_signature(body)
        if problem:
            extra = ""
            if problem[1] == "AuthorizationHeaderMalformed":
                extra = "<Region>%s</Region>" % esc(REGION)
            return self._error(problem[0], problem[1], problem[2], extra)

        if self._count():
            return self._flake()

        bucket, key = self._target()
        if bucket is None:
            return self._list_buckets(head_only)

        base = self._local(bucket, "")
        if base is None or not os.path.isdir(base):
            return self._error(404, "NoSuchBucket", "no such bucket")

        if not key:
            query = self._query()
            if "uploads" in query:
                return self._list_multipart_uploads(bucket, head_only)
            if "list-type" in query:
                return self._list_objects(bucket, query, head_only)
            # HEAD on a bucket: it exists, and that is the whole answer.
            return self._send(200, b"", head_only=head_only)

        return self._get_object(bucket, key, head_only)

    def _list_buckets(self, head_only):
        rows = []
        for name in sorted(os.listdir(ROOT)):
            if not os.path.isdir(os.path.join(ROOT, name)):
                continue
            stamp = os.stat(os.path.join(ROOT, name)).st_mtime
            rows.append("<Bucket><Name>%s</Name><CreationDate>%s</CreationDate></Bucket>"
                        % (esc(name), iso8601(stamp)))
        body = (
            '<?xml version="1.0" encoding="UTF-8"?>'
            '<ListAllMyBucketsResult xmlns="http://s3.amazonaws.com/doc/2006-03-01/">'
            "<Owner><ID>fixture</ID><DisplayName>fixture-owner</DisplayName></Owner>"
            "<Buckets>%s</Buckets></ListAllMyBucketsResult>"
        ) % "".join(rows)
        self._send(200, body.encode("utf-8"), head_only=head_only)

    def _walk_keys(self, bucket):
        """Every key in `bucket`, plus a synthetic "dir/" key for each empty directory."""
        base = os.path.join(ROOT, bucket)
        keys = []
        for dirpath, dirnames, filenames in os.walk(base):
            rel = os.path.relpath(dirpath, base)
            prefix = "" if rel == "." else rel + "/"
            for name in filenames:
                keys.append((prefix + name, os.path.join(dirpath, name)))
            for name in dirnames:
                full = os.path.join(dirpath, name)
                if not os.listdir(full):
                    # An empty directory is how this fixture stores a prefix marker object, since a
                    # file whose name ends in "/" cannot exist.
                    keys.append((prefix + name + "/", None))
        keys.sort(key=lambda pair: pair[0])
        return keys

    def _list_objects(self, bucket, query, head_only):
        prefix = query.get("prefix", [""])[0]
        delimiter = query.get("delimiter", [""])[0]
        encoding = query.get("encoding-type", [""])[0]
        token = query.get("continuation-token", [""])[0]
        try:
            max_keys = min(int(query.get("max-keys", [str(MAX_KEYS_CAP)])[0]), MAX_KEYS_CAP)
        except ValueError:
            max_keys = MAX_KEYS_CAP
        max_keys = max(1, max_keys)

        def out(value):
            return response_encode(value) if encoding == "url" else esc(value)

        contents, prefixes = [], []
        for key, local in self._walk_keys(bucket):
            if not key.startswith(prefix):
                continue
            rest = key[len(prefix):]
            if delimiter and delimiter in rest:
                common = prefix + rest.split(delimiter, 1)[0] + delimiter
                if common not in prefixes:
                    prefixes.append(common)
                continue
            contents.append((key, local))

        # One flat, ordered stream so that a continuation token is just an offset into it. The real
        # service's tokens are opaque; so is this one, as far as the client can tell.
        items = [("p", p, None) for p in prefixes] + [("c", k, l) for k, l in contents]
        items.sort(key=lambda triple: triple[1])
        start = 0
        if token:
            try:
                start = int(base64.urlsafe_b64decode(token.encode()).decode())
            except Exception:
                return self._error(400, "InvalidArgument", "bad continuation token")
        page = items[start:start + max_keys]
        truncated = start + len(page) < len(items)

        rows = []
        for kind, value, local in page:
            if kind == "p":
                rows.append("<CommonPrefixes><Prefix>%s</Prefix></CommonPrefixes>" % out(value))
                continue
            if local is None:
                size, stamp = 0, 0
            else:
                st = os.stat(local)
                size, stamp = st.st_size, st.st_mtime
            etag = "fixture-%d" % size
            rows.append(
                "<Contents><Key>%s</Key><LastModified>%s</LastModified>"
                "<ETag>&quot;%s&quot;</ETag><Size>%d</Size>"
                "<StorageClass>STANDARD</StorageClass></Contents>"
                % (out(value), iso8601(stamp), etag, size))

        next_token = ""
        if truncated:
            offset = str(start + len(page)).encode()
            next_token = "<NextContinuationToken>%s</NextContinuationToken>" % esc(
                base64.urlsafe_b64encode(offset).decode())

        body = (
            '<?xml version="1.0" encoding="UTF-8"?>'
            '<ListBucketResult xmlns="http://s3.amazonaws.com/doc/2006-03-01/">'
            "<Name>%s</Name><Prefix>%s</Prefix><Delimiter>%s</Delimiter>"
            "<MaxKeys>%d</MaxKeys><KeyCount>%d</KeyCount>"
            "<EncodingType>%s</EncodingType>"
            "<IsTruncated>%s</IsTruncated>%s%s</ListBucketResult>"
        ) % (esc(bucket), out(prefix), out(delimiter), max_keys, len(page),
             esc(encoding), "true" if truncated else "false", next_token, "".join(rows))
        self._send(200, body.encode("utf-8"), head_only=head_only)

        _listings[0] += 1
        if DIE_AFTER_LISTINGS and _listings[0] >= DIE_AFTER_LISTINGS:
            # The page above has already been written, so the client gets a truthful truncated
            # answer and then nothing. `os._exit` rather than a clean shutdown: a graceful stop would
            # drain in-flight requests, which is the opposite of what is being simulated.
            try:
                self.wfile.flush()
            except Exception:
                pass
            os._exit(0)

    def _get_object(self, bucket, key, head_only):
        local = self._local(bucket, key)
        if local is None:
            return self._error(403, "AccessDenied", "outside the served tree")
        if os.path.isdir(local):
            # A prefix, not an object. The real service answers 404 for the key "photos" when only
            # "photos/..." exists, and the plugin has to recognise that as a directory by listing.
            return self._error(404, "NoSuchKey", "no such key")
        if not os.path.isfile(local):
            return self._error(404, "NoSuchKey", "no such key")
        with open(local, "rb") as handle:
            data = handle.read()
        st = os.stat(local)
        extra = {
            "Last-Modified": email.utils.formatdate(st.st_mtime, usegmt=True),
            "ETag": '"fixture-%d"' % st.st_size,
            "x-amz-storage-class": "STANDARD",
            "Accept-Ranges": "bytes",
        }
        self._send(200, data, content_type="application/octet-stream",
                   extra=extra, head_only=head_only)


    def do_PUT(self):
        body = self._body()
        problem = self._verify_signature(body)
        if problem:
            return self._error(problem[0], problem[1], problem[2])

        if self._count():
            return self._flake()

        bucket, key = self._target()
        if bucket is None:
            return self._error(400, "InvalidRequest", "cannot PUT the service root")

        base = self._local(bucket, "")
        if base is None:
            return self._error(403, "AccessDenied", "outside the served tree")

        if not key:
            # CreateBucket. us-east-1 must not carry a LocationConstraint and every other region
            # must, which is the most common way a first CreateBucket fails — so it is checked.
            if os.path.isdir(base):
                return self._error(409, "BucketAlreadyOwnedByYou", "bucket exists")
            if body and b"LocationConstraint" in body and REGION == "us-east-1":
                return self._error(400, "InvalidLocationConstraint",
                                   "us-east-1 must not send a LocationConstraint")
            if not body and REGION != "us-east-1":
                return self._error(400, "InvalidLocationConstraint",
                                   "a LocationConstraint is required outside us-east-1")
            os.makedirs(base)
            return self._send(200, b"")

        query = self._query()
        if "uploadId" in query and "partNumber" in query:
            return self._upload_part(query, body)
        if "x-amz-copy-source" in {k.lower() for k in self.headers.keys()}:
            return self._copy_object(bucket, key)
        return self._write_object(bucket, key, body)

    def _write_object(self, bucket, key, body):
        local = self._local(bucket, key)
        if local is None:
            return self._error(403, "AccessDenied", "outside the served tree")
        if key.endswith("/"):
            # A prefix marker. It cannot be a file on a filesystem, so an empty directory stands in —
            # the same representation `_walk_keys` reads back.
            os.makedirs(local, exist_ok=True)
            return self._send(200, b"", extra={"ETag": '"d41d8cd98f00b204e9800998ecf8427e"'})
        parent = os.path.dirname(local)
        if not os.path.isdir(parent):
            os.makedirs(parent, exist_ok=True)
        if os.path.isdir(local):
            return self._error(409, "InvalidRequest", "a prefix of that name already exists")
        with open(local, "wb") as handle:
            handle.write(body)
        etag = hashlib.md5(body).hexdigest()
        self._send(200, b"", extra={"ETag": '"%s"' % etag})

    def _copy_object(self, bucket, key):
        source = None
        for name in self.headers.keys():
            if name.lower() == "x-amz-copy-source":
                source = self.headers[name]
                break
        source = urllib.parse.unquote((source or "").lstrip("/"))
        if "/" not in source:
            return self._error(400, "InvalidArgument", "malformed x-amz-copy-source")
        src_bucket, src_key = source.split("/", 1)
        src_local = self._local(src_bucket, src_key)
        dst_local = self._local(bucket, key)
        if src_local is None or dst_local is None:
            return self._error(403, "AccessDenied", "outside the served tree")
        if not os.path.isfile(src_local):
            return self._error(404, "NoSuchKey", "no such source key")
        parent = os.path.dirname(dst_local)
        if not os.path.isdir(parent):
            os.makedirs(parent, exist_ok=True)
        shutil.copyfile(src_local, dst_local)
        st = os.stat(dst_local)
        body = ('<?xml version="1.0" encoding="UTF-8"?><CopyObjectResult>'
                "<LastModified>%s</LastModified><ETag>&quot;fixture-%d&quot;</ETag>"
                "</CopyObjectResult>") % (iso8601(st.st_mtime), st.st_size)
        self._send(200, body.encode("utf-8"))

    def do_DELETE(self):
        body = self._body()
        problem = self._verify_signature(body)
        if problem:
            return self._error(problem[0], problem[1], problem[2])

        if self._count():
            return self._flake()

        bucket, key = self._target()
        if bucket is None:
            return self._error(400, "InvalidRequest", "cannot DELETE the service root")

        query = self._query()
        if "uploadId" in query:
            # AbortMultipartUpload. 204 whether or not it was there: the client calls this on every
            # failure path and must not be told off for aborting twice.
            _uploads.pop(query["uploadId"][0], None)
            return self._send(204, b"")

        base = self._local(bucket, "")
        if base is None or not os.path.isdir(base):
            return self._error(404, "NoSuchBucket", "no such bucket")

        if not key:
            if os.listdir(base):
                return self._error(409, "BucketNotEmpty", "the bucket still contains objects")
            os.rmdir(base)
            return self._send(204, b"")

        local = self._local(bucket, key)
        if local is None:
            return self._error(403, "AccessDenied", "outside the served tree")
        if key.endswith("/") and os.path.isdir(local):
            if not os.listdir(local):
                os.rmdir(local)
            return self._send(204, b"")
        if os.path.isfile(local):
            os.remove(local)
            self._prune(local, bucket)
        # 204 for a key that was never there, which is what the real service does — and the reason a
        # client must decide whether something is a folder BEFORE deleting it, since deleting a
        # folder as an object "succeeds" and removes nothing.
        self._send(204, b"")

    def do_POST(self):
        body = self._body()
        problem = self._verify_signature(body)
        if problem:
            return self._error(problem[0], problem[1], problem[2])

        if self._count():
            return self._flake()

        bucket, key = self._target()
        if bucket is None:
            return self._error(400, "InvalidRequest", "cannot POST the service root")
        query = self._query()

        if "delete" in query:
            return self._batch_delete(bucket, body)
        if "uploads" in query:
            return self._start_multipart(bucket, key)
        if "uploadId" in query:
            return self._complete_multipart(bucket, key, query, body)
        return self._error(400, "InvalidRequest", "unsupported POST")

    def _batch_delete(self, bucket, body):
        # Content-MD5 is REQUIRED on this call by the real service. Enforced here, because a client
        # that omits it works against a lenient fixture and fails against AWS.
        supplied = None
        for name in self.headers.keys():
            if name.lower() == "content-md5":
                supplied = self.headers[name]
                break
        if not supplied:
            return self._error(400, "MissingContentMD5", "Content-MD5 is required for a batch delete")
        expected = base64.b64encode(hashlib.md5(body).digest()).decode()
        if supplied.strip() != expected:
            return self._error(400, "BadDigest", "Content-MD5 does not match the body")

        keys = re.findall(rb"<Key>(.*?)</Key>", body, re.S)
        deleted, errors = [], []
        for raw in keys:
            key = xml.sax.saxutils.unescape(raw.decode("utf-8"))
            local = self._local(bucket, key)
            if local is None:
                errors.append((key, "AccessDenied"))
                continue
            try:
                if os.path.isdir(local):
                    if not os.listdir(local):
                        os.rmdir(local)
                        self._prune(local, bucket)
                elif os.path.isfile(local):
                    os.remove(local)
                    self._prune(local, bucket)
                deleted.append(key)
            except OSError:
                errors.append((key, "InternalError"))
        rows = "".join("<Deleted><Key>%s</Key></Deleted>" % esc(k) for k in deleted)
        rows += "".join("<Error><Key>%s</Key><Code>%s</Code></Error>" % (esc(k), c)
                        for k, c in errors)
        body_out = ('<?xml version="1.0" encoding="UTF-8"?><DeleteResult>%s</DeleteResult>' % rows)
        # 200 even when nothing was deleted, which is why the client has to read the body.
        self._send(200, body_out.encode("utf-8"))

    def _start_multipart(self, bucket, key):
        upload_id = "upload-%d" % _next_upload[0]
        _next_upload[0] += 1
        _uploads[upload_id] = {"bucket": bucket, "key": key, "parts": {}}
        body = ('<?xml version="1.0" encoding="UTF-8"?><InitiateMultipartUploadResult>'
                "<Bucket>%s</Bucket><Key>%s</Key><UploadId>%s</UploadId>"
                "</InitiateMultipartUploadResult>") % (esc(bucket), esc(key), esc(upload_id))
        self._send(200, body.encode("utf-8"))

    def _upload_part(self, query, body):
        upload_id = query["uploadId"][0]
        try:
            number = int(query["partNumber"][0])
        except ValueError:
            return self._error(400, "InvalidArgument", "bad partNumber")
        state = _uploads.get(upload_id)
        if state is None:
            return self._error(404, "NoSuchUpload", "no such upload")
        if FAIL_PART and number == FAIL_PART:
            return self._error(500, "InternalError", "this part is refused on purpose")
        state["parts"][number] = body
        self._send(200, b"", extra={"ETag": '"%s"' % hashlib.md5(body).hexdigest()})

    def _complete_multipart(self, bucket, key, query, body):
        upload_id = query["uploadId"][0]
        state = _uploads.get(upload_id)
        if state is None:
            return self._error(404, "NoSuchUpload", "no such upload")
        wanted = [int(n) for n in re.findall(rb"<PartNumber>(\d+)</PartNumber>", body)]
        if not wanted:
            return self._error(400, "InvalidRequest", "no parts listed")
        missing = [n for n in wanted if n not in state["parts"]]
        if missing:
            return self._error(400, "InvalidPart", "part %d was never uploaded" % missing[0])
        local = self._local(state["bucket"], state["key"])
        if local is None:
            return self._error(403, "AccessDenied", "outside the served tree")
        parent = os.path.dirname(local)
        if not os.path.isdir(parent):
            os.makedirs(parent, exist_ok=True)
        with open(local, "wb") as handle:
            for number in wanted:
                handle.write(state["parts"][number])
        del _uploads[upload_id]
        body_out = ('<?xml version="1.0" encoding="UTF-8"?><CompleteMultipartUploadResult>'
                    "<Bucket>%s</Bucket><Key>%s</Key><ETag>&quot;fixture-multipart&quot;</ETag>"
                    "</CompleteMultipartUploadResult>") % (esc(state["bucket"]), esc(state["key"]))
        self._send(200, body_out.encode("utf-8"))

    def _list_multipart_uploads(self, bucket, head_only):
        rows = "".join(
            "<Upload><Key>%s</Key><UploadId>%s</UploadId></Upload>" % (esc(v["key"]), esc(k))
            for k, v in sorted(_uploads.items()) if v["bucket"] == bucket)
        body = ('<?xml version="1.0" encoding="UTF-8"?><ListMultipartUploadsResult>'
                "<Bucket>%s</Bucket><IsTruncated>false</IsTruncated>%s"
                "</ListMultipartUploadsResult>") % (esc(bucket), rows)
        self._send(200, body.encode("utf-8"), head_only=head_only)


if __name__ == "__main__":
    ThreadingHTTPServer(("127.0.0.1", PORT), Handler).serve_forever()
