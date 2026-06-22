#!/usr/bin/env bash
#
# privacy_propagation_log.sh — measure how long Steam's keyed Web API keeps
# serving a profile's data after its privacy settings change.
#
# Appends one timestamped row per run to out/privacy_timeline.log so repeated
# runs (e.g. every 30 min) build a timeline. We watch dev-key wishlist/owned
# counts for the moment they drop to 0 — that's the API-side cache reset.
#
# Throwaway investigation tool, not part of the app. Dev key only (the token
# isn't needed to detect the reset, and it expires in ~24h anyway).

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
for envf in "$HERE/../.env" "$HERE/.env"; do
  if [[ -z "${STEAM_API_KEY:-}" && -f "$envf" ]]; then set -a; . "$envf"; set +a; fi
done

SID="${1:-76561198000323336}"
LOG="$HERE/out/privacy_timeline.log"
mkdir -p "$HERE/out"

PRIV=$(curl -s "https://steamcommunity.com/profiles/${SID}/?xml=1" \
  | sed -n 's:.*<privacyState>\([a-z]*\)</privacyState>.*:\1:p' | head -1)
KW=$(curl -s "https://api.steampowered.com/IWishlistService/GetWishlist/v1/?key=${STEAM_API_KEY}&steamid=${SID}" \
  | grep -oE '"appid":[0-9]+' | wc -l | tr -d ' ')
KO=$(curl -s "https://api.steampowered.com/IPlayerService/GetOwnedGames/v1/?key=${STEAM_API_KEY}&steamid=${SID}&include_appinfo=1" \
  | grep -oE '"appid":[0-9]+' | wc -l | tr -d ' ')

TS=$(date '+%Y-%m-%d %H:%M:%S %Z')
ROW="$(printf '%s | privacyState=%-9s | devkey wishlist=%-4s owned=%-4s' "$TS" "$PRIV" "$KW" "$KO")"
echo "$ROW" | tee -a "$LOG"

# Exit 9 = reset detected (dev key can no longer see the data) so a caller can stop looping.
if [[ "$KW" -eq 0 && "$KO" -eq 0 ]]; then
  echo ">>> RESET DETECTED: dev key now sees 0/0 — API-side privacy has propagated."
  exit 9
fi
