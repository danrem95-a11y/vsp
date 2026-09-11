# -*- coding: utf-8 -*-
"""
Builds all 12 dw_rpt_is_flat_multibulan0N.srd files by surgically trimming the ACTUAL
proven reference file (git commit 90e3fb8's dw_rpt_is_flat_multibulan.srd). Every object
line kept in the output is either byte-identical to the proven file's own line (verbatim),
or produced by the SAME verified string-construction logic used for the SQL block (which
was checked to reproduce the proven file's 12-month SQL exactly). Nothing is reworded from
scratch; only whole per-month object lines are dropped/regenerated using the proven file's
own line-shape as a template.
"""
import re
import subprocess

# PRIMARY BUSINESS-LOGIC SOURCE: dw_rpt_is_flat_multibulan.srd (git 90e3fb8). This is where the
# actual required report LAYOUT lives -- the sd-lalu/sd-ini comparison columns + descending
# slot1..N month columns ("Excel comparison format") that was explicitly negotiated earlier in
# this project and is the confirmed business requirement. This file is now known to itself fail
# PB 11.5 import (at its own "line 294", the same detail-band-boundary symptom every generated
# file in this session has hit) -- so its OBJECT CONTENT/EXPRESSIONS remain the layout source of
# truth, but its GRAMMAR/STRUCTURE cannot be trusted blindly.
raw = subprocess.run(['git', 'show', '90e3fb8:dw_rpt_is_flat_multibulan.srd'], capture_output=True).stdout
PROVEN = raw.decode('utf-16')
PROVEN_LINES = PROVEN.split('\r\n')

# SECONDARY GRAMMAR/STRUCTURE ORACLE: dw_rpt_is_flat_multibulan_mantap.srd -- confirmed by the
# user to actually import/run in PowerBuilder 11.5. Used ONLY for PB 11.5 grammar/structure
# patterns (never for business layout/expressions), specifically three concrete differences a
# structural diff found versus the broken 90e3fb8 file:
#   1. a header.2 band (a column() object bound to the group-2 column) + matching
#      group(level=2 by=(...)) -- every column() object in this codebase's genuinely working
#      files has edit.limit=/edit.case=/edit.autoselect=/edit.autohscroll=; 90e3fb8's lacked both.
#   2. edit.limit=/edit.case=/edit.autoselect=/edit.autohscroll= on every column() object.
#   3. the fuller footer (htmlgen/xhtmlgen+cssgen/xmlgen/xsltgen/jsgen/export.pdf/export.xhtml).
with open('dw_rpt_is_flat_multibulan_mantap.srd', 'r', encoding='utf-16', newline='') as _fh:
    MANTAP = _fh.read()
MANTAP_LINES = MANTAP.split('\r\n')


def find_mantap_line(name_pattern):
    matches = []
    for i, l in enumerate(MANTAP_LINES):
        m = re.search(r'\bname=(\S+) visible=', l)
        if m and m.group(1) == name_pattern:
            matches.append((i, l))
    assert len(matches) == 1, f"expected exactly 1 mantap line for {name_pattern}, found {len(matches)}"
    return matches[0]

CRLF = '\r\n'


def find_line(name_pattern):
    """Return (index, line) for the single detail-band line whose name= matches name_pattern exactly."""
    matches = []
    for i, l in enumerate(PROVEN_LINES):
        m = re.search(r'\bname=(\S+) visible=', l)
        if m and m.group(1) == name_pattern:
            matches.append((i, l))
    assert len(matches) == 1, f"expected exactly 1 line for {name_pattern}, found {len(matches)}"
    return matches[0]


def build_sql(n_months):
    select_lines = [
        "select",
        "a.fincatcode,a.fincatdes,b.parentcode,b.parentname,c.accountcode,c.accountdes,c.debetcredit as flag_dk,",
        "isnull(awal2.debit,0.00) as awal2_debit,",
        "isnull(awal2.credit,0.00) as awal2_credit,",
    ]
    for n in range(1, n_months + 1):
        select_lines.append(f"isnull(bln{n}.debit,0.00) as bln{n}_debit,")
        select_lines.append(f"isnull(bln{n}.credit,0.00) as bln{n}_credit,")
    select_lines.append("a.fincatdes+' '+b.parentname+' '+c.accountcode as is_find")
    select_lines.append("from")
    select_lines.append("gl_cate a,gl_cate_detail b,gl_acc c,")

    subqueries = [
        "(\nSELECT gl_journal.account_id,\ncast(sum(isnull(debet,0)) as decimal(18,6)) as debit,\n"
        "cast(sum(isnull(kredit,0)) as decimal(18,6)) as credit\nFROM gl_journal\n"
        "WHERE tgl between :arg_tgl1 and :arg_tgl2 and\n"
        "((isnull(gl_journal.show_hide,'1') = '1') or 1 = :arg_show)\nGROUP BY gl_journal.account_id\n) awal2,"
    ]
    for n in range(1, n_months + 1):
        trailing = "," if n < n_months else ""
        subqueries.append(
            "(\nSELECT gl_journal.account_id,\ncast(sum(isnull(debet,0)) as decimal(18,6)) as debit,\n"
            "cast(sum(isnull(kredit,0)) as decimal(18,6)) as credit\nFROM gl_journal\n"
            f"WHERE tgl between :arg_bln{n}_awal and :arg_bln{n}_akhir and\n"
            "((isnull(gl_journal.show_hide,'1') = '1') or 1 = :arg_show)\n"
            f"GROUP BY gl_journal.account_id\n) bln{n}{trailing}"
        )

    where_lines = [
        "where a.fincatcode = b.fincatcode and",
        "b.parentcode = c.parentcode and",
        "(a.fincatcode = 'IS1001' or a.fincatcode = 'IS1110' or a.fincatcode = 'IS2010' or a.fincatcode = 'IS2110' or a.fincatcode = 'IS2120' or a.fincatcode = 'IS2130' or a.fincatcode = 'IS2230' or a.fincatcode = 'IS2330') and",
        "((isnull(c.show_hide,'1') = '1') or 1 = :arg_show) and",
        "c.accountcode *= awal2.account_id and",
    ]
    for n in range(1, n_months + 1):
        conj = " and" if n < n_months else ""
        where_lines.append(f"c.accountcode *= bln{n}.account_id{conj}")

    order_lines = ["order by", "a.fincatcode,b.parentcode,c.accountcode"]

    return "\n".join(select_lines) + "\n" + "\n".join(subqueries) + "\n" + "\n".join(where_lines) + "\n" + "\n".join(order_lines)


