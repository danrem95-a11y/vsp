# -*- coding: utf-8 -*-
# Generate PB 11.5 Window (.srw) for FA module, cloning w_master ancestor pattern.
# Single ue_new / ue_save per window (bodies parameterized -> no duplicate events).
import os
def write_srw(name, folder, body):
    out=body.replace('\n','\r\n')
    if not out.endswith('\r\n'): out+='\r\n'
    path=os.path.join('source_powerbuilder_11.5',folder,'Window',name+'.srw')
    open(path,'wb').write(b'\xff\xfe'+out.encode('utf-16-le'))
    print('wrote',path)

DEF_UENEW="tab_1.selectedtab = 1\nidw_up1.triggerevent('ue_insert')\nidw_up1.setfocus()"
DEF_UESAVE=("choose case tab_1.selectedtab\n\tcase 1\n\t\tidw_up1.triggerevent('ue_save')"
            "\n\tcase 2\n\t\t//\nend choose")
PARAM_UENEW="tab_1.selectedtab = 1\nidw_up1.reset()\nidw_up1.retrieve()\nidw_up1.setfocus()"

def window(name,title,entry_text,entry_do,list_text,list_do,
           uenew=DEF_UENEW,uesave=DEF_UESAVE,dw1_events='',dw2_edit='//',
           dw2_retrieve="this.retrieve(gs_site)"):
    return f'''$PBExportHeader${name}.srw
forward
global type {name} from w_master
end type
end forward

global type {name} from w_master
string title = "{title}"
end type
global {name} {name}

on {name}.create
call super::create
end on

on {name}.destroy
call super::destroy
if IsValid(MenuID) then destroy(MenuID)
end on

event ue_new;call super::ue_new;{uenew}
end event

event ue_edit;call super::ue_edit;choose case tab_1.selectedtab
	case 1
		//
	case 2
		idw_up2.triggerevent('ue_edit')
end choose
end event

event ue_retrieve;call super::ue_retrieve;tab_1.selectedtab = 2
idw_up2.triggerevent('ue_retrieve')
end event

event ue_save;call super::ue_save;{uesave}
end event

type dw_update from w_master`dw_update within {name}
end type

type dw_search from w_master`dw_search within {name}
end type

type st_split from w_master`st_split within {name}
end type

type dw_anim from w_master`dw_anim within {name}
end type

type dw_statusbar from w_master`dw_statusbar within {name}
end type

type dw_leftmenu from w_master`dw_leftmenu within {name}
end type

type tab_1 from w_master`tab_1 within {name}
end type

type tabpage_1 from w_master`tabpage_1 within tab_1
string text = "{entry_text}"
end type

type dw_1 from w_master`dw_1 within tabpage_1
string dataobject = "{entry_do}"
end type

event dw_1::ue_insert;call super::ue_insert;this.reset()
this.insertrow(0)
this.setfocus()
end event
{dw1_events}
type tabpage_2 from w_master`tabpage_2 within tab_1
string text = "{list_text}"
end type

type dw_arg from w_master`dw_arg within tabpage_2
integer height = 288
end type

type dw_2 from w_master`dw_2 within tabpage_2
integer y = 288
string dataobject = "{list_do}"
end type

event dw_2::doubleclicked;call super::doubleclicked;of_edit()
end event

event dw_2::ue_edit;call super::ue_edit;{dw2_edit}
end event

event dw_2::ue_retrieve;call super::ue_retrieve;{dw2_retrieve}
end event

type st_split2 from w_master`st_split2 within {name}
end type
'''

