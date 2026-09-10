# -*- coding: utf-8 -*-
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
baseX_desc_end = 1422  # description column end (unchanged)

# Columns, in final left-to-right order: sd_lalu, sd_ini, then 12 "slot" month columns
# (slot 1 = rightmost-selected month = position arg_jml_bulan, slot 2 = that month - 1, etc,
# descending down to Jan always in the last populated slot).
N_SLOTS = 12
col_x = {}
col_x['sd_lalu'] = baseX_desc_end
col_x['sd_ini'] = baseX_desc_end + subStep
for slot in range(1, N_SLOTS + 1):
    col_x[f'slot{slot}'] = baseX_desc_end + subStep * (1 + slot)

netcond = "fincatcode='IS2230' and parentcode='500-010'"

def cbln_mutasi(n):
    return f"(bln{n}_debit - bln{n}_credit) * if(flag_dk='D',1,(-1))"

def cbln_cumulative_through(n):
    parts = [cbln_mutasi(m) for m in range(1, n + 1)]
    return "(" + " + ".join(parts) + ")"

# "sd_ini" (cumulative this year through the selected last month) -- chained if() on arg_jml_bulan
sd_ini_expr = cbln_cumulative_through(12)
for n in range(11, 0, -1):
    sd_ini_expr = f"if(arg_jml_bulan={n},{cbln_cumulative_through(n)}," + sd_ini_expr + ")"

# For each descending "slot", the actual month number = arg_jml_bulan - (slot - 1).
# slot's mutasi value = cbln{that month} -- build via chained if() on arg_jml_bulan (1..12).
def slot_mutasi_expr(slot):
    # slot 1 corresponds to month = arg_jml_bulan; slot 2 -> arg_jml_bulan-1; etc.
    # For a given arg_jml_bulan=J, slot s is valid only if (J - s + 1) >= 1, i.e. s <= J.
    expr = "0"
    for j in range(12, 0, -1):
        month_num = j - slot + 1
        if month_num >= 1:
            expr = f"if(arg_jml_bulan={j},{cbln_mutasi(month_num)}," + expr + ")"
    return expr

def slot_header_expr(slot):
    expr = "''"
    for j in range(12, 0, -1):
        month_num = j - slot + 1
        if month_num >= 1:
            expr = f"if(arg_jml_bulan={j},string(arg_bln{month_num}_akhir,'mmm yyyy')," + expr + ")"
    return expr

objs_header = []
objs_header1 = []
objs_detail = []
objs_trailer2 = []
objs_trailer1 = []
objs_summary = []

# ---------------- HEADER ----------------
objs_header.append(f'compute(band=header alignment="0" expression="f_company()"border="0" color="33554432" x="14" y="8" height="80" width="1376" format="[GENERAL]" html.valueishtml="0"  name=compute_1 visible="1" {CTAILB}')
objs_header.append(f'compute(band=header alignment="0" expression="\'INCOME STATEMENT\'"border="0" color="33554432" x="14" y="104" height="80" width="1376" format="[GENERAL]" html.valueishtml="0"  name=compute_2 visible="1" {CTAILB}')
end_expr = "string(arg_bln12_akhir,'mmm yyyy')"
for n in range(11, 0, -1):
    end_expr = f"if(arg_jml_bulan={n},string(arg_bln{n}_akhir,'mmm yyyy')," + end_expr + ")"
title_expr = "'Periode : '+string(arg_bln1_awal,'mmm yyyy')+' s/d '+" + end_expr
objs_header.append(f'compute(band=header alignment="0" expression="{title_expr}"border="0" color="33554432" x="14" y="196" height="80" width="1870" format="[GENERAL]" html.valueishtml="0"  name=compute_3 visible="1" {CTAILB}')
objs_header.append(f'text(band=header alignment="2" text="Description"border="2" color="33554432" x="9" y="316" height="128" width="1408" html.valueishtml="0"  name=t_desc visible="1" {CTAILB}')

