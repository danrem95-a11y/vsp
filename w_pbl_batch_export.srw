$PBExportHeader$w_pbl_batch_export.srw
forward
global type w_pbl_batch_export from window
end type
type st_dest from statictext within w_pbl_batch_export
end type
type sle_dest from singlelineedit within w_pbl_batch_export
end type
type cb_browse_dest from commandbutton within w_pbl_batch_export
end type
type cbx_bytype from checkbox within w_pbl_batch_export
end type
type cb_add from commandbutton within w_pbl_batch_export
end type
type cb_import_pbt from commandbutton within w_pbl_batch_export
end type
type cb_remove from commandbutton within w_pbl_batch_export
end type
type cb_clear from commandbutton within w_pbl_batch_export
end type
type cb_checkall from commandbutton within w_pbl_batch_export
end type
type cb_uncheckall from commandbutton within w_pbl_batch_export
end type
type cb_export from commandbutton within w_pbl_batch_export
end type
type cb_close from commandbutton within w_pbl_batch_export
end type
type dw_libs from datawindow within w_pbl_batch_export
end type
type st_overall from statictext within w_pbl_batch_export
end type
type hpb_overall from hprogressbar within w_pbl_batch_export
end type
type st_current from statictext within w_pbl_batch_export
end type
type hpb_current from hprogressbar within w_pbl_batch_export
end type
type st_libs from statictext within w_pbl_batch_export
end type
type st_objok from statictext within w_pbl_batch_export
end type
type st_objfail from statictext within w_pbl_batch_export
end type
end forward

global type w_pbl_batch_export from window
integer width = 3470
integer height = 2200
boolean titlebar = true
string title = "PBL Batch Source Export Manager"
boolean controlmenu = true
boolean minbox = true
boolean maxbox = true
boolean resizable = true
long backcolor = 67108864
string icon = "AppIcon!"
boolean center = true
st_dest st_dest
sle_dest sle_dest
cb_browse_dest cb_browse_dest
cbx_bytype cbx_bytype
cb_add cb_add
cb_import_pbt cb_import_pbt
cb_remove cb_remove
cb_clear cb_clear
cb_checkall cb_checkall
cb_uncheckall cb_uncheckall
cb_export cb_export
cb_close cb_close
dw_libs dw_libs
st_overall st_overall
hpb_overall hpb_overall
st_current st_current
hpb_current hpb_current
st_libs st_libs
st_objok st_objok
st_objfail st_objfail
end type
global w_pbl_batch_export w_pbl_batch_export

type variables
string is_dest
end variables

forward prototypes
public function string wf_ext (string as_type)
public function integer wf_ensuredir (string as_dir)
public function string wf_sanitize (string as_name)
public function integer wf_log (string as_file, string as_msg)
public subroutine wf_addpbl (string as_fullpath)
public subroutine wf_setall (string as_value)
public function long wf_count (string as_pbl)
public function long wf_export_one (string as_pbl, string as_destbase, boolean ab_bytype, ref long al_ok, ref long al_fail)
public function integer wf_run_batch ()
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

public function integer wf_log (string as_file, string as_msg);// Append one timestamped line to a log file
integer li
li = FileOpen(as_file, LineMode!, Write!, LockWrite!, Append!)
IF li < 1 THEN RETURN -1
FileWrite(li, "[" + String(Now(), "yyyy-mm-dd hh:mm:ss") + "] " + as_msg)
FileClose(li)
RETURN 1
end function

public subroutine wf_addpbl (string as_fullpath);// Add one PBL row (skip duplicates, by full path case-insensitive)
string ls_file, ls_path
long i, ll
ls_path = Trim(as_fullpath)
IF ls_path = "" THEN RETURN
FOR i = 1 TO dw_libs.RowCount()
	IF Lower(dw_libs.GetItemString(i, "c_pbl")) = Lower(ls_path) THEN RETURN
