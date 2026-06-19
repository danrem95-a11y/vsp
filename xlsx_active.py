import zipfile, re, sys
from xml.etree import ElementTree as ET
NS='{http://schemas.openxmlformats.org/spreadsheetml/2006/main}'
RNS='{http://schemas.openxmlformats.org/officeDocument/2006/relationships}'
PNS='{http://schemas.openxmlformats.org/package/2006/relationships}'
z=zipfile.ZipFile("WP_Aset tetap_TAM 2026.xlsx")
sst=[]
r=ET.fromstring(z.read('xl/sharedStrings.xml'))
for si in r.findall(NS+'si'):
    sst.append(''.join(t.text or '' for t in si.iter(NS+'t')))
rels={}
for rel in ET.fromstring(z.read('xl/_rels/workbook.xml.rels')).findall(PNS+'Relationship'):
    rels[rel.get('Id')]=rel.get('Target')
wb=ET.fromstring(z.read('xl/workbook.xml'))
sheets=[]
for sh in wb.find(NS+'sheets').findall(NS+'sheet'):
    tgt=rels[sh.get(RNS+'id')]; tgt='xl/'+tgt if not tgt.startswith('xl/') else tgt
    sheets.append((sh.get('name'),tgt))
def cidx(ref):
    m=re.match(r'[A-Z]+',ref).group(0); n=0
    for c in m: n=n*26+(ord(c)-64)
    return n
def num(s):
    try: return float(s)
    except: return None
for name,tgt in sheets:
    if name in ('JURNAL','Tanah'): continue
    root=ET.fromstring(z.read(tgt))
    rows=root.find(NS+'sheetData').findall(NS+'row')
    cnt=0; active=0; tot2026=0.0; details=[]
    for row in rows:
        cells={}
        for c in row.findall(NS+'c'):
            ci=cidx(c.get('r')); t=c.get('t'); v=c.find(NS+'v'); val=''
            if t=='s' and v is not None: val=sst[int(v.text)]
            elif v is not None: val=v.text
            cells[ci]=val
        # description = text cell in col 4 (D)
        desc=cells.get(4,'') or ''
        # acquisition cost audited: first plausible numeric among col 8..14
        cost=None
        for cc in (14,13,11,8):
            if num(cells.get(cc,'')): cost=num(cells[cc]); break
        # trailing 13 numbers = TOTAL,JAN..DEC ; find max col
        maxc=max(cells) if cells else 0
        tail=[num(cells.get(i,'')) for i in range(maxc-12,maxc+1)]
        total26=tail[0] if tail and tail[0] is not None else 0
        if isinstance(desc,str) and desc.strip() and cost and cost>0:
            cnt+=1
            if total26 and total26>0:
                active+=1; tot2026+=total26
                jan=tail[1] if len(tail)>1 and tail[1] else 0
                details.append((desc[:34],int(cost),round(total26,2),round(jan or 0,2)))
    print(f"=== {name}: assets={cnt} active2026={active} total2026Depr={round(tot2026,2):,}")
    for d in details[:8]:
        print(f"    {d[0]:34} cost={d[1]:>14,} yr2026={d[2]:>16,.2f} jan={d[3]:>14,.2f}")
