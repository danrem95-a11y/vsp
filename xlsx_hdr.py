import zipfile, re, sys
from xml.etree import ElementTree as ET
NS='{http://schemas.openxmlformats.org/spreadsheetml/2006/main}'
RNS='{http://schemas.openxmlformats.org/officeDocument/2006/relationships}'
PNS='{http://schemas.openxmlformats.org/package/2006/relationships}'
z=zipfile.ZipFile("WP_Aset tetap_TAM 2026.xlsx")
sst=[]
for si in ET.fromstring(z.read('xl/sharedStrings.xml')).findall(NS+'si'):
    sst.append(''.join(t.text or '' for t in si.iter(NS+'t')))
rels={}
for rel in ET.fromstring(z.read('xl/_rels/workbook.xml.rels')).findall(PNS+'Relationship'):
    rels[rel.get('Id')]=rel.get('Target')
sheets=[]
for sh in ET.fromstring(z.read('xl/workbook.xml')).find(NS+'sheets').findall(NS+'sheet'):
    tgt=rels[sh.get(RNS+'id')]; tgt='xl/'+tgt if not tgt.startswith('xl/') else tgt
    sheets.append((sh.get('name'),tgt))
def cidx(ref):
    m=re.match(r'[A-Z]+',ref).group(0); n=0
    for c in m: n=n*26+(ord(c)-64)
    return n
target=sys.argv[1]
hdr_rows=[int(x) for x in sys.argv[2].split(',')] if len(sys.argv)>2 else [6,7,8]
for name,tgt in sheets:
    if target.lower() not in name.lower(): continue
    root=ET.fromstring(z.read(tgt))
    for row in root.find(NS+'sheetData').findall(NS+'row'):
        rn=int(row.get('r'))
        if rn not in hdr_rows: continue
        cells=[]
        for c in row.findall(NS+'c'):
            ci=cidx(c.get('r')); t=c.get('t'); v=c.find(NS+'v'); val=''
            if t=='s' and v is not None: val=sst[int(v.text)]
            elif v is not None: val=v.text
            if val and str(val).strip(): cells.append(f"{ci}:{str(val).strip()[:22]}")
        print(f"[{name}] r{rn}: "+" | ".join(cells))
