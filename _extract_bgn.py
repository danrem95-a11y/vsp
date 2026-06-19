import zipfile, re
from xml.etree import ElementTree as ET
NS='{http://schemas.openxmlformats.org/spreadsheetml/2006/main}'
RNS='{http://schemas.openxmlformats.org/officeDocument/2006/relationships}'
PNS='{http://schemas.openxmlformats.org/package/2006/relationships}'
z=zipfile.ZipFile("WP_Aset tetap_TAM 2026-rekonsiliasi.xlsx")
sst=[]
r=ET.fromstring(z.read('xl/sharedStrings.xml'))
for si in r.findall(NS+'si'):
    sst.append(''.join(t.text or '' for t in si.iter(NS+'t')))
rels={}
for rel in ET.fromstring(z.read('xl/_rels/workbook.xml.rels')).findall(PNS+'Relationship'):
    rels[rel.get('Id')]=rel.get('Target')
wb=ET.fromstring(z.read('xl/workbook.xml'))
tgt=None
for sh in wb.find(NS+'sheets').findall(NS+'sheet'):
    if sh.get('name')=='Bangunan':
        t=rels[sh.get(RNS+'id')]; tgt=t if t.startswith('xl/') else 'xl/'+t
def cl(ref): return re.match(r'[A-Z]+',ref).group(0)
def ci(l):
    n=0
    for c in l: n=n*26+(ord(c)-64)
    return n
root=ET.fromstring(z.read(tgt))
def num(x):
    try: return float(x)
    except: return None
tot_cost=tot_akum=tot_nbv=0.0
print(f"{'acq':>8} {'cost(c13)':>16} {'akum2025(c42)':>16} {'nbv2025(c43)':>16}  desc")
for row in root.find(NS+'sheetData').findall(NS+'row'):
    rn=int(row.get('r'))
    if rn<12 or rn>52: continue
    cells={}
    for c in row.findall(NS+'c'):
        idx=ci(cl(c.get('r'))); t=c.get('t'); v=c.find(NS+'v'); val=''
        if t=='s' and v is not None: val=sst[int(v.text)]
        elif v is not None: val=v.text
        cells[idx]=val
    cost=num(cells.get(14,''))
    desc=cells.get(5,'') or cells.get(4,'')
    if cost is None or cost==0: continue
    akum=num(cells.get(43,'')) or 0.0
    nbv=num(cells.get(44,'')) or 0.0
    acq=cells.get(3,'')
    tot_cost+=cost; tot_akum+=akum; tot_nbv+=nbv
    print(f"{acq:>8} {cost:>16,.2f} {akum:>16,.2f} {nbv:>16,.2f}  {desc}")
print("-"*70)
print(f"{'TOTAL':>8} {tot_cost:>16,.2f} {tot_akum:>16,.2f} {tot_nbv:>16,.2f}")
