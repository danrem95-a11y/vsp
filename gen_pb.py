# -*- coding: utf-8 -*-
# Generate PowerBuilder 11.5 DataWindow (.srd) for the FA module.
# Reuses verbatim proven property strings from reference DataWindows and adds
# styles: edit / date(calendar) / num(editmask) / ddlb(enum) / dddw(lookup).
import re, os

REF = open('_ref_u8/dw_journal_entry.srd.txt', encoding='utf-8').read()
REFG= open('_ref_u8/dw_journal_list.srd.txt',  encoding='utf-8').read()

def grab(text, startswith, contains=None):
    for ln in text.split('\n'):
        if ln.startswith(startswith) and (contains is None or contains in ln):
            return ln
    raise SystemExit('template not found: '+startswith)

DW_FF  = grab(REF, 'datawindow (')
DW_GR  = grab(REFG,'datawindow(')
BAND_SUM=grab(REF, 'summary(')
BAND_FT =grab(REF, 'footer(')
T_TEXT = grab(REF, 'text(name=voucher_t')
T_EDIT = grab(REF, 'column(name=voucher ')
T_DATE = grab(REF, 'column(name=tgl ')        # editmask + ddcalendar
T_NUM  = grab(REF, 'column(name=rate_rp ')    # editmask numeric
T_DDLB = grab(REF, 'column(name=curr_id ')    # dropdownlistbox
TAIL   = REF[REF.find('htmltable('):REF.find('data()')+6]

def band(kind, h):
    return re.sub(r'height=\d+', 'height='+str(h), grab(REF, kind+'('), count=1)

A=r'(?<![\w.])'   # anchor: not preceded by word-char/dot
def setattr_(s, key, val, q=True):
    pat = A+re.escape(key)+r'="\d+"' if not q else A+re.escape(key)+r'="[^"]*"'
    rep = '%s="%s"'%(key,val)
    return re.sub(pat, rep, s, count=1)

HDRBG=15853276   # rgb(220,230,241) enterprise light blue-gray
def sub_text(name, x, y, w, h, txt, bandname, align=None, bg=None):
    s=T_TEXT
    s=re.sub(A+r'name=\S+','name='+name,s,1)
    s=re.sub(A+r'band=\w+','band='+bandname,s,1)
    s=re.sub(A+r'x="\d+"','x="%d"'%x,s,1)
    s=re.sub(A+r'y="\d+"','y="%d"'%y,s,1)
    s=re.sub(A+r'width="\d+"','width="%d"'%w,s,1)
    s=re.sub(A+r'height="\d+"','height="%d"'%h,s,1)
    s=re.sub(A+r'text="[^"]*"','text="%s"'%txt,s,1)
    if align is not None:
        s=re.sub(A+r'alignment="\d+"','alignment="%d"'%align,s,1)
    if bg is not None:   # solid header background
        s=re.sub(r'background\.mode="\d+"','background.mode="2"',s,1)
        s=re.sub(r'background\.color="\d+"','background.color="%d"'%bg,s,1)
    return s

MONEY_W=800   # lebar minimal kolom uang -> muat 1.000.000.000.000,00 (1 triliun) penuh
def sub_col(name, cid, x, y, w, h, bandname, tabseq, style='edit', fmt='[general]',
            limit=0, child='', disp='', data='', align=None, color_expr=None, link=False, protect=False):
    s = {'edit':T_EDIT,'date':T_DATE,'num':T_NUM,'ddlb':T_DDLB,'dddw':T_EDIT}[style]
    s=re.sub(A+r'name=\S+','name='+name,s,1)
    s=re.sub(A+r'band=\w+','band='+bandname,s,1)
    s=re.sub(A+r'id=\d+','id=%d'%cid,s,1)
    s=re.sub(A+r'x="\d+"','x="%d"'%x,s,1)
    s=re.sub(A+r'y="\d+"','y="%d"'%y,s,1)
    s=re.sub(A+r'width="\d+"','width="%d"'%w,s,1)
    s=re.sub(A+r'height="\d+"','height="%d"'%h,s,1)
    s=re.sub(A+r'format="[^"]*"','format="%s"'%fmt,s,1)
    s=re.sub(A+r'tabsequence=\d+','tabsequence=%d'%tabseq,s,1)
    if style=='edit':
        s=re.sub(r'edit\.limit=\d+','edit.limit=%d'%limit,s,1)
    if style=='ddlb':
        s=s.replace(' tag="w_ddo_currency"','')
    if style=='dddw':
        # dropdown width = percentwidth% of column width. Target ~1850 PBU (fits code + 50-char name).
        pw=max(150, min(600, int(round(1850.0/max(w,1)*100))))
        block=('dddw.name=%s dddw.displaycolumn=%s dddw.datacolumn=%s dddw.percentwidth=%d '
               'dddw.lines=12 dddw.limit=0 dddw.allowedit=yes dddw.vscrollbar=yes '
               'dddw.useasborder=yes dddw.case=any')%(child,disp,data,pw)
        s=re.sub(r'(?:edit\.\S+\s*)+', block+' ', s, count=1)
    if align is not None:   # 0=left 1=right 2=center
        s=re.sub(A+r'alignment="\d+"','alignment="%d"'%align,s,count=1)
    if color_expr:          # conditional text color
        s=re.sub(A+r'color="\d+"','color="33554432~t%s"'%color_expr,s,count=1)
    if link:                # gaya hyperlink: warna biru (penanda clickable) -- aman utk kolom PB
        s=re.sub(A+r'color="[^"]*"','color="13395456"',s,count=1)   # rgb(0,102,204)
    if protect:             # grid read-only: protect + tidak bisa di-tab/edit
        s=re.sub(A+r'tabsequence=\d+','tabsequence=0 protect="1"',s,count=1)
    return s

