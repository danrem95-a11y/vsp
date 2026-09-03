$PBExportHeader$w_fa_pull_purchase.srw
forward
global type w_fa_pull_purchase from w_report
end type
type cb_tarik from commandbutton within w_fa_pull_purchase
end type
type cb_generate from commandbutton within w_fa_pull_purchase
end type
type cb_proses from commandbutton within w_fa_pull_purchase
end type
end forward

global type w_fa_pull_purchase from w_report
string title = "Tarik Aktiva dari Pembelian"
cb_tarik cb_tarik
cb_generate cb_generate
cb_proses cb_proses
end type
global w_fa_pull_purchase w_fa_pull_purchase

event open;call super::open;//
end event

on w_fa_pull_purchase.create
int iCurrent
call super::create
this.cb_tarik=create cb_tarik
this.cb_generate=create cb_generate
this.cb_proses=create cb_proses
iCurrent=UpperBound(this.Control)
this.Control[iCurrent+1]=this.cb_tarik
this.Control[iCurrent+2]=this.cb_generate
this.Control[iCurrent+3]=this.cb_proses
end on

on w_fa_pull_purchase.destroy
call super::destroy
if IsValid(MenuID) then destroy(MenuID)
destroy(this.cb_tarik)
destroy(this.cb_generate)
destroy(this.cb_proses)
end on

event ue_xls;gurningsoft_xls(dw_2)
end event

type dw_1 from w_report`dw_1 within w_fa_pull_purchase
integer height = 280
string dataobject = "d_range_fa_pull"
end type

event dw_1::constructor;call super::constructor;this.insertrow(0)
this.setitem(1,'tgl1', f_bom(gdt_today))
this.setitem(1,'tgl2', f_eom(gdt_today))
end event

type dw_2 from w_report`dw_2 within w_fa_pull_purchase
string dataobject = "dw_fa_purchase_preview"
end type

type cb_tarik from commandbutton within w_fa_pull_purchase
integer x = 1198
integer y = 40
integer width = 750
integer height = 112
integer taborder = 60
boolean bringtotop = true
integer textsize = -9
integer weight = 700
fontcharset fontcharset = ansi!
fontpitch fontpitch = variable!
fontfamily fontfamily = swiss!
string facename = "Tahoma"
string text = "&Tarik dari Pembelian"
boolean default = true
end type

event cb_tarik::clicked;// Tampilkan preview: GL debit ke akun aktiva yang belum jadi aset (periode terpilih).
datetime ldt_from, ldt_to
dw_1.accepttext()
ldt_from = dw_1.object.tgl1[1]
ldt_to   = dw_1.object.tgl2[1]
if isnull(ldt_from) or isnull(ldt_to) then
	messagebox('', 'Isi Dari/ Sampai Tanggal..!')
	return
end if
setpointer(hourglass!)
dw_2.dataobject = "dw_fa_purchase_preview"
dw_2.settransobject(sqlca)
dw_2.retrieve(gs_site, date(ldt_from), date(ldt_to))
if dw_2.rowcount() <= 0 then
	messagebox('Info','Tidak ada pembelian aktiva yang belum ditarik pada periode ini.')
end if
end event

type cb_generate from commandbutton within w_fa_pull_purchase
integer x = 1970
integer y = 40
integer width = 700
integer height = 112
integer taborder = 70
boolean bringtotop = true
integer textsize = -9
integer weight = 700
fontcharset fontcharset = ansi!
fontpitch fontpitch = variable!
fontfamily fontfamily = swiss!
string facename = "Tahoma"
string text = "&Generate Aktiva"
end type

event cb_generate::clicked;// Buat FA_ASSET dari baris tercentang (pilih='Y') via sp_fa_pull_one.
long    ll, ll_cnt, li_p
string  ls_sql, ls_vch, ls_cat, ls_name
integer li_urut, li_ul
dw_2.accepttext()
if dw_2.dataobject <> "dw_fa_purchase_preview" then
	messagebox('', 'Klik "Tarik dari Pembelian" dulu.')
	return
end if
if dw_2.rowcount() <= 0 then return
if messagebox('Konfirmasi','Buat aktiva dari baris tercentang (Y)?',question!,yesno!) = 2 then return
setpointer(hourglass!)
ll_cnt = 0
for ll = 1 to dw_2.rowcount()
	if upper(dw_2.object.pilih[ll]) = 'Y' then
		ls_vch  = trim(dw_2.object.voucher[ll])
		li_urut = dw_2.object.urut[ll]
		ls_cat  = trim(dw_2.object.golongan[ll])
		ls_name = dw_2.object.nama_aset[ll]
		li_ul   = dw_2.object.umur[ll]
		if isnull(ls_name) then ls_name = ''
		// escape petik satu (' -> '') supaya SQL tidak error
		li_p = pos(ls_name, "'")
		do while li_p > 0
			ls_name = replace(ls_name, li_p, 1, "''")
			li_p = pos(ls_name, "'", li_p + 2)
		loop
		ls_sql = "call sp_fa_pull_one('" + gs_site + "','" + ls_vch + "'," + string(li_urut) + &
		         ",'" + ls_cat + "','" + ls_name + "'," + string(li_ul) + ")"
		EXECUTE IMMEDIATE :ls_sql USING SQLCA;
		if sqlca.sqlcode <> 0 then
			messagebox('Error Generate', ls_vch + ' : ' + sqlca.sqlerrtext)
			rollback using sqlca;
			return
		end if
		ll_cnt = ll_cnt + 1
	end if
next
commit using sqlca;
messagebox('Info', string(ll_cnt) + ' aktiva dibuat. Klik "Hitung Penyusutan" untuk susutkan periode ybs.')
dw_2.retrieve(gs_site, date(dw_1.object.tgl1[1]), date(dw_1.object.tgl2[1]))
end event

type cb_proses from commandbutton within w_fa_pull_purchase
integer x = 2690
integer y = 40
integer width = 700
integer height = 112
integer taborder = 80
boolean bringtotop = true
integer textsize = -9
integer weight = 700
fontcharset fontcharset = ansi!
fontpitch fontpitch = variable!
fontfamily fontfamily = swiss!
string facename = "Tahoma"
string text = "&Hitung Penyusutan"
end type

event cb_proses::clicked;// (Re)generate + posting penyusutan per bulan pada rentang terpilih (idempotent).
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
if messagebox('Konfirmasi','Hitung & posting penyusutan periode terpilih?',question!,yesno!) = 2 then return
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
messagebox('Info', 'Hitung & posting penyusutan selesai.')
end event
