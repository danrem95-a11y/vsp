# -*- coding: utf-8 -*-
"""
Generates 12 static DataWindow .srd files: dw_rpt_is_flat_multibulan01.srd .. 12.srd.
File N has exactly N month columns (in descending order: month N, N-1, ..., 1), plus the
two year-to-date comparison columns (sd tahun lalu, sd tahun ini) -- no dynamic
if(arg_jml_bulan=...) column-selection logic anywhere, since each file's column count is
fixed by construction. This avoids PowerBuilder's DWE unreliability with deeply-chained
conditional expressions altogether.
"""
import re

CRLF = '\r\n'

CTAIL = (' font.face="Tahoma" font.height="-8" font.weight="400"  font.family="2" font.pitch="2" font.charset="0" '
         'background.mode="1" background.color="536870912" background.transparency="0" background.gradient.color="8421504" '
         'background.gradient.transparency="0" background.gradient.angle="0" background.brushmode="0" '
         'background.gradient.repetition.mode="0" background.gradient.repetition.count="0" background.gradient.repetition.length="100" '
         'background.gradient.focus="0" background.gradient.scale="100" background.gradient.spread="100" '
         'tooltip.backcolor="134217752" tooltip.delay.initial="0" tooltip.delay.visible="32000" tooltip.enabled="0" '
         'tooltip.hasclosebutton="0" tooltip.icon="0" tooltip.isbubble="0" tooltip.maxwidth="0" tooltip.textcolor="134217751" '
         'tooltip.transparency="0" transparency="0" )')
CTAILB = CTAIL.replace('font.weight="400"', 'font.weight="700"')

subW = 560
subStep = 580
descX_end = 1422

netcond = "fincatcode='IS2230' and parentcode='500-010'"

cat_filters = {
    'penjualan': "fincatcode='IS1001'",
    'hpp': "fincatcode='IS1110'",
    'biaya': "(fincatcode='IS2010' or fincatcode='IS2110' or fincatcode='IS2120' or fincatcode='IS2130')",
    'pendapatan': "(fincatcode='IS2230' and parentcode='500-000')",
    'biayalain': "(fincatcode='IS2230' and parentcode='500-010')",
    'pajak': "fincatcode='IS2330'",
}


def cbln_mutasi(n):
    return f"(bln{n}_debit - bln{n}_credit) * if(flag_dk='D',1,(-1))"


def cbln_cumulative_through(n):
    parts = [cbln_mutasi(m) for m in range(1, n + 1)]
    return "(" + " + ".join(parts) + ")"