objs_header.append(f'compute(band=header alignment="2" expression="\'s.d. \'+string(arg_bln1_awal,\'mmm\')+\' \'+string(year(date(arg_tgl1)),\'0000\')"border="2" color="33554432" x="{col_x["sd_lalu"]}" y="316" height="128" width="{subW}" format="[GENERAL]" html.valueishtml="0"  name=chdr_sdlalu visible="1" {CTAILB}')
objs_header.append(f'compute(band=header alignment="2" expression="\'s.d. \'+{end_expr}"border="2" color="33554432" x="{col_x["sd_ini"]}" y="316" height="128" width="{subW}" format="[GENERAL]" html.valueishtml="0"  name=chdr_sdini visible="1" {CTAILB}')

for slot in range(1, N_SLOTS + 1):
    x = col_x[f'slot{slot}']
    objs_header.append(f'compute(band=header alignment="2" expression="{slot_header_expr(slot)}"border="2" color="33554432" x="{x}" y="316" height="128" width="{subW}" format="[GENERAL]" html.valueishtml="0"  name=chdr_slot{slot} visible="1" {CTAILB}')

# ---------------- HEADER.1 ----------------
objs_header1.append(f'column(band=header.1 id=1 alignment="0" tabsequence=32766 border="0" color="33554432" x="18" y="8" height="76" width="1400" format="[GENERAL]" html.valueishtml="0"  name=fincatdes visible="1" {CTAILB}')

# ---------------- DETAIL ----------------
objs_detail.append(f'column(band=detail id=2 alignment="0" tabsequence=32766 border="0" color="33554432" x="69" y="4" height="76" width="1335" format="[GENERAL]" html.valueishtml="0"  name=accountdes visible="1" {CTAIL}')

# sd_lalu: cumulative through the "sd" month of the PRIOR year, sourced from awal2_debit/credit
# (already correctly ranged Jan..sd-month of prior year by the caller's arg_tgl1/arg_tgl2)
objs_detail.append(f'compute(band=detail alignment="1" expression="(awal2_debit - awal2_credit) * if(flag_dk = \'D\',1,(-1))"border="2" color="33554432" x="{col_x["sd_lalu"]}" y="4" height="76" width="{subW}" format="#,##0.00" html.valueishtml="0"  name=cbln_sdlalu visible="1" {CTAIL}')

# sd_ini: cumulative this year through selected month
objs_detail.append(f'compute(band=detail alignment="1" expression="{sd_ini_expr}"border="2" color="33554432" x="{col_x["sd_ini"]}" y="4" height="76" width="{subW}" format="#,##0.00" html.valueishtml="0"  name=cbln_sdini visible="1" {CTAIL}')

# 12 plain mutasi fields (unchanged meaning: cbln{n} = month n's own movement)
for n in range(1, 13):
    objs_detail.append(f'compute(band=detail alignment="1" expression="{cbln_mutasi(n)}"border="0" color="33554432" x="18" y="{200+n}" height="1" width="1" format="#,##0.00" html.valueishtml="0"  name=cbln{n} visible="1" {CTAIL}')

# 12 descending "slot" display cells, each showing whichever month applies for the current arg_jml_bulan
for slot in range(1, N_SLOTS + 1):
    x = col_x[f'slot{slot}']
    objs_detail.append(f'compute(band=detail alignment="1" expression="{slot_mutasi_expr(slot)}"border="2" color="33554432" x="{x}" y="4" height="76" width="{subW}" format="#,##0.00" html.valueishtml="0"  name=cslot{slot} visible="1" {CTAIL}')

# net-split helpers (single field, no chain) -- now needed for sd_lalu, sd_ini, and each cbln{n}
hidden_y = [220]
def next_hidden_pos():
    y = hidden_y[0]
    hidden_y[0] += 1
    return f'x="18" y="{y}" height="1" width="1"'

