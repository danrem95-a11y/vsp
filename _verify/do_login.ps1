Add-Type @"
using System;
using System.Text;
using System.Runtime.InteropServices;
using System.Collections.Generic;
public class U {
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc f, IntPtr l);
  [DllImport("user32.dll")] public static extern bool EnumChildWindows(IntPtr h, EnumProc f, IntPtr l);
  [DllImport("user32.dll")] public static extern int GetClassName(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint p);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll")] public static extern int GetWindowLong(IntPtr h, int i);
  [DllImport("user32.dll", CharSet=CharSet.Auto)] public static extern IntPtr SendMessage(IntPtr h, uint m, IntPtr w, string l);
  [DllImport("user32.dll")] public static extern IntPtr SendMessage(IntPtr h, uint m, IntPtr w, IntPtr l);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  public delegate bool EnumProc(IntPtr h, IntPtr l);
  public static uint Target;
  public static List<IntPtr> Edits=new List<IntPtr>();
  public static IntPtr LoginBtn=IntPtr.Zero, LoginWin=IntPtr.Zero, Combo=IntPtr.Zero;
  public static string Cls(IntPtr h){var s=new StringBuilder(256);GetClassName(h,s,256);return s.ToString();}
  public static string Txt(IntPtr h){var s=new StringBuilder(256);GetWindowText(h,s,256);return s.ToString();}
  static bool ChildCb(IntPtr h, IntPtr l){
    string c=Cls(h);
    if(c=="Edit" && IsWindowVisible(h)) Edits.Add(h);
    if(c=="ComboBox" && IsWindowVisible(h)) Combo=h;
    if(c=="Button" && Txt(h)=="Login") LoginBtn=h;
    return true;
  }
  static bool TopCb(IntPtr h, IntPtr l){
    uint p; GetWindowThreadProcessId(h, out p);
    if(p==Target && Cls(h)=="FNWNS3115" && IsWindowVisible(h)){ LoginWin=h; EnumChildWindows(h, ChildCb, IntPtr.Zero); }
    return true;
  }
  public static void Scan(uint pid){ Target=pid; Edits.Clear(); LoginBtn=IntPtr.Zero; LoginWin=IntPtr.Zero; Combo=IntPtr.Zero; EnumWindows(TopCb, IntPtr.Zero); }
}
"@
$b = Get-Process bottas -ErrorAction SilentlyContinue | Select-Object -First 1
if(-not $b){ Write-Host "bottas tidak berjalan"; exit }
[U]::Scan([uint32]$b.Id)
Write-Host ("LoginWin=" + [U]::LoginWin + "  Edits=" + [U]::Edits.Count + "  LoginBtn=" + [U]::LoginBtn + "  Combo=" + [U]::Combo)
if([U]::Combo -ne [IntPtr]::Zero){ Write-Host ("Server combo text = '" + [U]::Txt([U]::Combo) + "'") }
if([U]::Edits.Count -lt 2 -or [U]::LoginBtn -eq [IntPtr]::Zero){ Write-Host "Kontrol login tidak lengkap ditemukan"; exit }

$WM_SETTEXT=0x000C; $BM_CLICK=0x00F5; $GWL_STYLE=-16; $ES_PASSWORD=0x0020
# identifikasi field password via style ES_PASSWORD
$eA=[U]::Edits[0]; $eB=[U]::Edits[1]
$sA=[U]::GetWindowLong($eA,$GWL_STYLE); $sB=[U]::GetWindowLong($eB,$GWL_STYLE)
if(($sA -band $ES_PASSWORD) -ne 0){ $pass=$eA; $user=$eB } else { $pass=$eB; $user=$eA }
Write-Host ("user-edit=" + $user + "  pass-edit=" + $pass)
[void][U]::SendMessage($user,$WM_SETTEXT,[IntPtr]::Zero,"super")
[void][U]::SendMessage($pass,$WM_SETTEXT,[IntPtr]::Zero,"w1r4s")
Write-Host ("Terisi -> user='" + [U]::Txt($user) + "' pass(len)=" + ([U]::Txt($pass)).Length)
Start-Sleep -Milliseconds 300
[void][U]::SetForegroundWindow([U]::LoginWin)
[void][U]::SendMessage([U]::LoginBtn,$BM_CLICK,[IntPtr]::Zero,[IntPtr]::Zero)
Write-Host "Klik Login terkirim. Menunggu hasil..."

# verifikasi: koneksi DB established + window utama muncul
$conn=$null; $mainWin=$false
for($i=0;$i -lt 25;$i++){
  Start-Sleep -Milliseconds 800
  $c = Get-NetTCPConnection -OwningProcess $b.Id -State Established -ErrorAction SilentlyContinue | Where-Object { $_.RemoteAddress -eq '103.233.89.43' -and $_.RemotePort -eq 2638 }
  if($c){ $conn=$c }
  $b.Refresh()
  if($b.MainWindowTitle -and $b.MainWindowTitle.Length -gt 0){ $mainWin=$true }
  if($conn -and $mainWin){ break }
}
Write-Host ""
Write-Host ("KONEKSI DB prod : " + ([bool]$conn) + $(if($conn){" -> "+$conn.RemoteAddress+":"+$conn.RemotePort}else{""}))
$b.Refresh()
Write-Host ("Proses hidup    : " + (-not $b.HasExited))
Write-Host ("MainWindowTitle : '" + $b.MainWindowTitle + "'")
# cek dialog error (#32770) milik bottas
[U]::Scan([uint32]$b.Id)  # rescan login win presence
Write-Host ("Login window masih tampil? : " + ([U]::LoginWin -ne [IntPtr]::Zero))