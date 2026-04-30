@echo off
CLS
mode con cols=80 lines=20
title С�Ǻ�������ƹ���
:init
setlocal DisableDelayedExpansion
set "batchPath=%~0"
for %%k in (%0) do set batchName=%%~nk
set "vbsGetPrivileges=%temp%\OEgetPriv_%batchName%.vbs"
setlocal EnableDelayedExpansion
:checkPrivileges
NET FILE 1>NUL 2>NUL
if '%errorlevel%' == '0' ( goto gotPrivileges ) else ( goto getPrivileges )
:getPrivileges
if '%1'=='ELEV' (echo ELEV & shift /1 & goto gotPrivileges)
ECHO.
ECHO ********************************
ECHO ���� UAC Ȩ����׼����
ECHO ********************************
ECHO Set UAC = CreateObject^("Shell.Application"^) > "%vbsGetPrivileges%"
ECHO args = "ELEV " >> "%vbsGetPrivileges%"
ECHO For Each strArg in WScript.Arguments >> "%vbsGetPrivileges%"
ECHO args = args ^& strArg ^& " "  >> "%vbsGetPrivileges%"
ECHO Next >> "%vbsGetPrivileges%"
ECHO UAC.ShellExecute "!batchPath!", args, "", "runas", 1 >> "%vbsGetPrivileges%"
"%SystemRoot%\System32\WScript.exe" "%vbsGetPrivileges%" %*
exit /B
:gotPrivileges
setlocal & pushd .
cd /d %~dp0
if '%1'=='ELEV' (del "%vbsGetPrivileges%" 1>nul 2>nul  &  shift /1)

set gitBash=git

echo ����git�汾Ϊ��
%gitBash% --version
echo.

if %ERRORLEVEL% EQU 0 (
  echo ��ȡ���������
  %gitBash% pull origin master
  echo ��ȡ����������
) else (
  cls
  echo.
  echo δ��װgit�����밲װgit����https://git-scm.com/install/windows
  ping -n 3 127.1 >nul
  echo.
  echo ʮ����Զ��˳�...
  ping -n 10 127.1 >nul
  exit
)
echo.
echo 3���ʼ���£�Ctrl + Cֹͣ����
ping -n 3 127.1 >nul

Setlocal enabledelayedexpansion
set rimeUserDir=%APPDATA%\Rime
for /f "skip=2 delims=: tokens=1,*" %%i in ('reg query "HKEY_CURRENT_USER\SOFTWARE\Rime\Weasel" /v "RimeUserDir"') do (
   set str=%%i
   set var=%%j
   set "var=!var:"=!"
   if not "!var:~-1!"=="=" set rimeUserDir=!str:~-1!:!var!
)

if exist "%CD%\����\" (
  del "%CD%\����\" /S /Q
) else (
  mkdir "%CD%\����\"
)
xcopy "%rimeUserDir%" "%CD%\����\" /Y /E
cls
echo ����ԭ�дʿ�		���

taskkill /f /im WeaselServer.exe
del "%rimeUserDir%\" /S /Q
xcopy "..\..\rime" "%rimeUserDir%\" /Y /E
echo ��������ļ�		���

xcopy "..\..\schema\desktop\*" "%rimeUserDir%\" /Y /E
echo ���ƶ�������		���

xcopy "..\..\schema\windows\*" "%rimeUserDir%\" /Y /E
echo ���ƶ���Ĳ�ƽ̨����		���

cls

if exist "%CD%\�û�����\" (
  xcopy ".\�û�����\*" "%rimeUserDir%\" /Y /E
  echo ��ԭ�û�����		���
) else (
  mkdir "%CD%\�û�����\"
)

echo.
echo.

echo �Ѱ�װ��ɣ�
echo.
echo ���²���
"%CD%\4deploy.bat"
exit
