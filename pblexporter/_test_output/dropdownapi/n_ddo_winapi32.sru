forward
global type n_ddo_winapi32 from nonvisualobject
end type
type ust_rect16 from structure within n_ddo_winapi32
end type
type ust_rect32 from structure within n_ddo_winapi32
end type
type ust_point16 from structure within n_ddo_winapi32
end type
type ust_point32 from structure within n_ddo_winapi32
end type
end forward

type ust_rect16 from structure
	integer		left
	integer		top
	integer		right
	integer		bottom
end type

type ust_rect32 from structure
	long		left
	long		top
	long		right
	long		bottom
end type

type ust_point16 from structure
	integer		left
	integer		top
end type

type ust_point32 from structure
	long		left
	long		top
end type

global type n_ddo_winapi32 from nonvisualobject
end type
global n_ddo_winapi32 n_ddo_winapi32

type prototypes
// 16 - bit functions
FUNCTION uint GetFocus16()  LIBRARY "user.exe" ALIAS FOR "GetFocus"
SUBROUTINE GetWindowRect16(uint hwnd, REF ust_RECT16 RECT)  LIBRARY "user.exe" ALIAS FOR "GetWindowRect;Ansi"

// 32 - bit functions
FUNCTION uint GetFocus32()  LIBRARY "user32.dll" ALIAS FOR "GetFocus"
FUNCTION boolean GetWindowRect32(uint hwnd, REF ust_RECT32 RECT)  LIBRARY "user32.dll" ALIAS FOR "GetWindowRect;Ansi"

end prototypes

type variables
datawindow	idw_source
window		iw_Parent
integer		ii_X, ii_Y, ii_Height

environment 		ienv_Env
ust_RECT16		ist_RECT16
ust_RECT32		ist_RECT32
ust_POINT16		ist_POINT16
ust_POINT32		ist_POINT32
end variables

on n_ddo_winapi32.create
call super::create
TriggerEvent( this, "constructor" )
end on

on n_ddo_winapi32.destroy
TriggerEvent( this, "destructor" )
call super::destroy
end on