def netsplit_pair(base_name, body):
    a = f'compute(band=detail alignment="1" expression="if({netcond},0,{body})"border="0" color="33554432" {next_hidden_pos()} format="#,##0.00" html.valueishtml="0"  name={base_name}_a visible="1" {CTAIL}'
    b = f'compute(band=detail alignment="1" expression="if({netcond},{body},0)"border="0" color="33554432" {next_hidden_pos()} format="#,##0.00" html.valueishtml="0"  name={base_name}_b visible="1" {CTAIL}'
    return [a, b]

objs_detail.extend(netsplit_pair('cbln_sdlalu', "(awal2_debit - awal2_credit) * if(flag_dk = 'D',1,(-1))"))
objs_detail.extend(netsplit_pair('cbln_sdini', sd_ini_expr))
for n in range(1, 13):
    objs_detail.extend(netsplit_pair(f'cbln{n}', cbln_mutasi(n)))
for slot in range(1, N_SLOTS + 1):
    objs_detail.extend(netsplit_pair(f'cslot{slot}', slot_mutasi_expr(slot)))

# category rollup building blocks -- reused business logic, now per plain-month "for all" aggregates
cat_filters = {
    'penjualan': "fincatcode='IS1001'",
    'hpp': "fincatcode='IS1110'",
    'biaya': "(fincatcode='IS2010' or fincatcode='IS2110' or fincatcode='IS2120' or fincatcode='IS2130')",
    'pendapatan': "(fincatcode='IS2230' and parentcode='500-000')",
    'biayalain': "(fincatcode='IS2230' and parentcode='500-010')",
    'pajak': "fincatcode='IS2330'",
}
rollup_cols = ['sdlalu', 'sdini'] + [f'slot{s}' for s in range(1, N_SLOTS + 1)]
col_field_map = {'sdlalu': 'cbln_sdlalu', 'sdini': 'cbln_sdini'}
for s in range(1, N_SLOTS + 1):
    col_field_map[f'slot{s}'] = f'cslot{s}'

for cat, filt in cat_filters.items():
    for col in rollup_cols:
        field = col_field_map[col]
        objs_detail.append(f'compute(band=detail alignment="1" expression="sum(if({filt},{field},0) for all)"border="0" color="33554432" {next_hidden_pos()} format="#,##0.00" html.valueishtml="0"  name=tot_{cat}_{col} visible="1" {CTAIL}')

def labakotor(col): return f"tot_penjualan_{col} - tot_hpp_{col}"
def labaoperasional(col): return f"({labakotor(col)}) - tot_biaya_{col}"
def othernonop(col): return f"tot_pendapatan_{col} - tot_biayalain_{col}"
def labasblmpajak(col): return f"({labaoperasional(col)}) + ({othernonop(col)})"
def labaBersih(col): return f"({labasblmpajak(col)}) - tot_pajak_{col}"

for col in rollup_cols:
    objs_detail.append(f'compute(band=detail alignment="1" expression="{labakotor(col)}"border="0" color="33554432" {next_hidden_pos()} format="#,##0.00" html.valueishtml="0"  name=labakotor_{col} visible="1" {CTAIL}')
    objs_detail.append(f'compute(band=detail alignment="1" expression="{labaoperasional(col)}"border="0" color="33554432" {next_hidden_pos()} format="#,##0.00" html.valueishtml="0"  name=labaoperasional_{col} visible="1" {CTAIL}')
    objs_detail.append(f'compute(band=detail alignment="1" expression="{othernonop(col)}"border="0" color="33554432" {next_hidden_pos()} format="#,##0.00" html.valueishtml="0"  name=othernonop_{col} visible="1" {CTAIL}')
    objs_detail.append(f'compute(band=detail alignment="1" expression="{labasblmpajak(col)}"border="0" color="33554432" {next_hidden_pos()} format="#,##0.00" html.valueishtml="0"  name=labasblmpajak_{col} visible="1" {CTAIL}')
    objs_detail.append(f'compute(band=detail alignment="1" expression="{labaBersih(col)}"border="0" color="33554432" {next_hidden_pos()} format="#,##0.00" html.valueishtml="0"  name=labaBersih_{col} visible="1" {CTAIL}')