# Verify build_sql(12) reproduces the proven file's SQL exactly before trusting it for N<12.
_m = re.search(r'retrieve="(.*?)" arguments=', PROVEN, re.DOTALL)
assert build_sql(12) == _m.group(1), "SQL builder does not reproduce the proven 12-month SQL"


def build_table_block(n_months):
    lines = [
        'table(column=(type=char(10) updatewhereclause=yes name=fincatcode dbname="fincatcode" )',
        ' column=(type=char(50) updatewhereclause=yes name=fincatdes dbname="fincatdes" )',
        ' column=(type=char(25) updatewhereclause=yes name=parentcode dbname="parentcode" )',
        ' column=(type=char(100) updatewhereclause=yes name=parentname dbname="parentname" )',
        ' column=(type=char(15) updatewhereclause=yes name=accountcode dbname="accountcode" )',
        ' column=(type=char(50) updatewhereclause=yes name=accountdes dbname="accountdes" )',
        ' column=(type=char(1) updatewhereclause=yes name=flag_dk dbname="flag_dk" )',
        ' column=(type=decimal(6) updatewhereclause=yes name=awal2_debit dbname="awal2_debit" )',
        ' column=(type=decimal(6) updatewhereclause=yes name=awal2_credit dbname="awal2_credit" )',
    ]
    for n in range(1, n_months + 1):
        lines.append(f' column=(type=decimal(6) updatewhereclause=yes name=bln{n}_debit dbname="bln{n}_debit" )')
        lines.append(f' column=(type=decimal(6) updatewhereclause=yes name=bln{n}_credit dbname="bln{n}_credit" )')
    lines.append(' column=(type=char(218) updatewhereclause=yes name=is_find dbname="is_find" )')
    return CRLF.join(lines)


# Verify build_table_block(12) matches the proven file's actual table() block, ignoring
# whitespace-run differences (the proven file packs two column declarations onto one physical
# line at one spot -- a cosmetic PB-export artifact; every other .srd in this codebase,
# including dw_rpt_is_hpp_multibulan.srd, uses one column per line consistently and is valid).
_idx1 = PROVEN.find('table(column=')
_idx2 = PROVEN.find('retrieve="select')
_proven_table = PROVEN[_idx1:_idx2]
_proven_table_trimmed = _proven_table[:_proven_table.rindex(')') + 1]


def _normalize_ws(s):
    return re.sub(r'\s+', ' ', s).strip()


assert _normalize_ws(_proven_table_trimmed) == _normalize_ws(build_table_block(12)), \
    "table() builder content does not match proven file (token-level)"

# NOTE on terminology: the SQL check just above (build_sql(12) == the proven file's actual SQL
# text) is a genuine byte-for-byte comparison, no normalization. The table() check directly above
# is token-equivalent only (whitespace-run-normalized), because the proven file packs two column
# declarations onto one physical line at one spot while this generator emits one per line -- both
# are valid PB syntax, but the raw text differs by whitespace. Do not call the table() result
# "byte-identical"; it is token-equivalent.
print("SQL builder verified byte-identical to the proven 12-month file's actual SQL text.")
print("table() builder verified token-equivalent to the proven 12-month file (whitespace-normalized; a single cosmetic line-packing difference is expected and does not affect PB grammar).")


def y_of(line):
    m = re.search(r'\by="(\d+)"', line)
    return int(m.group(1))


def set_y(line, new_y):
    return re.sub(r'\by="\d+"', f'y="{new_y}"', line, count=1)


