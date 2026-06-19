$PBExportHeader$w_pbl_export_manager.srw
forward
global type w_pbl_export_manager from window
end type
type sle_pbl from singlelineedit within w_pbl_export_manager
end type
type cb_browse_pbl from commandbutton within w_pbl_export_manager
end type
type sle_export from singlelineedit within w_pbl_export_manager
end type
type cb_browse_export from commandbutton within w_pbl_export_manager
end type
type st_pbl from statictext within w_pbl_export_manager
end type
type st_export from statictext within w_pbl_export_manager
end type
type cb_load from commandbutton within w_pbl_export_manager
end type
type cb_checkall from commandbutton within w_pbl_export_manager
end type
type cb_uncheckall from commandbutton within w_pbl_export_manager
end type
type cb_refresh from commandbutton within w_pbl_export_manager
end type
type st_filter from statictext within w_pbl_export_manager
end type
type ddlb_filter from dropdownlistbox within w_pbl_export_manager
end type
type cb_export_sel from commandbutton within w_pbl_export_manager
end type
type cb_export_all from commandbutton within w_pbl_export_manager
end type
type dw_list from datawindow within w_pbl_export_manager
end type
type st_progress from statictext within w_pbl_export_manager
end type
type hpb_progress from hprogressbar within w_pbl_export_manager
end type
type st_exported from statictext within w_pbl_export_manager
end type
type st_success from statictext within w_pbl_export_manager
end type
type st_failed from statictext within w_pbl_export_manager
end type
end forward

global type w_pbl_export_manager from window
integer width = 3470
integer height = 2300
boolean titlebar = true
string title = "PBL Source Export Manager"
boolean controlmenu = true
boolean minbox = true
boolean maxbox = true
boolean resizable = true
long backcolor = 67108864
string icon = "AppIcon!"
boolean center = true
sle_pbl sle_pbl
cb_browse_pbl cb_browse_pbl
sle_export sle_export
cb_browse_export cb_browse_export
st_pbl st_pbl
st_export st_export
cb_load cb_load
cb_checkall cb_checkall
cb_uncheckall cb_uncheckall
cb_refresh cb_refresh
st_filter st_filter
ddlb_filter ddlb_filter
cb_export_sel cb_export_sel
cb_export_all cb_export_all
dw_list dw_list
st_progress st_progress
hpb_progress hpb_progress
st_exported st_exported
st_success st_success
st_failed st_failed
end type
global w_pbl_export_manager w_pbl_export_manager

type variables
string is_pbl
string is_export
end variables

forward prototypes
public function string wf_ext (string as_type)
public function integer wf_ensuredir (string as_dir)
public function string wf_sanitize (string as_name)
public function integer wf_log (string as_file, string as_msg)
public subroutine wf_setall (string as_value)
public function long wf_load ()
public function long wf_export (boolean ab_onlychecked)
end prototypes

public function string wf_ext (string as_type);// Map object type name -> PowerBuilder source extension
string ls
CHOOSE CASE as_type
	CASE "Application" ; ls = ".sra"
	CASE "Window"      ; ls = ".srw"
	CASE "DataWindow"  ; ls = ".srd"
	CASE "Function"    ; ls = ".srf"
	CASE "Menu"        ; ls = ".srm"
	CASE "Structure"   ; ls = ".srs"
	CASE "Query"       ; ls = ".srq"
	CASE "UserObject"  ; ls = ".sru"
	CASE "Pipeline"    ; ls = ".srp"
	CASE "Project"     ; ls = ".srj"
	CASE ELSE          ; ls = ".txt"
END CHOOSE
RETURN ls
end function

public function integer wf_ensuredir (string as_dir);// Ensure a directory exists (create if missing). Returns 1 ok, -1 fail.
IF DirectoryExists(as_dir) THEN RETURN 1
IF CreateDirectory(as_dir) = 1 THEN RETURN 1
RETURN -1
end function

