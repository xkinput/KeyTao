@echo off
CLS
mode con cols=80 lines=20
title 小狼毫重新部署工具

echo 正在尝试自动部署！
echo 请稍等...

set weaselVersion=0.14.3
set weaselInstallPath="C:\Program Files (x86)\Rime\weasel-%weaselVersion%"

if exist %weaselInstallPath%\WeaselDeployer.exe (
  %weaselInstallPath%\WeaselDeployer.exe /deploy
)

cls
echo 部署完成！
echo 更新完成，可以关闭我了

if exist %weaselInstallPath%\WeaselServer.exe (
  %weaselInstallPath%\WeaselServer.exe
)

exit
