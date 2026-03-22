#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────
#  Merge-new_Main-Data.sh
#  Reads data/SinclairPrograms_Main.csv and rewrites the RAW_DATA
#  array inside SinclairExplorer.html in-place.
#
#  Usage:  bash scripts/Merge-new_Main-Data.sh
#  Run from the project root (the folder containing SinclairExplorer.html)
# ─────────────────────────────────────────────────────────────────

set -euo pipefail

# ── Paths (relative to project root) ─────────────────────────────
HTML_FILE="SinclairExplorer.html"
CSV_FILE="data/SinclairPrograms_Main.csv"

# ── Sanity checks ─────────────────────────────────────────────────
if [[ ! -f "$HTML_FILE" ]]; then
  echo "❌  Cannot find $HTML_FILE — run this script from the project root." >&2
  exit 1
fi
if [[ ! -f "$CSV_FILE" ]]; then
  echo "❌  Cannot find $CSV_FILE" >&2
  exit 1
fi

# ── Build the new RAW_DATA JS block from the CSV ──────────────────
# Expected CSV columns (row 1 = header, skipped):
#   AlphabeticalLetter, Title, ProgramType, InterestLevel,
#   MeanSalary, CurrentJobs, JobGrowth, JobSatisfaction

NEW_ARRAY=$(python3 - "$CSV_FILE" <<'PYEOF'
import csv, sys, json

csv_path = sys.argv[1]
rows = []

with open(csv_path, newline='', encoding='utf-8-sig') as f:
    reader = csv.DictReader(f)
    # Normalize header keys: strip whitespace, lowercase
    reader.fieldnames = [h.strip().lower().replace(' ', '') for h in reader.fieldnames]

    for r in reader:
        letter       = r.get('alphabeticalletter', r.get('letter', '?')).strip().upper()
        title        = r.get('title', '').strip()
        prog_type    = r.get('programtype', r.get('type', '')).strip()
        interest     = r.get('interestlevel', r.get('interest', 'None')).strip()
        if interest not in ('High', 'Medium', 'Low', 'None'):
            interest = 'None'

        def num(key, *aliases):
            for k in (key, *aliases):
                v = r.get(k, '').strip()
                if v:
                    try: return float(v)
                    except ValueError: pass
            return 0

        salary       = num('meansalary',    'salary')
        jobs         = num('currentjobs',   'jobs')
        growth       = num('jobgrowth',     'growth')
        satisfaction = num('jobsatisfaction','satisfaction')

        rows.append([letter, title, prog_type, interest,
                     salary, jobs, growth, satisfaction])

# Emit as JS array literal, one row per line
lines = ['const RAW_DATA = [']
for i, row in enumerate(rows):
    comma = ',' if i < len(rows) - 1 else ''
    # Numbers: omit decimals when whole
    def fmt(v):
        if isinstance(v, float):
            return str(int(v)) if v == int(v) else str(v)
        return json.dumps(v, ensure_ascii=False)
    parts = ','.join(fmt(v) for v in row)
    lines.append(f'  [{parts}]{comma}')
lines.append('];')
print('\n'.join(lines))
PYEOF
)

if [[ -z "$NEW_ARRAY" ]]; then
  echo "❌  Failed to parse CSV — no rows generated." >&2
  exit 1
fi

ROW_COUNT=$(echo "$NEW_ARRAY" | grep -c '^\s*\[' || true)
echo "✅  Parsed $ROW_COUNT programs from $CSV_FILE"

# ── Replace the RAW_DATA block in the HTML ────────────────────────
# Matches from "const RAW_DATA = [" through the closing "];" line.
# Uses Python for reliable multi-line in-place replacement
# (avoids sed/awk portability issues across macOS and Linux).

python3 - "$HTML_FILE" "$NEW_ARRAY" <<'PYEOF'
import sys, re

html_path  = sys.argv[1]
new_block  = sys.argv[2]

with open(html_path, 'r', encoding='utf-8') as f:
    content = f.read()

pattern = r'const RAW_DATA\s*=\s*\[.*?\];'
flags   = re.DOTALL

if not re.search(pattern, content, flags):
    print("❌  Could not find RAW_DATA block in HTML file.", file=sys.stderr)
    sys.exit(1)

updated = re.sub(pattern, new_block, content, count=1, flags=flags)

with open(html_path, 'w', encoding='utf-8') as f:
    f.write(updated)

print(f"✅  RAW_DATA updated in {html_path}")
PYEOF

echo "🎉  Deploy complete — open SinclairExplorer.html to verify."
