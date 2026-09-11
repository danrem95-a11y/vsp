# -*- coding: utf-8 -*-
"""
Structural parser/dumper for .srd DataWindow source. Parses GOOD (golden master,
confirmed running in PB 11.5) and BAD (failing) into logical object records, then
produces an ordered structural diff -- not a line-based text diff.
"""
import re
import sys

GOOD_PATH = 'dw_rpt_is_flat_multibulan.srd'
BAD_PATH = 'dw_rpt_is_flat_multibulan01.srd'


def load(path):
    with open(path, 'r', encoding='utf-16', newline='') as fh:
        return fh.read()


def parse_top_level(content):
    """Extract the top-level declarations before table(."""
    idx = content.index('table(')
    top = content[:idx]
    result = {}
    for kw in ['$PBExportHeader$', 'release', 'datawindow(', 'header(', 'summary(', 'footer(', 'detail(']:
        m = re.search(re.escape(kw) + r'([^\r\n]*)', top)
        result[kw] = m.group(0) if m else None
    return result


def parse_table(content):
    m = re.search(r'table\((.*?)retrieve="', content, re.DOTALL)
    block = m.group(1)
    cols = re.findall(r'column=\(([^)]*)\)', block)
    return cols


def parse_retrieve(content):
    m = re.search(r'retrieve="(.*?)" arguments=\((.*?)\)\)  sort="([^"]*)" \)', content, re.DOTALL)
    return {'sql': m.group(1), 'arguments': m.group(2), 'sort': m.group(3)}


def parse_groups(content):
    return re.findall(r'^group\([^\r\n]*', content, re.MULTILINE)


def parse_objects(content):
    """
    Parse every band object (compute/column/text/groupbox/line/rectangle) into a
    structured record: type, band, name, and a dict of every attribute=value pair
    found on that object's line (each object is confirmed to be a single physical
    line in both files).
    """
    lines = content.split('\r\n')
    objects = []
    for ln in lines:
        m = re.match(r'^(compute|column|text|groupbox|line|rectangle|bitmap|report)\(band=(\S+)', ln)
        if not m:
            continue
        objtype, band = m.group(1), m.group(2)
        name_m = re.search(r'\bname=(\S+)', ln)
        name = name_m.group(1) if name_m else None
        # capture every attr="value" or attr=value pair for structural comparison
        attrs = {}
        for am in re.finditer(r'([\w.]+)=("[^"]*"|\S+)', ln):
            attrs[am.group(1)] = am.group(2)
        objects.append({'type': objtype, 'band': band, 'name': name, 'attrs': attrs, 'raw': ln})
    return objects


def band_order(objects):
    """Return the sequence of bands as they appear, collapsing consecutive same-band runs."""
    seq = []
    prev = None
    for o in objects:
        if o['band'] != prev:
            seq.append(o['band'])
            prev = o['band']
    return seq


if __name__ == '__main__':
    good = load(GOOD_PATH)
    bad = load(BAD_PATH)

    print("=" * 70)
    print("PHASE 1: TOP-LEVEL DECLARATIONS")
    print("=" * 70)
    good_top = parse_top_level(good)
    bad_top = parse_top_level(bad)
    for kw in good_top:
        g = good_top[kw]
        b = bad_top[kw]
        # normalize away the filename and numeric height values for comparison
        g_norm = re.sub(r'\$PBExportHeader\$\S+', '$PBExportHeader$X', g or '')
        b_norm = re.sub(r'\$PBExportHeader\$\S+', '$PBExportHeader$X', b or '')
        g_norm = re.sub(r'height=\d+', 'height=N', g_norm)
        b_norm = re.sub(r'height=\d+', 'height=N', b_norm)
        match = g_norm == b_norm
        print(f"{kw:20s} MATCH(ignoring height/filename)={match}")
        if not match:
            print(f"  GOOD: {g[:200]}")
            print(f"  BAD : {b[:200]}")

    print()
    print("=" * 70)
    print("PHASE 2: BAND SEQUENCE (ORDERING)")
    print("=" * 70)
    good_objs = parse_objects(good)
    bad_objs = parse_objects(bad)
    good_seq = band_order(good_objs)
    bad_seq = band_order(bad_objs)
    print("GOOD band sequence:", good_seq)
    print("BAD  band sequence:", bad_seq)
    print("Sequence identical:", good_seq == bad_seq)

    print()
    print("=" * 70)
    print("PHASE 3: GROUP DECLARATIONS")
    print("=" * 70)
    good_groups = parse_groups(good)
    bad_groups = parse_groups(bad)
    print(f"GOOD has {len(good_groups)} group(s):")
    for g in good_groups:
        print(" ", g[:120])
    print(f"BAD has {len(bad_groups)} group(s):")
    for g in bad_groups:
        print(" ", g[:120])

    print()
    print("=" * 70)
    print("PHASE 4: TABLE() COLUMN DECLARATIONS -- format template comparison")
    print("=" * 70)
    good_cols = parse_table(good)
    bad_cols = parse_table(bad)
    print(f"GOOD: {len(good_cols)} columns, BAD: {len(bad_cols)} columns")

    def col_template(c):
        return re.sub(r'name=\S+ dbname="[^"]*"', 'name=X dbname="X"', c)

    good_templates = set(col_template(c) for c in good_cols)
    bad_templates = set(col_template(c) for c in bad_cols)
    print("GOOD column declaration templates:", good_templates)
    print("BAD  column declaration templates:", bad_templates)
    print("Templates identical:", good_templates == bad_templates)

    print()
    print("=" * 70)
    print("PHASE 5: OBJECT TYPE INVENTORY PER BAND")
    print("=" * 70)
    from collections import Counter
    good_band_types = Counter((o['band'], o['type']) for o in good_objs)
    bad_band_types = Counter((o['band'], o['type']) for o in bad_objs)
    all_keys = sorted(set(good_band_types) | set(bad_band_types))
    for k in all_keys:
        g = good_band_types.get(k, 0)
        b = bad_band_types.get(k, 0)
        flag = '' if g > 0 and b > 0 or (g == 0) == (b == 0) else '  <-- ONE HAS ZERO, OTHER DOES NOT'
        print(f"  band={k[0]:12s} type={k[1]:10s} GOOD={g:3d} BAD={b:3d}{flag}")

    print()
    print("=" * 70)
    print("PHASE 6: ATTRIBUTE KEY INVENTORY -- every distinct attribute name used, per object type")
    print("=" * 70)
    for objtype in ['column', 'compute', 'text', 'groupbox']:
        good_attrs = set()
        for o in good_objs:
            if o['type'] == objtype:
                good_attrs |= set(o['attrs'].keys())
        bad_attrs = set()
        for o in bad_objs:
            if o['type'] == objtype:
                bad_attrs |= set(o['attrs'].keys())
        only_good = good_attrs - bad_attrs
        only_bad = bad_attrs - good_attrs
        print(f"type={objtype}: attrs only in GOOD: {sorted(only_good)}")
        print(f"type={objtype}: attrs only in BAD : {sorted(only_bad)}")
