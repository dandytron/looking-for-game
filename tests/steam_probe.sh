#!/usr/bin/env bash
#
# steam_probe.sh — Week-0 feasibility spike for LookingForGame.
# Proves we can actually pull Steam data (libraries, wishlists, app metadata)
# before any app code exists. Pure curl; no Go, no deps beyond curl + grep.
#
# Usage:
#   ./steam_probe.sh [VANITY_OR_STEAMID]        # keyless probes only
#   STEAM_API_KEY=xxxx ./steam_probe.sh dandytron   # also runs keyed probes
#
# Required probes (wishlist + appdetails) must pass or the script exits non-zero.
# Owned-games keyless returning 0 is a WARN, not a failure — that's the gap the
# keyed GetOwnedGames call exists to close.

set -u

TARGET="${1:-dandytron}"

# Auto-load .env (project root, then tests/) if STEAM_API_KEY isn't already set.
HERE="$(cd "$(dirname "$0")" && pwd)"
for envf in "$HERE/../.env" "$HERE/.env"; do
  if [[ -z "${STEAM_API_KEY:-}" && -f "$envf" ]]; then
    set -a; . "$envf"; set +a
  fi
done

KEY="${STEAM_API_KEY:-}"
OUT="$(dirname "$0")/out"
mkdir -p "$OUT"

pass() { printf '  \033[32mPASS\033[0m  %s\n' "$1"; }
warn() { printf '  \033[33mWARN\033[0m  %s\n' "$1"; }
fail() { printf '  \033[31mFAIL\033[0m  %s\n' "$1"; FAILED=1; }
hr()   { printf '\n=== %s ===\n' "$1"; }

FAILED=0

# --- 1. Resolve vanity -> SteamID64 -----------------------------------------
hr "1. Resolve  ($TARGET)"
if [[ "$TARGET" =~ ^[0-9]{17}$ ]]; then
  SID="$TARGET"
  pass "already a SteamID64: $SID"
else
  # keyless: public community profile as XML carries <steamID64>
  curl -s "https://steamcommunity.com/id/${TARGET}/?xml=1" >"$OUT/profile.xml"
  SID="$(sed -n 's:.*<steamID64>\([0-9]*\)</steamID64>.*:\1:p' "$OUT/profile.xml" | head -1)"
  if [[ -n "$SID" ]]; then
    PRIV="$(sed -n 's:.*<privacyState>\([a-z]*\)</privacyState>.*:\1:p' "$OUT/profile.xml" | head -1)"
    pass "keyless XML: $TARGET -> $SID (privacyState=$PRIV)"
  else
    fail "keyless XML did not yield a SteamID64 (private profile or bad vanity?)"
    echo "Cannot continue without a SteamID64." ; exit 1
  fi
  # keyed: the production path (ISteamUser/ResolveVanityURL)
  if [[ -n "$KEY" ]]; then
    curl -s "https://api.steampowered.com/ISteamUser/ResolveVanityURL/v1/?key=${KEY}&vanityurl=${TARGET}" >"$OUT/resolve_keyed.json"
    KSID="$(grep -oE '"steamid":"[0-9]+"' "$OUT/resolve_keyed.json" | grep -oE '[0-9]+')"
    if [[ "$KSID" == "$SID" ]]; then
      pass "keyed ResolveVanityURL agrees: $KSID"
    else
      warn "keyed ResolveVanityURL returned '$KSID' (expected $SID) — see out/resolve_keyed.json"
    fi
  fi
fi

# --- 2. Owned games (Library) -----------------------------------------------
hr "2. Owned games (Library)"
# keyless: community games list as XML (depends on the separate "game details" toggle)
curl -s "https://steamcommunity.com/profiles/${SID}/games?tab=all&xml=1" >"$OUT/games.xml"
GC="$(grep -oE '<appID>[0-9]+</appID>' "$OUT/games.xml" | wc -l | tr -d ' ')"
if [[ "$GC" -gt 0 ]]; then
  pass "keyless community XML: $GC games"
else
  warn "keyless community XML: 0 games (game-details privacy off, or endpoint unreliable) — this is why we use the keyed call"
fi
# keyed: IPlayerService/GetOwnedGames — the real production path
if [[ -n "$KEY" ]]; then
  curl -s "https://api.steampowered.com/IPlayerService/GetOwnedGames/v1/?key=${KEY}&steamid=${SID}&include_appinfo=1&include_played_free_games=1" >"$OUT/owned_keyed.json"
  KGC="$(grep -oE '"appid":[0-9]+' "$OUT/owned_keyed.json" | wc -l | tr -d ' ')"
  if [[ "$KGC" -gt 0 ]]; then
    pass "keyed GetOwnedGames: $KGC games"
  else
    fail "keyed GetOwnedGames returned 0 — key invalid, or this profile hides game details even from the API. See out/owned_keyed.json"
  fi
else
  warn "no STEAM_API_KEY set — skipping keyed GetOwnedGames (the path the Library column actually needs)"
fi

# --- 3. Wishlist (keyless IWishlistService) ---------------------------------
hr "3. Wishlist (IWishlistService/GetWishlist)"
CODE="$(curl -s -o "$OUT/wishlist.json" -w '%{http_code}' "https://api.steampowered.com/IWishlistService/GetWishlist/v1/?steamid=${SID}")"
WC="$(grep -oE '"appid":[0-9]+' "$OUT/wishlist.json" | wc -l | tr -d ' ')"
FIRST_APPID="$(grep -oE '"appid":[0-9]+' "$OUT/wishlist.json" | head -1 | grep -oE '[0-9]+')"
if [[ "$CODE" == "200" && "$WC" -gt 0 ]]; then
  pass "keyless HTTP $CODE, $WC items (shape: appid/priority/date_added)"
elif [[ "$CODE" == "200" ]]; then
  warn "keyless HTTP 200 but 0 items (empty or private wishlist)"
else
  fail "HTTP $CODE — see out/wishlist.json"
fi

# --- 4. Enrichment (keyless appdetails) -------------------------------------
hr "4. Enrichment (appdetails)"
PROBE_APPID="${FIRST_APPID:-322330}"   # fall back to Don't Starve Together
curl -s "https://store.steampowered.com/api/appdetails?appids=${PROBE_APPID}&filters=basic,categories" >"$OUT/appdetails.json"
NAME="$(grep -oE '"name":"[^"]+"' "$OUT/appdetails.json" | head -1 | sed 's/"name":"//; s/"$//')"
HASCAT="$(grep -oE '"categories"' "$OUT/appdetails.json" | head -1)"
if [[ -n "$NAME" ]]; then
  if [[ -n "$HASCAT" ]]; then
    pass "appid $PROBE_APPID -> \"$NAME\" (+categories present for Play-Together filter)"
  else
    warn "appid $PROBE_APPID -> \"$NAME\" but no categories block (some apps omit it)"
  fi
else
  fail "appdetails returned no name for appid $PROBE_APPID — see out/appdetails.json"
fi

# --- Summary -----------------------------------------------------------------
hr "Summary"
echo "  SteamID64 : $SID"
echo "  Key used  : $([[ -n "$KEY" ]] && echo yes || echo 'no (keyless only)')"
echo "  Raw dumps : $OUT/"
if [[ "$FAILED" -eq 0 ]]; then
  printf '  \033[32mRequired probes passed.\033[0m\n'
  exit 0
else
  printf '  \033[31mOne or more required probes failed.\033[0m\n'
  exit 1
fi
