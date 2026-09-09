import re
import json

SRC = 'dw_rpt_is_flat_multibulan.srd'
with open(SRC, 'r', encoding='utf-16', newline='') as fh:
    content = fh.read()

lines = re.split(r'\r\n', content)

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
print("=== RESULT ===")
if mismatches:
    print(f"FAIL -- {len(mismatches)} mismatch(es):")
    for m in mismatches:
        print(" -", m)
else:
    print("PASS -- every header/detail/trailer.1/trailer.2 numeric column object matches the")
    print("        trailer.2 (subtotal) master grid EXACTLY (x and right boundary, all 13 columns).")
