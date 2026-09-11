import re
import sys

def check_file(n_months):
    fname = f'dw_rpt_is_flat_multibulan{n_months:02d}.srd'
    with open(fname, 'r', encoding='utf-16', newline='') as fh:
        content = fh.read()
    lines = content.split('\r\n')

    issues = []

    # NOTE: an earlier version of this check flagged any bare LF (not part of \r\n) as an error,
    # on the theory that PowerBuilder Painter's parser needs every line CRLF-terminated. That
    # theory was disproven -- the proven reference file dw_rpt_is_flat_multibulan.srd (commit
    # 90e3fb8), which got further through PowerBuilder's import than any version without bare
    # LFs, has its entire retrieve="..." SQL text (166 bare LFs) on ONE physical line with
    # genuinely bare "\n" internally. Forcing that text onto separate "\r\n" physical lines was
    # itself a regression. Bare LF is now EXPECTED inside the retrieve="..." SQL text specifically
    # -- only flag one if it appears OUTSIDE that string (which would be a genuine anomaly).
    m_retrieve = re.search(r'retrieve="(.*?)" arguments=', content, re.DOTALL)
    if m_retrieve:
        outside = content[:m_retrieve.start()] + content[m_retrieve.end():]
    else:
        outside = content
    bare_lf_outside = sum(1 for i, c in enumerate(outside) if c == '\n' and (i == 0 or outside[i - 1] != '\r'))
    if bare_lf_outside:
        issues.append(f"{bare_lf_outside} bare LF character(s) found OUTSIDE the retrieve=\"...\" SQL text -- unexpected")

    # REVERTED: an earlier version of this check required column(...) objects to carry
    # edit.limit=/edit.case=/edit.autoselect=/edit.autohscroll=, based on comparison against
    # dw_rpt_is_hpp_multibulan.srd and dw_rpt_is.srd. Those were the WRONG oracle files for this
    # DataWindow family. A structural diff (srd_structural_diff.py) against the actual confirmed-
    # working golden master for THIS family, dw_rpt_is_flat_multibulan.srd (verified by the user
    # to run successfully in PowerBuilder 11.5), proves its own column() objects (fincatdes,
    # accountdes) do NOT have any edit.* attributes at all. Requiring them was itself a defect
    # this check introduced. column() objects in this family must NOT carry edit.* attributes,
    # matching the golden master exactly.
    for ln in lines:
        if not ln.startswith('column('):
            continue
        if 'edit.limit=' in ln or 'edit.case=' in ln or 'edit.autoselect=' in ln or 'edit.autohscroll=' in ln:
            name_m = re.search(r'\bname=(\S+)', ln)
            issues.append(f"column() object '{name_m.group(1) if name_m else '?'}' has an edit.* attribute -- the confirmed golden master's column() objects never do")

    # NOTE: an earlier version of this check required every declared group(level=N) to have a
    # matching header.N band. That theory was disproven -- the proven reference file
    # dw_rpt_is_flat_multibulan.srd (commit 90e3fb8) uses sum(...for group 2) and a trailer.2
    # band extensively WITHOUT ever declaring group(level=2) at all, and it got further through
    # PowerBuilder's import than any version that added one. This file intentionally has only
    # group(level=1); trailer.2's "for group 2" references are expected and correct as-is.
    group_levels = [int(m.group(1)) for m in re.finditer(r'^group\(level=(\d+) header\.height=(\d+)', content, re.MULTILINE)]
    for lvl in group_levels:
        if lvl == 1:
            continue
        band_name = f'header.{lvl}'
        if f'band={band_name} ' not in content and f'band={band_name}\t' not in content:
            issues.append(f"group(level={lvl}) declared but no band={band_name} object found (unexpected -- only group(level=1) should be declared)")

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
