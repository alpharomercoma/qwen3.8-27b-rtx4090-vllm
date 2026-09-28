#!/usr/bin/env python3
"""POD. Who may call the model API. Caddy asks this service before every /v1/* request (forward_auth).

Allowed callers:
  - CLI harnesses (pi, opencode, curl): a team API key listed in /workspace/.team_api_keys, one "<label> <key>" per
    line (manage with keys.sh; the file is re-read when it changes).
  - The web app's server on Vercel: a Vercel OIDC token, an RS256 JWT that Vercel mints for each deployment and
    rotates itself (2 h lifetime). Accepted only for this team's issuer and audience, the configured project id and
    environments (authz.env). No shared secret lives on Vercel.
Answers 200 with X-Heretic-Client: <caller> or 401 in OpenAI's error shape. Keys and tokens are never logged.
"""
import hashlib
import hmac
import json
import os
import sys
import threading
import time
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

import jwt  # PyJWT[crypto]

KEYS_FILE = os.environ.get("HERETIC_KEYS_FILE", "/workspace/.team_api_keys")
ISSUER = os.environ["VERCEL_OIDC_ISSUER"]            # https://oidc.vercel.com/<team-slug>
AUDIENCE = os.environ["VERCEL_OIDC_AUDIENCE"]        # https://vercel.com/<team-slug>
PROJECT_ID = os.environ["VERCEL_PROJECT_ID"]         # prj_...
ENVIRONMENTS = {e.strip() for e in os.environ.get("VERCEL_ENVIRONMENTS", "production").split(",") if e.strip()}
PORT = int(os.environ.get("AUTHZ_PORT", "8444"))
LEEWAY_S = 30


def log(msg):
    print(f"{time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime())} {msg}", flush=True)


def discover_jwks_uri():
    try:
        with urllib.request.urlopen(f"{ISSUER}/.well-known/openid-configuration", timeout=10) as r:
            return json.load(r)["jwks_uri"]
    except Exception as e:  # discovery is a convenience; the issuer's standard path is the fallback
        log(f"oidc discovery failed ({e}); using the issuer's /.well-known/jwks")
        return f"{ISSUER}/.well-known/jwks"


class SigningKeys:
    """Vercel's public signing keys, keyed by `kid`. Fetched on first use (startup must not wait on the network),
    refreshed hourly, and refreshed early for an unknown `kid` at most once a minute: a stream of made-up tokens
    therefore cannot make this server hammer Vercel or hang its threads on the network."""

    def __init__(self):
        self.uri, self.keys, self.fetched, self.lock = None, {}, 0.0, threading.Lock()

    def get(self, kid):
        now = time.time()
        with self.lock:
            stale = now - self.fetched > 3600
            unknown = kid not in self.keys and now - self.fetched > 60
            if stale or unknown:
                self.fetched = now  # also on failure: the next attempt waits its turn
                try:
                    self.uri = self.uri or discover_jwks_uri()
                    with urllib.request.urlopen(self.uri, timeout=10) as r:
                        data = json.load(r)
                    self.keys = {k.key_id: k for k in jwt.PyJWKSet.from_dict(data).keys if k.key_id}
                except Exception as e:
                    log(f"could not refresh Vercel's signing keys: {type(e).__name__}: {e}")
            return self.keys.get(kid)


SIGNING_KEYS = SigningKeys()
MAX_TOKEN_BYTES = 4096


class Keys:
    """Team keys, reloaded when the file changes. Compared in constant time."""

    def __init__(self, path):
        self.path, self.mtime, self.entries, self.lock = path, None, [], threading.Lock()

    def match(self, token):
        with self.lock:
            try:
                mtime = os.stat(self.path).st_mtime_ns
            except FileNotFoundError:
                mtime = None
            if mtime != self.mtime:
                self.entries = []
                if mtime is not None:
                    for line in open(self.path, encoding="utf-8"):
                        parts = line.split()
                        if len(parts) == 2 and not parts[0].startswith("#"):
                            self.entries.append((parts[0], parts[1].encode()))
                self.mtime = mtime
                log(f"loaded {len(self.entries)} team key(s)")
            entries = self.entries
        found = None
        for label, key in entries:  # check every key so timing does not depend on which one matched
            if hmac.compare_digest(key, token.encode()):
                found = label
        return found


