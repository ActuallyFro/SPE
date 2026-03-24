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
# AlphabeticalLetter, Title, ProgramType, StudentInterestLevel, IsDataVerified, BLSDataYear,
# MedianSalary, MedianPayPerHour, CurrentNumberJobs, JobOutlookGrowthPercent, JobOutlookChanges, JobSatisfaction,
# AIImpact, BLSTitle, BLSUrl, OEWSOhioMedianSalary, OEWSOhioPayPerHour, OEWSOhioEmployment, OEWSOhioEmploymentPer1000, OEWSOhioURL, EntryLevelDegree

NEW_ARRAY=$(python3 - "$CSV_FILE" <<'PYEOF'
import csv, sys, json

csv_path = sys.argv[1]
rows = []

try:
    with open(csv_path, newline='', encoding='utf-8-sig') as f:
        reader = csv.DictReader(f)
        # Normalize header keys: strip whitespace, lowercase, remove special chars
        # Columns in recent CSV: AlphabeticalLetter,Title,ProgramType,StudentInterestLevel,IsDataVerified,BLSDataYear,MedianSalary,MedianPayPerHour,
        # CurrentNumberJobs,JobOutlookGrowthPercent,JobOutlookChanges,JobSatisfaction,AIImpact,BLSTitle,BLSUrl,OEWSOhioMedianSalary,
        # OEWSOhioPayPerHour,OEWSOhioEmployment,OEWSOhioEmploymentPer1000,OEWSOhioURL,EntryLevelDegree
        
        reader.fieldnames = [
            h.strip().lower()
             .replace(' ', '')
             .replace('{', '')
             .replace('}', '')
             .replace('%', '')
             .replace('#', '')
             .replace('/', '')
            for h in reader.fieldnames
        ]

        for r in reader:
            # Helper to safely get a value with fallbacks
            def get(keys, default=''):
                if isinstance(keys, str): keys = [keys]
                for k in keys:
                    if k in r: return r[k].strip()
                return default

            # ── Parsing Helpers ─────────────────────────────────────────
            def num(keys):
                val = get(keys)
                # Remove currency/percent symbols and commas
                val = val.replace('$', '').replace('%', '').replace(',', '')
                if val and val != '-' and val.lower() != 'nan':
                    try: return float(val)
                    except ValueError: pass
                return None  # Return None (JSON null) for missing values instead of 0

            # ── Column Extraction ───────────────────────────────────────
            letter        = get(['alphabeticalletter', 'letter'], '?').upper()
            title         = get('title')
            prog_type     = get(['programtype', 'type'])
            interest      = get(['studentinterestlevel', 'interestlevel', 'interest'], 'None')
            # Normalize interest
            if interest not in ('High', 'Medium', 'Low', 'None'):
                interest = 'None'
            
            verified      = get(['isdataverified', 'verified'], 'No')
            year          = get(['blsdatayear', 'year'], '')

            # National Data
            salary        = num(['mediansalary', 'meansalary', 'salary'])
            hourly        = num(['medianpayperhour', 'hourly'])
            jobs          = num(['currentnumberjobs', 'currentjobs', 'jobs'])
            growth_pct    = num(['joboutlookgrowthpercent', 'jobgrowth', 'growth'])
            outlook_chg   = num(['joboutlookchanges'])
            satisfaction  = num(['jobsatisfaction', 'satisfaction'])

            # Extended Data
            ai_impact     = get(['aiimpact', 'ai'], 'Low')
            bls_title     = get(['blstitle'])
            bls_url       = get(['blsurl', 'url'])

            # Ohio OEWS Data
            # Header: OEWSOhioMedianSalary -> oewsohiomediansalary
            oh_salary     = num(['oewsohiomediansalary', 'ohiosalary'])
            oh_hourly     = num(['oewsohiopayperhour', 'ohiohourly'])
            oh_jobs       = num(['oewsohioemployment', 'ohiojobs', 'ohioemployment'])
            oh_density    = num(['oewsohioemploymentper1000', 'ohiokpl', 'ohiodensity'])
            oh_url        = get(['oewsohiourl', 'ohiourl'])
            
            # Education
            entry_degree  = get(['entryleveldegree', 'degree', 'education'])

            rows.append([
                letter, title, prog_type, interest, verified, year,
                salary, hourly, jobs, growth_pct, outlook_chg, satisfaction,
                ai_impact, bls_title, bls_url, 
                oh_salary, oh_hourly, oh_jobs, oh_density, oh_url, entry_degree
            ])
except Exception as e:
    # Print error to stderr so it doesn't end up in the JS output
    import sys
    print(f"Error parsing CSV: {e}", file=sys.stderr)
    sys.exit(1)

# Emit as JS array literal, one row per line
lines = ['const RAW_DATA = [']
for i, row in enumerate(rows):
    comma = ',' if i < len(rows) - 1 else ''
    # Format values for JS
    def fmt(v):
        if isinstance(v, (float, int)):
            # Format numbers: if it's effectively an integer, print as int
            return str(int(v)) if v == int(v) else str(v)
        # Strings are JSON dumped to handle quotes/escaping
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

python3 - "$HTML_FILE" "$NEW_ARRAY" <<'PYEOF'
import sys, re

html_path  = sys.argv[1]
new_block  = sys.argv[2] # This contains the full 'const RAW_DATA = [ ... ];'

with open(html_path, 'r', encoding='utf-8') as f:
    content = f.read()

# Pattern: match from `const RAW_DATA = [` ...
# ... up to the `// STATE` anchor if present, or just to `];` if not.
# We need to be careful to NOT delete the anchor if we match it.

pattern_anchored = r'(?s)(const RAW_DATA\s*=\s*\[.*?)(\s*// ─────────────────────────────────────────────\s*//\s*STATE)'
pattern_simple   = r'(?s)(const RAW_DATA\s*=\s*\[.*?\];)'

updated = content
replaced = False

if re.search(pattern_anchored, content):
    # If we match the anchored pattern, group(1) is the data block we want to replace.
    # group(2) is the anchor we want to keep.
    # We replace the whole match with (new_block + \n\n + group 2)
    def repl(m):
        return new_block + '\n\n' + m.group(2)
    updated = re.sub(pattern_anchored, repl, content, count=1)
    replaced = True
    print("✅  Replaced RAW_DATA block (anchored to STATE section).")

elif re.search(pattern_simple, content):
    print("⚠️  STATE section not found, using simple replacement matching start to `];`.")
    updated = re.sub(pattern_simple, new_block, content, count=1)
    replaced = True
else:
    print("❌  Could not find RAW_DATA block in HTML file.", file=sys.stderr)
    sys.exit(1)

with open(html_path, 'w', encoding='utf-8') as f:
    f.write(updated)
PYEOF

echo "🎉  Deploy complete — open SinclairExplorer.html to verify."