# group() + compute() token strings from real references (adapted per use)
GROUP_LINE = re.search(r'group\(level=1[^\n]*',
    open('dw_rpt_jual_faktur1_rekap.srd',encoding='utf-16').read()).group(0)
T_COMPUTE = next(ln.strip() for ln in open('dw_balance_sheet.srd',encoding='utf-16').read().split('\n')
                 if ln.strip().startswith('compute(band=trailer.3') and 'expression=' in ln)
ZEBRA = '16777215~tif(mod(getrow(),2)=1,rgb(238,242,248),rgb(255,255,255))'

def compute_field(name, expr, x, y, w, h, band, fmt, align):
    s=T_COMPUTE
    s=re.sub(A+r'band=[\w.]+','band='+band,s,1)
    s=re.sub(A+r'alignment="\d+"','alignment="%d"'%align,s,1)
    s=re.sub(r'expression="[^"]*"','expression="%s"'%expr,s,1)
    s=re.sub(A+r'x="\d+"','x="%d"'%x,s,1)
    s=re.sub(A+r'y="\d+"','y="%d"'%y,s,1)
    s=re.sub(A+r'height="\d+"','height="%d"'%h,s,1)
    s=re.sub(A+r'width="\d+"','width="%d"'%w,s,1)
    s=re.sub(A+r'format="[^"]*"','format="%s"'%fmt,s,1)
    s=re.sub(A+r'name=\w+','name='+name,s,1)
    return s

def coldef(c):
    t=c['t']
    ty={'s':'char(%d)'%c.get('len',20),'dt':'datetime','dec':'decimal(2)','int':'long'}[t]
    upd='update=yes updatewhereclause=yes ' if c.get('upd',True) else 'updatewhereclause=yes '
    vals=' values="%s" '%c['values'] if c.get('values') else ''
    return 'column=(type=%s %sname=%s dbname="%s"%s )'%(ty,upd,c['name'],c['db'],vals)

def bigbold(s, hgt=-12, color=None):
    s=re.sub(r'font\.height="-?\d+"','font.height="%d"'%hgt,s,1)
    s=re.sub(r'font\.weight="\d+"','font.weight="700"',s,1)
    if color is not None: s=re.sub(A+r'color="[^"]*"','color="%d"'%color,s,1)
    return s