DRILL='''
event dw_2::doubleclicked;string ls_voucher, ls_param
window lw_jrn
if row <= 0 then return
ls_voucher = this.object.journal_no[row]
if isnull(ls_voucher) or trim(ls_voucher) = '' then return
ls_param = ls_voucher + "|" + this.object.asset_code[row]
openwithparm(lw_jrn, ls_param, "w_fa_journal_popup")
end event
'''
# drill dari Summary -> Kartu Aktiva (per kategori)
DRILL_CAT='''
event dw_2::doubleclicked;string ls_cat
window lw_card
if row <= 0 then return
ls_cat = this.object.cat_code[row]
if isnull(ls_cat) or trim(ls_cat) = '' then return
openwithparm(lw_card, ls_cat, "w_rpt_fa_card")
end event
'''
# drill dari Aging/Register -> Kartu Aktiva (per ASET spesifik)
DRILL_ASSET='''
event dw_2::doubleclicked;string ls_asset
window lw_card
if row <= 0 then return
ls_asset = this.object.asset_code[row]
if isnull(ls_asset) or trim(ls_asset) = '' then return
openwithparm(lw_card, ls_asset, "w_rpt_fa_card")
end event
'''
def viewer_window(name,title,report_do,open_body):
    return f'''$PBExportHeader${name}.srw
forward
global type {name} from w_report
end type
end forward

global type {name} from w_report
string title = "{title}"
end type
global {name} {name}

event open;call super::open;{open_body}
end event

on {name}.create
call super::create
end on

on {name}.destroy
call super::destroy
if IsValid(MenuID) then destroy(MenuID)
end on

event ue_print;dw_2.accepttext()
if dw_2.rowcount() <= 0 then
	messagebox('', 'Tidak ada data..!')
	return
end if
Openwithparm(w_prompt_print, dw_2)
if Message.doubleparm = -1 then return
dw_2.print()
end event

event ue_xls;gurningsoft_xls(dw_2)
end event

type dw_2 from w_report`dw_2 within {name}
string dataobject = "{report_do}"
end type
'''
def report_window(name,title,criteria_do,report_do,constructor_body,click_body,btn_label='&Tampilkan',dw2_events='',open_body='//'):
    return f'''$PBExportHeader${name}.srw
forward
global type {name} from w_report
end type
type cb_tampil from commandbutton within {name}
end type
end forward

global type {name} from w_report
cb_tampil cb_tampil
end type
global {name} {name}

event open;call super::open;{open_body}
end event

on {name}.create
int iCurrent
call super::create
this.cb_tampil=create cb_tampil
iCurrent=UpperBound(this.Control)
this.Control[iCurrent+1]=this.cb_tampil
end on

on {name}.destroy
call super::destroy
if IsValid(MenuID) then destroy(MenuID)
destroy(this.cb_tampil)
end on

event ue_print;dw_2.accepttext()
if dw_2.rowcount() <= 0 then
	messagebox('', 'Tidak ada data..!')
	return
end if
Openwithparm(w_prompt_print, dw_2)
if Message.doubleparm = -1 then return
dw_2.print()
end event

event ue_xls;gurningsoft_xls(dw_2)
end event

type dw_1 from w_report`dw_1 within {name}
integer height = 280
string dataobject = "{criteria_do}"
end type

event dw_1::constructor;call super::constructor;this.insertrow(0)
{constructor_body}
end event

type dw_2 from w_report`dw_2 within {name}
string dataobject = "{report_do}"
end type

event dw_2::ue_retrieve;call super::ue_retrieve;cb_tampil.triggerevent(clicked!)
end event
{dw2_events}
type cb_tampil from commandbutton within {name}
integer x = 1198
integer y = 40
integer width = 640
integer height = 112
integer taborder = 60
boolean bringtotop = true
integer textsize = -9
integer weight = 700
fontcharset fontcharset = ansi!
fontpitch fontpitch = variable!
fontfamily fontfamily = swiss!
string facename = "Tahoma"
string text = "{btn_label}"
boolean default = true
end type

event cb_tampil::clicked;{click_body}
end event
'''