public function string wf_sanitize (string as_name);// Replace characters illegal in Windows filenames with underscore
string ls_bad, lc, ls
integer i, ll
ls = as_name
ls_bad = "\/:*?~"<>|"
ll = Len(ls)
FOR i = 1 TO ll
	lc = Mid(ls, i, 1)
	IF Pos(ls_bad, lc) > 0 THEN ls = Replace(ls, i, 1, "_")
NEXT
RETURN ls
end function

public function integer wf_log (string as_file, string as_msg);// Append one timestamped line to a log file (ANSI line mode).
integer li
li = FileOpen(as_file, LineMode!, Write!, LockWrite!, Append!)
IF li < 1 THEN RETURN -1
FileWrite(li, "[" + String(Now(), "yyyy-mm-dd hh:mm:ss") + "] " + as_msg)
FileClose(li)
RETURN 1
end function

public subroutine wf_setall (string as_value);// Set the "Sel" flag ("Y" / "") on every (filtered) row
long i, ll
ll = dw_list.RowCount()
dw_list.SetRedraw(FALSE)
FOR i = 1 TO ll
	dw_list.SetItem(i, "c_check", as_value)
NEXT
dw_list.SetRedraw(TRUE)
end subroutine

public function long wf_load ();// Scan the PBL for every object type and fill the grid.
string ls_dir, ls_line, ls_name, ls_rest, ls_date, ls_type, ls_ext
long ll_start, ll_nl, ll_t, ll_row, ll_total
integer li

is_pbl = Trim(sle_pbl.text)
IF is_pbl = "" OR NOT FileExists(is_pbl) THEN
	MessageBox("Error", "PBL path tidak valid / file tidak ditemukan.")
	RETURN -1
END IF

SetPointer(HourGlass!)
dw_list.SetRedraw(FALSE)
dw_list.Reset()
ll_total = 0

FOR li = 1 TO 10
	CHOOSE CASE li
		CASE 1  ; ls_type = "Application" ; ls_dir = LibraryDirectory(is_pbl, DirApplication!)
		CASE 2  ; ls_type = "Window"      ; ls_dir = LibraryDirectory(is_pbl, DirWindow!)
		CASE 3  ; ls_type = "DataWindow"  ; ls_dir = LibraryDirectory(is_pbl, DirDataWindow!)
		CASE 4  ; ls_type = "Function"    ; ls_dir = LibraryDirectory(is_pbl, DirFunction!)
		CASE 5  ; ls_type = "Menu"        ; ls_dir = LibraryDirectory(is_pbl, DirMenu!)
		CASE 6  ; ls_type = "Structure"   ; ls_dir = LibraryDirectory(is_pbl, DirStructure!)
		CASE 7  ; ls_type = "Query"       ; ls_dir = LibraryDirectory(is_pbl, DirQuery!)
		CASE 8  ; ls_type = "UserObject"  ; ls_dir = LibraryDirectory(is_pbl, DirUserObject!)
		CASE 9  ; ls_type = "Pipeline"    ; ls_dir = LibraryDirectory(is_pbl, DirPipeline!)
		CASE 10 ; ls_type = "Project"     ; ls_dir = LibraryDirectory(is_pbl, DirProject!)
	END CHOOSE

	IF IsNull(ls_dir) OR ls_dir = "" THEN CONTINUE
	ls_ext = wf_ext(ls_type)

	// Parse: entries separated by ~n ; fields separated by ~t (name~tcomment~tdate)
	ll_start = 1
	DO WHILE ll_start <= Len(ls_dir)
		ll_nl = Pos(ls_dir, "~n", ll_start)
		IF ll_nl = 0 THEN
			ls_line = Mid(ls_dir, ll_start)
			ll_start = Len(ls_dir) + 1
		ELSE
			ls_line = Mid(ls_dir, ll_start, ll_nl - ll_start)
			ll_start = ll_nl + 1
		END IF

		IF Trim(ls_line) = "" THEN CONTINUE

		ll_t = Pos(ls_line, "~t")
		IF ll_t > 0 THEN
			ls_name = Left(ls_line, ll_t - 1)
			ls_rest = Mid(ls_line, ll_t + 1)
			ll_t = Pos(ls_rest, "~t")
			IF ll_t > 0 THEN
				ls_date = Mid(ls_rest, ll_t + 1)
			ELSE
				ls_date = ls_rest
			END IF
		ELSE
			ls_name = ls_line
			ls_date = ""
		END IF

		ls_name = Trim(ls_name)
		ls_date = Trim(ls_date)
		IF ls_name = "" THEN CONTINUE

		ll_row = dw_list.InsertRow(0)
		dw_list.SetItem(ll_row, "c_check",    "Y")
		dw_list.SetItem(ll_row, "c_name",     ls_name)
		dw_list.SetItem(ll_row, "c_type",     ls_type)
		dw_list.SetItem(ll_row, "c_modified", ls_date)
		dw_list.SetItem(ll_row, "c_size",     "")
		dw_list.SetItem(ll_row, "c_ext",      ls_ext)
		dw_list.SetItem(ll_row, "c_status",   "Ready")
		ll_total ++
	LOOP