def build_table_and_sql(n_months):
    cols = [
        ' column=(type=char(10) updatewhereclause=yes name=fincatcode dbname="fincatcode" )',
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
        cols.append(f' column=(type=decimal(6) updatewhereclause=yes name=bln{n}_debit dbname="bln{n}_debit" )')
        cols.append(f' column=(type=decimal(6) updatewhereclause=yes name=bln{n}_credit dbname="bln{n}_credit" )')
    cols.append(' column=(type=char(218) updatewhereclause=yes name=is_find dbname="is_find" )')
    table_block = "table(column=(type=char(10) updatewhereclause=yes name=fincatcode dbname=\"fincatcode\" )\r\n" + \
                  "\r\n".join(cols[1:]) + "\r\n"

    select_cols = ["a.fincatcode,a.fincatdes,b.parentcode,b.parentname,c.accountcode,c.accountdes,c.debetcredit as flag_dk",
                   "isnull(awal2.debit,0.00) as awal2_debit",
                   "isnull(awal2.credit,0.00) as awal2_credit"]
    for n in range(1, n_months + 1):
        select_cols.append(f"isnull(bln{n}.debit,0.00) as bln{n}_debit")
        select_cols.append(f"isnull(bln{n}.credit,0.00) as bln{n}_credit")
    select_cols.append("a.fincatdes+' '+b.parentname+' '+c.accountcode as is_find")
    select_clause = "select\n" + ",\n".join(select_cols) + "\n"

    from_clause = "from\ngl_cate a,gl_cate_detail b,gl_acc c,\n"

    awal2_sub = (
        "(\n"
        "SELECT gl_journal.account_id,\n"
        "cast(sum(isnull(debet,0)) as decimal(18,6)) as debit,\n"
        "cast(sum(isnull(kredit,0)) as decimal(18,6)) as credit\n"
        "FROM gl_journal\n"
        "WHERE tgl between :arg_tgl1 and :arg_tgl2 and\n"
        "((isnull(gl_journal.show_hide,'1') = '1') or 1 = :arg_show)\n"
        "GROUP BY gl_journal.account_id\n"
        ") awal2,\n"
    )

    bln_subs = []
    for n in range(1, n_months + 1):
        trailing = "," if n < n_months else ""
        bln_subs.append(
            "(\n"
            "SELECT gl_journal.account_id,\n"
            "cast(sum(isnull(debet,0)) as decimal(18,6)) as debit,\n"
            "cast(sum(isnull(kredit,0)) as decimal(18,6)) as credit\n"
            "FROM gl_journal\n"
            f"WHERE tgl between :arg_bln{n}_awal and :arg_bln{n}_akhir and\n"
            "((isnull(gl_journal.show_hide,'1') = '1') or 1 = :arg_show)\n"
            "GROUP BY gl_journal.account_id\n"
            f") bln{n}{trailing}\n"
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
    where_clause = "\n".join(where_lines) + "\n"

    order_clause = "order by\na.fincatcode,b.parentcode,c.accountcode"

    sql_body = select_clause + from_clause + awal2_sub + "".join(bln_subs) + where_clause + order_clause

    arg_decl = '("arg_tgl1", datetime),("arg_tgl2", datetime),'
    for n in range(1, n_months + 1):
        arg_decl += f'("arg_bln{n}_awal", datetime),("arg_bln{n}_akhir", datetime),'
    arg_decl += '("arg_show", number),("arg_jml_bulan", number)'

    return table_block, sql_body, arg_decl


def generate_one(n_months):
    name = f"dw_rpt_is_flat_multibulan{n_months:02d}"

    table_block, sql_body, arg_decl = build_table_and_sql(n_months)

    # column x positions: sd_lalu, sd_ini, then n_months descending slots
    col_x = {'sd_lalu': descX_end, 'sd_ini': descX_end + subStep}
    for slot in range(1, n_months + 1):
        col_x[f'slot{slot}'] = descX_end + subStep * (1 + slot)
    last_x_end = col_x[f'slot{n_months}'] + subW

    objs_header = []
    objs_header1 = []
    objs_header2 = []
    objs_detail = []
    objs_trailer2 = []
    objs_trailer1 = []
    objs_summary = []

    objs_header.append(f'compute(band=header alignment="0" expression="f_company()"border="0" color="33554432" x="14" y="8" height="80" width="1376" format="[GENERAL]" html.valueishtml="0"  name=compute_1 visible="1" {CTAILB}')
    objs_header.append(f'compute(band=header alignment="0" expression="\'INCOME STATEMENT\'"border="0" color="33554432" x="14" y="104" height="80" width="1376" format="[GENERAL]" html.valueishtml="0"  name=compute_2 visible="1" {CTAILB}')
    title_expr = f"'Periode : '+string(arg_bln1_awal,'mmm yyyy')+' s/d '+string(arg_bln{n_months}_akhir,'mmm yyyy')"
    objs_header.append(f'compute(band=header alignment="0" expression="{title_expr}"border="0" color="33554432" x="14" y="196" height="80" width="1870" format="[GENERAL]" html.valueishtml="0"  name=compute_3 visible="1" {CTAILB}')
    objs_header.append(f'text(band=header alignment="2" text="Description"border="2" color="33554432" x="9" y="316" height="128" width="1408" html.valueishtml="0"  name=t_desc visible="1" {CTAILB}')
    objs_header.append(f'compute(band=header alignment="2" expression="\'s.d. \'+string(arg_bln1_awal,\'mmm\')+\' \'+string(year(date(arg_tgl1)),\'0000\')"border="2" color="33554432" x="{col_x["sd_lalu"]}" y="316" height="128" width="{subW}" format="[GENERAL]" html.valueishtml="0"  name=chdr_sdlalu visible="1" {CTAILB}')
    objs_header.append(f'compute(band=header alignment="2" expression="\'s.d. \'+string(arg_bln{n_months}_akhir,\'mmm yyyy\')"border="2" color="33554432" x="{col_x["sd_ini"]}" y="316" height="128" width="{subW}" format="[GENERAL]" html.valueishtml="0"  name=chdr_sdini visible="1" {CTAILB}')
    for slot in range(1, n_months + 1):
        month_num = n_months - slot + 1
        x = col_x[f'slot{slot}']
        objs_header.append(f'compute(band=header alignment="2" expression="string(arg_bln{month_num}_akhir,\'mmm yyyy\')"border="2" color="33554432" x="{x}" y="316" height="128" width="{subW}" format="[GENERAL]" html.valueishtml="0"  name=chdr_slot{slot} visible="1" {CTAILB}')

    objs_header1.append(f'column(band=header.1 id=1 alignment="0" tabsequence=32766 border="0" color="33554432" x="18" y="8" height="76" width="1400" format="[GENERAL]" html.valueishtml="0"  name=fincatdes visible="1" {CTAILB}')

    objs_header2.append(f'column(band=header.2 id=4 alignment="0" tabsequence=32766 border="0" color="33554432" x="37" y="4" height="76" width="1335" format="[GENERAL]" html.valueishtml="0"  name=parentname visible="1" {CTAIL}')

    objs_detail.append(f'column(band=detail id=2 alignment="0" tabsequence=32766 border="0" color="33554432" x="69" y="4" height="76" width="1335" format="[GENERAL]" html.valueishtml="0"  name=accountdes visible="1" {CTAIL}')
    objs_detail.append(f'compute(band=detail alignment="1" expression="(awal2_debit - awal2_credit) * if(flag_dk = \'D\',1,(-1))"border="2" color="33554432" x="{col_x["sd_lalu"]}" y="4" height="76" width="{subW}" format="#,##0.00" html.valueishtml="0"  name=cbln_sdlalu visible="1" {CTAIL}')
    sd_ini_expr = cbln_cumulative_through(n_months)
    objs_detail.append(f'compute(band=detail alignment="1" expression="{sd_ini_expr}"border="2" color="33554432" x="{col_x["sd_ini"]}" y="4" height="76" width="{subW}" format="#,##0.00" html.valueishtml="0"  name=cbln_sdini visible="1" {CTAIL}')

    for n in range(1, n_months + 1):
        objs_detail.append(f'compute(band=detail alignment="1" expression="{cbln_mutasi(n)}"border="0" color="33554432" x="18" y="{200+n}" height="1" width="1" format="#,##0.00" html.valueishtml="0"  name=cbln{n} visible="1" {CTAIL}')

    for slot in range(1, n_months + 1):
        month_num = n_months - slot + 1
        x = col_x[f'slot{slot}']
        objs_detail.append(f'compute(band=detail alignment="1" expression="cbln{month_num}"border="2" color="33554432" x="{x}" y="4" height="76" width="{subW}" format="#,##0.00" html.valueishtml="0"  name=cslot{slot} visible="1" {CTAIL}')

    hidden_y = [200 + n_months + 1]

    # No genuinely working report in this codebase hides a helper compute object by giving it
    # 1x1-twip geometry -- the PROVEN pattern (dw_rpt_is_pendapatan_rekap_multibulan.srd's
    # lalu_500/lalu_510 netsplit pair, and dw_rpt_is.srd's summary-band category rollups) is to
    # give the object real, normal geometry and hide it with visible="0" instead. Stacking dozens
    # of true 1x1 objects (in detail AND in summary) is a construct this session invented and
    # never actually validated against PowerBuilder's real parser. Match the proven convention.
    def next_hidden_pos():
        y = hidden_y[0]
        hidden_y[0] += 1
        return f'x="18" y="{y}" height="20" width="200"'

    def netsplit_pair(base_name, body):
        a = f'compute(band=detail alignment="1" expression="if({netcond},0,{body})"border="0" color="33554432" {next_hidden_pos()} format="#,##0.00" html.valueishtml="0"  name={base_name}_a visible="0" {CTAIL}'
        b = f'compute(band=detail alignment="1" expression="if({netcond},{body},0)"border="0" color="33554432" {next_hidden_pos()} format="#,##0.00" html.valueishtml="0"  name={base_name}_b visible="0" {CTAIL}'
        return [a, b]

    objs_detail.extend(netsplit_pair('cbln_sdlalu', "(awal2_debit - awal2_credit) * if(flag_dk = 'D',1,(-1))"))
    objs_detail.extend(netsplit_pair('cbln_sdini', sd_ini_expr))
    for slot in range(1, n_months + 1):
        month_num = n_months - slot + 1
        objs_detail.extend(netsplit_pair(f'cslot{slot}', f'cbln{month_num}'))

    rollup_cols = ['sdlalu', 'sdini'] + [f'slot{s}' for s in range(1, n_months + 1)]
    col_field_map = {'sdlalu': 'cbln_sdlalu', 'sdini': 'cbln_sdini'}
    for s in range(1, n_months + 1):
        col_field_map[f'slot{s}'] = f'cslot{s}'

    # Every fix attempt so far (bare-LF normalization, adding header.2, moving rollups from
    # detail to summary, switching 1x1 geometry to real geometry) left the reported import error
    # on the EXACT same line/column, which turned out to be the LAST visible rollup-row object
    # (rlp_5_slot1) -- i.e. the boundary right before the first hidden (visible="0") object in
    # the summary band. That boundary, and the ~33 consecutive hidden objects following it, is a
    # construct this session invented and never validated. Eliminate it entirely: no hidden
    # intermediate compute objects for the category/profit-line rollups at all -- inline the full
    # sum(if(filter,field,0) for all) expression directly into each visible rlp_* cell, exactly
    # the same way dw_rpt_is.srd (a real production file) computes its category totals with a
    # single sum(if(...)) call and no intermediate named helper.
    def tot_expr(cat, col):
        filt = cat_filters[cat]
        field = col_field_map[col]
        return f"sum(if({filt},{field},0) for all)"

    def labakotor(c): return f"({tot_expr('penjualan', c)}) - ({tot_expr('hpp', c)})"
    def labaoperasional(c): return f"({labakotor(c)}) - ({tot_expr('biaya', c)})"
    def othernonop(c): return f"({tot_expr('pendapatan', c)}) - ({tot_expr('biayalain', c)})"
    def labasblmpajak(c): return f"({labaoperasional(c)}) + ({othernonop(c)})"
    def labaBersih(c): return f"({labasblmpajak(c)}) - ({tot_expr('pajak', c)})"

    objs_trailer2.append(f'compute(band=trailer.2 alignment="0" expression="\'TOTAL \'+parentname"border="0" color="33554432" x="18" y="8" height="76" width="{col_x["sd_lalu"]-18}" format="[GENERAL]" html.valueishtml="0"  name=compute_5 visible="1" {CTAILB}')
    objs_trailer2.append(f'compute(band=trailer.2 alignment="1" expression="sum(cbln_sdlalu_a - cbln_sdlalu_b for group 2)"border="2" color="33554432" x="{col_x["sd_lalu"]}" y="8" height="76" width="{subW}" format="#,##0.00" html.valueishtml="0"  name=compute_6 visible="1" {CTAILB}')
    objs_trailer2.append(f'compute(band=trailer.2 alignment="1" expression="sum(cbln_sdini_a - cbln_sdini_b for group 2)"border="2" color="33554432" x="{col_x["sd_ini"]}" y="8" height="76" width="{subW}" format="#,##0.00" html.valueishtml="0"  name=t2_sdini visible="1" {CTAILB}')
    for slot in range(1, n_months + 1):
        x = col_x[f'slot{slot}']
        objs_trailer2.append(f'compute(band=trailer.2 alignment="1" expression="sum(cslot{slot}_a - cslot{slot}_b for group 2)"border="2" color="33554432" x="{x}" y="8" height="76" width="{subW}" format="#,##0.00" html.valueishtml="0"  name=t2_slot{slot} visible="1" {CTAILB}')

    objs_trailer1.append(f'groupbox(band=trailer.1 text=""border="2" color="33554432" x="14" y="0" height="92" width="{last_x_end-14}"  name=gb_2 visible="1" {CTAILB}')
    objs_trailer1.append(f'compute(band=trailer.1 alignment="0" expression="\'TOTAL \'+fincatdes"border="0" color="33554432" x="18" y="8" height="76" width="{last_x_end-18}" format="[GENERAL]" html.valueishtml="0"  name=compute_12 visible="1" {CTAILB}')
    objs_trailer1.append(f'compute(band=trailer.1 alignment="1" expression="sum(cbln_sdlalu_a - cbln_sdlalu_b for group 1)"border="2" color="33554432" x="{col_x["sd_lalu"]}" y="8" height="76" width="{subW}" format="#,##0.00" html.valueishtml="0"  name=compute_9 visible="1" {CTAILB}')
    objs_trailer1.append(f'compute(band=trailer.1 alignment="1" expression="sum(cbln_sdini_a - cbln_sdini_b for group 1)"border="2" color="33554432" x="{col_x["sd_ini"]}" y="8" height="76" width="{subW}" format="#,##0.00" html.valueishtml="0"  name=t_sdini visible="1" {CTAILB}')
    for slot in range(1, n_months + 1):
        x = col_x[f'slot{slot}']
        objs_trailer1.append(f'compute(band=trailer.1 alignment="1" expression="sum(cslot{slot}_a - cslot{slot}_b for group 1)"border="2" color="33554432" x="{x}" y="8" height="76" width="{subW}" format="#,##0.00" html.valueishtml="0"  name=t_slot{slot} visible="1" {CTAILB}')

    rollup_y = 8
    rollups = [
        ('1', 'LABA KOTOR PENJUALAN', labakotor),
        ('3', 'LABA (RUGI) OPERASIONAL', labaoperasional),
        ('4', 'LABA (RUGI) SEBELUM PAJAK', labasblmpajak),
        ('5', 'LABA (RUGI) BERSIH', labaBersih),
    ]
    for idx, label, fn in rollups:
        objs_summary.append(f'compute(band=summary alignment="0" expression="\'{label}\'"border="0" color="33554432" x="18" y="{rollup_y}" height="76" width="{col_x["sd_lalu"]-18}" format="[GENERAL]" html.valueishtml="0"  name=lbl_{idx} visible="1" {CTAILB}')
        objs_summary.append(f'compute(band=summary alignment="1" expression="{fn("sdlalu")}"border="2" color="33554432" x="{col_x["sd_lalu"]}" y="{rollup_y}" height="76" width="{subW}" format="#,##0.00" html.valueishtml="0"  name=rlp_{idx}_sdlalu visible="1" {CTAILB}')
        objs_summary.append(f'compute(band=summary alignment="1" expression="{fn("sdini")}"border="2" color="33554432" x="{col_x["sd_ini"]}" y="{rollup_y}" height="76" width="{subW}" format="#,##0.00" html.valueishtml="0"  name=rlp_{idx}_sdini visible="1" {CTAILB}')
        for slot in range(1, n_months + 1):
            x = col_x[f'slot{slot}']
            objs_summary.append(f'compute(band=summary alignment="1" expression="{fn(f"slot{slot}")}"border="2" color="33554432" x="{x}" y="{rollup_y}" height="76" width="{subW}" format="#,##0.00" html.valueishtml="0"  name=rlp_{idx}_slot{slot} visible="1" {CTAILB}')
        rollup_y += 84

    summary_height = rollup_y + 8

    all_body = objs_header + objs_header1 + objs_header2 + objs_detail + objs_trailer2 + objs_trailer1 + objs_summary
    body = CRLF.join(all_body)

    detail_max_bottom = 0
    for ln in objs_detail:
        m_y = re.search(r'\by="(\d+)"', ln)
        m_h = re.search(r'\bheight="(\d+)"', ln)
        if m_y and m_h:
            detail_max_bottom = max(detail_max_bottom, int(m_y.group(1)) + int(m_h.group(1)))
    detail_height = detail_max_bottom + 8

    header_lines = [
        f'$PBExportHeader${name}.srd',
        'release 11.5;',
        'datawindow(units=0 timer_interval=0 color=1073741824 brushmode=0 transparency=0 gradient.angle=0 gradient.color=8421504 gradient.focus=0 gradient.repetition.count=0 gradient.repetition.length=100 gradient.repetition.mode=0 gradient.scale=100 gradient.spread=100 gradient.transparency=0 picture.blur=0 picture.clip.bottom=0 picture.clip.left=0 picture.clip.right=0 picture.clip.top=0 picture.mode=0 picture.scale.x=100 picture.scale.y=100 picture.transparency=0 processing=0 HTMLDW=no print.printername="" print.documentname="" print.orientation = 1 print.margin.left = 110 print.margin.right = 110 print.margin.top = 96 print.margin.bottom = 96 print.paper.source = 0 print.paper.size = 0 print.canusedefaultprinter=yes print.prompt=no print.buttons=no print.preview.buttons=no print.cliptext=no print.overrideprintjob=no print.collate=yes print.background=no print.preview.background=no print.preview.outline=yes hidegrayline=no showbackcoloronxp=no picture.file="" )',
        'header(height=460 color="536870912" transparency="0" gradient.color="8421504" gradient.transparency="0" gradient.angle="0" brushmode="0" gradient.repetition.mode="0" gradient.repetition.count="0" gradient.repetition.length="100" gradient.focus="0" gradient.scale="100" gradient.spread="100" )',
        'summary(height=' + str(summary_height) + ' color="536870912" transparency="0" gradient.color="8421504" gradient.transparency="0" gradient.angle="0" brushmode="0" gradient.repetition.mode="0" gradient.repetition.count="0" gradient.repetition.length="100" gradient.focus="0" gradient.scale="100" gradient.spread="100" )',
        'footer(height=0 color="536870912" transparency="0" gradient.color="8421504" gradient.transparency="0" gradient.angle="0" brushmode="0" gradient.repetition.mode="0" gradient.repetition.count="0" gradient.repetition.length="100" gradient.focus="0" gradient.scale="100" gradient.spread="100" )',
        'detail(height=' + str(detail_height) + ' color="536870912" transparency="0" gradient.color="8421504" gradient.transparency="0" gradient.angle="0" brushmode="0" gradient.repetition.mode="0" gradient.repetition.count="0" gradient.repetition.length="100" gradient.focus="0" gradient.scale="100" gradient.spread="100" height.autosize=yes )',
    ]

    args_and_sort = f'" arguments=({arg_decl})  sort="fincatcode A parentcode A accountcode A " )'
    table_full = table_block + f'retrieve="{sql_body}{args_and_sort}'

    group1_height = 100
    group2_height = 100
    groups = [
        f'group(level=1 header.height=104 trailer.height={group1_height} by=("fincatcode" ) header.suppress=yes header.color="536870912" header.transparency="0" header.gradient.color="8421504" header.gradient.transparency="0" header.gradient.angle="0" header.brushmode="0" header.gradient.repetition.mode="0" header.gradient.repetition.count="0" header.gradient.repetition.length="100" header.gradient.focus="0" header.gradient.scale="100" header.gradient.spread="100" trailer.color="536870912" trailer.transparency="0" trailer.gradient.color="8421504" trailer.gradient.transparency="0" trailer.gradient.angle="0" trailer.brushmode="0" trailer.gradient.repetition.mode="0" trailer.gradient.repetition.count="0" trailer.gradient.repetition.length="100" trailer.gradient.focus="0" trailer.gradient.scale="100" trailer.gradient.spread="100" )',
        f'group(level=2 header.height=88 trailer.height={group2_height} by=("parentcode" ) header.suppress=yes header.color="536870912" header.transparency="0" header.gradient.color="8421504" header.gradient.transparency="0" header.gradient.angle="0" header.brushmode="0" header.gradient.repetition.mode="0" header.gradient.repetition.count="0" header.gradient.repetition.length="100" header.gradient.focus="0" header.gradient.scale="100" header.gradient.spread="100" trailer.color="536870912" trailer.transparency="0" trailer.gradient.color="8421504" trailer.gradient.transparency="0" trailer.gradient.angle="0" trailer.brushmode="0" trailer.gradient.repetition.mode="0" trailer.gradient.repetition.count="0" trailer.gradient.repetition.length="100" trailer.gradient.focus="0" trailer.gradient.scale="100" trailer.gradient.spread="100" )',
    ]

    footer_lines = [
        'htmltable(border="1" )',
        'xhtml(controlblock="no" visibleburnin="no" )',
        'export.xml(headgroup=no metadata=no linkschema=no id=no)',
        'import.xml(encoding="iso-8859-1" )',
    ]

    all_lines = header_lines + [table_full] + groups + [body] + footer_lines
    final = CRLF.join(all_lines)
    # Some embedded SQL text above was built with plain "\n" (readability in this script).
    # PowerBuilder's Painter source parser desyncs its line/column counter on a bare LF
    # inside a quoted string -- every line ending in the .srd file must be CRLF. Normalize
    # by collapsing to bare LF first, then expanding uniformly to CRLF, so this can never
    # regress regardless of which literal a future edit uses.
    final = final.replace('\r\n', '\n').replace('\n', '\r\n')
    assert final.count('\r\r') == 0
    assert '\r\n' in final and not re.search(r'(?<!\r)\n', final)

    fname = f'{name}.srd'
    with open(fname, 'w', encoding='utf-16', newline='') as fh:
        fh.write(final)

    total_objs = len(objs_header) + len(objs_header1) + len(objs_header2) + len(objs_detail) + len(objs_trailer2) + len(objs_trailer1) + len(objs_summary)
    return fname, total_objs, detail_height, last_x_end


if __name__ == '__main__':
    for n in range(1, 13):
        fname, total_objs, detail_h, max_x = generate_one(n)
        print(f"{fname}: objects={total_objs} detail_height={detail_h} max_x={max_x}")
