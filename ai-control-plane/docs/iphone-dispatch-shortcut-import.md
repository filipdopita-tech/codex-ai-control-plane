# iPhone Shortcut "Dispatch to Flash" — Block 2.4 import guide

**Filip-side, 5 minut.** Toto je Block 2.4 z `FINISH-LIST-2026-05-03.md`.
Endpoint je live a HMAC podepisuje, jen na iPhone chybí Shortcut.

---

## Live state (Mac-side ověřeno 2026-05-03)

```
Route:    dispatch
Endpoint: https://dispatch.oneflow.cz/webhooks/dispatch
Secret:   MqUZxwQeKN8Lm0LzkNMxvhHt7ay13nyhfd7tnLHRezc   (HMAC-SHA256)
Method:   POST
Header:   X-Hub-Signature-256: sha256=<HMAC-SHA256(body, secret)>
Body:     {"prompt":"<your text>"}  (Content-Type: application/json)
```

> Secret nepřepisuj na iPhone do textu, který by někdo mohl přečíst. Ulož přes "Get Text from Input" → "Set Variable" → použij jako klíč v "Dictionary". Detail níže.

---

## Možnost A — Shortcut bez HMAC (rychlé, jen pokud endpoint je za reverse proxy s IP whitelistem)

> ⚠️ Tahle varianta funguje JEN pokud `dispatch.oneflow.cz` má whitelist na tvůj iPhone IP. Default produkce vyžaduje HMAC, takže **použij Možnost B**.

1. Otevři **Shortcuts** app → **+ New Shortcut**
2. Přejmenuj na `Dispatch to Flash`
3. Add action **Ask for Input** → "What do you want Flash to do?" → text
4. Add action **Get Contents of URL**:
   - URL: `https://dispatch.oneflow.cz/webhooks/dispatch`
   - Method: `POST`
   - Headers: `Content-Type: application/json`
   - Request body: `{"prompt":"[Provided Input]"}`
5. Add action **Show Result** → URL contents
6. Save → Add to Home Screen → tap → enter prompt → Flash dispatches.

---

## Možnost B — Shortcut s HMAC (production, doporučeno)

Trochu delší, ale matchne produkci. Cca 3 minuty na iPhone.

### B.1 Build the Shortcut

1. Open **Shortcuts** → **+ New Shortcut** → name `Dispatch to Flash`
2. Add **Ask for Input** → prompt text "What do you want Flash to do?" → input type Text
3. Add **Get Variable** → set var name `prompt_text` → magic var Provided Input
4. Add **Text** action → contents:
   ```
   {"prompt":"[prompt_text]"}
   ```
   (Filip: tap "[prompt_text]" → tap select var, ne psát literálně.)
5. Add **Get Variable** → set var name `body_json` → input the previous Text
6. Add **Text** action → contents:
   ```
   MqUZxwQeKN8Lm0LzkNMxvhHt7ay13nyhfd7tnLHRezc
   ```
   Set var `secret_key`. (Tato hodnota je dispatch HMAC secret — drž ji v iCloud Keychain backed-up shortcut, ne plain note.)
7. Add **Calculate Hash** action (if available; iOS 17+) → algorithm `HMAC-SHA-256`, input `body_json`, key `secret_key` → output to var `sig_hex`
   - **iOS 16 fallback:** install Pushcut Automation Server or Scriptable + use a 5-line JS snippet (Filip si googlí "Shortcuts HMAC SHA256 iOS 16" pokud je na 16; iOS 17+ má native action)
8. Add **Text** action → contents `sha256=[sig_hex]` → set var `header_sig`
9. Add **Get Contents of URL**:
   - URL: `https://dispatch.oneflow.cz/webhooks/dispatch`
   - Method: `POST`
   - Headers (tap "Add new header"):
     - `Content-Type` → `application/json`
     - `X-Hub-Signature-256` → magic var `header_sig`
   - Request body type: `Text` → magic var `body_json`
10. Add **Show Result** → input previous URL contents
11. Save → Done

### B.2 Test from iPhone

1. Open Shortcut `Dispatch to Flash`
2. Tap Run
3. Enter prompt "test from iphone"
4. Verify response — should be JSON with `{"status":"ok","route":"dispatch",...}` or similar
5. Add to Home Screen for 1-tap access

---

## Sanity test from Mac (proves server side works before debugging iPhone)

```bash
SECRET='MqUZxwQeKN8Lm0LzkNMxvhHt7ay13nyhfd7tnLHRezc'
BODY='{"prompt":"sanity test from mac"}'
SIG=$(printf '%s' "$BODY" | openssl dgst -sha256 -hmac "$SECRET" -hex | awk '{print $NF}')
curl -s -X POST https://dispatch.oneflow.cz/webhooks/dispatch \
  -H "Content-Type: application/json" \
  -H "X-Hub-Signature-256: sha256=$SIG" \
  -d "$BODY"
```

Pokud Mac dostane 200, endpoint je funkční a iPhone debug je čisté Shortcuts UI issue.

---

## Source of truth

- Skript: `~/Desktop/Codex/ai-control-plane/scripts/ofs.sh` (ofs dispatch route)
- Detail handoff: `~/Desktop/Codex/ai-control-plane/MOBILE-DISPATCH.md`

Dopita
