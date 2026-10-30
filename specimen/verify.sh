#!/usr/bin/env bash
# Verify this bundle offline. Requires Python 3.11+ and sdcreceipt >= 4.3.3 (see ../requirements.lock).
set -euo pipefail
cd "$(dirname "$0")"
sum() { if command -v sha256sum >/dev/null; then sha256sum "$1" | cut -d' ' -f1; else shasum -a 256 "$1" | cut -d' ' -f1; fi; }
field() { python3 -c "import json,sys;d=json.load(open(sys.argv[1]));d=d.get('receipt',d);print(d[sys.argv[2]])" "$1" "$2"; }
check() { if [ "$1" = "$2" ]; then echo "PASS  $3"; else echo "FAIL  $3 ($1 != $2)"; exit 1; fi; }

R=3-settlement/settlement-receipt-a50yy5wwmr4dl97s1je8eqlg.json
D=5-refused-contrast/settlement-receipt-DENY-bcwiqmil3bmwlgirxyrfuzt0.json
# Since sdcreceipt 4.3.3 each key document is declared as the issuer's or a party's; --keys is refused.
KEYS=(--issuer-keys keys/sdcstudio-signing-keys.json --party-keys keys/kestrel-mercantile-vsl-key.json --party-keys keys/halvorsen-foods-vsl-key.json)
echo "== 1. The Receipt names the exact bytes of the source record and its model"
check "$(sum 1-source-record/receipt-advice-KM-RA-2026-000041.gdr.xml)" "$(field $R payload_hash)" "payload_hash = sha256(receipt advice GDR)"
check "$(sum 2-models/receipt-advice-dm-tog0v0p1zit1xwpxysxwpf3d.xsd)" "$(field $R schema_hash)" "schema_hash = sha256(receipt advice model)"
echo "== 2. The Receipt itself: issuer signature and both parties' release"
sdcreceipt verify $R "${KEYS[@]}"
echo "== 3. The refused transition: signed, attested, never settled"
check "$(sum 5-refused-contrast/receipt-advice-KM-RA-2026-000005.gdr.xml)" "$(field $D payload_hash)" "payload_hash = sha256(receipt advice KM-RA-2026-000005)"
sdcreceipt verify $D "${KEYS[@]}" || echo "(expected: a DENY Receipt accepts no triggers, so settlement is not established)"
echo "== 4. Every Governed Data Record validates against its model"
python3 - <<'PY'
from sdcvalidator import SDC4Validator
pairs = [("1-source-record/receipt-advice-KM-RA-2026-000041.gdr.xml", "2-models/receipt-advice-dm-tog0v0p1zit1xwpxysxwpf3d.xsd"),
         ("5-refused-contrast/receipt-advice-KM-RA-2026-000005.gdr.xml", "2-models/receipt-advice-dm-tog0v0p1zit1xwpxysxwpf3d.xsd"),
         ("4-execution/credit-note-HF-CN-2026-000041.gdr.xml", "2-models/credit-note-dm-jkuyr38hydqaiwlq5vhp2rjr.xsd")]
for x, s in pairs:
    errs = list(SDC4Validator(s).iter_errors(x))
    print(("PASS  " if not errs else "FAIL  ") + x + (" validates" if not errs else f": {errs[0]}"))
PY
echo "== 5. The execution record names the Settlement Receipt"
grep -q "urn:vsl:receipt:a50yy5wwmr4dl97s1je8eqlg" 4-execution/credit-note-HF-CN-2026-000041.gdr.xml && echo "PASS  credit note HF-CN-2026-000041 cites urn:vsl:receipt:a50yy5wwmr4dl97s1je8eqlg"
echo "== 6. Every file matches MANIFEST.sha256"
if command -v sha256sum >/dev/null; then sha256sum -c --quiet MANIFEST.sha256 && echo "PASS  manifest"; else shasum -a 256 -c MANIFEST.sha256 >/dev/null && echo "PASS  manifest"; fi
