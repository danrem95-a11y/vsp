import zipfile, re, datetime
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
sheets={}
for sh in ET.fromstring(z.read('xl/workbook.xml')).find(NS+'sheets').findall(NS+'sheet'):
    tgt=rels[sh.get(RNS+'id')]; tgt='xl/'+tgt if not tgt.startswith('xl/') else tgt
    sheets[sh.get('name')]=tgt
def cidx(ref):
    m=re.match(r'[A-Z]+',ref).group(0); n=0
    for c in m: n=n*26+(ord(c)-64)
    return n
def rows_of(sheet):
    root=ET.fromstring(z.read(sheets[sheet]))
    out=[]
    for row in root.find(NS+'sheetData').findall(NS+'row'):
        cells={}
        for c in row.findall(NS+'c'):
            ci=cidx(c.get('r')); t=c.get('t'); v=c.find(NS+'v'); val=''
            if t=='s' and v is not None: val=sst[int(v.text)]
            elif v is not None: val=v.text
            cells[ci]=val
        out.append((int(row.get('r')),cells))
    return out
def num(s):
    try: return float(s)
    except: return None
def xdate(serial):
    s=num(serial)
    if s is None: return None
    return (datetime.datetime(1899,12,30)+datetime.timedelta(days=float(s))).date()

# per-sheet column map: cat_code, date, desc, cost, life, accum2025, nbv2025, total2026, jan2026
MAP={
 'Kendaraan':     ('KDR',3,5,15,19,44,45,52,53),
 'Bangunan':      ('BGN',3,5,14,18,43,44,51,52),
 'Perl. Kantor':  ('PKT',3,5,14,16,40,41,48,49),
 'Perl. Bengkel': ('PBK',3,5,14,16,40,41,48,49),
}
HDRS={'Kendaraan','Bangunan','Peralatan Kantor','Peralatan Bengkel','Tanah','ASET TA',
      'Perl. Kantor','Perl. Bengkel'}

def esc(s): return (s or '').replace("'","''").strip()

assets=[]   # dict per asset
for sheet,(cat,cD,cDesc,cCost,cLife,cAcc,cNbv,cTot,cJan) in MAP.items():
    seq=0
    for rn,cells in rows_of(sheet):
        if rn<11: continue
        cost=num(cells.get(cCost,'')); desc=cells.get(cDesc,'') or ''
        if not cost or cost<=0: continue
        if not desc.strip() or desc.strip() in HDRS: continue
        life=num(cells.get(cLife,'')) or 0
        acc=num(cells.get(cAcc,'')) or 0
        nbv=num(cells.get(cNbv,''))
        if nbv is None: nbv=cost-acc
        tot=num(cells.get(cTot,'')) or 0
        months=[num(cells.get(cJan+i,'')) or 0 for i in range(12)]
        seq+=1
        assets.append(dict(cat=cat,seq=seq,date=xdate(cells.get(cD,'')),name=desc.strip(),
            cost=round(cost,2),life=int(round(life)),accum=round(acc,2),nbv=round(nbv,2),
            tot2026=round(tot,2),months=[round(m,2) for m in months]))

# Tanah (non-depreciable): cost col 13, desc col 4, date col 3
seq=0
for rn,cells in rows_of('Tanah'):
    if rn<11: continue
    cost=num(cells.get(13,'')); desc=cells.get(4,'') or ''
    if not cost or cost<=0: continue
    if not desc.strip() or desc.strip() in HDRS: continue
    seq+=1
    assets.append(dict(cat='TNH',seq=seq,date=xdate(cells.get(3,'')),name=desc.strip(),
        cost=round(cost,2),life=0,accum=0.0,nbv=round(cost,2),tot2026=0.0,months=[0]*12))

# ---- reconcile per category ----
from collections import defaultdict
agg=defaultdict(lambda:[0,0.0,0.0,0.0,0.0,[0.0]*12])  # n,cost,accum,nbv,tot2026,months
for a in assets:
    g=agg[a['cat']]; g[0]+=1; g[1]+=a['cost']; g[2]+=a['accum']; g[3]+=a['nbv']; g[4]+=a['tot2026']
    for i in range(12): g[5][i]+=a['months'][i]
