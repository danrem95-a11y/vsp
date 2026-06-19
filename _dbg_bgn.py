import zipfile, re
from xml.etree import ElementTree as ET
NS='{http://schemas.openxmlformats.org/spreadsheetml/2006/main}'
RNS='{http://schemas.openxmlformats.org/officeDocument/2006/relationships}'
PNS='{http://schemas.openxmlformats.org/package/2006/relationships}'
z=zipfile.ZipFile("WP_Aset tetap_TAM 2026-rekonsiliasi.xlsx")
sst=[]
for si in ET.fromstring(z.read('xl/sharedStrings.xml')).findall(NS+'si'):
    sst.append(''.join(t.text or '' for t in si.iter(NS+'t')))
rels={}
for rel in ET.fromstring(z.read('xl/_rels/workbook.xml.rels')).findall(PNS+'Relationship'):
    rels[rel.get('Id')]=rel.get('Target')
for sh in ET.fromstring(z.read('xl/workbook.xml')).find(NS+'sheets').findall(NS+'sheet'):
    if sh.get('name')=='Bangunan':
        t=rels[sh.get(RNS+'id')]; tgt=t if t.startswith('xl/') else 'xl/'+t
def cl(ref): return re.match(r'[A-Z]+',ref).group(0)
def ci(l):
    n=0
    for c in l: n=n*26+(ord(c)-64)
    return n
root=ET.fromstring(z.read(tgt))
for row in root.find(NS+'sheetData').findall(NS+'row'):
    if int(row.get('r')) not in (12,52): continue
    print("ROW",row.get('r'))
    for c in row.findall(NS+'c'):
        idx=ci(cl(c.get('r'))); t=c.get('t'); v=c.find(NS+'v'); val=''
        if t=='s' and v is not None: val=sst[int(v.text)]
        elif v is not None: val=v.text
        if val not in ('',None): print(f"  c{idx}({c.get('r')}): {val}")