# ===== w_fa_category =====
cat_dw1='''
event dw_1::ue_save;call super::ue_save;this.accepttext()
if getrow() <= 0 then return
string ls_kode, ls_nama, ls_acc
ls_kode = this.object.category_code[1]
ls_nama = this.object.category_name[1]
if isnull(ls_kode) or ls_kode = '' or isnull(ls_nama) or ls_nama = '' then
	messagebox('', 'Kode dan Nama kategori harus diisi..!')
	return
end if
ls_acc = this.object.asset_account[1]
if not isnull(ls_acc) and ls_acc <> '' then
	long ll_cek
	select count(*) into :ll_cek from gl_acc where accountcode = :ls_acc and site_id = :gs_site using sqlca;
	if ll_cek = 0 then
		messagebox('', 'Akun Aset ' + ls_acc + ' tidak ada di Chart of Account..!')
		return
	end if
end if
if isnull(this.object.site_id[1]) or this.object.site_id[1] = '' then this.object.site_id[1] = gs_site
this.update()
commit using sqlca;
triggerevent('ue_insert')
idw_up2.triggerevent('ue_retrieve')
end event
'''
write_srw('w_fa_category','fa_trans', window(
  'w_fa_category','Master Kategori Aktiva Tetap','Entry Kategori','dw_fa_category_entry',
  'List Kategori','dw_fa_category_list', dw1_events=cat_dw1,
  dw2_edit='''string ls_kode
if getrow() <= 0 then return
ls_kode = this.object.category_code[getrow()]
idw_up1.retrieve(ls_kode, gs_site)
tab_1.selectedtab = 1
idw_up1.setfocus()''',
  dw2_retrieve='this.retrieve(gs_site)'))

# ===== w_fa_master (asset) =====
ass_dw1='''
event dw_1::itemchanged;call super::itemchanged;string ls_cat, ls_aacc, ls_kacc, ls_eacc
long ll_life
choose case dwo.name
	case 'category_code'
		this.accepttext()
		ls_cat = data
		select asset_account, accum_dep_account, dep_expense_account, useful_life_month
		  into :ls_aacc, :ls_kacc, :ls_eacc, :ll_life
		  from FA_CATEGORY where category_code = :ls_cat and site_id = :gs_site using sqlca;
		if sqlca.sqlcode = 0 then
			this.setitem(1,'useful_life_month', ll_life)
		end if
end choose
end event

event dw_1::ue_save;call super::ue_save;this.accepttext()
if getrow() <= 0 then return
string ls_kode, ls_nama, ls_cat
ls_kode = this.object.asset_code[1]
ls_nama = this.object.asset_name[1]
ls_cat  = this.object.category_code[1]
if isnull(ls_kode) or ls_kode='' or isnull(ls_nama) or ls_nama='' or isnull(ls_cat) or ls_cat='' then
	messagebox('', 'Kode Aset, Nama, dan Kategori harus diisi..!')
	return
end if
if isnull(this.object.site_id[1]) or this.object.site_id[1] = '' then this.object.site_id[1] = gs_site
this.object.book_value_beginning[1] = this.object.acquisition_cost[1] - this.object.accum_dep_beginning[1]
this.update()
commit using sqlca;
triggerevent('ue_insert')
idw_up2.triggerevent('ue_retrieve')
end event
'''
write_srw('w_fa_master','fa_trans', window(
  'w_fa_master','Master Aktiva Tetap','Entry Aktiva','dw_fa_asset_entry',
  'List Aktiva','dw_fa_asset_list', dw1_events=ass_dw1,
  dw2_edit='''string ls_kode
if getrow() <= 0 then return
ls_kode = this.object.asset_code[getrow()]
idw_up1.retrieve(ls_kode, gs_site)
tab_1.selectedtab = 1
idw_up1.setfocus()''',
  dw2_retrieve='this.retrieve(gs_site)'))