def write_srd(fname, folder, grid, cols, retrieve, update_tbl, args,
              group_by=None, summary_col=None, summary_cols=None, zebra=False, row_color=None,
              seq=False, group_header_col=None, summary_counts=False,
              count_label='Jumlah Baris', count_expr=None):
    STEP=100
    hdr_h=116 if grid else 0
    vis=[c for c in cols if c.get('style')!='hidden']
    det_h=88 if grid else (len(vis)*STEP+80)
    sum_h=160 if (summary_col or summary_cols or summary_counts) else 0
    trl_h=92 if group_by else 0
    transp = zebra or bool(row_color)
    det_line=band('detail',det_h)
    if grid and (row_color or zebra):
        det_line=re.sub(r'color="\d+"','color="%s"'%(row_color or ZEBRA), det_line, count=1)
    sum_line=band('summary',sum_h)
    if sum_h>0:  # band summary kuning muda
        sum_line=re.sub(r'color="\d+"','color="13431551"', sum_line, count=1)
    L=['$PBExportHeader$%s.srd'%fname,'release 11.5;', DW_GR if grid else DW_FF,
       band('header',hdr_h), sum_line, BAND_FT, det_line]
    tb=['table('+coldef(cols[0])]
    for c in cols[1:]: tb.append(' '+coldef(c))
    if retrieve: tb.append(' retrieve="%s"'%retrieve)
    if update_tbl: tb.append(' update="%s" updatewhere=1 updatekeyinplace=no'%update_tbl)
    if args: tb.append(' arguments=(%s)'%','.join('("%s", %s)'%(a,t) for a,t in args))
    tb.append(')')
    L.append('\n'.join(tb))
    if group_by:
        gl=re.sub(r'by=\("[^"]*"','by=("%s"'%group_by, GROUP_LINE,1)
        gl=re.sub(r'header\.height=\d+','header.height=%d'%(92 if group_header_col else 0), gl,1)
        gl=re.sub(r'header\.suppress=\w+','header.suppress=%s'%('no' if group_header_col else 'yes'), gl,1)
        gl=re.sub(r'trailer\.height=\d+','trailer.height=%d'%trl_h, gl,1)
        gl=re.sub(r'header\.color="\d+"','header.color="6968388"', gl,1)    # banner gelap
        gl=re.sub(r'trailer\.color="\d+"','trailer.color="15461355"', gl,1) # subtotal abu muda
        L.append(gl)
    x=40; cid=1; tabseq=10; tot_x=560; tot_w=560; tot_fmt='#,##0.00'; col_pos={}
    if grid and seq:   # kolom No (urut per kategori)
        L.append(sub_text('no_t', x, 16, 110, 72, 'No', 'header', align=2, bg=HDRBG))
        L.append(compute_field('seq_no','getrow() - first(getrow() for group 1) + 1', x, 8, 110, 76, 'detail','0',2))
        x += 140
    for c in cols:
        cid_here=cid; cid+=1
        if c.get('style')=='hidden': continue
        w=c.get('w',400); fmt=c.get('fmt','[general]'); limit=c.get('len',0) or 0
        if c['t']=='dec': w=max(w, MONEY_W)   # kolom uang -> muat 1 triliun penuh
        st='edit' if grid else c.get('style','edit')
        if c['name']==summary_col: tot_x=x; tot_w=w; tot_fmt=fmt
        col_pos[c['name']]=(x,w,fmt)
        if grid:
            al = 1 if c['t'] in ('dec','int') else (2 if c['name']=='period' else 0)
            L.append(sub_text(c['name']+'_t', x, 16, w, 72, c['title'], 'header', align=2, bg=HDRBG))
            colstr=sub_col(c['name'], cid_here, x, 8, w, 76, 'detail', tabseq, 'edit', fmt, limit, align=al, color_expr=c.get('color_expr'), link=c.get('link',False), protect=True)
            if transp:
                colstr=colstr.replace('background.mode="2"','background.mode="1"',1)
            L.append(colstr)
            x += w+30
        else:
            yy=20+(cid_here-1)*STEP
            L.append(sub_text(c['name']+'_t', 40, yy+8, 480, 60, c['title']+':', 'detail'))
            L.append(sub_col(c['name'], cid_here, 560, yy, w, 76, 'detail', tabseq, st, fmt, limit,
                             c.get('child',''), c.get('disp',''), c.get('data','')))
        tabseq+=10
    if group_by and group_header_col:   # banner "KATEGORI ASSET : ..."
        ban=compute_field('g_banner', "'KATEGORI ASSET :   ' + "+group_header_col, 60, 14, 3200, 64, 'header.1','[general]',0)
        ban=bigbold(ban, -11, color=16777215)   # putih, besar, bold
        L.append(ban)
    if group_by:   # subtotal per kategori (bg abu muda), nilai per kolom amount
        L.append(bigbold(compute_field('c_sub_lbl', "'Subtotal  ' + "+(group_header_col or "''"), 60, 14, 1500, 60, 'trailer.1','[general]',0),-10))
        for nm in (summary_cols or ([summary_col] if summary_col else [])):
            xx,ww,ff=col_pos.get(nm,(tot_x,tot_w,tot_fmt))
            L.append(bigbold(compute_field('cs_'+nm,'sum('+nm+' for group 1)',xx,14,ww,68,'trailer.1',ff,1),-10))
    if summary_cols:
        L.append(bigbold(sub_text('t_grand', 40, 20, 400, 64, 'TOTAL :', 'summary', align=0),-11))
        for nm in summary_cols:
            xx,ww,ff=col_pos.get(nm,(tot_x,tot_w,tot_fmt))
            L.append(bigbold(compute_field('c_'+nm,'sum('+nm+' for all)',xx,20,ww,72,'summary',ff,1),-11))
    elif summary_col:
        L.append(bigbold(sub_text('t_grand', 40, 20, 1200, 64, 'GRAND TOTAL PENYUSUTAN :', 'summary', align=0),-12))
        L.append(bigbold(compute_field('c_grand','sum('+summary_col+' for all)',tot_x,20,tot_w,76,'summary',tot_fmt,1),-12))
    if summary_counts:
        L.append(bigbold(sub_text('t_cnt', 40, 100, 1200, 56, count_label+' :', 'summary', align=0),-10))
        cexpr = count_expr or ('count('+(summary_col or (summary_cols or ['x'])[0])+' for all)')
        L.append(bigbold(compute_field('c_cnt',cexpr,tot_x,100,tot_w,56,'summary','#,##0',1),-10))
    L.append(TAIL)
    out='\r\n'.join(L)+'\r\n'
    path=os.path.join('source_powerbuilder_11.5',folder,'DataWindow',fname+'.srd')
    open(path,'wb').write(b'\xff\xfe'+out.encode('utf-16-le'))
    print('wrote',path)

# convenience builders
def C(name,t,db,title,w=400,**kw):
    d=dict(name=name,t=t,db=db,title=title,w=w); d.update(kw); return d

# ===================== child DDDW DataWindows (no-arg) =====================
write_srd('ddw_fa_category','fa_trans',True,
  [C('category_code','s','FA_CATEGORY.category_code','Kode',360,len=10),
   C('category_name','s','FA_CATEGORY.category_name','Nama Kategori',1450,len=50)],
  "SELECT category_code,category_name FROM FA_CATEGORY WHERE site_id='101' ORDER BY category_code",'',[])
write_srd('ddw_gl_acc','fa_trans',True,
  [C('accountcode','s','gl_acc.AccountCode','Kode Akun',380,len=15),
   C('accountdes','s','gl_acc.AccountDes','Nama Akun',1450,len=50)],
  "SELECT AccountCode,AccountDes FROM gl_acc WHERE site_id='101' AND DetailYN='1' ORDER BY AccountCode",'',[])
write_srd('ddw_gl_depart','fa_trans',True,
  [C('depart_id','s','gl_depart.depart_id','Kode',360,len=10),
   C('depart_desc','s','gl_depart.depart_desc','Departemen',1450,len=50)],
  'SELECT depart_id,depart_desc FROM gl_depart ORDER BY depart_id','',[])
