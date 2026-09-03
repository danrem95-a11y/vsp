forward
global type w_ddo_base32 from window
end type
type p_1 from picture within w_ddo_base32
end type
end forward

global type w_ddo_base32 from window
integer x = 832
integer y = 356
integer width = 485
integer height = 468
windowtype windowtype = popup!
long backcolor = 79741120
boolean toolbarvisible = false
event command pbm_command
p_1 p_1
end type
global w_ddo_base32 w_ddo_base32

type prototypes

end prototypes

type variables
datawindow	idw_source,idw_list
end variables
event open;n_ddo_WinAPI32 luo_WinAPI
integer	li_X, li_Y

// get reference to the datawindow
luo_WinAPI = Message.PowerObjectParm

if NOT isValid(luo_WinAPI) then 
	// failed to find parent datawindow
	beep(3)
	MessageBox("Program Error", "Unable to find parent datawindow", StopSign!)
	close(this)
end if

idw_source = luo_WinAPI.idw_source

// convert from pixels to PowerBuilder units
li_X = min(luo_WinAPI.ii_X, PixelsToUnits(luo_WinAPI.ienv_Env.ScreenWidth, &
	XPixelsToUnits!) - this.Width )

if luo_WinAPI.ii_Y + this.Height + 200 > PixelsToUnits(luo_WinAPI.ienv_Env.ScreenHeight, &
	YPixelsToUnits!) then

	li_Y = luo_WinAPI.ii_Y  - this.Height - luo_WinAPI.ii_Height
else
	li_Y = luo_WinAPI.ii_Y 
end if

// position this window under active column
this.Move(li_X, li_Y)


end event

on w_ddo_base32.create
this.p_1=create p_1
this.Control[]={this.p_1}
end on

on w_ddo_base32.destroy
destroy(this.p_1)
end on

event deactivate;// Focus Lost
Close(this)

end event

event key;// If Escape key was pressed than cancel drop-down dialog
if KeyDown(KeyEscape!) then close(this)
end event

event close;if isValid(idw_source) then idw_source.AcceptText()
end event

type p_1 from picture within w_ddo_base32
boolean visible = false
integer x = 261
integer y = 116
integer width = 73
integer height = 64
boolean originalsize = true
string picturename = "kanan.bmp"
boolean focusrectangle = false
end type