# ===== w_fa_generate (w_report + tombol Proses = generate+post+show) =====
gen_click='''// Proses = (re)generate + post penyusutan per bulan via stored procedure, lalu tampilkan.
// Pakai EXECUTE IMMEDIATE (bukan DECLARE/EXECUTE+CLOSE) supaya tidak ada error
// "procedure has no result set"; sp_fa_regenerate_period idempotent (boleh utk periode yg sudah diposting).
datetime ldt_from, ldt_to
long ly, lm, ly2, lm2, ln_y, ln_m
date ld_me, ld_first_next
string ls_sql, ls_me
dw_1.accepttext()
ldt_from = dw_1.object.tgl1[1]
ldt_to   = dw_1.object.tgl2[1]
if isnull(ldt_from) or isnull(ldt_to) then
	messagebox('', 'Isi Dari/ Sampai Tanggal..!')
	return
end if
if messagebox('Konfirmasi','Generate & posting penyusutan periode terpilih?',question!,yesno!) = 2 then return
setpointer(hourglass!)
ly = year(date(ldt_from))
lm = month(date(ldt_from))
ly2 = year(date(ldt_to))
lm2 = month(date(ldt_to))
do while (ly * 12 + lm) <= (ly2 * 12 + lm2)
	if lm = 12 then
		ln_y = ly + 1
		ln_m = 1
	else
		ln_y = ly
		ln_m = lm + 1
	end if
	ld_first_next = date(ln_y, ln_m, 1)
	ld_me = relativedate(ld_first_next, -1)
	ls_me = string(ld_me, 'yyyy-mm-dd')
	ls_sql = "call sp_fa_regenerate_period('" + ls_me + "','" + gs_site + "')"
	EXECUTE IMMEDIATE :ls_sql USING SQLCA;
	if sqlca.sqlcode <> 0 then
		messagebox('Error Generate', 'Periode ' + ls_me + ' : ' + sqlca.sqlerrtext)
		rollback using sqlca;
		return
	end if
	// bangun ulang subledger link (FA_GL_LINK) untuk periode ini
	ls_sql = "call sp_fa_build_gl_link('" + ls_me + "','" + gs_site + "')"
	EXECUTE IMMEDIATE :ls_sql USING SQLCA;
	if sqlca.sqlcode <> 0 then
		messagebox('Error Link', 'Periode ' + ls_me + ' : ' + sqlca.sqlerrtext)
		rollback using sqlca;
		return
	end if
	commit using sqlca;
	if lm = 12 then
		ly = ly + 1
		lm = 1
	else
		lm = lm + 1
	end if
loop
dw_2.SetTransObject(sqlca)
dw_2.retrieve(gs_site, ldt_from, ldt_to)
messagebox('Info', 'Generate & posting penyusutan selesai. Baris: ' + string(dw_2.rowcount()))'''
write_srw('w_fa_generate','fa_trans', report_window(
  'w_fa_generate','Generate Penyusutan Aktiva Tetap','d_range_fa_period','dw_fa_depr_list',
  "this.setitem(1,'tgl1', f_bom(gdt_today))\nthis.setitem(1,'tgl2', f_eom(gdt_today))",
  gen_click, btn_label='&Proses', dw2_events=DRILL))

# ===== Daftar Aktiva Tetap =====
write_srw('w_rpt_fa_register','fa_reports', report_window(
  'w_rpt_fa_register','Daftar Aktiva Tetap','d_range_fa_period','dw_rpt_fa_register',
  "this.setitem(1,'tgl1', f_bom(gdt_today))\nthis.setitem(1,'tgl2', f_eom(gdt_today))",
  '''datetime ldt2
dw_1.accepttext()
ldt2 = dw_1.object.tgl2[1]
dw_2.SetTransObject(sqlca)
dw_2.retrieve(gs_site, ldt2)''', dw2_events=DRILL_ASSET))

# ===== Rekap Penyusutan =====
write_srw('w_rpt_fa_rekap','fa_reports', report_window(
  'w_rpt_fa_rekap','Rekap Penyusutan Aktiva Tetap','d_range_fa_period','dw_rpt_fa_rekap',
  "this.setitem(1,'tgl1', f_bom(gdt_today))\nthis.setitem(1,'tgl2', f_eom(gdt_today))",
  '''datetime ldt1, ldt2
dw_1.accepttext()
ldt1 = dw_1.object.tgl1[1]
ldt2 = dw_1.object.tgl2[1]
dw_2.SetTransObject(sqlca)
dw_2.retrieve(gs_site, ldt1, ldt2)'''))

# ===== Kartu Aktiva =====
write_srw('w_rpt_fa_card','fa_reports', report_window(
  'w_rpt_fa_card','Kartu Aktiva Tetap','d_range_fa_cat','dw_rpt_fa_card',
  "this.setitem(1,'category','*')",
  '''string ls_cat
dw_1.accepttext()
ls_cat = dw_1.object.category[1]
if isnull(ls_cat) or ls_cat = '' then ls_cat = '*'
dw_2.SetTransObject(sqlca)
dw_2.retrieve(gs_site, ls_cat)''', dw2_events=DRILL,
  open_body='''string ls_p
ls_p = Message.StringParm
if isnull(ls_p) or trim(ls_p) = '' then return
dw_2.SetTransObject(sqlca)
dw_2.retrieve(gs_site, ls_p)'''))