write_srd('ddw_fa_asset','fa_trans',True,
  [C('asset_code','s','FA_ASSET.asset_code','Kode Aset',380,len=20),
   C('asset_name','s','FA_ASSET.asset_name','Nama Aset',1450,len=100)],
  "SELECT asset_code,asset_name FROM FA_ASSET WHERE site_id='101' ORDER BY asset_code",'',[])
# kategori + baris sintetis "ALL AKTIVA" (value '*')
write_srd('ddw_fa_cat_all','fa_trans',True,
  [C('category_code','s','category_code','Kode',360,len=10),
   C('category_name','s','category_name','Kategori',1450,len=63)],
  "SELECT '*' AS category_code, 'ALL AKTIVA' AS category_name "
  "UNION ALL SELECT category_code, category_code||' | '||category_name FROM FA_CATEGORY WHERE site_id='101' "
  "ORDER BY 1",'',[])

YN='Ya~tY/Tidak~tN/'
ST_ASSET='Aktif~tA/Habis Disusut~tF/Dilepas~tD/Non-Aktif~tX/'

# ===================== fa_trans entry/list =====================
# Category entry (freeform, with dddw account lookups + ddlb yn)
CAT_E=[C('site_id','s','FA_CATEGORY.site_id','Site',200,len=4),
  C('category_code','s','FA_CATEGORY.category_code','Kode Kategori',300,len=10),
  C('category_name','s','FA_CATEGORY.category_name','Nama Kategori',900,len=50),
  C('asset_account','s','FA_CATEGORY.asset_account','Akun Aset',520,len=15,style='dddw',child='ddw_gl_acc',disp='accountdes',data='accountcode'),
  C('accum_dep_account','s','FA_CATEGORY.accum_dep_account','Akun Akumulasi',520,len=15,style='dddw',child='ddw_gl_acc',disp='accountdes',data='accountcode'),
  C('dep_expense_account','s','FA_CATEGORY.dep_expense_account','Akun Beban',520,len=15,style='dddw',child='ddw_gl_acc',disp='accountdes',data='accountcode'),
  C('useful_life_month','int','FA_CATEGORY.useful_life_month','Umur (bln)',300,style='num',fmt='#,##0'),
  C('residual_percent','dec','FA_CATEGORY.residual_percent','Residu %',260,style='num',fmt='#,##0.00'),
  C('depreciable_yn','s','FA_CATEGORY.depreciable_yn','Disusutkan',300,len=1,style='ddlb',values=YN)]
write_srd('dw_fa_category_entry','fa_trans',False,CAT_E,
  'SELECT site_id,category_code,category_name,asset_account,accum_dep_account,dep_expense_account,useful_life_month,residual_percent,depreciable_yn FROM FA_CATEGORY WHERE category_code=:arg_kode AND site_id=:arg_site',
  'FA_CATEGORY',[('arg_kode','string'),('arg_site','string')])

CAT_L=[C('site_id','s','FA_CATEGORY.site_id','Site',180,len=4),
  C('category_code','s','FA_CATEGORY.category_code','Kode',280,len=10),
  C('category_name','s','FA_CATEGORY.category_name','Nama Kategori',820,len=50),
  C('asset_account','s','FA_CATEGORY.asset_account','Akun Aset',380,len=15),
  C('accum_dep_account','s','FA_CATEGORY.accum_dep_account','Akun Akumulasi',380,len=15),
  C('dep_expense_account','s','FA_CATEGORY.dep_expense_account','Akun Beban',380,len=15),
  C('useful_life_month','int','FA_CATEGORY.useful_life_month','Umur(bln)',260,fmt='#,##0'),
  C('depreciable_yn','s','FA_CATEGORY.depreciable_yn','Disusut',200,len=1),
  C('is_find','s','is_find','',10,len=200,style='hidden',upd=False)]
write_srd('dw_fa_category_list','fa_trans',True,CAT_L,
  "SELECT site_id,category_code,category_name,asset_account,accum_dep_account,dep_expense_account,useful_life_month,depreciable_yn, lower(category_code||' '||category_name||' '||coalesce(asset_account,'')) as is_find FROM FA_CATEGORY WHERE site_id=:arg_site ORDER BY category_code",
  'FA_CATEGORY',[('arg_site','string')], zebra=True)

# Asset entry (freeform): category dddw, accounts dddw, dept dddw, date calendar, status ddlb
ASS_E=[C('site_id','s','FA_ASSET.site_id','Site',200,len=4),
  C('asset_code','s','FA_ASSET.asset_code','Kode Aset',360,len=20),
  C('asset_name','s','FA_ASSET.asset_name','Nama Aset',1100,len=100),
  C('category_code','s','FA_ASSET.category_code','Kategori',360,len=10,style='dddw',child='ddw_fa_category',disp='category_name',data='category_code'),
  C('acquisition_date','dt','FA_ASSET.acquisition_date','Tgl Perolehan',420,style='date',fmt='dd-mm-yyyy'),
  C('acquisition_cost','dec','FA_ASSET.acquisition_cost','Harga Perolehan',520,style='num',fmt='#,##0.00'),
  C('residual_value','dec','FA_ASSET.residual_value','Nilai Residu',460,style='num',fmt='#,##0.00'),
  C('useful_life_month','int','FA_ASSET.useful_life_month','Umur (bln)',300,style='num',fmt='#,##0'),
  C('accum_dep_beginning','dec','FA_ASSET.accum_dep_beginning','Akum Awal',520,style='num',fmt='#,##0.00'),
  C('book_value_beginning','dec','FA_ASSET.book_value_beginning','Nilai Buku Awal',520,style='num',fmt='#,##0.00'),
  C('remaining_life_begin','int','FA_ASSET.remaining_life_begin','Sisa Umur',300,style='num',fmt='#,##0'),
  C('department','s','FA_ASSET.department','Departemen',420,len=10,style='dddw',child='ddw_gl_depart',disp='depart_desc',data='depart_id'),
  C('status','s','FA_ASSET.status','Status',360,len=1,style='ddlb',values=ST_ASSET)]
