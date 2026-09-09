import re
import json

SRC = 'dw_rpt_is_flat_multibulan.srd'
with open(SRC, 'r', encoding='utf-16', newline='') as fh:
    content = fh.read()

lines = re.split(r'\r\n', content)

# Parse every object across the 4 relevant bands into (band, name, x, width, right)
objects = []
for ln in lines:
    band_m = re.search(r'\bband=([A-Za-z0-9_.]+)', ln)
    if not band_m:
        continue
    band = band_m.group(1)
    if band not in ('header', 'detail', 'trailer.1', 'trailer.2'):
        continue
    name_m = re.search(r'\bname=(\S+)', ln)
    x_m = re.search(r'\bx="(\d+)"', ln)
    w_m = re.search(r'\bwidth="(\d+)"', ln)
    if not (name_m and x_m and w_m):
        continue
    x = int(x_m.group(1))
    w = int(w_m.group(1))
    objects.append({'band': band, 'name': name_m.group(1), 'x': x, 'width': w, 'right': x + w})

# Column definitions: the canonical x-slots this report is supposed to use.
# Periode Lalu = x1422 w622 ; month N = baseX + (N-1)*580, w=560 (N=1..12)
baseX = 2048
step = 580
colW = 560

expected = {'Periode Lalu': (1422, 622)}
for n in range(1, 13):
    expected[f'Month{n}'] = (baseX + (n - 1) * step, colW)

def classify(x, w):
    for label, (ex, ew) in expected.items():
        if x == ex and w == ew:
            return label
    return None

# Group objects by (x,width) slot and by band, to verify every occupant of a slot matches
slot_occupants = {}
unclassified = []
for obj in objects:
    label = classify(obj['x'], obj['width'])
    if label is None:
        unclassified.append(obj)
        continue
    slot_occupants.setdefault(label, {}).setdefault(obj['band'], []).append(obj['name'])

report = {}
mismatches = []

for label, (ex, ew) in expected.items():
    bands_present = slot_occupants.get(label, {})
    report[label] = {
        'expected_x': ex,
        'expected_width': ew,
        'expected_right': ex + ew,
        'bands': {b: names for b, names in bands_present.items()},
    }
    # every real content band should have exactly one occupant in this slot (except header
    # which may have both a value compute and, for months, the month object -- 1 is fine)
    missing_bands = [b for b in ('detail', 'trailer.1', 'trailer.2') if b not in bands_present]
    if missing_bands:
        mismatches.append(f"{label}: missing occupant in band(s) {missing_bands}")

print("=== EXPECTED COLUMN SLOTS (x, width, right) ===")
for label, info in report.items():
    print(f"{label}: x={info['expected_x']} width={info['expected_width']} right={info['expected_right']}  bands={list(info['bands'].keys())}")

print()
print("=== UNCLASSIFIED OBJECTS (x/width doesn't match any canonical slot) ===")
# filter out the tiny 1x1 hidden helpers and header sub-labels/groupbox which are expected to differ
real_unclassified = [o for o in unclassified if o['width'] > 1 and o['band'] != 'header']
for o in real_unclassified:
    print(o)

print()
print("=== MISMATCHES ===")
if mismatches:
    for m in mismatches:
        print(" -", m)
else:
    print("none -- every canonical column slot has a matching occupant in detail, trailer.1, and trailer.2")

with open('_alignment_report.json', 'w') as fh:
    json.dump({'report': report, 'unclassified_nontrivial': real_unclassified, 'mismatches': mismatches}, fh, indent=2)
print()
print("Full JSON report written to _alignment_report.json")