KEYS = Keys(KEYS_FILE)
MAX_CONCURRENT = 64
SLOTS = threading.BoundedSemaphore(MAX_CONCURRENT)
_verified = {}  # sha256(token) -> (exp, caller); saves a signature check per request
_verified_lock = threading.Lock()


def check_vercel_token(token):
    digest = hashlib.sha256(token.encode()).hexdigest()
    now = time.time()
    with _verified_lock:
        hit = _verified.get(digest)
        if hit and hit[0] > now:
            return hit[1]
    if len(token) > MAX_TOKEN_BYTES:
        raise jwt.InvalidTokenError("token too long")
    # Cheap checks on the unverified token first; only a plausible token can cost a signature check or a key fetch.
    header = jwt.get_unverified_header(token)
    if header.get("alg") != "RS256" or not header.get("kid"):
        raise jwt.InvalidTokenError("not an RS256 token with a key id")
    if jwt.decode(token, options={"verify_signature": False}).get("iss") != ISSUER:
        raise jwt.InvalidTokenError("wrong issuer")
    key = SIGNING_KEYS.get(header["kid"])
    if key is None:
        raise jwt.InvalidTokenError("unknown signing key")
    claims = jwt.decode(
        token, key.key, algorithms=["RS256"], audience=AUDIENCE, issuer=ISSUER, leeway=LEEWAY_S,
        options={"require": ["exp", "iat", "iss", "aud", "sub"]},
    )
    if claims.get("project_id") != PROJECT_ID:
        raise jwt.InvalidTokenError("wrong project")
    if claims.get("environment") not in ENVIRONMENTS:
        raise jwt.InvalidTokenError(f"environment {claims.get('environment')!r} not allowed")
    caller = f"vercel-{claims['environment']}"
    with _verified_lock:
        if len(_verified) > 1000:
            _verified.clear()
        _verified[digest] = (min(claims["exp"], now + 600), caller)
    return caller


class Handler(BaseHTTPRequestHandler):
    server_version = "authz"
    sys_version = ""

    def log_message(self, *args):  # the gateway's access log already records requests
        pass

    def reply(self, status, caller=None, message=None, kind="authentication_error"):
        body = b"" if status == 200 else json.dumps(
            {"error": {"message": message, "type": kind, "code": "invalid_api_key" if status == 401 else kind}}).encode()
        self.send_response(status)
        if caller:
            self.send_header("X-Heretic-Client", caller)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def handle_auth(self):
        if not SLOTS.acquire(blocking=False):  # never more than MAX_CONCURRENT checks at once
            return self.reply(503, message="Too many requests at once; retry shortly.", kind="rate_limit_error")
        try:
            self.check()
        finally:
            SLOTS.release()

    def check(self):
        auth = self.headers.get("Authorization", "")
        token = auth[7:].strip() if auth[:7].lower() == "bearer " else ""
        who = self.headers.get("X-Forwarded-For", "?").split(",")[0].strip()
        uri = self.headers.get("X-Forwarded-Uri", "?")
        if not token:
            return self.reply(401, message="Missing API key. Send it as 'Authorization: Bearer <key>'.")
        label = KEYS.match(token)
        if label:
            return self.reply(200, caller=f"key-{label}")
        if token.count(".") == 2:
            try:
                return self.reply(200, caller=check_vercel_token(token))
            except Exception as e:
                log(f"rejected token from {who} for {uri}: {type(e).__name__}: {e}")
                return self.reply(401, message="Invalid or expired token.")
        log(f"rejected key from {who} for {uri}")
        return self.reply(401, message="Invalid API key.")

    do_GET = do_POST = do_HEAD = do_PUT = do_DELETE = do_PATCH = handle_auth


if __name__ == "__main__":
    log(f"authz on 127.0.0.1:{PORT}; issuer {ISSUER}; project {PROJECT_ID}; environments {sorted(ENVIRONMENTS)}")
    KEYS.match("")  # load the key file once at start, so a missing file shows in the log
    ThreadingHTTPServer.daemon_threads = True
    ThreadingHTTPServer(("127.0.0.1", PORT), Handler).serve_forever()
