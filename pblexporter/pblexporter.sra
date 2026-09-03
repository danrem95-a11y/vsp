$PBExportHeader$pblexporter.sra
global type pblexporter from application
end type
global pblexporter pblexporter

on pblexporter.create
end on

on pblexporter.destroy
end on

event open;// Headless batch entry point - no window is ever opened.
// CommandParm() must be the path to a small 2-line job file written by the
// PowerShell driver (line 1 = worklist file, line 2 = output SOURCE root).
string ls_jobfile

ls_jobfile = Trim(CommandParm())
IF ls_jobfile = "" THEN
	MessageBox("pblexporter", "Usage: pblexporter.exe <jobfile.txt>")
	Halt Close
END IF

gf_pbl_main(ls_jobfile)

Halt Close
end event
