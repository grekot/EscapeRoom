param([string]$Actions)
# Drives the escape_room.exe window. Actions separated by ';':
#   top | notop | move:x,y,w,h | mclick:x,y | drag:x1,y1,x2,y2 | wheel:x,y,ticks (neg = down)
#   type:text | key:{ENTER} | sleep:sec | shot:name
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms
Add-Type @"
using System; using System.Runtime.InteropServices;
public class UI {
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out R r);
  [DllImport("user32.dll")] public static extern bool ClientToScreen(IntPtr h, ref P p);
  [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h, IntPtr hdc, uint f);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
  [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr a, int x, int y, int cx, int cy, uint f);
  [DllImport("user32.dll")] public static extern void mouse_event(uint f, uint x, uint y, uint d, UIntPtr e);
  [StructLayout(LayoutKind.Sequential)] public struct R { public int L, T, Rt, B; }
  [StructLayout(LayoutKind.Sequential)] public struct P { public int X, Y; }
  public static void Down() { mouse_event(0x0002, 0, 0, 0, UIntPtr.Zero); }
  public static void Up() { mouse_event(0x0004, 0, 0, 0, UIntPtr.Zero); }
  public static void Wheel(int delta) { mouse_event(0x0800, 0, 0, unchecked((uint)delta), UIntPtr.Zero); }
}
"@
$p = Get-Process escape_room -ErrorAction Stop | Where-Object { $_.MainWindowHandle -ne 0 } | Sort-Object { $_.MainWindowTitle.Length } -Descending | Select-Object -First 1
$h = $p.MainWindowHandle

function ToScreen($x, $y) {
  $pt = New-Object UI+P; $pt.X = $x; $pt.Y = $y
  [UI]::ClientToScreen($h, [ref]$pt) | Out-Null
  return $pt
}

foreach ($a in ($Actions -split ';')) {
  $kind, $arg = $a -split ':', 2
  switch ($kind) {
    'top'   { [UI]::SetWindowPos($h, [IntPtr](-1), 0, 0, 0, 0, 0x3) | Out-Null; [UI]::SetForegroundWindow($h) | Out-Null; Start-Sleep -Milliseconds 400 }
    'notop' { [UI]::SetWindowPos($h, [IntPtr](-2), 0, 0, 0, 0, 0x3) | Out-Null }
    'move' {
      $x, $y, $w, $ht = ($arg -split ',') | ForEach-Object { [int]$_ }
      [UI]::SetWindowPos($h, [IntPtr]::Zero, $x, $y, $w, $ht, 0x4) | Out-Null; Start-Sleep -Milliseconds 700
    }
    'mclick' {
      $x, $y = ($arg -split ',') | ForEach-Object { [int]$_ }
      $pt = ToScreen $x $y
      [UI]::SetCursorPos($pt.X, $pt.Y) | Out-Null; Start-Sleep -Milliseconds 150
      [UI]::Down(); Start-Sleep -Milliseconds 90; [UI]::Up(); Start-Sleep -Milliseconds 500
    }
    'drag' {
      $x1, $y1, $x2, $y2 = ($arg -split ',') | ForEach-Object { [int]$_ }
      $pt = ToScreen $x1 $y1
      [UI]::SetCursorPos($pt.X, $pt.Y) | Out-Null; Start-Sleep -Milliseconds 120
      [UI]::Down(); Start-Sleep -Milliseconds 700
      for ($i = 1; $i -le 20; $i++) {
        $pt2 = ToScreen ($x1 + ($x2 - $x1) * $i / 20) ($y1 + ($y2 - $y1) * $i / 20)
        [UI]::SetCursorPos($pt2.X, $pt2.Y) | Out-Null; Start-Sleep -Milliseconds 30
      }
      Start-Sleep -Milliseconds 200; [UI]::Up(); Start-Sleep -Milliseconds 500
    }
    'wheel' {
      $x, $y, $t = ($arg -split ',') | ForEach-Object { [int]$_ }
      $pt = ToScreen $x $y
      [UI]::SetCursorPos($pt.X, $pt.Y) | Out-Null; Start-Sleep -Milliseconds 200
      for ($i = 0; $i -lt [math]::Abs($t); $i++) { [UI]::Wheel($(if ($t -lt 0) { -120 } else { 120 })); Start-Sleep -Milliseconds 70 }
      Start-Sleep -Milliseconds 700
    }
    'type'  { [UI]::SetForegroundWindow($h) | Out-Null; Start-Sleep -Milliseconds 200; [System.Windows.Forms.SendKeys]::SendWait($arg); Start-Sleep -Milliseconds 300 }
    'key'   { [UI]::SetForegroundWindow($h) | Out-Null; Start-Sleep -Milliseconds 200; [System.Windows.Forms.SendKeys]::SendWait($arg); Start-Sleep -Milliseconds 300 }
    'sleep' { Start-Sleep -Seconds ([double]$arg) }
    'shot' {
      $r = New-Object UI+R; [UI]::GetWindowRect($h, [ref]$r) | Out-Null
      $w = $r.Rt - $r.L; $ht = $r.B - $r.T
      $bmp = New-Object System.Drawing.Bitmap $w, $ht
      $g = [System.Drawing.Graphics]::FromImage($bmp); $hdc = $g.GetHdc()
      [UI]::PrintWindow($h, $hdc, 2) | Out-Null; $g.ReleaseHdc($hdc)
      $bmp.Save("C:\TMP\jtmp\$arg.png"); $g.Dispose(); $bmp.Dispose()
      Write-Output "shot C:\TMP\jtmp\$arg.png ($w x $ht)"
    }
  }
}

