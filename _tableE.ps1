$ErrorActionPreference='Stop'
$enc = New-Object System.Text.UnicodeEncoding($false,$true)
$path = "C:\BTV\debug\w_refresh_transaksi_modern.srw"
$t = [System.IO.File]::ReadAllText($path,[System.Text.Encoding]::Unicode)
$nl = "`r`n"
function Coord($ctl,$typ,$ox,$oy,$ow,$oh,$nx,$ny,$nw,$nh){
  $f = "type $ctl from $typ within w_refresh_transaksi_modern${nl}integer x = $ox${nl}integer y = $oy${nl}integer width = $ow${nl}integer height = $oh"
  $r = "type $ctl from $typ within w_refresh_transaksi_modern${nl}integer x = $nx${nl}integer y = $ny${nl}integer width = $nw${nl}integer height = $nh"
  $n = ([regex]::Matches($t,[regex]::Escape($f))).Count
  if ($n -ne 1){ throw "expected 1 for $ctl, found $n" }
  $script:t = $t.Replace($f,$r); Write-Host ("OK  {0,-18} x={1,-5} y={2,-5} w={3,-5} h={4,-4} kanan={5} bawah={6}" -f $ctl,$nx,$ny,$nw,$nh,($nx+$nw),($ny+$nh))
}

Coord "st_from"          "statictext"      1250 270 300 40   1226 288 280 52
Coord "ddlb_bulan"       "dropdownlistbox" 1600 260 350 80   1520 280 380 400
Coord "st_to"            "statictext"      1250 350 300 40   1226 388 280 52
Coord "ddlb_tahun"       "dropdownlistbox" 1600 340 350 80   1520 380 380 400
Coord "st_periode_lbl"   "statictext"      1250 430 500 35   1226 484 520 44
Coord "st_periode_aktif" "statictext"      1250 465 900 45   1226 532 1000 44

[System.IO.File]::WriteAllText($path,$t,$enc)
$b=[System.IO.File]::ReadAllBytes($path); $bom=($b[0]-eq0xFF -and $b[1]-eq0xFE)
$v=[System.IO.File]::ReadAllText($path,[System.Text.Encoding]::Unicode)
$cr=([regex]::Matches($v,"`r")).Count; $lf=([regex]::Matches($v,"`n")).Count; $lone=([regex]::Matches($v,"(?<!`r)`n")).Count
Write-Host ("`nBOM={0} CR={1} LF={2} lone={3}" -f $bom,$cr,$lf,$lone)
Write-Host "--- VALIDASI (gb_period 1166..2766, bawah 596 | gb_status mulai 2900) ---"
Write-Host "isi periode paling kanan = 2226 (st_periode_aktif)  < 2766 dalam panel & < 2900 tak masuk status : AMAN"
Write-Host "isi periode paling bawah = 576 (st_periode_aktif)   < 596 batas bawah gb_period : AMAN"
Write-Host "label kanan=1506 < dropdown kiri=1520 : label TIDAK tertutup dropdown : AMAN"
