function T($lbl,$cs){
  $cn=New-Object System.Data.Odbc.OdbcConnection $cs
  try{ $cn.Open(); $c=$cn.CreateCommand(); $c.CommandText="select db_name(),property('Name')"; $rd=$c.ExecuteReader(); $rd.Read()
       Write-Host ("   OK  $lbl -> db="+[string]$rd[0]+" server="+[string]$rd[1]); $rd.Close(); $cn.Close() }
  catch{ Write-Host ("   GAGAL $lbl : "+($_.Exception.Message -replace "`r`n"," ")) }
}
# FRAMENEW apa adanya (ENG=vsp) - tanpa SharedMemory (paksa TCP ke prod)
T "FRAMENEW ENG=vsp  TCP prod" "DRIVER=Adaptive Server Anywhere 9.0;UID=dba;PWD=jakarta;CommLinks=TCPIP{host=103.233.89.43:2638};EngineName=vsp"
# FRAMENEW apa adanya persis (SharedMemory,TCPIP + ENG=vsp)
T "FRAMENEW persis (SharedMemory,TCP ENG=vsp)" "DRIVER=Adaptive Server Anywhere 9.0;UID=dba;PWD=jakarta;CommLinks=SharedMemory,TCPIP{host=103.233.89.43:2638};EngineName=vsp"
# Koreksi: ENG=vspnew
T "FRAMENEW koreksi ENG=vspnew" "DRIVER=Adaptive Server Anywhere 9.0;UID=dba;PWD=jakarta;CommLinks=SharedMemory,TCPIP{host=103.233.89.43:2638};EngineName=vspnew"