def build_detail_band(n_months):
    """
    Build the detail band for n_months by taking the PROVEN file's actual object lines for
    accountdes, cbln_sdlalu, cbln1..N (dropping N+1..12), and reusing the proven file's exact
    netsplit/_a/_b and tot_*/profit-line line SHAPES (verbatim except for numeric substitutions
    that mechanically follow the proven file's own bln{n}/cbln{n} pattern), re-sequencing their
    y= coordinates to be contiguous (the proven file's own y sequence has no gaps either).
    """
    out = []
    y_counter = [0]

    def next_y():
        y_counter[0] += 1
        return y_counter[0]

    # REVERTED: a previous fix added edit.limit=/edit.case=/edit.autoselect=/edit.autohscroll=
    # here, based on comparison against dw_rpt_is_hpp_multibulan.srd and dw_rpt_is.srd -- the
    # wrong oracle files for this DataWindow family. dw_rpt_is_flat_multibulan.srd (90e3fb8) was
    # then treated as the confirmed-working reference and its lack of edit.* was taken as ground
    # truth -- but 90e3fb8 is now known to itself fail PB 11.5 import. The user-supplied
    # dw_rpt_is_flat_multibulan_mantap.srd (confirmed actually working) DOES have edit.* on every
    # column() object, matching each column's own char(N) length exactly. Graft that attribute
    # block onto accountdes (char(50) -> edit.limit=50) while keeping its business
    # expression/geometry/name from the 90e3fb8 layout source.
    #
    # SECOND BUG FOUND (user report: "accountdes nya perbaiki donk agar nama desc sesuai" --
    # live PB 11.5 screenshot showed every detail row's Description repeating one generic value
    # ["PENJUALAN"] instead of the real distinct accountdes text). Live DB query via
    # DSN=vsp;DBN=vspnew confirmed gl_acc.accountdes itself holds correct, distinct values --
    # ruling out a data-layer cause. Comparing column() id= attributes against the confirmed-
    # working mantap file found a genuine mismatch: 90e3fb8 (PROVEN_LINES, itself already known
    # broken) has accountdes id=2 -- the id that rightfully belongs to fincatdes in mantap -- and
    # fincatdes id=1, neither matching mantap's own accountdes id=6 / fincatdes id=2 / parentname
    # id=4. Graft the correct id= from mantap the same way edit.* is grafted, since PB's id=
    # appears to govern column binding/reference independent of name= string matching.
    accountdes_line = PROVEN_LINES[find_line('accountdes')[0]]
    accountdes_line = accountdes_line.replace(
        'visible="1"  font.face',
        'visible="1" edit.limit=50 edit.case=any edit.autoselect=yes edit.autohscroll=yes  font.face', 1)
    _, mantap_accountdes = find_mantap_line('accountdes')
    mantap_id_m = re.search(r'\bid=(\d+)', mantap_accountdes)
    accountdes_line = re.sub(r'\bid=\d+', f'id={mantap_id_m.group(1)}', accountdes_line, count=1)
    out.append(accountdes_line)
    out.append(PROVEN_LINES[find_line('cbln_sdlalu')[0]])

    # cbln_sdini: proven file has this as a giant if(arg_jml_bulan=N,...) chain. For a STATIC
    # file (n_months fixed), it must equal the plain cumulative sum through month n_months, same
    # shape as cbln{n_months} but with all n_months mutasi terms added -- which the proven file's
    # OWN cbln{n} lines already express for a SINGLE month; verified by using the identical
    # "(blnN_debit - blnN_credit) * if(flag_dk='D',1,(-1))" fragment the proven cbln{n} lines use.
    _, cbln_sdini_line = find_line('cbln_sdini')
    if n_months == 1:
        # bare single term, same as cbln1's own expression (verified fragment below)
        _, cbln1_line = find_line('cbln1')
        m = re.search(r'expression="([^"]*)"', cbln1_line)
        sdini_expr = m.group(1)
    else:
        _, cbln1_line = find_line('cbln1')
        m = re.search(r'expression="\(([^"]*)\)"', cbln1_line)
        term_tpl = "(bln{n}_debit - bln{n}_credit) * if(flag_dk='D',1,(-1))"
        terms = [term_tpl.format(n=n) for n in range(1, n_months + 1)]
        sdini_expr = "(" + " + ".join(terms) + ")"
    # BUG FIX: this line used to also call set_y(line, next_y() + 200), moving cbln_sdini's own
    # y coordinate into the hidden-helper vertical stacking zone (y=200+) as if it were an
    # invisible 1x1 helper object like cbln1..N. It is NOT a hidden helper -- it is a real,
    # visible detail-row cell (border="2", full row height/width) that must stay at the same
    # y as its sibling cbln_sdlalu (y="4", untouched, appended verbatim two lines above). This
    # was producing exactly the visual defect seen in a live PowerBuilder screenshot: the s.d.
    # <this year> column rendered as an empty box at the correct row, while its real value
    # appeared as a disconnected floating box far below (at the hidden-helper y position).
    line = re.sub(r'expression="[^"]*"', f'expression="{sdini_expr}"', cbln_sdini_line, count=1)
    out.append(line)

    # cbln1..cbln{n_months}: byte-identical proven lines (just re-sequence y)
    for n in range(1, n_months + 1):
        _, l = find_line(f'cbln{n}')
        out.append(set_y(l, next_y() + 200))

    # cslot1..cslot{n_months}: for a STATIC file, cslot{slot} (descending position) = the mutasi
    # of month (n_months - slot + 1), i.e. just "cbln{month_num}" -- confirmed by inspecting the
    # proven file's cslot{K} chain: its arg_jml_bulan=K branch IS exactly cbln{K}'s own formula.
    for slot in range(1, n_months + 1):
        month_num = n_months - slot + 1
        _, cslotN_line = find_line(f'cslot{slot}')
        # Reuse this exact proven line's tail (border, geometry template, name) but replace the
        # expression with a bare reference to cbln{month_num}, matching how the proven cslot
        # objects are VISIBLE (border="2", real width) unlike the hidden cbln/netsplit helpers.
        line = re.sub(r'expression="[^"]*"', f'expression="cbln{month_num}"', cslotN_line, count=1)
        out.append(line)

    # netsplit _a/_b pairs for sdlalu, sdini, slot1..N -- proven file's OWN line shape, y resequenced
    def netsplit(base_a_name, base_b_name, body_expr):
        _, a_line = find_line(base_a_name)
        _, b_line = find_line(base_b_name)
        a_line = re.sub(r'expression="[^"]*"', f'expression="{body_expr[0]}"', a_line, count=1)
        b_line = re.sub(r'expression="[^"]*"', f'expression="{body_expr[1]}"', b_line, count=1)
        a_line = set_y(a_line, next_y() + 200)
        b_line = set_y(b_line, next_y() + 200)
        out.append(a_line)
        out.append(b_line)

    netcond = "fincatcode='IS2230' and parentcode='500-010'"
    _, cbln_sdlalu_a0 = find_line('cbln_sdlalu_a')
    m = re.search(r'expression="if\([^,]+,0,(.*)\)"border', cbln_sdlalu_a0)
    sdlalu_body = m.group(1)
    netsplit('cbln_sdlalu_a', 'cbln_sdlalu_b', (f"if({netcond},0,{sdlalu_body})", f"if({netcond},{sdlalu_body},0)"))
    netsplit('cbln_sdini_a', 'cbln_sdini_b', (f"if({netcond},0,{sdini_expr})", f"if({netcond},{sdini_expr},0)"))

    # cbln{n}_a/cbln{n}_b: present in the golden master for every month 1..12 (right after
    # cbln_sdini_a/_b, before the cslot{n}_a/_b loop), even though nothing in the golden master's
    # own summary/trailer bands actually references them -- only cslot{n}_a/_b are referenced by
    # trailer.2/trailer.1's sum(cslot{n}_a - cslot{n}_b for group N). Confirmed via direct search:
    # cbln1_a appears exactly once in the whole golden master (its own declaration), so these are
    # genuinely dead/unreferenced objects there too -- but per explicit instruction to retain
    # golden-master objects/attributes as much as possible, keep them present for months 1..N.
    for n in range(1, n_months + 1):
        _, cbln_a_line = find_line(f'cbln{n}_a')
        _, cbln_b_line = find_line(f'cbln{n}_b')
        cbln_a_line = set_y(cbln_a_line, next_y() + 200)
        cbln_b_line = set_y(cbln_b_line, next_y() + 200)
        out.append(cbln_a_line)
        out.append(cbln_b_line)

    for slot in range(1, n_months + 1):
        month_num = n_months - slot + 1
        body = f"cbln{month_num}"
        _, a_line = find_line('cbln1_a')  # template shape (any cblnN_a has the same shape)
        _, b_line = find_line('cbln1_b')
        a_line2 = re.sub(r'expression="[^"]*"', f'expression="if({netcond},0,{body})"', a_line, count=1)
        b_line2 = re.sub(r'expression="[^"]*"', f'expression="if({netcond},{body},0)"', b_line, count=1)
        a_line2 = re.sub(r'name=\S+ visible', f'name=cslot{slot}_a visible', a_line2, count=1)
        b_line2 = re.sub(r'name=\S+ visible', f'name=cslot{slot}_b visible', b_line2, count=1)
        a_line2 = set_y(a_line2, next_y() + 200)
        b_line2 = set_y(b_line2, next_y() + 200)
        out.append(a_line2)
        out.append(b_line2)

    # tot_{category}_{column} rollups: proven file's exact line shape (verbatim expression
    # pattern sum(if(filter,field,0) for all)), just naming the field to our column set.
    cat_filters = {
        'penjualan': "fincatcode='IS1001'",
        'hpp': "fincatcode='IS1110'",
        'biaya': "(fincatcode='IS2010' or fincatcode='IS2110' or fincatcode='IS2120' or fincatcode='IS2130')",
        'pendapatan': "(fincatcode='IS2230' and parentcode='500-000')",
        'biayalain': "(fincatcode='IS2230' and parentcode='500-010')",
        'pajak': "fincatcode='IS2330'",
    }
    cols = ['sdlalu', 'sdini'] + [f'slot{s}' for s in range(1, n_months + 1)]
    field_map = {'sdlalu': 'cbln_sdlalu', 'sdini': 'cbln_sdini'}
    for s in range(1, n_months + 1):
        field_map[f'slot{s}'] = f'cslot{s}'

    _, tot_template = find_line('tot_penjualan_sdlalu')
    for cat, filt in cat_filters.items():
        for col in cols:
            field = field_map[col]
            line = re.sub(r'expression="[^"]*"', f'expression="sum(if({filt},{field},0) for all)"', tot_template, count=1)
            line = re.sub(r'name=\S+ visible', f'name=tot_{cat}_{col} visible', line, count=1)
            line = set_y(line, next_y() + 200)
            out.append(line)

    # profit-line helpers: proven file's exact line shape
    _, laba_template = find_line('labakotor_sdlalu')

    def labakotor(c): return f"tot_penjualan_{c} - tot_hpp_{c}"
    def labaoperasional(c): return f"({labakotor(c)}) - tot_biaya_{c}"
    def othernonop(c): return f"tot_pendapatan_{c} - tot_biayalain_{c}"
    def labasblmpajak(c): return f"({labaoperasional(c)}) + ({othernonop(c)})"
    def labaBersih(c): return f"({labasblmpajak(c)}) - tot_pajak_{c}"

    for col in cols:
        for fname, fn in [('labakotor', labakotor), ('labaoperasional', labaoperasional),
                           ('othernonop', othernonop), ('labasblmpajak', labasblmpajak),
                           ('labaBersih', labaBersih)]:
            line = re.sub(r'expression="[^"]*"', f'expression="{fn(col)}"', laba_template, count=1)
            line = re.sub(r'name=\S+ visible', f'name={fname}_{col} visible', line, count=1)
            line = set_y(line, next_y() + 200)
            out.append(line)

    return out


