# One-time build (must be done inside PowerBuilder 11.5 IDE)

Why this manual step exists: PowerBuilder's external ORCA automation API
(PBORC115.DLL) is SySAM-license-gated on this machine — confirmed by direct
test, even with the IDE closed — and OrcaScript (`orcascr115.exe`) has no
export command at all. The only mechanism that actually works here is
PowerScript's own `LibraryDirectory()` / `LibraryExport()` functions, which
only run inside a compiled PowerBuilder application. There is no way to
produce that compiled application without using the IDE's own Build feature —
i.e. this one step cannot be scripted from outside PowerBuilder.

After this one-time build, everything else is the single PowerShell command
at the bottom — no more manual steps, ever, for future exports.

## 1. Create a new empty target

In the PB 11.5 IDE: File > New > Target > Application, name the library
`pblexporter.pbl`, saved anywhere convenient (e.g. `C:\BTV\debug\pblexporter\`).

## 2. Import the 9 function files

File > Import Source... (or Library painter > right-click > Import), pick this
folder (`C:\BTV\debug\pblexporter\`), select all 9 `.srf` files and import them
into `pblexporter.pbl`:

- gf_pbl_ext.srf
- gf_pbl_ensuredir.srf
- gf_pbl_sanitize.srf
- gf_pbl_log.srf
- gf_pbl_jsonesc.srf
- gf_pbl_writefile.srf
- gf_pbl_readlines.srf
- gf_pbl_export_one.srf
- gf_pbl_main.srf

## 3. Create the Application object

Use File > New > Application Object in the target (so PB generates a
guaranteed-correct skeleton), name it `pblexporter`. Then open its **Open**
event in the Script painter and paste this in place of whatever PB generated:

```powerscript
string ls_jobfile

ls_jobfile = Trim(CommandParm())
IF ls_jobfile = "" THEN
	MessageBox("pblexporter", "Usage: pblexporter.exe <jobfile.txt>")
	Halt Close
END IF

gf_pbl_main(ls_jobfile)

Halt Close
```

(`pblexporter.sra` in this folder is the fully hand-written equivalent, in
case you'd rather import it directly instead — try that first if you like;
fall back to the wizard+paste approach above only if it throws an import
error, and tell me the exact error text so I can fix the file.)

## 4. Full Build, then fix anything that doesn't compile

Design > Full Build (or F7). This is the one point where any typo in the
PowerScript I wrote will show up — as a normal PB compiler error with a file
and line number. If anything fails, paste me the exact error text and I'll
correct the source.

## 5. Create the executable

File > Create Executable (or Project painter). Point it at this same
`pblexporter.pbl`/target, application object `pblexporter`, and save the EXE
anywhere (e.g. `C:\BTV\debug\pblexporter\pblexporter.exe`). No PBDs/DLLs need
bundling beyond the standard PB runtime already on this machine.

## 6. Run the real thing (one command, from now on)

```powershell
C:\BTV\debug\pblexporter\export_all_pbl.ps1 `
    -InputDir "C:\BTV\Apps" `
    -OutputDir "C:\BTV\SOURCE" `
    -ExePath  "C:\BTV\debug\pblexporter\pblexporter.exe"
```

This scans every `.pbl` in `C:\BTV\Apps`, exports each into its own
`C:\BTV\SOURCE\<pblname>\` folder (flat — no per-type subfolders), and writes
`export.log`, `failed_objects.log`, and one `_manifest.json` per PBL folder,
finishing with a FOUND/EXPORTED/FAILED validation table.

## Known, honest limitation

Proxy Object, Binary (embedded bitmaps/icons/cursors), and Service entries
have no PowerScript `LibraryExport` type at all — only the license-blocked
external ORCA API can read them. The tool detects their presence (via a
`LibraryDirectoryEx(..., DirAll!)` cross-check) and logs them as
`skipped_unsupported_type` in `failed_objects.log` and each PBL's manifest,
rather than silently omitting them. If your PBLs turn out to contain any,
exporting those specifically needs either the SySAM ORCA entitlement fixed,
or a manual per-object export from the Library painter.
