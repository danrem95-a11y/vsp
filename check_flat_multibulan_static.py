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

    # dw_rpt_is_flat_multibulan.srd (git 90e3fb8) was believed confirmed-working for most of this
    # investigation, but the user has since confirmed it actually fails PB 11.5 import too (same
    # detail-band-boundary symptom as every generated file). The user supplied a genuinely working
    # replacement, dw_rpt_is_flat_multibulan_mantap.srd -- its column() objects DO carry
    # edit.limit=/edit.case=/edit.autoselect=/edit.autohscroll= (matching each column's own
    # char(N) length). Require it.
    for ln in lines:
        if not ln.startswith('column('):
            continue
        if 'edit.limit=' not in ln:
            name_m = re.search(r'\bname=(\S+)', ln)
            issues.append(f"column() object '{name_m.group(1) if name_m else '?'}' is missing edit.limit=/edit.case=/edit.autoselect=/edit.autohscroll= -- required per the confirmed-working mantap file")

    # Every VISIBLE detail-row object (bordered, real width -- as opposed to a 1x1-twip hidden
    # helper) must share the SAME y coordinate as its row siblings. Found via an actual live
    # PowerBuilder 11.5 screenshot: cbln_sdini had its y accidentally overwritten to land in the
    # hidden-helper vertical-stacking zone (y=200+) instead of staying at the row's real y (4) --
    # the static structural checks in this file (paren/quote balance, column-name-alignment
    # grid, etc.) never caught this because cbln_sdini's OWN x/width were still internally
    # self-consistent; the defect was that it silently rendered as an empty box at the correct
    # row while its real value appeared as a disconnected floating box far below. Catch this
    # class of bug generally: collect the y of every detail-band object with border!="0" and
    # width>1, and flag any that doesn't match the majority (mode) y value.
    detail_visible_ys = []
    for ln in lines:
        if 'band=detail' not in ln:
            continue
        bm = re.search(r'border="(\d+)"', ln)
        wm = re.search(r'width="(\d+)"', ln)
        ym = re.search(r'\by="(\d+)"', ln)
        nm = re.search(r'\bname=(\S+)', ln)
        if bm and wm and ym and nm and bm.group(1) != '0' and int(wm.group(1)) > 1:
            detail_visible_ys.append((nm.group(1), int(ym.group(1))))
    if detail_visible_ys:
        from collections import Counter
        y_counts = Counter(y for _, y in detail_visible_ys)
        common_y, _ = y_counts.most_common(1)[0]
        for name, y in detail_visible_ys:
            if y != common_y:
                issues.append(f"detail-band visible object '{name}' has y={y}, but every other visible detail row object shares y={common_y} -- this object will render disconnected from its row (the exact defect seen in a live PB 11.5 screenshot)")

    # Every declared group(level=N) must have a matching header.N band -- confirmed by the mantap
    # file, which has group(level=2 by=("parentcode")) alongside a real header.2 band (a column()
    # bound to parentname). 90e3fb8 lacked both and is now known to be broken.
    group_levels = [int(m.group(1)) for m in re.finditer(r'^group\(level=(\d+) header\.height=(\d+)', content, re.MULTILINE)]
    for lvl in group_levels:
        if lvl == 1:
            continue
        band_name = f'header.{lvl}'
        if f'band={band_name} ' not in content and f'band={band_name}\t' not in content:
            issues.append(f"group(level={lvl}) declared but no band={band_name} object found")

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

    # 2. detail band height must cover all VISIBLE content (real width, > 1 twip).
    # BUG FIX: this used to require detail(height=) to cover the max bottom across ALL detail
    # objects, including the ~100+ 1x1-twip hidden helper computes deliberately stacked far below
    # the visible row purely for unique non-colliding positions. That is WRONG -- confirmed
    # against the mantap oracle, whose own hidden helpers go down to y=360 while its declared
    # detail(height=84) covers only the visible row content (y=4 h=76). Enforcing the old rule
    # caused the generator to inflate detail(height=) to 331+, and PB allocates the FULL declared
    # band height to every data row -- producing a huge dead gap under each row in live PB 11.5
    # rendering (reported by the user: "rapikan garis agar tidak terlihat lompat2"). Only visible
    # (real-width) objects should be considered here.
    detail_decl_m = re.search(r'^detail\(height=(\d+)', content, re.MULTILINE)
    detail_decl = int(detail_decl_m.group(1)) if detail_decl_m else None
    detail_objs = [o for o in objects if o['band'] == 'detail' and o['width'] is not None and o['width'] > 1]
    detail_max_bottom = max((o['y'] + o['height']) for o in detail_objs if o['y'] is not None and o['height'] is not None)
    if detail_decl is None or detail_decl < detail_max_bottom:
        issues.append(f"detail(height={detail_decl}) < actual VISIBLE content max bottom {detail_max_bottom}")

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