write_srd('dw_fa_asset_entry','fa_trans',False,ASS_E,
  'SELECT site_id,asset_code,asset_name,category_code,acquisition_date,acquisition_cost,residual_value,useful_life_month,accum_dep_beginning,book_value_beginning,remaining_life_begin,department,status FROM FA_ASSET WHERE asset_code=:arg_kode AND site_id=:arg_site',
  'FA_ASSET',[('arg_kode','string'),('arg_site','string')])

ASS_L=[C('site_id','s','FA_ASSET.site_id','Site',180,len=4),
  C('asset_code','s','FA_ASSET.asset_code','Kode',340,len=20),
  C('asset_name','s','FA_ASSET.asset_name','Nama Aset',1100,len=100),
  C('category_code','s','FA_ASSET.category_code','Kategori',280,len=10),
  C('acquisition_date','dt','FA_ASSET.acquisition_date','Tgl Perolehan',400,fmt='dd-mm-yyyy'),
  C('acquisition_cost','dec','FA_ASSET.acquisition_cost','Harga Perolehan',500,fmt='#,##0.00'),
  C('accum_dep_beginning','dec','FA_ASSET.accum_dep_beginning','Akum Awal',500,fmt='#,##0.00'),
  C('book_value_beginning','dec','FA_ASSET.book_value_beginning','Nilai Buku',500,fmt='#,##0.00'),
  C('status','s','FA_ASSET.status','St',160,len=1),
  C('is_find','s','is_find','',10,len=200,style='hidden',upd=False)]
write_srd('dw_fa_asset_list','fa_trans',True,ASS_L,
  "SELECT site_id,asset_code,asset_name,category_code,acquisition_date,acquisition_cost,accum_dep_beginning,book_value_beginning,status, lower(asset_code||' '||asset_name||' '||category_code) as is_find FROM FA_ASSET WHERE site_id=:arg_site ORDER BY category_code,asset_code",
  'FA_ASSET',[('arg_site','string')], zebra=True)

# conditional formatting expressions (PB DataWindow)
GRAY  = "if(book_value=0,rgb(150,150,150),rgb(33,33,33))"
STCOL = "if(status_desc='Posted',rgb(0,128,0),if(status_desc='Open',rgb(214,130,0),if(status_desc='Void',rgb(200,0,0),rgb(33,33,33))))"
ROWHL = "16777215~tif(status_desc='Void',rgb(255,235,235),if(mod(getrow(),2)=1,rgb(245,245,245),rgb(255,255,255)))"
DEP_L=[C('site_id','s','FA_DEPRECIATION.site_id','Site',160,len=4,upd=False),
  C('asset_code','s','FA_DEPRECIATION.asset_code','Kode Aset',360,len=20,upd=False),
  C('period','dt','FA_DEPRECIATION.period','Periode',320,fmt='mmm-yyyy',upd=False),
  C('depreciation_amount','dec','FA_DEPRECIATION.depreciation_amount','Penyusutan',460,fmt='#,##0.00',upd=False,color_expr=GRAY),
  C('accum_depreciation','dec','FA_DEPRECIATION.accum_depreciation','Akumulasi',500,fmt='#,##0.00',upd=False,color_expr=GRAY),
  C('book_value','dec','FA_DEPRECIATION.book_value','Nilai Buku',500,fmt='#,##0.00',upd=False,color_expr=GRAY),
  C('journal_no','s','FA_DEPRECIATION.journal_no','No Voucher',420,len=15,upd=False,link=True),
  C('status_desc','s','status_desc','Status',300,len=12,upd=False,color_expr=STCOL),
  C('is_find','s','is_find','',10,len=200,style='hidden',upd=False)]
write_srd('dw_fa_depr_list','fa_trans',True,DEP_L,
  "SELECT site_id,asset_code,period,depreciation_amount,accum_depreciation,book_value,journal_no, "
  "CASE posting_status WHEN 'P' THEN 'Posted' WHEN 'D' THEN 'Open' WHEN 'R' THEN 'Void' ELSE posting_status END AS status_desc, "
  "lower(asset_code||' '||coalesce(journal_no,'')) as is_find "
  "FROM FA_DEPRECIATION WHERE site_id=:arg_site AND period BETWEEN :arg_d1 AND :arg_d2 ORDER BY asset_code,period",
  'FA_DEPRECIATION',[('arg_site','string'),('arg_d1','datetime'),('arg_d2','datetime')],
  summary_cols=['depreciation_amount','accum_depreciation','book_value'], row_color=ROWHL)

# generate preview (computed grid)
PREV=[C('category_code','s','FA_ASSET.category_code','Kategori',320,len=10,upd=False),
  C('period','dt','FA_DEPRECIATION.period','Periode',300,fmt='mmm-yyyy',upd=False),
  C('jml_aset','int','jml_aset','Jml Aset',260,fmt='#,##0',upd=False),
  C('total_penyusutan','dec','total_penyusutan','Total Penyusutan',560,fmt='#,##0.00',upd=False)]