NEXT

dw_list.SetSort("c_type A, c_name A")
dw_list.Sort()
dw_list.SetRedraw(TRUE)
SetPointer(Arrow!)

st_exported.text = "Loaded: " + String(ll_total)
st_success.text  = "Success: 0"
st_failed.text   = "Failed: 0"
hpb_progress.Position = 0
RETURN ll_total
end function

public function long wf_export (boolean ab_onlychecked);// Export objects (all or only checked) to <ExportFolder>\<Type>\<name><ext>
long i, ll, ll_done, ll_total, ll_ok, ll_fail
integer li_h
string ls_name, ls_type, ls_ext, ls_src, ls_folder, ls_path, ls_logf, ls_errf
LibExportType le

is_pbl = Trim(sle_pbl.text)
is_export = Trim(sle_export.text)

IF is_pbl = "" OR NOT FileExists(is_pbl) THEN
	MessageBox("Error", "PBL tidak valid.") ; RETURN -1
END IF
IF is_export = "" THEN
	MessageBox("Error", "Export folder belum dipilih.") ; RETURN -1
END IF
IF wf_ensuredir(is_export) < 0 THEN
	MessageBox("Error", "Gagal membuat folder export: " + is_export) ; RETURN -1
END IF

ls_logf = is_export + "\export.log"
ls_errf = is_export + "\export_error.log"

ll = dw_list.RowCount()
ll_total = 0
FOR i = 1 TO ll
	IF ab_onlychecked AND dw_list.GetItemString(i, "c_check") <> "Y" THEN CONTINUE
	ll_total ++
NEXT
IF ll_total = 0 THEN
	MessageBox("Info", "Tidak ada object yang dipilih untuk diexport.") ; RETURN 0
END IF

wf_log(ls_logf, "START EXPORT (" + String(ll_total) + " object)  PBL=" + is_pbl)
SetPointer(HourGlass!)
dw_list.SetRedraw(FALSE)
hpb_progress.Position = 0
ll_done = 0 ; ll_ok = 0 ; ll_fail = 0