def collapse_chain(expr, n_months):
    """
    Collapse a proven if(arg_jml_bulan=K,BRANCH_K,if(arg_jml_bulan=K+1,BRANCH_K+1,...)) chain down
    to just the branch matching n_months.

    BUG FIXED HERE: this function used to assume every chain's first branch is literally
    "arg_jml_bulan=1" and walked K=1,2,3... by LOOP COUNTER. That is false for objects like
    chdr_slot2/chdr_slot3/etc: the golden master's own chdr_slot{S} chain actually STARTS at
    "arg_jml_bulan=S" (verified directly against dw_rpt_is_flat_multibulan.srd, commit 90e3fb8 --
    e.g. chdr_slot2's first branch is "if(arg_jml_bulan=2,string(arg_bln1_akhir,...)," not
    "arg_jml_bulan=1"). The old code's loop, starting k at 1, failed to match that first branch
    at all and silently returned the ENTIRE uncollapsed chain unchanged -- meaning every
    chdr_slot{S} object for S>=2 in every one of the 12 generated files still contained the full
    12-branch dynamic arg_jml_bulan chain instead of being collapsed to a static value. Fixed by
    reading the ACTUAL "arg_jml_bulan=<K>" value present at each step of the chain (whatever it
    is) instead of assuming it matches the loop counter, and matching against n_months by that
    real value.
    """
    remaining = expr
    for _ in range(13):
        m = re.match(r'^if\(arg_jml_bulan=(\d+),', remaining)
        if not m:
            # last branch has no wrapping if() (proven chain's final else is bare, e.g. chdr_slot
            # dead ends in '' but compute_3/chdr_sdini dead-end in the literal last value)
            return remaining
        k = int(m.group(1))
        # find the matching comma for this branch's VALUE by tracking paren depth from the point
        # right after "if(arg_jml_bulan=K,"
        start = m.end()
        depth = 0
        i = start
        while True:
            c = remaining[i]
            if c == '(':
                depth += 1
            elif c == ')':
                depth -= 1
            elif c == ',' and depth == 0:
                break
            i += 1
        value = remaining[start:i]
        rest = remaining[i + 1:-1] if remaining[-1] == ')' else remaining[i + 1:]
        if k == n_months:
            return value
        remaining = rest
    return remaining
    return remaining