write_srd('dw_fa_generate_preview','fa_trans',True,PREV,
  'SELECT a.category_code,d.period,COUNT(*) AS jml_aset,SUM(d.depreciation_amount) AS total_penyusutan FROM FA_DEPRECIATION d JOIN FA_ASSET a ON a.site_id=d.site_id AND a.asset_code=d.asset_code WHERE d.site_id=:arg_site AND d.period BETWEEN :arg_d1 AND :arg_d2 GROUP BY a.category_code,d.period ORDER BY d.period,a.category_code',
  '',[('arg_site','string'),('arg_d1','datetime'),('arg_d2','datetime')], summary_col='total_penyusutan', zebra=True)

# parameter DW (freeform): date calendar; default Jan-Jun 2026 (has data)
PARAM=[C('from_period','dt','from_period','Dari Periode',420,style='date',fmt='dd-mm-yyyy',upd=False),
  C('to_period','dt','to_period','Sampai Periode',420,style='date',fmt='dd-mm-yyyy',upd=False),
  C('site_id','s','site_id','Site',240,len=4,upd=False)]
write_srd('dw_fa_generate_param','fa_trans',False,PARAM,
  "SELECT CAST('2026-01-31' AS datetime) AS from_period, CAST('2026-06-30' AS datetime) AS to_period, '101' AS site_id",'',[])

# card param (freeform): asset_code dddw
CARDP=[C('asset_code','s','asset_code','Pilih Aktiva',520,len=20,style='dddw',child='ddw_fa_asset',disp='asset_name',data='asset_code'),
  C('site_id','s','site_id','Site',240,len=4,upd=False)]
write_srd('dw_fa_card_param','fa_trans',False,CARDP,
  "SELECT CAST('' AS varchar(20)) AS asset_code, '101' AS site_id",'',[])

# ===================== fa_reports =====================
# Daftar Aktiva per tanggal: akumulasi & nilai buku dihitung s/d :arg_d2 (as-of date)
REG=[C('category_code','s','FA_ASSET.category_code','Kategori',300,len=10,upd=False),
  C('asset_code','s','FA_ASSET.asset_code','Kode',340,len=20,upd=False),
  C('asset_name','s','FA_ASSET.asset_name','Nama Aset',1100,len=100,upd=False),
  C('acquisition_date','dt','FA_ASSET.acquisition_date','Tgl Perolehan',400,fmt='dd-mm-yyyy',upd=False),
  C('acquisition_cost','dec','FA_ASSET.acquisition_cost','Harga Perolehan',500,fmt='#,##0.00',upd=False),
  C('accum_dep','dec','accum_dep','Akum s/d Tgl',500,fmt='#,##0.00',upd=False),
  C('book_value','dec','book_value','Nilai Buku',500,fmt='#,##0.00',upd=False),
  C('status','s','FA_ASSET.status','St',160,len=1,upd=False)]
write_srd('dw_rpt_fa_register','fa_reports',True,REG,
  "SELECT a.category_code,a.asset_code,a.asset_name,a.acquisition_date,a.acquisition_cost, "
  "a.accum_dep_beginning + coalesce((SELECT SUM(d.depreciation_amount) FROM FA_DEPRECIATION d "
  "WHERE d.site_id=a.site_id AND d.asset_code=a.asset_code AND d.period <= :arg_d2),0) AS accum_dep, "
  "a.acquisition_cost - (a.accum_dep_beginning + coalesce((SELECT SUM(d.depreciation_amount) FROM FA_DEPRECIATION d "
  "WHERE d.site_id=a.site_id AND d.asset_code=a.asset_code AND d.period <= :arg_d2),0)) AS book_value, "
  "a.status FROM FA_ASSET a WHERE a.site_id=:arg_site AND a.acquisition_date <= :arg_d2 "
  "ORDER BY a.category_code,a.asset_code",
  '',[('arg_site','string'),('arg_d2','datetime')], summary_col='book_value', zebra=True)

CARD=[C('kategori','s','kategori','Kategori',10,len=63,style='hidden',upd=False),   # untuk group header
  C('asset_code','s','FA_DEPRECIATION.asset_code','Kode Aset',360,len=20,upd=False),
  C('asset_name','s','FA_ASSET.asset_name','Nama Aset',1100,len=100,upd=False),
  C('period','dt','FA_DEPRECIATION.period','Periode',320,fmt='mmm-yyyy',upd=False),
  C('depreciation_amount','dec','FA_DEPRECIATION.depreciation_amount','Penyusutan',460,fmt='#,##0.00',upd=False,color_expr=GRAY),
  C('accum_depreciation','dec','FA_DEPRECIATION.accum_depreciation','Akumulasi',500,fmt='#,##0.00',upd=False,color_expr=GRAY),
  C('book_value','dec','FA_DEPRECIATION.book_value','Nilai Buku',500,fmt='#,##0.00',upd=False,color_expr=GRAY),
  C('journal_no','s','FA_DEPRECIATION.journal_no','Voucher',420,len=15,upd=False,link=True)]
