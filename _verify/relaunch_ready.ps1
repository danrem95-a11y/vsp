Add-Type @"
using System; using System.Text; using System.Runtime.InteropServices; using System.Collections.Generic;
public class W2 {
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc f, IntPtr l);
  [DllImport("user32.dll")] public static extern bool EnumChildWindows(IntPtr h, EnumProc f, IntPtr l);
  [DllImport("user32.dll")] public static extern int GetClassName(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint p);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll")] public static extern IntPtr SendMessage(IntPtr h, uint m, IntPtr w, StringBuilder l);
  [DllImport("user32.dll")] public static extern IntPtr SendMessage(IntPtr h, uint m, IntPtr w, IntPtr l);
  public delegate bool EnumProc(IntPtr h, IntPtr l);
  public static uint Target; public static bool LoginSeen=false; public static IntPtr Combo=IntPtr.Zero; public static List<string> ComboItems=new List<string>();
  static string Cls(IntPtr h){var s=new StringBuilder(256);GetClassName(h,s,256);return s.ToString();}
  static bool ChildCb(IntPtr h, IntPtr l){ if(Cls(h)=="ComboBox" && IsWindowVisible(h)){ Combo=h;
      int n=(int)SendMessage(h,0x0146,IntPtr.Zero,IntPtr.Zero); /*CB_GETCOUNT*/
      for(int i=0;i<n;i++){ var sb=new StringBuilder(256); SendMessage(h,0x0148,(IntPtr)i,sb); ComboItems.Add(sb.ToString()); } }
    return true; }
  static bool TopCb(IntPtr h, IntPtr l){ uint p; GetWindowThreadProcessId(h,out p);
    if(p==Target && Cls(h)=="FNWNS3115" && IsWindowVisible(h)){ LoginSeen=true; EnumChildWindows(h,ChildCb,IntPtr.Zero); } return true; }
  public static void Scan(uint pid){ Target=pid; LoginSeen=false; Combo=IntPtr.Zero; ComboItems.Clear(); EnumWindows(TopCb,IntPtr.Zero); }
}
"@
# tutup instance lama kalau masih ada
Get-Process bottas -ErrorAction SilentlyContinue | ForEach-Object { try{$_.Kill()}catch{} }
Start-Sleep -Milliseconds 800
$p = Start-Process "C:\Bottas 2015\bottas.exe" -WorkingDirectory "C:\Bottas 2015" -PassThru
Write-Host ("Relaunch PID="+$p.Id)
for($i=0;$i -lt 12;$i++){ Start-Sleep -Milliseconds 700; [W2]::Scan([uint32]$p.Id); if([W2]::LoginSeen -and [W2]::ComboItems.Count -gt 0){break} }
$p.Refresh()
Write-Host ("Proses hidup       : " + (-not $p.HasExited))
Write-Host ("Layar login tampil : " + [W2]::LoginSeen)
Write-Host ("Pilihan Server (dropdown):")
if([W2]::ComboItems.Count -eq 0){ Write-Host "   (belum termuat / kosong)" } else { [W2]::ComboItems | ForEach-Object { Write-Host ("   - "+$_) } }