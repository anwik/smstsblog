:: This script will find the builtin product key and use it to activate Windows

@echo off
SetLocal EnableDelayedExpansion 
set count=0 
for /F "delims=" %%a in ('wmic path softwarelicensingservice get oa3xoriginalproductkey') do ( 
  set key=%%a 
  set /a count=!count! + 1 
  if !count! GTR 1 goto Exit 
) 
:Exit 
echo Key=%key% 
 
cscript //NoLogo //B %windir%\system32\slmgr.vbs /ipk %key% 
cscript //NoLogo //B %windir%\system32\slmgr.vbs /ato