lastX_end = col_x[f'slot{N_SLOTS}'] + subW

# ---------------- TRAILER.2 ----------------
objs_trailer2.append(f'compute(band=trailer.2 alignment="0" expression="\'TOTAL \'+parentname"border="0" color="33554432" x="18" y="8" height="76" width="{col_x["sd_lalu"]-18}" format="[GENERAL]" html.valueishtml="0"  name=compute_5 visible="1" {CTAILB}')
objs_trailer2.append(f'compute(band=trailer.2 alignment="1" expression="sum(cbln_sdlalu_a - cbln_sdlalu_b for group 2)"border="2" color="33554432" x="{col_x["sd_lalu"]}" y="8" height="76" width="{subW}" format="#,##0.00" html.valueishtml="0"  name=compute_6 visible="1" {CTAILB}')
objs_trailer2.append(f'compute(band=trailer.2 alignment="1" expression="sum(cbln_sdini_a - cbln_sdini_b for group 2)"border="2" color="33554432" x="{col_x["sd_ini"]}" y="8" height="76" width="{subW}" format="#,##0.00" html.valueishtml="0"  name=t2_sdini visible="1" {CTAILB}')
for slot in range(1, N_SLOTS + 1):
    x = col_x[f'slot{slot}']
    objs_trailer2.append(f'compute(band=trailer.2 alignment="1" expression="sum(cslot{slot}_a - cslot{slot}_b for group 2)"border="2" color="33554432" x="{x}" y="8" height="76" width="{subW}" format="#,##0.00" html.valueishtml="0"  name=t2_slot{slot} visible="1" {CTAILB}')

# ---------------- TRAILER.1 ----------------
objs_trailer1.append(f'groupbox(band=trailer.1 text=""border="2" color="33554432" x="14" y="0" height="92" width="{lastX_end-14}"  name=gb_2 visible="1" {CTAILB}')
objs_trailer1.append(f'compute(band=trailer.1 alignment="0" expression="\'TOTAL \'+fincatdes"border="0" color="33554432" x="18" y="8" height="76" width="{lastX_end-18}" format="[GENERAL]" html.valueishtml="0"  name=compute_12 visible="1" {CTAILB}')
objs_trailer1.append(f'compute(band=trailer.1 alignment="1" expression="sum(cbln_sdlalu_a - cbln_sdlalu_b for group 1)"border="2" color="33554432" x="{col_x["sd_lalu"]}" y="8" height="76" width="{subW}" format="#,##0.00" html.valueishtml="0"  name=compute_9 visible="1" {CTAILB}')
objs_trailer1.append(f'compute(band=trailer.1 alignment="1" expression="sum(cbln_sdini_a - cbln_sdini_b for group 1)"border="2" color="33554432" x="{col_x["sd_ini"]}" y="8" height="76" width="{subW}" format="#,##0.00" html.valueishtml="0"  name=t_sdini visible="1" {CTAILB}')
for slot in range(1, N_SLOTS + 1):
    x = col_x[f'slot{slot}']
    objs_trailer1.append(f'compute(band=trailer.1 alignment="1" expression="sum(cslot{slot}_a - cslot{slot}_b for group 1)"border="2" color="33554432" x="{x}" y="8" height="76" width="{subW}" format="#,##0.00" html.valueishtml="0"  name=t_slot{slot} visible="1" {CTAILB}')

