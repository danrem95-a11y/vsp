Add-Type @"
using System;
using System.Text;
using System.Runtime.InteropServices;
using System.Collections.Generic;
public class Win {
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);
  [DllImport("user32.dll")] public static extern bool EnumChildWindows(IntPtr hWnd, EnumWindowsProc lpEnumFunc, IntPtr lParam);
  [DllImport("user32.dll")] public static extern int GetWindowText(IntPtr hWnd, StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern int GetClassName(IntPtr hWnd, StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint pid);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr hWnd);
  public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);
  public static uint Target;
  public static List<string> Rows = new List<string>();
  static string Txt(IntPtr h){ var s=new StringBuilder(256); GetWindowText(h,s,256); return s.ToString(); }
  static string Cls(IntPtr h){ var s=new StringBuilder(256); GetClassName(h,s,256); return s.ToString(); }
  public static bool Child(IntPtr h, IntPtr l){ Rows.Add("     child cls='"+Cls(h)+"' txt='"+Txt(h)+"' vis="+IsWindowVisible(h)); return true; }
  public static bool Top(IntPtr h, IntPtr l){
    uint pid; GetWindowThreadProcessId(h, out pid);
    if(pid==Target){ Rows.Add("TOP cls='"+Cls(h)+"' txt='"+Txt(h)+"' vis="+IsWindowVisible(h)); EnumChildWindows(h, Child, IntPtr.Zero); }
    return true;
  }
  public static void Run(uint pid){ Target=pid; Rows.Clear(); EnumWindows(Top, IntPtr.Zero); }
}
"@
$b = Get-Process bottas -ErrorAction SilentlyContinue | Select-Object -First 1
if(-not $b){ Write-Host "bottas.exe tidak berjalan"; exit }
Write-Host ("bottas PID="+$b.Id)
[Win]::Run([uint32]$b.Id)
[Win]::Rows | ForEach-Object { Write-Host $_ }