import re
import json

SRC = 'dw_rpt_is_flat_multibulan.srd'
with open(SRC, 'r', encoding='utf-16', newline='') as fh:
    content = fh.read()

lines = re.split(r'\r\n', content)

# ---------------------------------------------------------------------------
# CALLER RUNTIME-OVERRIDE CHECK (w_rpt_neraca.srw)
# ---------------------------------------------------------------------------
# The actual root cause of one alignment regression was not in the .srd at all:
# a leftover dw_2.Modify("cbln{n}.Width='480'~tchdr_bln{n}.Width='480'") loop in
# the calling window, run AFTER dw_2.retrieve(), silently forced the detail/
# header columns back to an old width while trailer.1/trailer.2 (never targeted
# by that Modify call) kept whatever width the .srd declares -- producing a
# "detail column narrower than its own subtotal" mismatch invisible to any
# check that only reads the .srd. Guard against this class of bug reappearing.
CALLER = 'w_rpt_neraca.srw'
caller_issues = []
try:
    with open(CALLER, 'r', encoding='utf-16', newline='') as fh:
        caller_content = fh.read()
    if '.Width=' in caller_content:
        for m in re.finditer(r'.{0,60}\.Width=.{0,60}', caller_content):
            caller_issues.append(m.group(0))
except FileNotFoundError:
    caller_issues.append(f"WARNING: {CALLER} not found, could not check for runtime width overrides")

print("=== CALLER RUNTIME-OVERRIDE CHECK (w_rpt_neraca.srw) ===")
if caller_issues:
    print(f"FAIL -- found {len(caller_issues)} runtime .Width= reference(s) that could override .srd geometry:")
    for c in caller_issues:
        print("  ", c)
else:
    print("PASS -- no runtime .Width= Modify() calls found; column widths are controlled")
    print("        exclusively by dw_rpt_is_flat_multibulan.srd's own declared geometry.")
print()

# Parse every object in the 4 bands.
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
    h_m = re.search(r'\bheight="(\d+)"', ln)
    if not (name_m and x_m and w_m):
        continue
    x = int(x_m.group(1))
    w = int(w_m.group(1))
    objects.append({'band': band, 'name': name_m.group(1), 'x': x, 'width': w, 'right': x + w,
                     'height': int(h_m.group(1)) if h_m else None})

# MASTER GRID = the subtotal (trailer.2) row's numeric-column objects, per the user's explicit
# instruction that subtotal/total geometry is the master. trailer.2's numeric value objects are
# t2_cbln{n} (months) and compute_6 (Periode Lalu). Build the master grid strictly FROM these.
master = {}
for o in objects:
    if o['band'] != 'trailer.2':
        continue
    if o['name'] == 'compute_6':
        master['Periode Lalu'] = (o['x'], o['width'])
    else:
        m = re.match(r'^t2_cbln(\d+)$', o['name'])
        if m:
            master[f"Month{m.group(1)}"] = (o['x'], o['width'])

print("=== MASTER GRID (derived from trailer.2 / subtotal row) ===")
for label in ['Periode Lalu'] + [f'Month{n}' for n in range(1, 13)]:
    if label in master:
        mx, mw = master[label]
        print(f"{label}: x={mx} width={mw} right={mx+mw}")
    else:
        print(f"{label}: MISSING from trailer.2 -- cannot verify")

# Now check every band's corresponding numeric objects against this master, EXACT equality.
name_patterns = {
    'header': {'Periode Lalu': None, **{f'Month{n}': f'chdr_bln{n}' for n in range(1, 13)}},
    'detail': {'Periode Lalu': 'saldo_awal', **{f'Month{n}': f'cbln{n}' for n in range(1, 13)}},
    'trailer.1': {'Periode Lalu': 'compute_9', **{f'Month{n}': f't_cbln{n}' for n in range(1, 13)}},
    'trailer.2': {'Periode Lalu': 'compute_6', **{f'Month{n}': f't2_cbln{n}' for n in range(1, 13)}},
}

by_band_name = {}
for o in objects:
    by_band_name.setdefault(o['band'], {})[o['name']] = o