# ---------------- SUMMARY (4 profit-line rollups, once at report end) ----------------
rollup_y = 8
rollups = [
    ('1', 'LABA KOTOR PENJUALAN', 'labakotor'),
    ('3', 'LABA (RUGI) OPERASIONAL', 'labaoperasional'),
    ('4', 'LABA (RUGI) SEBELUM PAJAK', 'labasblmpajak'),
    ('5', 'LABA (RUGI) BERSIH', 'labaBersih'),
]
for idx, label, base in rollups:
    objs_summary.append(f'compute(band=summary alignment="0" expression="\'{label}\'"border="0" color="33554432" x="18" y="{rollup_y}" height="76" width="{col_x["sd_lalu"]-18}" format="[GENERAL]" html.valueishtml="0"  name=lbl_{idx} visible="1" {CTAILB}')
    objs_summary.append(f'compute(band=summary alignment="1" expression="{base}_sdlalu"border="2" color="33554432" x="{col_x["sd_lalu"]}" y="{rollup_y}" height="76" width="{subW}" format="#,##0.00" html.valueishtml="0"  name=rlp_{idx}_sdlalu visible="1" {CTAILB}')
    objs_summary.append(f'compute(band=summary alignment="1" expression="{base}_sdini"border="2" color="33554432" x="{col_x["sd_ini"]}" y="{rollup_y}" height="76" width="{subW}" format="#,##0.00" html.valueishtml="0"  name=rlp_{idx}_sdini visible="1" {CTAILB}')
    for slot in range(1, N_SLOTS + 1):
        x = col_x[f'slot{slot}']
        objs_summary.append(f'compute(band=summary alignment="1" expression="{base}_slot{slot}"border="2" color="33554432" x="{x}" y="{rollup_y}" height="76" width="{subW}" format="#,##0.00" html.valueishtml="0"  name=rlp_{idx}_slot{slot} visible="1" {CTAILB}')
    rollup_y += 84

summary_height = rollup_y + 8

all_body = objs_header + objs_header1 + objs_detail + objs_trailer2 + objs_trailer1 + objs_summary
body = CRLF.join(all_body)

with open('_prefix_excel.txt', 'r', encoding='utf-16', newline='') as fh:
    prefix = fh.read()

prefix = re.sub(r'(group\(level=1 header\.height=\d+ trailer\.height=)\d+', r'\g<1>100', prefix)

# The detail band's own top-level height declaration must cover every object placed in it,
# including the hidden 1x1 calculation helpers stacked via next_hidden_pos() -- otherwise the
# band's actual content overflows its declared height, which is exactly the kind of mismatch
# that has previously caused PB Painter's source parser to lose sync at the band boundary.
detail_max_bottom = 0
for ln in objs_detail:
    m_y = re.search(r'\by="(\d+)"', ln)
    m_h = re.search(r'\bheight="(\d+)"', ln)
    if m_y and m_h:
        detail_max_bottom = max(detail_max_bottom, int(m_y.group(1)) + int(m_h.group(1)))
detail_height = detail_max_bottom + 8
prefix = re.sub(r'^detail\(height=\d+', f'detail(height={detail_height}', prefix, count=1, flags=re.MULTILINE)
print("detail band height set to:", detail_height, "(actual max content bottom:", detail_max_bottom, ")")

footer = CRLF.join([
    'htmltable(border="1" )',
    'xhtml(controlblock="no" visibleburnin="no" )',
    'export.xml(headgroup=no metadata=no linkschema=no id=no)',
    'import.xml(encoding="iso-8859-1" )',
])

final = prefix + CRLF + body + CRLF + footer
assert final.count('\r\r') == 0

with open('dw_rpt_is_flat_multibulan.srd', 'w', encoding='utf-16', newline='') as fh:
    fh.write(final)

print("rebuild complete.")
total_objs = len(objs_header) + len(objs_header1) + len(objs_detail) + len(objs_trailer2) + len(objs_trailer1) + len(objs_summary)
print("header:", len(objs_header), "detail:", len(objs_detail), "trailer1:", len(objs_trailer1),
      "trailer2:", len(objs_trailer2), "summary:", len(objs_summary))
print("TOTAL OBJECTS:", total_objs)
print("last x end:", lastX_end)
print("summary_height:", summary_height)
print("file chars:", len(final))