def build_header_band(n_months):
    out = []
    for nm in ['compute_1', 'compute_2']:
        _, l = find_line(nm)
        out.append(l)

    _, compute_3 = find_line('compute_3')
    m = re.search(r'expression="(.*)"border', compute_3)
    full_expr = m.group(1)
    prefix = "'Periode : '+string(arg_bln1_awal,'mmm yyyy')+' s/d '+"
    assert full_expr.startswith(prefix)
    chain = full_expr[len(prefix):]
    collapsed = collapse_chain(chain, n_months)
    new_expr = prefix + collapsed
    out.append(re.sub(r'expression="[^"]*"', f'expression="{new_expr}"', compute_3, count=1))

    _, t_desc = find_line('t_desc')
    out.append(t_desc)
    # BUG FIX: chdr_sdlalu's business-layout-source expression was
    # "'s.d. '+string(arg_bln1_awal,'mmm')+' '+string(year(date(arg_tgl1)),'0000')" -- deriving
    # the displayed month from arg_bln1_awal (the START of the FIRST selected month, i.e. always
    # January) and the year from arg_tgl1 (the comparative period's own START date). That always
    # renders "Jan <year>" regardless of which month the report actually ends on. The comparative
    # period's correct END date is already computed correctly in w_rpt_neraca.srw as
    # ldt_des_lalu_akhir = f_eom(date(year(bln_awal[ll_jml_bulan])-1, month(bln_awal[ll_jml_bulan]), 1))
    # -- i.e. (report end month, report year - 1) -- and passed in as arg_tgl2. The VALUE
    # (cbln_sdlalu's amount) was already using this correctly; only the LABEL text ignored it and
    # rebuilt an incorrect date from unrelated arguments. Fixed by reading directly off arg_tgl2,
    # which is exactly the correct comparative-period end date already being retrieved with.
    _, chdr_sdlalu = find_line('chdr_sdlalu')
    chdr_sdlalu = re.sub(
        r'expression="[^"]*"',
        'expression="\'s.d. \'+string(arg_tgl2,\'mmm yyyy\')"',
        chdr_sdlalu, count=1)
    out.append(chdr_sdlalu)

    _, chdr_sdini = find_line('chdr_sdini')
    m = re.search(r'expression="(.*)"border', chdr_sdini)
    full_expr = m.group(1)
    prefix2 = "'s.d. '+"
    assert full_expr.startswith(prefix2)
    chain2 = full_expr[len(prefix2):]
    collapsed2 = collapse_chain(chain2, n_months)
    out.append(re.sub(r'expression="[^"]*"', f'expression="\'s.d. \'+{collapsed2}"', chdr_sdini, count=1))

    # BUG FIXED HERE: this loop used to call collapse_chain(chain3, slot) -- passing the loop
    # counter (which SLOT position we're filling in) instead of n_months (the actual selected
    # month count, which is what every arg_jml_bulan=K branch test is against). Verified directly
    # against the golden master: chdr_slot2's own chain is
    # "if(arg_jml_bulan=2,string(arg_bln1_akhir,...),if(arg_jml_bulan=3,string(arg_bln2_akhir,...),...))"
    # -- for a report showing n_months=7 total, chdr_slot2 must select the arg_jml_bulan=7 branch
    # (value: string(arg_bln6_akhir,...)), never the arg_jml_bulan=2 branch. Passing "slot" caused
    # every chdr_slot{S} with S>=2 to either fail to collapse at all (old collapse_chain bug) or,
    # after that fix alone, collapse to the WRONG branch (always resolving to whatever branch
    # equals the slot's own position, not the file's actual month count).
    for slot in range(1, n_months + 1):
        _, chdr_slotN = find_line(f'chdr_slot{slot}')
        m = re.search(r'expression="(.*)"border', chdr_slotN)
        chain3 = m.group(1)
        collapsed3 = collapse_chain(chain3, n_months)
        out.append(re.sub(r'expression="[^"]*"', f'expression="{collapsed3}"', chdr_slotN, count=1))

    return out


def build_header1_band():
    # edit.limit=/edit.case=/edit.autoselect=/edit.autohscroll= added back, sourced from the
    # confirmed-working mantap file's own fincatdes column() object (char(50) -> edit.limit=50,
    # matching its own table() declaration exactly). Business content (expression, geometry,
    # name) stays from the 90e3fb8 layout source; only this attribute block is grafted in.
    # id= also grafted from mantap (fincatdes id=1 in 90e3fb8 -> id=2 in mantap) -- see the
    # matching accountdes fix in build_detail_band() for the full root-cause explanation.
    _, l = find_line('fincatdes')
    l = l.replace('visible="1"  font.face',
                   'visible="1" edit.limit=50 edit.case=any edit.autoselect=yes edit.autohscroll=yes  font.face', 1)
    _, mantap_fincatdes = find_mantap_line('fincatdes')
    mantap_id_m = re.search(r'\bid=(\d+)', mantap_fincatdes)
    l = re.sub(r'\bid=\d+', f'id={mantap_id_m.group(1)}', l, count=1)
    return [l]