mismatches = []
print()
print("=== EXACT EQUALITY CHECK: header.x == detail.x == trailer.1.x == trailer.2.x (master) ===")
for label in ['Periode Lalu'] + [f'Month{n}' for n in range(1, 13)]:
    if label not in master:
        continue
    mx, mw = master[label]
    mright = mx + mw
    row = {'label': label, 'master_x': mx, 'master_right': mright}
    for band in ('header', 'detail', 'trailer.1', 'trailer.2'):
        if label == 'Periode Lalu' and band == 'header':
            continue  # header has no per-column "Periode Lalu" data object (it's a static text label)
        obj_name = name_patterns[band].get(label)
        obj = by_band_name.get(band, {}).get(obj_name)
        if obj is None:
            mismatches.append(f"{label}/{band}: object '{obj_name}' not found")
            row[band] = 'MISSING'
            continue
        ok_x = obj['x'] == mx
        ok_right = obj['right'] == mright
        row[band] = f"x={obj['x']} right={obj['right']} {'OK' if (ok_x and ok_right) else 'MISMATCH'}"
        if not ok_x:
            mismatches.append(f"{label}/{band} ({obj_name}): x={obj['x']} != master_x={mx}")
        if not ok_right:
            mismatches.append(f"{label}/{band} ({obj_name}): right={obj['right']} != master_right={mright}")
    print(row)

print()
print("=== RESULT: MASTER GRID EQUALITY ===")
if mismatches:
    print(f"FAIL -- {len(mismatches)} mismatch(es):")
    for m in mismatches:
        print(" -", m)
else:
    print("PASS -- every header/detail/trailer.1/trailer.2 numeric column object matches the")
    print("        trailer.2 (subtotal) master grid EXACTLY (x and right boundary, all 13 columns).")

# ---------------------------------------------------------------------------
# STRAY BORDER CHECK
# ---------------------------------------------------------------------------
# A bordered object whose edges don't land on the canonical grid draws a visible
# line/box at an unexpected screen position -- this is exactly what produced the
# "detail column border doesn't reach TOTAL" artifacts reported against this file:
# ~169 tiny (1x1 twip) calculation-helper compute objects in the detail band had
# border="2" inherited from the shared template, each drawing a stray border
# fragment stacked at x=18 inside the Description column.
canonical_edges = set()
for mx, mw in master.values():
    canonical_edges.add(mx)
    canonical_edges.add(mx + mw)

stray = []
for ln in lines:
    band_m = re.search(r'\bband=([A-Za-z0-9_.]+)', ln)
    if not band_m or band_m.group(1) not in ('header', 'detail', 'trailer.1', 'trailer.2'):
        continue
    name_m = re.search(r'\bname=(\S+)', ln)
    x_m = re.search(r'\bx="(\d+)"', ln)
    w_m = re.search(r'\bwidth="(\d+)"', ln)
    border_m = re.search(r'\bborder="(\d+)"', ln)
    if not (name_m and x_m and w_m):
        continue
    x = int(x_m.group(1))
    w = int(w_m.group(1))
    right = x + w
    border = border_m.group(1) if border_m else '0'
    if border == '0':
        continue
    # gb_2 (and any other full-row background/groupbox whose right edge matches the
    # master grid's last column) is legitimate -- it is allowed to start left of the
    # first data column to cover the description area. Only flag objects whose EDGES
    # land somewhere with no correspondence to the grid at all.
    if x in canonical_edges and right in canonical_edges:
        continue
    if right == max(mx + mw for mx, mw in master.values()) and w > 1000:
        continue  # full-row background/groupbox spanning to the last column -- legitimate
    stray.append((band_m.group(1), name_m.group(1), x, w, right, border))

print()
print("=== RESULT: STRAY BORDER CHECK ===")
if stray:
    print(f"FAIL -- {len(stray)} bordered object(s) not aligned to the canonical grid:")
    for band, name, x, w, right, border in stray:
        print(f"  band={band} name={name} x={x} width={w} right={right} border={border}")
else:
    print("PASS -- no bordered object exists off the canonical column grid "
          "(no stray border artifacts).")

print()
if not mismatches and not stray and not caller_issues:
    print("=== FINAL: PASS -- exact vertical column alignment verified ===")
else:
    print("=== FINAL: FAIL -- alignment still inconsistent ===")
