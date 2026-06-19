setlocal
set path=C:\Program Files (x86)\SQL Anywhere 11\Bin32;;%path%
set classpath=C:\Program Files (x86)\SQL Anywhere 11\Bin32\..\java\isql.jar;C:\Program Files (x86)\SQL Anywhere 11\Bin32\..\java\jlogon.jar;C:\Program Files (x86)\SQL Anywhere 11\Bin32\..\java\SCEditor600.jar;C:\Program Files (x86)\SQL Anywhere 11\Bin32\..\java\JComponents1100.jar;C:\Program Files (x86)\SQL Anywhere 11\Bin32\..\java\jsyblib600.jar;C:\Program Files (x86)\SQL Anywhere 11\Bin32\..\sun\javahelp-2_0\jh.jar
"C:\Program Files (x86)\SQL Anywhere 11\Bin32\..\sun\jre160_x86\bin\java.exe"  -Dsun.java2d.noddraw=true -Dsun.java2d.d3d=false -ea sybase.isql.isql  "-input" "C:\Users\USer\AppData\Local\Temp\test.sql" 
endlocal