# ===== Sprint 1: FA Journal popup (Response! modal, auto-filter by voucher) =====
def _st(name,x,y,w,text):
    return '''type %s from statictext within w_fa_journal_popup
integer x = %d
integer y = %d
integer width = %d
integer height = 72
integer textsize = -10
integer weight = 700
fontcharset fontcharset = ansi!
fontpitch fontpitch = variable!
fontfamily fontfamily = swiss!
string facename = "Tahoma"
long textcolor = 33554432
long backcolor = 16777215
string text = "%s"
alignment alignment = left!
boolean focusrectangle = false
end type
'''%(name,x,y,w,text)

POPUP=r'''$PBExportHeader$w_fa_journal_popup.srw
forward
global type w_fa_journal_popup from window
end type
type st_voucher from statictext within w_fa_journal_popup
end type
type st_tgl from statictext within w_fa_journal_popup
end type
type st_status from statictext within w_fa_journal_popup
end type
type st_asset from statictext within w_fa_journal_popup
end type
type dw_journal from datawindow within w_fa_journal_popup
end type
type cb_close from commandbutton within w_fa_journal_popup
end type
end forward

global type w_fa_journal_popup from window
integer width = 4360
integer height = 2200
boolean titlebar = true
string title = "Detail Jurnal GL"
windowtype windowtype = response!
long backcolor = 16777215
boolean center = true
boolean resizable = true
boolean maxbox = false
boolean minbox = false
st_voucher st_voucher
st_tgl st_tgl
st_status st_status
st_asset st_asset
dw_journal dw_journal
cb_close cb_close
end type
global w_fa_journal_popup w_fa_journal_popup

event resize;long ll_w, ll_h, ll_half
ll_w = this.WorkSpaceWidth()
ll_h = this.WorkSpaceHeight()
ll_half = (ll_w - 110) / 2
st_voucher.width = ll_half
st_tgl.x = 55 + ll_half + 20
st_tgl.width = ll_half - 20
st_status.width = ll_w - 110
st_asset.width = ll_w - 110
dw_journal.width = ll_w - 110
dw_journal.height = ll_h - dw_journal.y - 220
cb_close.x = (ll_w - cb_close.width) / 2
cb_close.y = ll_h - 170
end event

event open;string ls_param, ls_v, ls_asset, ls_st, ls_map, ls_aname
long ll_pos, ll_r
decimal ldec_alloc, ldec_x
datetime ldt
ls_param = Message.StringParm
if isnull(ls_param) then ls_param = ''
ll_pos = pos(ls_param, '|')
if ll_pos > 0 then
	ls_v = left(ls_param, ll_pos - 1)
	ls_asset = mid(ls_param, ll_pos + 1)
else
	ls_v = ls_param
	ls_asset = ''
end if
SELECT tgl, posting INTO :ldt, :ls_st FROM gl_journal
 WHERE site_id = :gs_site AND voucher = :ls_v AND urut = 1 USING SQLCA;
choose case ls_st
	case 'P'
		ls_map = 'Posted'
	case 'N'
		ls_map = 'Open'
	case 'R'
		ls_map = 'Void'
	case else
		ls_map = ls_st
end choose
ls_aname = ''
ldec_alloc = 0
if ls_asset <> '' then
	SELECT asset_name INTO :ls_aname FROM FA_ASSET
	 WHERE site_id = :gs_site AND asset_code = :ls_asset USING SQLCA;
	SELECT SUM(amount) INTO :ldec_alloc FROM FA_GL_LINK
	 WHERE site_id = :gs_site AND voucher = :ls_v AND asset_code = :ls_asset AND dk = 'K' USING SQLCA;
	if isnull(ldec_alloc) then ldec_alloc = 0
end if
st_voucher.text = "Voucher  : " + ls_v
st_tgl.text     = "Tanggal  : " + string(ldt, 'dd-mmm-yyyy')
st_status.text  = "Status   : " + ls_map
st_asset.text   = "Aset     : " + ls_asset + "  " + ls_aname + "      |      Alokasi penyusutan: " + string(ldec_alloc, '#,##0.00')
this.title = "Detail Jurnal GL - " + ls_v
dw_journal.settransobject(sqlca)
dw_journal.retrieve(gs_site, ls_v, ls_asset)
// highlight baris milik aset ini secara deterministik (via FA_GL_LINK -> kolom alloc)
for ll_r = 1 to dw_journal.rowcount()
	ldec_x = dw_journal.object.alloc[ll_r]
	if not isnull(ldec_x) then
		if ldec_x > 0 then dw_journal.selectrow(ll_r, true)
	end if
next
end event

on w_fa_journal_popup.create
this.st_voucher=create st_voucher
this.st_tgl=create st_tgl
this.st_status=create st_status
this.st_asset=create st_asset
this.dw_journal=create dw_journal
this.cb_close=create cb_close
this.Control[]={this.st_voucher,this.st_tgl,this.st_status,this.st_asset,this.dw_journal,this.cb_close}
end on

on w_fa_journal_popup.destroy
destroy(this.st_voucher)
destroy(this.st_tgl)
destroy(this.st_status)
destroy(this.st_asset)
destroy(this.dw_journal)
destroy(this.cb_close)
end on

''' + _st('st_voucher',55,40,2070,'Voucher  :') + _st('st_tgl',2145,40,2050,'Tanggal  :') \
    + _st('st_status',55,120,4140,'Status   :') + _st('st_asset',55,200,4140,'Aset     :') + r'''
type dw_journal from datawindow within w_fa_journal_popup
integer x = 55
integer y = 290
integer width = 4140
integer height = 1700
integer taborder = 10
boolean bringtotop = true
string title = "none"
string dataobject = "dw_rpt_fa_journal"
boolean livescroll = true
borderstyle borderstyle = stylelowered!
end type

type cb_close from commandbutton within w_fa_journal_popup
integer x = 1825
integer y = 2010
integer width = 600
integer height = 116
integer taborder = 20
integer textsize = -10
integer weight = 700
fontcharset fontcharset = ansi!
fontpitch fontpitch = variable!
fontfamily fontfamily = swiss!
string facename = "Tahoma"
string text = "&Tutup"
boolean default = true
boolean cancel = true
end type

event cb_close::clicked;close(parent)
end event
'''
write_srw('w_fa_journal_popup','fa_reports', POPUP)

