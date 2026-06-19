import zipfile, re, sys
from xml.etree import ElementTree as ET

NS='{http://schemas.openxmlformats.org/spreadsheetml/2006/main}'
RNS='{http://schemas.openxmlformats.org/officeDocument/2006/relationships}'
PNS='{http://schemas.openxmlformats.org/package/2006/relationships}'
path=sys.argv[1]
z=zipfile.ZipFile(path)

sst=[]
if 'xl/sharedStrings.xml' in z.namelist():
    r=ET.fromstring(z.read('xl/sharedStrings.xml'))
    for si in r.findall(NS+'si'):
        txt=''.join(t.text or '' for t in si.iter(NS+'t'))
        sst.append(txt)

rels={}
rr=ET.fromstring(z.read('xl/_rels/workbook.xml.rels'))
for rel in rr.findall(PNS+'Relationship'):
    rels[rel.get('Id')]=rel.get('Target')

wb=ET.fromstring(z.read('xl/workbook.xml'))
sheets=[]
for sh in wb.find(NS+'sheets').findall(NS+'sheet'):
    name=sh.get('name'); rid=sh.get(RNS+'id')
    tgt=rels[rid]
    if not tgt.startswith('xl/'): tgt='xl/'+tgt
    sheets.append((name,tgt))

def col_letter(ref): return re.match(r'[A-Z]+', ref).group(0)
def col_idx(letters):
    n=0
    for c in letters: n=n*26+(ord(c)-64)
    return n

want=sys.argv[2] if len(sys.argv)>2 else None
maxrows=int(sys.argv[3]) if len(sys.argv)>3 else 80

print("SHEETS:", [s[0] for s in sheets])
for name,tgt in sheets:
    if want and want.lower() not in name.lower(): continue
    print("\n===== SHEET:",name,"=====")
    root=ET.fromstring(z.read(tgt))
    data=root.find(NS+'sheetData')
    rows=data.findall(NS+'row')
    print("rows:",len(rows))
    for row in rows[:maxrows]:
        cells={}; maxc=0
        for c in row.findall(NS+'c'):
            ref=c.get('r'); ci=col_idx(col_letter(ref)); maxc=max(maxc,ci)
            t=c.get('t'); v=c.find(NS+'v'); val=''
            if t=='s' and v is not None: val=sst[int(v.text)]
            elif t=='inlineStr':
                isv=c.find(NS+'is'); val=''.join(x.text or '' for x in isv.iter(NS+'t')) if isv is not None else ''
            elif v is not None: val=v.text
            cells[ci]=(val or '').strip()
        line=" | ".join(f"{cells.get(i,'')}" for i in range(1,maxc+1))
        if line.strip(): print(f"r{row.get('r')}: {line}")
