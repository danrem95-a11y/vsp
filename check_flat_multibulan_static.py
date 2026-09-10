import re
import sys

def check_file(n_months):
    fname = f'dw_rpt_is_flat_multibulan{n_months:02d}.srd'
    with open(fname, 'r', encoding='utf-16', newline='') as fh:
        content = fh.read()
    lines = content.split('\r\n')

    issues = []

    # A bare LF (not part of a \r\n pair) inside the file -- typically from embedded SQL text
    # built with plain "\n" -- desyncs PowerBuilder Painter's own line/column counter and has
    # caused real "incorrect syntax" errors at unrelated line numbers. Every line ending in a
    # .srd must be CRLF.
    bare_lf = sum(1 for i, c in enumerate(content) if c == '\n' and (i == 0 or content[i - 1] != '\r'))
    if bare_lf:
        issues.append(f"{bare_lf} bare LF character(s) found (not part of \\r\\n) -- will desync PB Painter's parser")

    # Every declared group(level=N ...) must have a matching header.N band with at least one
    # object, and a nonzero header.height. A file that declares group(level=2 ...) but never
    # emits any band=header.2 object (or gives it header.height=0) desyncs PB Painter's parser
    # further down the file -- this was the actual root cause of a real "incorrect syntax" import
    # error that only ever surfaced at some unrelated, size-proportional line number.
    group_levels = [int(m.group(1)) for m in re.finditer(r'^group\(level=(\d+) header\.height=(\d+)', content, re.MULTILINE)]
    group_heights = {int(m.group(1)): int(m.group(2)) for m in re.finditer(r'^group\(level=(\d+) header\.height=(\d+)', content, re.MULTILINE)}
    for lvl in group_levels:
        if lvl == 1:
            continue  # level 1 uses band=header.1, always present by construction
        band_name = f'header.{lvl}'
        if f'band={band_name} ' not in content and f'band={band_name}\t' not in content:
            issues.append(f"group(level={lvl}) declared but no band={band_name} object found")
        if group_heights.get(lvl, 0) == 0:
            issues.append(f"group(level={lvl}) has header.height=0 -- must be nonzero to match its header.{lvl} band content")

    # 1. every 'name=' must be unique
    names_by_band = {}
    objects = []
    for ln in lines:
        band_m = re.search(r'\bband=([A-Za-z0-9_.]+)', ln)
        if not band_m:
            continue
        band = band_m.group(1)
        name_m = re.search(r'\bname=(\S+)', ln)
        x_m = re.search(r'\bx="(\d+)"', ln)
        w_m = re.search(r'\bwidth="(\d+)"', ln)
        h_m = re.search(r'\bheight="(\d+)"', ln)
        y_m = re.search(r'\by="(\d+)"', ln)
        border_m = re.search(r'\bborder="(\d+)"', ln)
        if not (name_m and x_m and w_m):
            continue
        x = int(x_m.group(1)); w = int(w_m.group(1))
        obj = {'band': band, 'name': name_m.group(1), 'x': x, 'width': w, 'right': x + w,
               'y': int(y_m.group(1)) if y_m else None,
               'height': int(h_m.group(1)) if h_m else None,
               'border': border_m.group(1) if border_m else '0'}
        objects.append(obj)
        names_by_band.setdefault(band, {})
        if obj['name'] in names_by_band[band]:
            issues.append(f"DUP NAME in band {band}: {obj['name']}")
        names_by_band[band][obj['name']] = obj

    # 2. detail band height must cover all content
    detail_decl_m = re.search(r'^detail\(height=(\d+)', content, re.MULTILINE)
    detail_decl = int(detail_decl_m.group(1)) if detail_decl_m else None
    detail_objs = [o for o in objects if o['band'] == 'detail']
    detail_max_bottom = max((o['y'] + o['height']) for o in detail_objs if o['y'] is not None and o['height'] is not None)
    if detail_decl is None or detail_decl < detail_max_bottom:
        issues.append(f"detail(height={detail_decl}) < actual max content bottom {detail_max_bottom}")

    # 3. summary band height must cover all content
    summary_decl_m = re.search(r'^summary\(height=(\d+)', content, re.MULTILINE)
    summary_decl = int(summary_decl_m.group(1)) if summary_decl_m else None
    summary_objs = [o for o in objects if o['band'] == 'summary']
    if summary_objs:
        summary_max_bottom = max((o['y'] + o['height']) for o in summary_objs if o['y'] is not None and o['height'] is not None)
        if summary_decl is None or summary_decl < summary_max_bottom:
            issues.append(f"summary(height={summary_decl}) < actual max content bottom {summary_max_bottom}")

    # 4. master grid from trailer.2, exact equality across header/detail/trailer.1/trailer.2
    master = {}
    for o in objects:
        if o['band'] != 'trailer.2':
            continue
        if o['name'] == 'compute_6':
            master['sdlalu'] = (o['x'], o['width'])
        elif o['name'] == 't2_sdini':
            master['sdini'] = (o['x'], o['width'])
        else:
            m = re.match(r'^t2_slot(\d+)$', o['name'])
            if m:
                master[f"slot{m.group(1)}"] = (o['x'], o['width'])

    expected_cols = ['sdlalu', 'sdini'] + [f'slot{s}' for s in range(1, n_months + 1)]
    for c in expected_cols:
        if c not in master:
            issues.append(f"master grid missing column {c} (trailer.2 object not found)")

    name_patterns = {
        'header': {'sdlalu': 'chdr_sdlalu', 'sdini': 'chdr_sdini', **{f'slot{s}': f'chdr_slot{s}' for s in range(1, n_months+1)}},
        'detail': {'sdlalu': 'cbln_sdlalu', 'sdini': 'cbln_sdini', **{f'slot{s}': f'cslot{s}' for s in range(1, n_months+1)}},
        'trailer.1': {'sdlalu': 'compute_9', 'sdini': 't_sdini', **{f'slot{s}': f't_slot{s}' for s in range(1, n_months+1)}},
        'trailer.2': {'sdlalu': 'compute_6', 'sdini': 't2_sdini', **{f'slot{s}': f't2_slot{s}' for s in range(1, n_months+1)}},
    }
    for col in expected_cols:
        if col not in master:
            continue
        mx, mw = master[col]
        mright = mx + mw
        for band in ('header', 'detail', 'trailer.1', 'trailer.2'):
            obj_name = name_patterns[band].get(col)
            obj = names_by_band.get(band, {}).get(obj_name)
            if obj is None:
                issues.append(f"{col}/{band}: object '{obj_name}' not found")
                continue
            if obj['x'] != mx or obj['right'] != mright:
                issues.append(f"{col}/{band} ({obj_name}): x={obj['x']} right={obj['right']} != master x={mx} right={mright}")

    # 5. stray border check
    canonical_edges = set()
    for mx, mw in master.values():
        canonical_edges.add(mx)
        canonical_edges.add(mx + mw)
    max_right = max((mx + mw) for mx, mw in master.values()) if master else 0
    description_col_names = {'t_desc', 'fincatdes', 'accountdes', 'compute_5', 'compute_12'}
    min_grid_x = min(mx for mx, mw in master.values()) if master else 0
    for o in objects:
        if o['band'] not in ('header', 'detail', 'trailer.1', 'trailer.2'):
            continue
        if o['border'] == '0':
            continue
        if o['name'] in description_col_names:
            continue
        if o['x'] in canonical_edges and o['right'] in canonical_edges:
            continue
        if o['right'] == max_right and o['width'] > 1000:
            continue
        issues.append(f"STRAY BORDER band={o['band']} name={o['name']} x={o['x']} width={o['width']} right={o['right']} border={o['border']}")

    # 6. every non-hidden compute expression referencing a name must resolve to a real object in the same band or a column
    # (light check: look for undefined cbln{N} refs beyond n_months)
    for m in re.finditer(r'\bcbln(\d+)\b', content):
        num = int(m.group(1))
        if num > n_months:
            issues.append(f"reference to cbln{num} but this file only has {n_months} months")

    return fname, issues, len(objects)


if __name__ == '__main__':
    all_pass = True
    for n in range(1, 13):
        fname, issues, nobj = check_file(n)
        status = "PASS" if not issues else "FAIL"
        print(f"{fname}: {status} ({nobj} objects)")
        if issues:
            all_pass = False
            for i in issues:
                print("   -", i)
    print()
    print("=== FINAL:", "PASS -- all 12 static files verified" if all_pass else "FAIL -- see above", "===")
    sys.exit(0 if all_pass else 1)