NEXT
ll = LastPos(ls_path, "\")
IF ll > 0 THEN ls_file = Mid(ls_path, ll + 1) ELSE ls_file = ls_path
ll = dw_libs.InsertRow(0)
dw_libs.SetItem(ll, "c_check",   "Y")
dw_libs.SetItem(ll, "c_name",    ls_file)
dw_libs.SetItem(ll, "c_pbl",     ls_path)
dw_libs.SetItem(ll, "c_objects", "")
dw_libs.SetItem(ll, "c_ok",      "")
dw_libs.SetItem(ll, "c_fail",    "")
dw_libs.SetItem(ll, "c_status",  "Ready")
end subroutine

public subroutine wf_setall (string as_value);// Set the "Sel" flag ("Y" / "") on every row
long i, ll
ll = dw_libs.RowCount()
dw_libs.SetRedraw(FALSE)
FOR i = 1 TO ll
	dw_libs.SetItem(i, "c_check", as_value)
NEXT
dw_libs.SetRedraw(TRUE)
end subroutine

public function long wf_count (string as_pbl);// Count total exportable objects across all 10 object types
string ls_dir, ls_line
long ll, ll_start, ll_nl
integer li
ll = 0
FOR li = 1 TO 10
	CHOOSE CASE li
		CASE 1  ; ls_dir = LibraryDirectory(as_pbl, DirApplication!)
		CASE 2  ; ls_dir = LibraryDirectory(as_pbl, DirWindow!)
		CASE 3  ; ls_dir = LibraryDirectory(as_pbl, DirDataWindow!)
		CASE 4  ; ls_dir = LibraryDirectory(as_pbl, DirFunction!)
		CASE 5  ; ls_dir = LibraryDirectory(as_pbl, DirMenu!)
		CASE 6  ; ls_dir = LibraryDirectory(as_pbl, DirStructure!)
		CASE 7  ; ls_dir = LibraryDirectory(as_pbl, DirQuery!)
		CASE 8  ; ls_dir = LibraryDirectory(as_pbl, DirUserObject!)
		CASE 9  ; ls_dir = LibraryDirectory(as_pbl, DirPipeline!)
		CASE 10 ; ls_dir = LibraryDirectory(as_pbl, DirProject!)
	END CHOOSE
	IF IsNull(ls_dir) OR ls_dir = "" THEN CONTINUE
	ll_start = 1
	DO WHILE ll_start <= Len(ls_dir)
		ll_nl = Pos(ls_dir, "~n", ll_start)
		IF ll_nl = 0 THEN
			ls_line = Mid(ls_dir, ll_start) ; ll_start = Len(ls_dir) + 1
		ELSE
			ls_line = Mid(ls_dir, ll_start, ll_nl - ll_start) ; ll_start = ll_nl + 1
		END IF
		IF Trim(ls_line) <> "" THEN ll ++
	LOOP
NEXT
RETURN ll
end function

public function long wf_export_one (string as_pbl, string as_destbase, boolean ab_bytype, ref long al_ok, ref long al_fail);// Export ALL objects of one PBL into as_destbase. Returns total objects processed.
string ls_dir, ls_line, ls_name, ls_type, ls_ext, ls_folder, ls_path, ls_src, ls_errf
long ll_total, ll_start, ll_nl, ll_t, ll_max
integer li, li_h
LibExportType le

al_ok = 0 ; al_fail = 0 ; ll_total = 0
ls_errf = is_dest + "\batch_error.log"

ll_max = wf_count(as_pbl)
IF ll_max < 1 THEN ll_max = 1
hpb_current.MinPosition = 0
hpb_current.MaxPosition = ll_max
hpb_current.Position = 0

FOR li = 1 TO 10
	CHOOSE CASE li
		CASE 1  ; ls_type = "Application" ; le = ExportApplication! ; ls_dir = LibraryDirectory(as_pbl, DirApplication!)
		CASE 2  ; ls_type = "Window"      ; le = ExportWindow!      ; ls_dir = LibraryDirectory(as_pbl, DirWindow!)
		CASE 3  ; ls_type = "DataWindow"  ; le = ExportDataWindow!  ; ls_dir = LibraryDirectory(as_pbl, DirDataWindow!)
		CASE 4  ; ls_type = "Function"    ; le = ExportFunction!    ; ls_dir = LibraryDirectory(as_pbl, DirFunction!)
		CASE 5  ; ls_type = "Menu"        ; le = ExportMenu!        ; ls_dir = LibraryDirectory(as_pbl, DirMenu!)
		CASE 6  ; ls_type = "Structure"   ; le = ExportStructure!   ; ls_dir = LibraryDirectory(as_pbl, DirStructure!)
		CASE 7  ; ls_type = "Query"       ; le = ExportQuery!       ; ls_dir = LibraryDirectory(as_pbl, DirQuery!)
		CASE 8  ; ls_type = "UserObject"  ; le = ExportUserObject!  ; ls_dir = LibraryDirectory(as_pbl, DirUserObject!)
		CASE 9  ; ls_type = "Pipeline"    ; le = ExportPipeline!    ; ls_dir = LibraryDirectory(as_pbl, DirPipeline!)
		CASE 10 ; ls_type = "Project"     ; le = ExportProject!     ; ls_dir = LibraryDirectory(as_pbl, DirProject!)
	END CHOOSE

	IF IsNull(ls_dir) OR ls_dir = "" THEN CONTINUE
	ls_ext = wf_ext(ls_type)

	ll_start = 1
	DO WHILE ll_start <= Len(ls_dir)
		ll_nl = Pos(ls_dir, "~n", ll_start)
		IF ll_nl = 0 THEN
			ls_line = Mid(ls_dir, ll_start) ; ll_start = Len(ls_dir) + 1
		ELSE
			ls_line = Mid(ls_dir, ll_start, ll_nl - ll_start) ; ll_start = ll_nl + 1
		END IF

		IF Trim(ls_line) = "" THEN CONTINUE
		ll_t = Pos(ls_line, "~t")
		IF ll_t > 0 THEN
			ls_name = Left(ls_line, ll_t - 1)
		ELSE
			ls_name = ls_line
		END IF
		ls_name = Trim(ls_name)
		IF ls_name = "" THEN CONTINUE

		ls_src = LibraryExport(as_pbl, ls_name, le)
		IF IsNull(ls_src) OR ls_src = "" THEN
			al_fail ++
			wf_log(ls_errf, "FAILED~t" + as_pbl + "~t" + ls_type + "~t" + ls_name + "~tLibraryExport empty")
		ELSE
			IF ab_bytype THEN
				ls_folder = as_destbase + "\" + ls_type
			ELSE
				ls_folder = as_destbase
			END IF
			IF wf_ensuredir(ls_folder) < 0 THEN
				al_fail ++
				wf_log(ls_errf, "FAILED~t" + as_pbl + "~t" + ls_type + "~t" + ls_name + "~tcannot create folder")
			ELSE
				ls_path = ls_folder + "\" + wf_sanitize(ls_name) + ls_ext
				li_h = FileOpen(ls_path, StreamMode!, Write!, LockWrite!, Replace!, EncodingUTF16LE!)
				IF li_h < 1 THEN
					al_fail ++
					wf_log(ls_errf, "FAILED~t" + as_pbl + "~t" + ls_type + "~t" + ls_name + "~tcannot open " + ls_path)
				ELSE
					FileWriteEx(li_h, ls_src)
					FileClose(li_h)
					al_ok ++
				END IF
			END IF
		END IF

		ll_total ++
		IF Mod(ll_total, 10) = 0 OR ll_total = ll_max THEN
			IF ll_total > hpb_current.MaxPosition THEN
				hpb_current.Position = hpb_current.MaxPosition
			ELSE
				hpb_current.Position = ll_total
			END IF
			Yield()
		END IF
	LOOP
NEXT

hpb_current.Position = hpb_current.MaxPosition
RETURN ll_total
end function

public function integer wf_run_batch ();// Drive the whole batch: each checked PBL -> <dest>\<pblname>\...
long i, ll, ll_total_libs, ll_done_libs, ll_ok, ll_fail
long ll_grand_ok, ll_grand_fail, ll_objs, ll_dot
string ls_pbl, ls_name, ls_folder_name, ls_base, ls_logf
boolean lb_bytype

is_dest = Trim(sle_dest.text)
IF is_dest = "" THEN
	MessageBox("Error", "Folder tujuan belum dipilih.") ; RETURN -1
END IF
IF wf_ensuredir(is_dest) < 0 THEN
	MessageBox("Error", "Gagal membuat folder tujuan: " + is_dest) ; RETURN -1
END IF

lb_bytype = cbx_bytype.Checked
ls_logf = is_dest + "\batch_export.log"

ll = dw_libs.RowCount()
ll_total_libs = 0
FOR i = 1 TO ll
	IF dw_libs.GetItemString(i, "c_check") = "Y" THEN ll_total_libs ++
NEXT
IF ll_total_libs = 0 THEN
	MessageBox("Info", "Tidak ada library yang dicentang.") ; RETURN 0
END IF

wf_log(ls_logf, "==================== BATCH START : " + String(ll_total_libs) + " library ====================")
SetPointer(HourGlass!)
hpb_overall.MinPosition = 0
hpb_overall.MaxPosition = ll_total_libs
hpb_overall.Position = 0
ll_done_libs = 0 ; ll_grand_ok = 0 ; ll_grand_fail = 0

FOR i = 1 TO ll
	IF dw_libs.GetItemString(i, "c_check") <> "Y" THEN CONTINUE

	ls_pbl  = Trim(dw_libs.GetItemString(i, "c_pbl"))
	ls_name = dw_libs.GetItemString(i, "c_name")

	IF NOT FileExists(ls_pbl) THEN
		dw_libs.SetItem(i, "c_status", "NOT FOUND")
		wf_log(ls_logf, "SKIP (not found): " + ls_pbl)
		ll_done_libs ++
		hpb_overall.Position = ll_done_libs
		Yield()
		CONTINUE
	END IF

	// folder name = pbl filename without extension
	ll_dot = LastPos(ls_name, ".")
	IF ll_dot > 0 THEN
		ls_folder_name = Left(ls_name, ll_dot - 1)
	ELSE
		ls_folder_name = ls_name
	END IF
	ls_folder_name = wf_sanitize(ls_folder_name)
	ls_base = is_dest + "\" + ls_folder_name

	IF wf_ensuredir(ls_base) < 0 THEN
		dw_libs.SetItem(i, "c_status", "FOLDER ERROR")
		wf_log(ls_logf, "FOLDER ERROR: " + ls_base)
		ll_done_libs ++
		hpb_overall.Position = ll_done_libs
		Yield()
		CONTINUE
	END IF

	dw_libs.SetItem(i, "c_status", "Exporting...")
	Yield()

	ll_objs = wf_export_one(ls_pbl, ls_base, lb_bytype, ll_ok, ll_fail)

	dw_libs.SetItem(i, "c_objects", String(ll_objs))
	dw_libs.SetItem(i, "c_ok",      String(ll_ok))
	dw_libs.SetItem(i, "c_fail",    String(ll_fail))
	IF ll_fail = 0 THEN
		dw_libs.SetItem(i, "c_status", "DONE")
	ELSE
		dw_libs.SetItem(i, "c_status", "DONE (errors)")
	END IF

	ll_grand_ok   += ll_ok
	ll_grand_fail += ll_fail
	ll_done_libs ++
	hpb_overall.Position = ll_done_libs
	st_libs.text    = "Libraries: " + String(ll_done_libs) + " / " + String(ll_total_libs)
	st_objok.text   = "Objects OK: " + String(ll_grand_ok)
	st_objfail.text = "Failed: " + String(ll_grand_fail)
	wf_log(ls_logf, "PBL DONE: " + ls_pbl + "  ->  " + ls_base + "  (OK=" + String(ll_ok) + " Fail=" + String(ll_fail) + ")")
	Yield()
NEXT

SetPointer(Arrow!)
wf_log(ls_logf, "==================== BATCH END  OK=" + String(ll_grand_ok) + "  Fail=" + String(ll_grand_fail) + " ====================")
MessageBox("Selesai", "Batch export selesai.~r~n~r~nLibrary  : " + String(ll_done_libs) + " / " + String(ll_total_libs) + &
	"~r~nObjects OK : " + String(ll_grand_ok) + "~r~nFailed     : " + String(ll_grand_fail) + &
	"~r~n~r~nLog: " + ls_logf)
RETURN ll_grand_ok
end function

on w_pbl_batch_export.create
this.st_dest=create st_dest
this.sle_dest=create sle_dest
this.cb_browse_dest=create cb_browse_dest
this.cbx_bytype=create cbx_bytype
this.cb_add=create cb_add
this.cb_import_pbt=create cb_import_pbt
this.cb_remove=create cb_remove
this.cb_clear=create cb_clear
this.cb_checkall=create cb_checkall
this.cb_uncheckall=create cb_uncheckall
this.cb_export=create cb_export
this.cb_close=create cb_close
this.dw_libs=create dw_libs
this.st_overall=create st_overall
this.hpb_overall=create hpb_overall
this.st_current=create st_current
this.hpb_current=create hpb_current
this.st_libs=create st_libs
this.st_objok=create st_objok
this.st_objfail=create st_objfail
this.Control[]={this.st_dest,&
this.sle_dest,&
this.cb_browse_dest,&
this.cbx_bytype,&
this.cb_add,&
this.cb_import_pbt,&
this.cb_remove,&
this.cb_clear,&
this.cb_checkall,&
this.cb_uncheckall,&
this.cb_export,&
this.cb_close,&
this.dw_libs,&
this.st_overall,&
this.hpb_overall,&
this.st_current,&
this.hpb_current,&
this.st_libs,&
this.st_objok,&
this.st_objfail}
end on

on w_pbl_batch_export.destroy
destroy(this.st_dest)
destroy(this.sle_dest)
destroy(this.cb_browse_dest)
destroy(this.cbx_bytype)
destroy(this.cb_add)
destroy(this.cb_import_pbt)
destroy(this.cb_remove)
destroy(this.cb_clear)
destroy(this.cb_checkall)
destroy(this.cb_uncheckall)
destroy(this.cb_export)
destroy(this.cb_close)
destroy(this.dw_libs)
destroy(this.st_overall)
destroy(this.hpb_overall)
destroy(this.st_current)
destroy(this.hpb_current)
destroy(this.st_libs)
destroy(this.st_objok)
destroy(this.st_objfail)
end on

event open;dw_libs.SetTransObject(SQLCA)
dw_libs.Reset()
cbx_bytype.Checked = TRUE
hpb_overall.MinPosition = 0 ; hpb_overall.MaxPosition = 100 ; hpb_overall.Position = 0
hpb_current.MinPosition = 0 ; hpb_current.MaxPosition = 100 ; hpb_current.Position = 0
st_libs.text    = "Libraries: 0 / 0"
st_objok.text   = "Objects OK: 0"
st_objfail.text = "Failed: 0"
end event

type st_dest from statictext within w_pbl_batch_export
integer x = 23
integer y = 36
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
string text = "Export Folder :"
end type

type sle_dest from singlelineedit within w_pbl_batch_export
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

event modified;is_dest = Trim(this.text)
end event

type cb_browse_dest from commandbutton within w_pbl_batch_export
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

event clicked;// No native folder picker: pick any file in the target folder, take its directory
string ls_path, ls_file
integer li
long ll
li = GetFileSaveName("Pilih folder tujuan (ketik nama file apa saja, mis. x.txt)", ls_path, ls_file, "", "All Files (*.*),*.*")
IF li = 1 THEN
	ll = LastPos(ls_path, "\")
	IF ll > 0 THEN
		is_dest = Left(ls_path, ll - 1)
		sle_dest.text = is_dest
	END IF
END IF
end event

type cbx_bytype from checkbox within w_pbl_batch_export
integer x = 343
integer y = 136
integer width = 1280
integer height = 72
integer taborder = 30
integer textsize = -9
fontcharset fontcharset = ansi!
fontpitch fontpitch = variable!
fontfamily fontfamily = swiss!
string facename = "Tahoma"
long backcolor = 67108864
string text = "Buat subfolder per tipe object (Window, DataWindow, ...)"
boolean checked = true
end type

type cb_add from commandbutton within w_pbl_batch_export
integer x = 23
integer y = 232
integer width = 311
integer height = 100
integer taborder = 40
integer textsize = -9
integer weight = 700
fontcharset fontcharset = ansi!
fontpitch fontpitch = variable!
fontfamily fontfamily = swiss!
string facename = "Tahoma"
string text = "Add PBL..."
end type

event clicked;// Multi-select PBL files in one dialog (OFN_EXPLORER | OFN_ALLOWMULTISELECT).
// The multi-select overload requires the file argument to be a STRING ARRAY.
string ls_path, ls_pref, ls_one
string ls_files[]
integer li_rc, i

// Passing a STRING ARRAY for the file argument automatically enables
// the multi-select dialog in PB 11.5 (no flags argument needed).
ls_path = ""
li_rc = GetFileOpenName("Pilih PBL (Ctrl/Shift = multi-pilih)", ls_path, ls_files[], "pbl", &
	"PowerBuilder Library (*.pbl),*.pbl")
IF li_rc < 1 THEN RETURN

// ls_path = directory ; ls_files[] = selected file names
IF Right(ls_path, 1) = "\" THEN
	ls_pref = ls_path
ELSE
	ls_pref = ls_path + "\"
END IF

FOR i = 1 TO UpperBound(ls_files[])
	ls_one = Trim(ls_files[i])
	IF ls_one = "" THEN CONTINUE
	// If the array already holds a full path, use it as-is
	IF Pos(ls_one, ":") > 0 OR Pos(ls_one, "\") > 0 THEN
		wf_addpbl(ls_one)
	ELSE
		wf_addpbl(ls_pref + ls_one)
	END IF
NEXT
end event

type cb_import_pbt from commandbutton within w_pbl_batch_export
integer x = 347
integer y = 232
integer width = 360
integer height = 100
integer taborder = 50
integer textsize = -9
integer weight = 700
fontcharset fontcharset = ansi!
fontpitch fontpitch = variable!
fontfamily fontfamily = swiss!
string facename = "Tahoma"
string text = "Import .pbt..."
end type

event clicked;// Read a PB target (.pbt), parse the LibList line, add every library
string ls_path, ls_file, ls_line, ls_inner, ls_dir, ls_one
integer li_rc, li_h
long ll_p1, ll_p2, ll_start, ll_semi, ll_added
string ls_q

li_rc = GetFileOpenName("Pilih Target (.pbt)", ls_path, ls_file, "pbt", "PB Target (*.pbt),*.pbt")
IF li_rc <> 1 THEN RETURN

ll_p1 = LastPos(ls_path, "\")
IF ll_p1 > 0 THEN ls_dir = Left(ls_path, ll_p1 - 1) ELSE ls_dir = ""

li_h = FileOpen(ls_path, LineMode!, Read!, LockRead!, Replace!, FileEncoding(ls_path))
IF li_h < 1 THEN
	MessageBox("Error", "Tidak bisa membuka file .pbt") ; RETURN
END IF
ls_inner = ""
DO WHILE FileRead(li_h, ls_line) >= 0
	IF Pos(ls_line, "LibList") > 0 THEN
		ls_q = Char(34)
		ll_p1 = Pos(ls_line, ls_q)
		ll_p2 = LastPos(ls_line, ls_q)
		IF ll_p1 > 0 AND ll_p2 > ll_p1 THEN
			ls_inner = Mid(ls_line, ll_p1 + 1, ll_p2 - ll_p1 - 1)
		END IF
		EXIT
	END IF
LOOP
FileClose(li_h)

IF Trim(ls_inner) = "" THEN
	MessageBox("Info", "Baris LibList tidak ditemukan di .pbt") ; RETURN
END IF

ll_start = 1 ; ll_added = 0
DO WHILE ll_start <= Len(ls_inner)
	ll_semi = Pos(ls_inner, ";", ll_start)
	IF ll_semi = 0 THEN
		ls_one = Mid(ls_inner, ll_start) ; ll_start = Len(ls_inner) + 1
	ELSE
		ls_one = Mid(ls_inner, ll_start, ll_semi - ll_start) ; ll_start = ll_semi + 1
	END IF
	ls_one = Trim(ls_one)
	IF ls_one <> "" THEN
		// resolve relative path against the .pbt directory
		IF Pos(ls_one, ":") = 0 AND ls_dir <> "" THEN ls_one = ls_dir + "\" + ls_one
		wf_addpbl(ls_one)
		ll_added ++
	END IF
LOOP
MessageBox("Info", String(ll_added) + " library ditambahkan dari target.")
end event

type cb_remove from commandbutton within w_pbl_batch_export
integer x = 720
integer y = 232
integer width = 260
integer height = 100
integer taborder = 60
integer textsize = -9
fontcharset fontcharset = ansi!
fontpitch fontpitch = variable!
fontfamily fontfamily = swiss!
string facename = "Tahoma"
string text = "Remove"
end type

event clicked;long ll
ll = dw_libs.GetRow()
IF ll > 0 THEN dw_libs.DeleteRow(ll)
end event

type cb_clear from commandbutton within w_pbl_batch_export
integer x = 993
integer y = 232
integer width = 220
integer height = 100
integer taborder = 70
integer textsize = -9
fontcharset fontcharset = ansi!
fontpitch fontpitch = variable!
fontfamily fontfamily = swiss!
string facename = "Tahoma"
string text = "Clear"
end type

event clicked;dw_libs.Reset()
end event

type cb_checkall from commandbutton within w_pbl_batch_export
integer x = 1225
integer y = 232
integer width = 260
integer height = 100
integer taborder = 80
integer textsize = -9
fontcharset fontcharset = ansi!
fontpitch fontpitch = variable!
fontfamily fontfamily = swiss!
string facename = "Tahoma"
string text = "Check All"
end type

event clicked;wf_setall("Y")
end event

type cb_uncheckall from commandbutton within w_pbl_batch_export
integer x = 1497
integer y = 232
integer width = 300
integer height = 100
integer taborder = 90
integer textsize = -9
fontcharset fontcharset = ansi!
fontpitch fontpitch = variable!
fontfamily fontfamily = swiss!
string facename = "Tahoma"
string text = "Uncheck All"
end type

event clicked;wf_setall("")
end event

type cb_export from commandbutton within w_pbl_batch_export
integer x = 1893
integer y = 232
integer width = 530
integer height = 100
integer taborder = 100
integer textsize = -9
integer weight = 700
fontcharset fontcharset = ansi!
fontpitch fontpitch = variable!
fontfamily fontfamily = swiss!
string facename = "Tahoma"
string text = "EXPORT BATCH"
end type

event clicked;wf_run_batch()
end event

type cb_close from commandbutton within w_pbl_batch_export
integer x = 2747
integer y = 232
integer width = 311
integer height = 100
integer taborder = 110
integer textsize = -9
fontcharset fontcharset = ansi!
fontpitch fontpitch = variable!
fontfamily fontfamily = swiss!
string facename = "Tahoma"
string text = "Close"
end type

event clicked;Close(Parent)
end event

type dw_libs from datawindow within w_pbl_batch_export
integer x = 23
integer y = 360
integer width = 3035
integer height = 1232
integer taborder = 120
string title = "none"
string dataobject = "d_pbl_libs"
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

type st_overall from statictext within w_pbl_batch_export
integer x = 23
integer y = 1628
integer width = 384
integer height = 72
integer textsize = -9
fontcharset fontcharset = ansi!
fontpitch fontpitch = variable!
fontfamily fontfamily = swiss!
string facename = "Tahoma"
long textcolor = 33554432
long backcolor = 67108864
boolean background = false
string text = "Overall (library) :"
end type

type hpb_overall from hprogressbar within w_pbl_batch_export
integer x = 416
integer y = 1620
integer width = 2642
integer height = 80
integer setstep = 1
boolean smoothscroll = true
end type

type st_current from statictext within w_pbl_batch_export
integer x = 23
integer y = 1724
integer width = 384
integer height = 72
integer textsize = -9
fontcharset fontcharset = ansi!
fontpitch fontpitch = variable!
fontfamily fontfamily = swiss!
string facename = "Tahoma"
long textcolor = 33554432
long backcolor = 67108864
boolean background = false
string text = "Current PBL (object) :"
end type

type hpb_current from hprogressbar within w_pbl_batch_export
integer x = 416
integer y = 1716
integer width = 2642
integer height = 80
integer setstep = 1
boolean smoothscroll = true
end type

type st_libs from statictext within w_pbl_batch_export
integer x = 23
integer y = 1820
integer width = 1000
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
string text = "Libraries: 0 / 0"
end type

type st_objok from statictext within w_pbl_batch_export
integer x = 1051
integer y = 1820
integer width = 900
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
string text = "Objects OK: 0"
end type

type st_objfail from statictext within w_pbl_batch_export
integer x = 1970
integer y = 1820
integer width = 900
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
