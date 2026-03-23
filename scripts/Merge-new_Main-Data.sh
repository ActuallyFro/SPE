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
#   AlphabeticalLetter, Title, ProgramType, StudentInterestLevel,
#   IsDataVerified, BLSDataYear, MedianSalary, MedianPayPerHour,
#   CurrentNumberJobs, JobOutlookGrowthPercent, JobOutlookChanges, JobSatisfaction

NEW_ARRAY=$(python3 - "$CSV_FILE" <<'PYEOF'
import csv, sys, json

csv_path = sys.argv[1]
rows = []

with open(csv_path, newline='', encoding='utf-8-sig') as f:
    reader = csv.DictReader(f)
    # Normalize header keys: strip whitespace, lowercase, remove special chars
    reader.fieldnames = [h.strip().lower().replace(' ', '').replace('{', '').replace('}', '').replace('%', '').replace('#', '') for h in reader.fieldnames]

    for r in reader:
        # Helper to safely get a value with fallbacks
        def get(keys, default=''):
            if isinstance(keys, str): keys = [keys]
            for k in keys:
                if k in r: return r[k].strip()
            return default

        letter       = get(['alphabeticalletter', 'letter'], '?').upper()
        title        = get('title')
        prog_type    = get(['programtype', 'type'])
        interest     = get(['studentinterestlevel', 'interestlevel', 'interest'], 'None')
        if interest not in ('High', 'Medium', 'Low', 'None'):
            interest = 'None'
        
        verified     = get(['isdataverified', 'verified'], 'No')
        year         = get(['blsdatayear', 'year'], '')

        def num(keys):
            val = get(keys)
            # Remove currency/percent symbols and commas
            val = val.replace('$', '').replace('%', '').replace(',', '')
            if val:
                try: return float(val)
                except ValueError: pass
            return 0

        salary       = num(['mediansalary', 'meansalary', 'salary'])
        hourly       = num(['medianpayperhour', 'hourly'])
        jobs         = num(['currentnumberjobs', 'currentjobs', 'jobs'])
        growth_pct   = num(['joboutlookgrowthpercent', 'jobgrowth', 'growth'])
        outlook_chg  = num(['joboutlookchanges'])
        satisfaction = num(['jobsatisfaction', 'satisfaction'])

        rows.append([letter, title, prog_type, interest, verified, year,
                     salary, hourly, jobs, growth_pct, outlook_chg, satisfaction])

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

# Pattern: match from `const RAW_DATA = [` up to but not including `//  STATE`
# If `//  STATE` is missing, fallback to `];`
# This consumes any trailing garbage from previous failed merges.

# 1. Try anchored match (safest)
# Matches `const RAW_DATA = [` ... (greedy until) ... `// ─────────────────────────────────────────────\n//  STATE`
pattern_anchored = r'(?s)(const RAW_DATA\s*=\s*\[.*?)(\s*// ─────────────────────────────────────────────\s*//\s*STATE)'

# 2. Try simple match if anchor missing
pattern_simple = r'(?s)(const RAW_DATA\s*=\s*\[.*?\];)'

updated = content
replaced = False

if re.search(pattern_anchored, content):
    # Determine what to replace WITH. new_block is `const RAW_DATA = [...];`
    # We want to replace group 1 with new_block.
    # Actually, re.sub on the whole match is easier:
    # replace (whole_match) with (new_block + \n\n + group 2)
    def repl(m):
        return new_block + '\n\n' + m.group(2)
    
    updated = re.sub(pattern_anchored, repl, content, count=1)
    replaced = True
    print("✅  Replaced RAW_DATA block (anchored to STATE section).")

elif re.search(pattern_simple, content):
    print("⚠️  STATE section not found or pattern mismatch, using simple replacement.")
    updated = re.sub(pattern_simple, new_block, content, count=1)
    replaced = True
else:
    print("❌  Could not find RAW_DATA block in HTML file.", file=sys.stderr)
    sys.exit(1)

with open(html_path, 'w', encoding='utf-8') as f:
    f.write(updated)

print(f"✅  RAW_DATA updated in {html_path}")
PYEOF

echo "🎉  Deploy complete — open SinclairExplorer.html to verify."