print("cat   n    cost            accum2025       nbv2025         tot2026        jan..jun2026")
for cat in ('TNH','BGN','PKT','PBK','KDR'):
    g=agg[cat]
    print(f"{cat} {g[0]:4d} {g[1]:16,.2f} {g[2]:16,.2f} {g[3]:16,.2f} {g[4]:15,.2f}  "+
          " ".join(f"{g[5][i]:,.0f}" for i in range(6)))
tc=sum(agg[c][1] for c in agg); ta=sum(agg[c][2] for c in agg); tn=sum(agg[c][3] for c in agg); tt=sum(agg[c][4] for c in agg)
print(f"TOT {sum(agg[c][0] for c in agg):4d} {tc:16,.2f} {ta:16,.2f} {tn:16,.2f} {tt:15,.2f}")

# ---- emit SQL ----
acode=lambda a: f"{a['cat']}-{a['seq']:04d}"
with open('fa_02_assets.sql','w',encoding='utf-8') as f:
    f.write("DELETE FROM FA_ASSET WHERE site_id='101';\n")
    for a in assets:
        d="NULL" if not a['date'] else "'%s'"%a['date'].isoformat()
        rem=int(round(a['nbv']/ (max(a['months']) ))) if max(a['months'])>0 else 0
        st='A' if a['nbv']>0.005 else 'F'
        f.write("INSERT INTO FA_ASSET (site_id,asset_code,asset_name,category_code,acquisition_date,"
                "acquisition_cost,residual_value,useful_life_month,accum_dep_beginning,book_value_beginning,"
                "remaining_life_begin,beginning_period,status) VALUES "
                f"('101','{acode(a)}','{esc(a['name'])[:100]}','{a['cat']}',{d},{a['cost']},0,"
                f"{a['life']},{a['accum']},{a['nbv']},{rem},'2025-12-31','{st}');\n")
    f.write("COMMIT;\n")
# FA_DEPRECIATION load for Jan-Jun 2026 from validated WP monthly, with running accumulation
monthends=['2026-01-31','2026-02-28','2026-03-31','2026-04-30','2026-05-31','2026-06-30']
with open('fa_04_depr.sql','w',encoding='utf-8') as f:
    f.write("DELETE FROM FA_DEPRECIATION WHERE site_id='101' AND period<='2026-06-30';\n")
    for a in assets:
        if a['cat']=='TNH': continue
        run=a['accum']
        for i in range(6):
            amt=a['months'][i]
            if amt and amt!=0:
                run=round(run+amt,2)
                bv=round(a['nbv']-(run-a['accum']),2)
                f.write("INSERT INTO FA_DEPRECIATION (site_id,asset_code,period,depreciation_amount,"
                        f"accum_depreciation,book_value,posting_status) VALUES ('101','{acode(a)}',"
                        f"'{monthends[i]}',{amt},{run},{bv},'D');\n")
    f.write("COMMIT;\n")
with open('fa_03_xls_monthly.sql','w',encoding='utf-8') as f:
    f.write("IF EXISTS(SELECT 1 FROM SYS.SYSTABLE WHERE table_name='FA_XLS_MONTHLY') THEN DROP TABLE FA_XLS_MONTHLY END IF;\n")
    f.write("CREATE TABLE FA_XLS_MONTHLY (asset_code varchar(20), mon integer, amount decimal(18,2));\n")
    for a in assets:
        for i in range(12):
            if a['months'][i]:
                f.write(f"INSERT INTO FA_XLS_MONTHLY VALUES ('{acode(a)}',{i+1},{a['months'][i]});\n")
    f.write("COMMIT;\n")
print("\nwrote fa_02_assets.sql, fa_03_xls_monthly.sql ; assets=",len(assets))