FOR i = 1 TO ll
	IF ab_onlychecked AND dw_list.GetItemString(i, "c_check") <> "Y" THEN CONTINUE

	ls_name = Trim(dw_list.GetItemString(i, "c_name"))
	ls_type = dw_list.GetItemString(i, "c_type")
	ls_ext  = dw_list.GetItemString(i, "c_ext")

	CHOOSE CASE ls_type
		CASE "Application" ; le = ExportApplication!
		CASE "Window"      ; le = ExportWindow!
		CASE "DataWindow"  ; le = ExportDataWindow!
		CASE "Function"    ; le = ExportFunction!
		CASE "Menu"        ; le = ExportMenu!
		CASE "Structure"   ; le = ExportStructure!
		CASE "Query"       ; le = ExportQuery!
		CASE "UserObject"  ; le = ExportUserObject!
		CASE "Pipeline"    ; le = ExportPipeline!
		CASE "Project"     ; le = ExportProject!
		CASE ELSE          ; le = ExportWindow!
	END CHOOSE

	ls_src = LibraryExport(is_pbl, ls_name, le)

	IF IsNull(ls_src) OR ls_src = "" THEN
		ll_fail ++
		dw_list.SetItem(i, "c_status", "FAILED")
		wf_log(ls_errf, "FAILED~t" + ls_type + "~t" + ls_name + "~tLibraryExport returned empty")
	ELSE
		ls_folder = is_export + "\" + ls_type
		IF wf_ensuredir(ls_folder) < 0 THEN
			ll_fail ++
			dw_list.SetItem(i, "c_status", "FAILED")
			wf_log(ls_errf, "FAILED~t" + ls_type + "~t" + ls_name + "~tcannot create folder")
		ELSE
			ls_path = ls_folder + "\" + wf_sanitize(ls_name) + ls_ext
			li_h = FileOpen(ls_path, StreamMode!, Write!, LockWrite!, Replace!, EncodingUTF16LE!)
			IF li_h < 1 THEN
				ll_fail ++
				dw_list.SetItem(i, "c_status", "FAILED")
				wf_log(ls_errf, "FAILED~t" + ls_type + "~t" + ls_name + "~tcannot open file " + ls_path)
			ELSE
				FileWriteEx(li_h, ls_src)
				FileClose(li_h)
				ll_ok ++
				dw_list.SetItem(i, "c_status", "SUCCESS")
				dw_list.SetItem(i, "c_size", String(Len(ls_src)) + " ch")
			END IF
		END IF
	END IF

	ll_done ++
	IF Mod(ll_done, 10) = 0 OR ll_done = ll_total THEN
		hpb_progress.Position = Integer((ll_done * 100.0) / ll_total)
		st_exported.text = "Exported: " + String(ll_done) + " / " + String(ll_total)
		st_success.text  = "Success: " + String(ll_ok)
		st_failed.text   = "Failed: " + String(ll_fail)
		dw_list.SetRedraw(TRUE)
		Yield()
		dw_list.SetRedraw(FALSE)
	END IF
NEXT

dw_list.SetRedraw(TRUE)
hpb_progress.Position = 100
st_exported.text = "Exported: " + String(ll_done) + " / " + String(ll_total)
st_success.text  = "Success: " + String(ll_ok)
st_failed.text   = "Failed: " + String(ll_fail)
SetPointer(Arrow!)

wf_log(ls_logf, "END EXPORT  Success=" + String(ll_ok) + "  Failed=" + String(ll_fail))
MessageBox("Selesai", "Export selesai.~r~nSuccess: " + String(ll_ok) + "~r~nFailed: " + String(ll_fail) + &
	"~r~n~r~nLog: " + ls_logf)
RETURN ll_ok
end function

on w_pbl_export_manager.create
this.sle_pbl=create sle_pbl
this.cb_browse_pbl=create cb_browse_pbl
this.sle_export=create sle_export
this.cb_browse_export=create cb_browse_export
this.st_pbl=create st_pbl
this.st_export=create st_export
this.cb_load=create cb_load
this.cb_checkall=create cb_checkall
this.cb_uncheckall=create cb_uncheckall
this.cb_refresh=create cb_refresh
this.st_filter=create st_filter
this.ddlb_filter=create ddlb_filter
this.cb_export_sel=create cb_export_sel
this.cb_export_all=create cb_export_all
this.dw_list=create dw_list
this.st_progress=create st_progress
this.hpb_progress=create hpb_progress
this.st_exported=create st_exported
this.st_success=create st_success
this.st_failed=create st_failed
this.Control[]={this.sle_pbl,&
this.cb_browse_pbl,&
this.sle_export,&
this.cb_browse_export,&
this.st_pbl,&
this.st_export,&
this.cb_load,&
this.cb_checkall,&
this.cb_uncheckall,&
this.cb_refresh,&
this.st_filter,&
this.ddlb_filter,&
this.cb_export_sel,&
this.cb_export_all,&
this.dw_list,&
this.st_progress,&
this.hpb_progress,&
this.st_exported,&
this.st_success,&
this.st_failed}
end on

