@echo off
CLS
mode con cols=80 lines=20
title 小狼毫重新部署工具
setlocal DisableDelayedExpansion

echo 正在尝试自动部署！
echo 请稍等...

set "weaselInstallPath="
for /f "tokens=2,*" %%i in ('reg query "HKLM\SOFTWARE\Rime\Weasel" /v WeaselRoot 2^>nul') do set "weaselInstallPath=%%j"
if not defined weaselInstallPath (
  for /f "tokens=2,*" %%i in ('reg query "HKLM\SOFTWARE\WOW6432Node\Rime\Weasel" /v WeaselRoot 2^>nul') do set "weaselInstallPath=%%j"
)

if not defined weaselInstallPath (
  echo 错误：未找到小狼毫安装路径，请先安装小狼毫。
  pause
  exit /b 1
)
if not exist "%weaselInstallPath%\WeaselDeployer.exe" (
  echo 错误：安装目录中未找到 WeaselDeployer.exe，无法部署。
  pause
  exit /b 1
)
"%weaselInstallPath%\WeaselDeployer.exe" /deploy
if errorlevel 1 (
  echo 错误：小狼毫部署失败。
  pause
  exit /b 1
)

cls
echo 部署完成！
echo 更新完成，可以关闭我了

if exist "%weaselInstallPath%\WeaselServer.exe" (
  "%weaselInstallPath%\WeaselServer.exe"
)

exit
