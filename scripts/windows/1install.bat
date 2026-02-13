@echo off
mode con cols=45 lines=20
echo 小狼毫安装引导程序
echo ======================
echo 1、安装小狼毫输入法扩展程序
"%CD%\app\weasel-expansion-0.9.18.0.exe"
echo .
echo ======================
echo 2、复制码表，并自动部署
"%CD%\2update.bat"
exit