#!/usr/bin/env bash

set -euo pipefail

URL="${URL:-http://localhost:4000/auth/log_in}"
EMAIL="${EMAIL:-test@example.com}"

echo "Smoke test against ${URL}"
echo "Using email=${EMAIL}"
echo "---- Variant 1: email param ----"
for i in $(seq 1 12); do
  code=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
    -d "email=${EMAIL}" \
    "${URL}")
  echo "req ${i}: ${code}"
done

echo "---- Variant 2: user[email] param ----"
for i in $(seq 1 12); do
  code=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
    -d "user[email]=${EMAIL}" \
    "${URL}")
  echo "req ${i}: ${code}"
done