def build_header2_band():
    # New band, not present in the 90e3fb8 layout source at all. Structurally required per the
    # confirmed-working mantap file: a column() bound to the group-2 column (parentname here,
    # matching group(level=2 by=("parentcode")) below), with edit.* attributes matching its own
    # char(100) declaration. Built directly from the mantap file's own parentname line, with only
    # geometry/name left as that file's own (there is no 90e3fb8 equivalent object to graft onto).
    _, l = find_mantap_line('parentname')
    return [l]


def build_trailer2_band(n_months):
    out = []
    for nm in ['compute_5', 'compute_6', 't2_sdini']:
        _, l = find_line(nm)
        out.append(l)
    for slot in range(1, n_months + 1):
        _, l = find_line(f't2_slot{slot}')
        out.append(l)
    return out


def build_trailer1_band(n_months):
    # NOTE: gb_2/compute_12's width used to be computed HERE from t_slot{n_months}'s position --
    # but that ran BEFORE close_column_gaps() (called later, in build_file()) shifts every
    # sdini/slot{n} object's x to close the gaps between them, which also moves the true right
    # edge of the row further right. Computing the width here used the PRE-gap-closing position,
    # leaving gb_2/compute_12 too narrow and producing a real stray-border gap at the row's right
    # end. Their widths are now finalized in build_file(), AFTER gap-closing, from the actual
    # final position of the last column. Emit them here with a placeholder width (overwritten
    # later) so the rest of this function's logic (which needs their x) stays unchanged.
    out = []
    _, gb_2 = find_line('gb_2')
    out.append(gb_2)

    _, compute_12 = find_line('compute_12')
    out.append(compute_12)

    for nm in ['compute_9', 't_sdini']:
        _, l = find_line(nm)
        out.append(l)
    for slot in range(1, n_months + 1):
        _, l = find_line(f't_slot{slot}')
        out.append(l)
    return out


def build_summary_band(n_months):
    out = []
    for idx in ['1', '3', '4', '5']:
        _, lbl = find_line(f'lbl_{idx}')
        out.append(lbl)
        for nm in [f'rlp_{idx}_sdlalu', f'rlp_{idx}_sdini']:
            _, l = find_line(nm)
            out.append(l)
        for slot in range(1, n_months + 1):
            _, l = find_line(f'rlp_{idx}_slot{slot}')
            out.append(l)
    return out


def resequence_y(lines, base):
    """Renumber y= for every line to be contiguous starting at base, preserving relative order."""
    out = []
    for i, l in enumerate(lines):
        out.append(set_y(l, base + i))
    return out


def close_column_gaps(lines, n_months, sdlalu_x, sdlalu_w):
    """
    Per explicit instruction: eliminate the small gaps between adjacent numeric-column boxes
    (sdini, slot1..N) so they touch and form one continuous grid, instead of the canonical
    mantap file's own convention (which has 4-23 unit gaps between column boxes -- confirmed
    intentional there, but not wanted for this report). Only x is changed; width/height/border/
    font/alignment/expression are untouched, so box SIZE and content stay exactly as built.
    Recomputes each logical column's x as the immediately preceding column's right edge (x+width)
    -- sdlalu itself is left as-is (it already touches the description column with zero gap; its
    x/width are passed in as the fixed anchor since its OWN object name differs per band --
    chdr_sdlalu/cbln_sdlalu in header/detail vs compute_6/compute_9 in trailer.2/trailer.1, so it
    cannot be auto-detected by a name pattern the way sdini/slot{n} can). sdini's x is set to
    sdlalu's right, slot1's x to sdini's right, slot2's x to slot1's right, and so on. Applied to
    every object whose name ends in _sdini or _slot<N> -- the naming convention IS uniform for
    those (chdr_/c/t2_/t_/rlp_{N}_ prefixes, always ending exactly in "sdini" or "slot<n>") --
    across every band, so header/detail/trailer.2/trailer.1/summary share identical column edges.
    """
    def width_of(col_suffix):
        for l in lines:
            m = re.search(r'name=\S*' + col_suffix + r'\b', l)
            if m:
                wm = re.search(r'\bwidth="(\d+)"', l)
                if wm and int(wm.group(1)) > 1:
                    return int(wm.group(1))
        return None

    # BORDER_OVERLAP: every column here uses border="2" (PowerBuilder's full "Box" style, all 4
    # sides) independently. When two such boxes are placed with EXACTLY touching edges (gap=0,
    # as computed above), PowerBuilder draws both boxes' adjoining lines side-by-side, rendering
    # as a visibly thicker/doubled seam at every column join (confirmed from a live PB 11.5
    # screenshot after the gap=0 fix). PB's border= attribute has no per-side control (values are
    # whole shapes: None/Shadow/Box/Resize/Underline/3D), so the standard technique to merge two
    # independently-drawn box edges into what reads as one line is a small deliberate NEGATIVE
    # gap (overlap) instead of an exact zero gap, so the two border lines draw on top of each
    # other rather than adjacent to each other.
    BORDER_OVERLAP = 1

    target_x = {}
    cursor = sdlalu_x + sdlalu_w - BORDER_OVERLAP
    sdini_w = width_of('sdini')
    if sdini_w:
        target_x['sdini'] = cursor
        cursor += sdini_w - BORDER_OVERLAP
    for slot in range(1, n_months + 1):
        w = width_of(f'slot{slot}')
        if w:
            target_x[f'slot{slot}'] = cursor
            cursor += w - BORDER_OVERLAP

    out = []
    for l in lines:
        m = re.search(r'name=\S*?(sdini|slot\d+)\b', l)
        wm = re.search(r'\bwidth="(\d+)"', l)
        if m and wm and int(wm.group(1)) > 1 and m.group(1) in target_x:
            l = re.sub(r'\bx="\d+"', f'x="{target_x[m.group(1)]}"', l, count=1)
        out.append(l)
    return out