write_srd('dw_rpt_fa_card','fa_reports',True,CARD,
  "SELECT a.category_code||' | '||c.category_name AS kategori, d.asset_code,a.asset_name,d.period,"
  "d.depreciation_amount,d.accum_depreciation,d.book_value,d.journal_no "
  "FROM FA_DEPRECIATION d JOIN FA_ASSET a ON a.site_id=d.site_id AND a.asset_code=d.asset_code "
  "JOIN FA_CATEGORY c ON c.site_id=a.site_id AND c.category_code=a.category_code "
  "WHERE d.site_id=:arg_site AND (:arg_cat='*' OR a.category_code=:arg_cat OR d.asset_code=:arg_cat) "
  "ORDER BY a.category_code, d.asset_code, d.period",
  '',[('arg_site','string'),('arg_cat','string')],
  group_by='kategori', group_header_col='kategori', seq=True, summary_counts=True,
  count_label='JUMLAH ASET', count_expr="sum(if(getrow()=1 or asset_code<>asset_code[-1],1,0) for all)",
  summary_col='depreciation_amount',
  summary_cols=['depreciation_amount','accum_depreciation','book_value'], zebra=True)

REKAP=[C('kategori','s','kategori','Kategori Asset',760,len=63,upd=False),
  C('period','dt','FA_DEPRECIATION.period','Periode',300,fmt='mmm-yyyy',upd=False),
  C('dept_display','s','dept_display','Departemen',760,len=63,upd=False),
  C('total_penyusutan','dec','total_penyusutan','Total Penyusutan',560,fmt='#,##0.00',upd=False)]
write_srd('dw_rpt_fa_rekap','fa_reports',True,REKAP,
  "SELECT a.category_code || ' | ' || c.category_name AS kategori, "
  "d.period, "
  "CASE WHEN a.department IS NULL OR a.department = '' THEN '- ALL DEPARTMENT -' "
  "ELSE a.department || ' | ' || COALESCE(dp.depart_desc,'') END AS dept_display, "
  "SUM(d.depreciation_amount) AS total_penyusutan "
  "FROM FA_DEPRECIATION d "
  "JOIN FA_ASSET a ON a.site_id=d.site_id AND a.asset_code=d.asset_code "
  "JOIN FA_CATEGORY c ON c.site_id=a.site_id AND c.category_code=a.category_code "
  "LEFT JOIN gl_depart dp ON dp.depart_id=a.department "
  "WHERE d.site_id=:arg_site AND d.period BETWEEN :arg_d1 AND :arg_d2 "
  "GROUP BY a.category_code, c.category_name, d.period, a.department, dp.depart_desc "
  "ORDER BY a.category_code, a.department, d.period",   # kronologis: period datetime, BUKAN string
  '',[('arg_site','string'),('arg_d1','datetime'),('arg_d2','datetime')],
  group_by='kategori', summary_col='total_penyusutan', zebra=True,
  seq=True, group_header_col='kategori', summary_counts=True)

# ===== criteria/range DW for w_report (dw_1) -- external, insertrow in constructor =====
write_srd('d_range_fa_period','fa_trans',False,
  [C('tgl1','dt','tgl1','Dari Tanggal',420,style='date',fmt='dd-mm-yyyy',upd=False),
   C('tgl2','dt','tgl2','Sampai Tanggal',420,style='date',fmt='dd-mm-yyyy',upd=False)],
  '','',[])
write_srd('d_range_fa_asset','fa_trans',False,
  [C('asset_code','s','asset_code','Pilih Aktiva',560,len=20,style='dddw',child='ddw_fa_asset',disp='asset_name',data='asset_code')],
  '','',[])
# filter Kartu Aktiva: dropdown KATEGORI + ALL AKTIVA
write_srd('d_range_fa_cat','fa_trans',False,
  [C('category','s','category','Pilih Aktiva',680,len=10,style='dddw',child='ddw_fa_cat_all',disp='category_name',data='category_code')],
  '','',[])

# ===== Sprint 1: FA Journal viewer (drill-down voucher -> jurnal GL) =====
ALLOCCOL="if(isnull(alloc) or alloc=0,rgb(170,170,170),rgb(0,102,204))"  # baris milik aset -> biru
# Kolom dirampingkan agar muat di popup 1366x768 tanpa clip (ket dibuang -> akun+nilai+alokasi cukup)
JRN=[C('urut','int','gl_journal.urut','No',140,fmt='#,##0',upd=False),
  C('account_id','s','gl_journal.account_id','Akun',420,len=15,upd=False),
  C('account_name','s','account_name','Nama Akun',1000,len=50,upd=False),
  C('debet','dec','gl_journal.debet','Debet',520,fmt='#,##0.00',upd=False),
  C('kredit','dec','gl_journal.kredit','Kredit',520,fmt='#,##0.00',upd=False),
  C('alloc','dec','alloc','Alokasi Aset',540,fmt='#,##0.00',upd=False,color_expr=ALLOCCOL)]
write_srd('dw_rpt_fa_journal','fa_reports',True,JRN,
  "SELECT j.urut, j.account_id, a.AccountDes AS account_name, j.debet, j.kredit, "
  "(SELECT l.amount FROM FA_GL_LINK l WHERE l.site_id=j.site_id AND l.voucher=j.voucher "
  "AND l.journal_urut=j.urut AND l.asset_code=:arg_asset) AS alloc "
  "FROM gl_journal j LEFT JOIN gl_acc a ON a.AccountCode=j.account_id AND a.site_id=j.site_id "
  "WHERE j.site_id=:arg_site AND j.voucher=:arg_voucher ORDER BY j.urut",
  '',[('arg_site','string'),('arg_voucher','string'),('arg_asset','string')],
  summary_cols=['debet','kredit'], zebra=True)

