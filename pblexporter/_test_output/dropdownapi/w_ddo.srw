forward
global type w_ddo from w_ddo_base32
end type
type dw_1 from uo_dw within w_ddo
end type
type st_1 from statictext within w_ddo
end type
type sle_find from singlelineedit within w_ddo
end type
end forward

global type w_ddo from w_ddo_base32
integer width = 2345
integer height = 1268
long backcolor = 134217730
dw_1 dw_1
st_1 st_1
sle_find sle_find
end type
global w_ddo w_ddo

type variables
string is_find,is_code
end variables

on w_ddo.create
int iCurrent
call super::create
this.dw_1=create dw_1
this.st_1=create st_1
this.sle_find=create sle_find
iCurrent=UpperBound(this.Control)
this.Control[iCurrent+1]=this.dw_1
this.Control[iCurrent+2]=this.st_1
this.Control[iCurrent+3]=this.sle_find
end on

on w_ddo.destroy
call super::destroy
destroy(this.dw_1)
destroy(this.st_1)
destroy(this.sle_find)
end on

event open;call super::open;sle_find.setfocus()
is_code = this.tag
dw_1.retrieve()

end event

event key;call super::key;integer li_row


if KeyDown(KeyEnter!) then

	li_row = dw_1.GetRow()
	if li_row <= 0 then return
	
	idw_source.SetText(dw_1.GetItemString(li_row, is_code))
							 
	close(this)
end if
end event

type p_1 from w_ddo_base32`p_1 within w_ddo
end type

type dw_1 from uo_dw within w_ddo
integer x = 5
integer width = 2331
integer height = 1132
integer taborder = 10
boolean bringtotop = true
string is_type_dw = "LIST"
boolean ib_readonly = true
end type

event ue_edit;call super::ue_edit;// DoubleClicked Script for dw_1
if getRow() > 0 then 
	idw_source.SetText(GetItemString(GetRow(), is_code))
	close(Parent)
end if

end event

event doubleclicked;call super::doubleclicked;triggerevent('ue_edit')
end event

type st_1 from statictext within w_ddo
integer x = 14
integer y = 1148
integer width = 402
integer height = 80
boolean bringtotop = true
integer textsize = -10
integer weight = 700
fontcharset fontcharset = ansi!
fontpitch fontpitch = variable!
fontfamily fontfamily = swiss!
string facename = "Tahoma"
long textcolor = 16777215
long backcolor = 134217730
string text = "Search :"
alignment alignment = right!
boolean focusrectangle = false
end type

type sle_find from singlelineedit within w_ddo
event change pbm_enchange
integer x = 434
integer y = 1144
integer width = 1865
integer height = 92
integer taborder = 20
boolean bringtotop = true
integer textsize = -10
integer weight = 700
fontcharset fontcharset = ansi!
fontpitch fontpitch = variable!
fontfamily fontfamily = swiss!
string facename = "Tahoma"
long textcolor = 33554432
borderstyle borderstyle = stylelowered!
end type

event change;//////////singlelineedit>>> pbm_enchange
string ls_nama

ls_nama = upper(sle_find.text)
if isnull(ls_nama) then ls_nama = ''

if ls_nama = '' then
	dw_1.setfilter('')
else	
	dw_1.setfilter('upper(is_find) like "%' + ls_nama + '%"')
end if
dw_1.filter()
dw_1.sort()
dw_1.groupcalc()
if dw_1.rowcount()>0 then
	dw_1.setrow(1)
end if


end event