on w_pbl_export_manager.destroy
destroy(this.sle_pbl)
destroy(this.cb_browse_pbl)
destroy(this.sle_export)
destroy(this.cb_browse_export)
destroy(this.st_pbl)
destroy(this.st_export)
destroy(this.cb_load)
destroy(this.cb_checkall)
destroy(this.cb_uncheckall)
destroy(this.cb_refresh)
destroy(this.st_filter)
destroy(this.ddlb_filter)
destroy(this.cb_export_sel)
destroy(this.cb_export_all)
destroy(this.dw_list)
destroy(this.st_progress)
destroy(this.hpb_progress)
destroy(this.st_exported)
destroy(this.st_success)
destroy(this.st_failed)
end on

event open;// Initialize controls
dw_list.SetTransObject(SQLCA)
dw_list.Reset()

ddlb_filter.Reset()
ddlb_filter.AddItem("All")
ddlb_filter.AddItem("Window")
ddlb_filter.AddItem("DataWindow")
ddlb_filter.AddItem("UserObject")
ddlb_filter.AddItem("Function")
ddlb_filter.AddItem("Menu")
ddlb_filter.AddItem("Structure")
ddlb_filter.AddItem("Query")
ddlb_filter.AddItem("Pipeline")
ddlb_filter.AddItem("Project")
ddlb_filter.AddItem("Application")
ddlb_filter.SelectItem(1)

hpb_progress.MinPosition = 0
hpb_progress.MaxPosition = 100
hpb_progress.Position = 0

st_exported.text = "Exported: 0 / 0"
st_success.text  = "Success: 0"
st_failed.text   = "Failed: 0"
end event

type sle_pbl from singlelineedit within w_pbl_export_manager
integer x = 343
integer y = 24
integer width = 2382
integer height = 96
integer taborder = 10
integer textsize = -9
fontcharset fontcharset = ansi!
fontpitch fontpitch = variable!
fontfamily fontfamily = swiss!
string facename = "Tahoma"
boolean border = true
borderstyle borderstyle = stylelowered!
end type

type cb_browse_pbl from commandbutton within w_pbl_export_manager
integer x = 2747
integer y = 24
integer width = 311
integer height = 96
integer taborder = 20
integer textsize = -9
fontcharset fontcharset = ansi!
fontpitch fontpitch = variable!
fontfamily fontfamily = swiss!
string facename = "Tahoma"
string text = "Browse..."
end type

event clicked;string ls_path, ls_file
integer li
li = GetFileOpenName("Pilih PBL", ls_path, ls_file, "pbl", "PowerBuilder Library (*.pbl),*.pbl")
IF li = 1 THEN
	is_pbl = ls_path
	sle_pbl.text = ls_path
END IF
end event

type sle_export from singlelineedit within w_pbl_export_manager
integer x = 343
integer y = 136
integer width = 2382
integer height = 96
integer taborder = 30
integer textsize = -9
fontcharset fontcharset = ansi!
fontpitch fontpitch = variable!
fontfamily fontfamily = swiss!
string facename = "Tahoma"
boolean border = true
borderstyle borderstyle = stylelowered!
end type