# ===== Sprint 2: FA Summary (executive dashboard) =====
ACC_ASOF=("a.accum_dep_beginning + coalesce((SELECT sum(d.depreciation_amount) FROM FA_DEPRECIATION d "
          "WHERE d.site_id=a.site_id AND d.asset_code=a.asset_code AND d.period<=:arg_d2),0)")
SUMM=[C('kategori','s','kategori','Kategori Asset',760,len=63,upd=False),
  C('cat_code','s','cat_code','',10,len=10,style='hidden',upd=False),
  C('jml_asset','int','jml_asset','Jumlah Asset',300,fmt='#,##0',upd=False),
  C('perolehan','dec','perolehan','Nilai Perolehan',620,fmt='#,##0.00',upd=False),
  C('akumulasi','dec','akumulasi','Akumulasi Penyusutan',620,fmt='#,##0.00',upd=False),
  C('nilai_buku','dec','nilai_buku','Nilai Buku',620,fmt='#,##0.00',upd=False)]
write_srd('dw_rpt_fa_summary','fa_reports',True,SUMM,
  "SELECT a.category_code||' | '||c.category_name AS kategori, a.category_code AS cat_code, "
  "count(*) AS jml_asset, sum(a.acquisition_cost) AS perolehan, "
  "sum("+ACC_ASOF+") AS akumulasi, "
  "sum(a.acquisition_cost) - sum("+ACC_ASOF+") AS nilai_buku "
  "FROM FA_ASSET a JOIN FA_CATEGORY c ON c.site_id=a.site_id AND c.category_code=a.category_code "
  "WHERE a.site_id=:arg_site AND a.acquisition_date<=:arg_d2 "
  "GROUP BY a.category_code, c.category_name ORDER BY a.category_code",
  '',[('arg_site','string'),('arg_d2','datetime')],
  summary_cols=['jml_asset','perolehan','akumulasi','nilai_buku'], zebra=True)

# ===== Sprint 3: Aging Asset =====
# ERP-grade aging: derived view di atas FA engine (NBV/useful-life/remaining as-of tanggal)
AGE_YRS="datediff(day,a.acquisition_date,:arg_d2)/365"
REMAIN ="(CASE WHEN a.useful_life_month - datediff(month,a.acquisition_date,:arg_d2) < 0 THEN 0 "\
        "ELSE a.useful_life_month - datediff(month,a.acquisition_date,:arg_d2) END)"
AGEBKT =("CASE WHEN "+AGE_YRS+"<=1 THEN '1. 0-1 Tahun' "
         "WHEN "+AGE_YRS+"<=5 THEN '2. 2-5 Tahun' "
         "WHEN "+AGE_YRS+"<=10 THEN '3. 6-10 Tahun' ELSE '4. >10 Tahun' END")
GRAY2="if(nbv=0,rgb(150,150,150),rgb(33,33,33))"
AGE=[C('asset_code','s','FA_ASSET.asset_code','Kode Aset',340,len=20,upd=False,link=True),
  C('asset_name','s','FA_ASSET.asset_name','Nama Aset',760,len=100,upd=False),
  C('acquisition_date','dt','FA_ASSET.acquisition_date','Tgl Perolehan',360,fmt='dd-mm-yyyy',upd=False),
  C('useful_life','int','useful_life','Umur Ek.(Th)',240,fmt='#,##0',upd=False),
  C('age_years','int','age_years','Umur (Th)',200,fmt='#,##0',upd=False),
  C('remaining_year','int','remaining_year','Sisa (Th)',220,fmt='#,##0',upd=False),
  C('acquisition_cost','dec','FA_ASSET.acquisition_cost','Perolehan',460,fmt='#,##0.00',upd=False),
  C('accum_dep','dec','accum_dep','Akumulasi',460,fmt='#,##0.00',upd=False),
  C('nbv','dec','nbv','Nilai Buku',460,fmt='#,##0.00',upd=False,color_expr=GRAY2),
  C('bucket','s','bucket','Kelompok Umur',10,len=20,style='hidden',upd=False),
  C('cat_code','s','cat_code','',10,len=10,style='hidden',upd=False)]
write_srd('dw_rpt_fa_aging','fa_reports',True,AGE,
  "SELECT a.asset_code, a.asset_name, a.acquisition_date, "
  "a.useful_life_month/12 AS useful_life, "+AGE_YRS+" AS age_years, "+REMAIN+"/12 AS remaining_year, "
  "a.acquisition_cost, "+ACC_ASOF+" AS accum_dep, a.acquisition_cost - ("+ACC_ASOF+") AS nbv, "
  +AGEBKT+" AS bucket, a.category_code AS cat_code "
  "FROM FA_ASSET a WHERE a.site_id=:arg_site AND a.acquisition_date<=:arg_d2 "
  "ORDER BY "+AGEBKT+", a.category_code, a.asset_code",
  '',[('arg_site','string'),('arg_d2','datetime')],
  group_by='bucket', group_header_col='bucket', seq=True,
  summary_col='acquisition_cost', summary_cols=['acquisition_cost','accum_dep','nbv'],
  summary_counts=True, count_label='JUMLAH ASET',
  count_expr="sum(if(getrow()=1 or asset_code<>asset_code[-1],1,0) for all)", zebra=True)

print('DONE DataWindows')