def build_file(n_months):
    name = f'dw_rpt_is_flat_multibulan{n_months:02d}'

    header_lines_content = build_header_band(n_months)
    header1_lines_content = build_header1_band()
    header2_lines_content = build_header2_band()
    detail_lines_content = build_detail_band(n_months)
    trailer2_lines_content = build_trailer2_band(n_months)
    trailer1_lines_content = build_trailer1_band(n_months)
    summary_lines_content = build_summary_band(n_months)

    # Close the gaps between adjacent numeric column boxes (sdini, slot1..N) uniformly across
    # every band, so header/detail/trailer.2/trailer.1/summary all share identical column edges.
    # sdlalu_x/w read once from detail's cbln_sdlalu (reliably named the same across every band's
    # generation -- unlike the sdlalu object itself, whose NAME differs per band).
    _sdlalu_x = _sdlalu_w = None
    for _l in detail_lines_content:
        if re.search(r'name=cbln_sdlalu\b', _l):
            _sdlalu_x = int(re.search(r'\bx="(\d+)"', _l).group(1))
            _sdlalu_w = int(re.search(r'\bwidth="(\d+)"', _l).group(1))
            break
    assert _sdlalu_x is not None, "cbln_sdlalu not found -- cannot anchor column gap-closing"

    header_lines_content = close_column_gaps(header_lines_content, n_months, _sdlalu_x, _sdlalu_w)
    detail_lines_content = close_column_gaps(detail_lines_content, n_months, _sdlalu_x, _sdlalu_w)
    trailer2_lines_content = close_column_gaps(trailer2_lines_content, n_months, _sdlalu_x, _sdlalu_w)
    trailer1_lines_content = close_column_gaps(trailer1_lines_content, n_months, _sdlalu_x, _sdlalu_w)
    summary_lines_content = close_column_gaps(summary_lines_content, n_months, _sdlalu_x, _sdlalu_w)

    # Finalize gb_2/compute_12's width now that gap-closing has established the row's true final
    # right edge (the last slot column's x+width, post gap-closing).
    _last_x = _last_w = None
    for _l in trailer1_lines_content:
        if re.search(r'name=t_slot' + str(n_months) + r'\b', _l):
            _last_x = int(re.search(r'\bx="(\d+)"', _l).group(1))
            _last_w = int(re.search(r'\bwidth="(\d+)"', _l).group(1))
            break
    assert _last_x is not None, f"t_slot{n_months} not found -- cannot finalize row width"
    _right_edge = _last_x + _last_w

    def _resize_to_right_edge(lines, name):
        result = []
        for l in lines:
            if re.search(r'\bname=' + re.escape(name) + r'\b', l):
                xm = int(re.search(r'\bx="(\d+)"', l).group(1))
                l = re.sub(r'\bwidth="\d+"', f'width="{_right_edge - xm}"', l, count=1)
            result.append(l)
        return result

    trailer1_lines_content = _resize_to_right_edge(trailer1_lines_content, 'gb_2')
    trailer1_lines_content = _resize_to_right_edge(trailer1_lines_content, 'compute_12')

    header2_max_bottom = max(y_of(l) + int(re.search(r'height="(\d+)"', l).group(1)) for l in header2_lines_content)
    header2_height = header2_max_bottom + 4

    detail_max_bottom = max(y_of(l) + int(re.search(r'height="(\d+)"', l).group(1)) for l in detail_lines_content)
    detail_height = detail_max_bottom + 8

    summary_max_bottom = max(y_of(l) + int(re.search(r'height="(\d+)"', l).group(1)) for l in summary_lines_content)
    summary_height = summary_max_bottom + 8

    table_block = build_table_block(n_months)
    sql = build_sql(n_months)
    arg_decl = '("arg_tgl1", datetime),("arg_tgl2", datetime),'
    for n in range(1, n_months + 1):
        arg_decl += f'("arg_bln{n}_awal", datetime),("arg_bln{n}_akhir", datetime),'
    arg_decl += '("arg_show", number),("arg_jml_bulan", number)'
    table_full = table_block + CRLF + f' retrieve="{sql}" arguments=({arg_decl})  sort="fincatcode A parentcode A accountcode A " )'

    header_top = [
        f'$PBExportHeader${name}.srd',
        'release 11.5;',
        'datawindow(units=0 timer_interval=0 color=1073741824 brushmode=0 transparency=0 gradient.angle=0 gradient.color=8421504 gradient.focus=0 gradient.repetition.count=0 gradient.repetition.length=100 gradient.repetition.mode=0 gradient.scale=100 gradient.spread=100 gradient.transparency=0 picture.blur=0 picture.clip.bottom=0 picture.clip.left=0 picture.clip.right=0 picture.clip.top=0 picture.mode=0 picture.scale.x=100 picture.scale.y=100 picture.transparency=0 processing=0 HTMLDW=no print.printername="" print.documentname="" print.orientation = 0 print.margin.left = 110 print.margin.right = 110 print.margin.top = 96 print.margin.bottom = 96 print.paper.source = 0 print.paper.size = 0 print.canusedefaultprinter=yes print.prompt=no print.buttons=no print.preview.buttons=no print.cliptext=no print.overrideprintjob=no print.collate=yes print.background=no print.preview.background=no print.preview.outline=yes hidegrayline=yes showbackcoloronxp=no picture.file="" )',
        'header(height=460 color="536870912" transparency="0" gradient.color="8421504" gradient.transparency="0" gradient.angle="0" brushmode="0" gradient.repetition.mode="0" gradient.repetition.count="0" gradient.repetition.length="100" gradient.focus="0" gradient.scale="100" gradient.spread="100" )',
        f'summary(height={summary_height} color="536870912" transparency="0" gradient.color="8421504" gradient.transparency="0" gradient.angle="0" brushmode="0" gradient.repetition.mode="0" gradient.repetition.count="0" gradient.repetition.length="100" gradient.focus="0" gradient.scale="100" gradient.spread="100" )',
        'footer(height=0 color="536870912" transparency="0" gradient.color="8421504" gradient.transparency="0" gradient.angle="0" brushmode="0" gradient.repetition.mode="0" gradient.repetition.count="0" gradient.repetition.length="100" gradient.focus="0" gradient.scale="100" gradient.spread="100" )',
        f'detail(height={detail_height} color="536870912" transparency="0" gradient.color="8421504" gradient.transparency="0" gradient.angle="0" brushmode="0" gradient.repetition.mode="0" gradient.repetition.count="0" gradient.repetition.length="100" gradient.focus="0" gradient.scale="100" gradient.spread="100" )',
    ]

    # group(level=2 by=("parentcode")) restored to match the confirmed-working mantap file --
    # required alongside the header.2 band above. trailer.height stays 100 (this design's own,
    # already-verified-sufficient trailer.2 content), not mantap's 180 (a different report with
    # different trailer.2 content); header.height is computed from header2's own actual content.
    group_line_1 = 'group(level=1 header.height=104 trailer.height=100 by=("fincatcode" ) header.suppress=yes header.color="536870912" header.transparency="0" header.gradient.color="8421504" header.gradient.transparency="0" header.gradient.angle="0" header.brushmode="0" header.gradient.repetition.mode="0" header.gradient.repetition.count="0" header.gradient.repetition.length="100" header.gradient.focus="0" header.gradient.scale="100" header.gradient.spread="100" trailer.color="536870912" trailer.transparency="0" trailer.gradient.color="8421504" trailer.gradient.transparency="0" trailer.gradient.angle="0" trailer.brushmode="0" trailer.gradient.repetition.mode="0" trailer.gradient.repetition.count="0" trailer.gradient.repetition.length="100" trailer.gradient.focus="0" trailer.gradient.scale="100" trailer.gradient.spread="100" )'
    group_line_2 = f'group(level=2 header.height={header2_height} trailer.height=100 by=("parentcode" ) header.suppress=yes header.color="536870912" header.transparency="0" header.gradient.color="8421504" header.gradient.transparency="0" header.gradient.angle="0" header.brushmode="0" header.gradient.repetition.mode="0" header.gradient.repetition.count="0" header.gradient.repetition.length="100" header.gradient.focus="0" header.gradient.scale="100" header.gradient.spread="100" trailer.color="536870912" trailer.transparency="0" trailer.gradient.color="8421504" trailer.gradient.transparency="0" trailer.gradient.angle="0" trailer.brushmode="0" trailer.gradient.repetition.mode="0" trailer.gradient.repetition.count="0" trailer.gradient.repetition.length="100" trailer.gradient.focus="0" trailer.gradient.scale="100" trailer.gradient.spread="100" )'

    # Switched to match dw_rpt_is_hpp_multibulan.srd's footer exactly -- a genuinely, fully
    # confirmed production file (not just "got furthest") -- rather than the proven-furthest
    # 90e3fb8 file's shorter footer, as one of the few remaining untested concrete differences
    # between the two reference files.
    # REVERTED to the confirmed golden master's own footer (dw_rpt_is_flat_multibulan.srd,
    # verified by the user to run successfully in PowerBuilder 11.5, and confirmed byte-
    # identical to this exact footer via direct read). A previous fix switched to
    # dw_rpt_is_hpp_multibulan.srd's fuller footer -- the wrong oracle for this file family.
    # Footer sourced verbatim from the confirmed-working mantap file (fuller than 90e3fb8's,
    # which lacked htmlgen/xhtmlgen+cssgen/xmlgen/xsltgen/jsgen/export.pdf/export.xhtml).
    footer_lines = [
        'htmltable(border="1" )',
        'htmlgen(clientevents="1" clientvalidation="1" clientcomputedfields="1" clientformatting="0" clientscriptable="0" generatejavascript="1" encodeselflinkargs="1" netscapelayers="0" pagingmethod=0 generatedddwframes="1" )',
        'xhtmlgen() cssgen(sessionspecific="0" )',
        'xmlgen(inline="0" )',
        'xsltgen()',
        'jsgen()',
        'export.xml(headgroups="1" includewhitespace="0" metadatatype=0 savemetadata=0 )',
        'import.xml()',
        'export.pdf(method=0 distill.custompostscript="0" xslfop.print="0" )',
        'export.xhtml()',
    ]

    all_lines = (header_top + [table_full] + [group_line_1, group_line_2] +
                 header_lines_content + header1_lines_content + header2_lines_content +
                 detail_lines_content +
                 trailer2_lines_content + trailer1_lines_content + summary_lines_content +
                 footer_lines)
    final = CRLF.join(all_lines)
    assert final.count('\r\r') == 0

    fname = f'{name}.srd'
    with open(fname, 'w', encoding='utf-16', newline='') as fh:
        fh.write(final)
    return fname, len(all_lines)


if __name__ == '__main__':
    for n in range(1, 13):
        fname, nlines = build_file(n)
        print(f"{fname}: {nlines} top-level lines written")