# ===== Sprint 2: FA Summary dashboard (drill -> Kartu Aktiva per kategori) =====
write_srw('w_rpt_fa_summary','fa_reports', report_window(
  'w_rpt_fa_summary','Ringkasan Aktiva Tetap (FA Summary)','d_range_fa_period','dw_rpt_fa_summary',
  "this.setitem(1,'tgl1', f_bom(gdt_today))\nthis.setitem(1,'tgl2', f_eom(gdt_today))",
  '''datetime ldt2
dw_1.accepttext()
ldt2 = dw_1.object.tgl2[1]
dw_2.SetTransObject(sqlca)
dw_2.retrieve(gs_site, ldt2)''', dw2_events=DRILL_CAT))

# ===== Sprint 3: Aging Asset (ERP-grade: NBV/useful-life + drill ke FA Card) =====
write_srw('w_rpt_fa_aging','fa_reports', report_window(
  'w_rpt_fa_aging','Umur Aktiva Tetap (Aging)','d_range_fa_period','dw_rpt_fa_aging',
  "this.setitem(1,'tgl1', f_bom(gdt_today))\nthis.setitem(1,'tgl2', f_eom(gdt_today))",
  '''datetime ldt2
dw_1.accepttext()
ldt2 = dw_1.object.tgl2[1]
dw_2.SetTransObject(sqlca)
dw_2.retrieve(gs_site, ldt2)''', dw2_events=DRILL_ASSET))

print('DONE Windows')