type cb_browse_export from commandbutton within w_pbl_export_manager
integer x = 2747
integer y = 136
integer width = 311
integer height = 96
integer taborder = 40
integer textsize = -9
fontcharset fontcharset = ansi!
fontpitch fontpitch = variable!
fontfamily fontfamily = swiss!
string facename = "Tahoma"
string text = "Browse..."
end type

event clicked;// PB punya no native folder picker: pilih file apa saja di folder tujuan, ambil direktorinya.
string ls_path, ls_file
integer li
long ll
li = GetFileSaveName("Pilih folder tujuan (ketik nama file apa saja, mis. x.txt)", ls_path, ls_file, "", "All Files (*.*),*.*")
IF li = 1 THEN
	ll = LastPos(ls_path, "\")
	IF ll > 0 THEN
		is_export = Left(ls_path, ll - 1)
		sle_export.text = is_export
	END IF
END IF
end event

type st_pbl from statictext within w_pbl_export_manager
integer x = 23
integer y = 36
integer width = 300
integer height = 72
integer textsize = -9
fontcharset fontcharset = ansi!
fontpitch fontpitch = variable!
fontfamily fontfamily = swiss!
string facename = "Tahoma"
long textcolor = 33554432
long backcolor = 67108864
boolean background = false
string text = "Target PBL :"
end type

type st_export from statictext within w_pbl_export_manager
integer x = 23
integer y = 148
integer width = 300
integer height = 72
integer textsize = -9
fontcharset fontcharset = ansi!
fontpitch fontpitch = variable!
fontfamily fontfamily = swiss!
string facename = "Tahoma"
long textcolor = 33554432
long backcolor = 67108864
boolean background = false
string text = "Export Folder :"
end type

type cb_load from commandbutton within w_pbl_export_manager
integer x = 23
integer y = 256
integer width = 366
integer height = 100
integer taborder = 50
integer textsize = -9
integer weight = 700
fontcharset fontcharset = ansi!
fontpitch fontpitch = variable!
fontfamily fontfamily = swiss!
string facename = "Tahoma"
string text = "Load Library"
end type

event clicked;wf_load()
end event

type cb_checkall from commandbutton within w_pbl_export_manager
integer x = 407
integer y = 256
integer width = 320
integer height = 100
integer taborder = 60
integer textsize = -9
fontcharset fontcharset = ansi!
fontpitch fontpitch = variable!
fontfamily fontfamily = swiss!
string facename = "Tahoma"
string text = "Check All"
end type

event clicked;wf_setall("Y")
end event

type cb_uncheckall from commandbutton within w_pbl_export_manager
integer x = 745
integer y = 256
integer width = 320
integer height = 100
integer taborder = 70
integer textsize = -9
fontcharset fontcharset = ansi!
fontpitch fontpitch = variable!
fontfamily fontfamily = swiss!
string facename = "Tahoma"
string text = "Uncheck All"
end type

event clicked;wf_setall("")
end event

type cb_refresh from commandbutton within w_pbl_export_manager
integer x = 1083
integer y = 256
integer width = 288
integer height = 100
integer taborder = 80
integer textsize = -9
fontcharset fontcharset = ansi!
fontpitch fontpitch = variable!
fontfamily fontfamily = swiss!
string facename = "Tahoma"
string text = "Refresh"
end type

event clicked;wf_load()
end event

type st_filter from statictext within w_pbl_export_manager
integer x = 1408
integer y = 276
integer width = 160
integer height = 72
integer textsize = -9
fontcharset fontcharset = ansi!
fontpitch fontpitch = variable!
fontfamily fontfamily = swiss!
string facename = "Tahoma"
long textcolor = 33554432
long backcolor = 67108864
boolean background = false
string text = "Filter :"
alignment alignment = right!
end type

type ddlb_filter from dropdownlistbox within w_pbl_export_manager
integer x = 1582
integer y = 256
integer width = 507
integer height = 600
integer taborder = 90
integer textsize = -9
fontcharset fontcharset = ansi!
fontpitch fontpitch = variable!
fontfamily fontfamily = swiss!
string facename = "Tahoma"
boolean vscrollbar = true
borderstyle borderstyle = stylelowered!
end type

event selectionchanged;string ls
ls = this.text
IF ls = "All" OR ls = "" THEN
	dw_list.SetFilter("")
ELSE
	dw_list.SetFilter("c_type = '" + ls + "'")
END IF
dw_list.Filter()
end event

type cb_export_sel from commandbutton within w_pbl_export_manager
integer x = 2117
integer y = 256
integer width = 462
integer height = 100
integer taborder = 100
integer textsize = -9
integer weight = 700
fontcharset fontcharset = ansi!
fontpitch fontpitch = variable!
fontfamily fontfamily = swiss!
string facename = "Tahoma"
string text = "Export Selected"
end type

event clicked;wf_export(TRUE)
end event

type cb_export_all from commandbutton within w_pbl_export_manager
integer x = 2597
integer y = 256
integer width = 462
integer height = 100
integer taborder = 110
integer textsize = -9
integer weight = 700
fontcharset fontcharset = ansi!
fontpitch fontpitch = variable!
fontfamily fontfamily = swiss!
string facename = "Tahoma"
string text = "Export All"
end type

event clicked;wf_export(FALSE)
end event

type dw_list from datawindow within w_pbl_export_manager
integer x = 23
integer y = 392
integer width = 3035
integer height = 1480
integer taborder = 120
string title = "none"
string dataobject = "d_pbl_objects"
boolean hscrollbar = true
boolean vscrollbar = true
boolean livescroll = true
borderstyle borderstyle = stylelowered!
end type

event clicked;// Toggle the "Sel" flag when clicking the Sel column cell
IF row > 0 AND IsValid(dwo) THEN
	IF dwo.name = "c_check" THEN
		IF this.GetItemString(row, "c_check") = "Y" THEN
			this.SetItem(row, "c_check", "")
		ELSE
			this.SetItem(row, "c_check", "Y")
		END IF
	END IF
END IF
end event

type st_progress from statictext within w_pbl_export_manager
integer x = 23
integer y = 1904
integer width = 320
integer height = 72
integer textsize = -9
fontcharset fontcharset = ansi!
fontpitch fontpitch = variable!
fontfamily fontfamily = swiss!
string facename = "Tahoma"
long textcolor = 33554432
long backcolor = 67108864
boolean background = false
string text = "Progress :"
end type

type hpb_progress from hprogressbar within w_pbl_export_manager
integer x = 343
integer y = 1896
integer width = 2715
integer height = 84
integer setstep = 1
integer position = 0
boolean smoothscroll = true
end type

type st_exported from statictext within w_pbl_export_manager
integer x = 23
integer y = 2008
integer width = 1029
integer height = 72
integer textsize = -9
integer weight = 700
fontcharset fontcharset = ansi!
fontpitch fontpitch = variable!
fontfamily fontfamily = swiss!
string facename = "Tahoma"
long textcolor = 33554432
long backcolor = 67108864
boolean background = false
string text = "Exported: 0 / 0"
end type

type st_success from statictext within w_pbl_export_manager
integer x = 1097
integer y = 2008
integer width = 891
integer height = 72
integer textsize = -9
integer weight = 700
fontcharset fontcharset = ansi!
fontpitch fontpitch = variable!
fontfamily fontfamily = swiss!
string facename = "Tahoma"
long textcolor = 32768
long backcolor = 67108864
boolean background = false
string text = "Success: 0"
end type

type st_failed from statictext within w_pbl_export_manager
integer x = 2034
integer y = 2008
integer width = 891
integer height = 72
integer textsize = -9
integer weight = 700
fontcharset fontcharset = ansi!
fontpitch fontpitch = variable!
fontfamily fontfamily = swiss!
string facename = "Tahoma"
long textcolor = 255
long backcolor = 67108864
boolean background = false
string text = "Failed: 0"
end type
