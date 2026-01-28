@echo off
if exist "..\SystemTools\WindowsTools\����" (
  mkdir "..\..\..\����"
  xcopy "..\SystemTools\WindowsTools\����" "..\..\..\����" /y /e
  echo �û��ʿⱸ�����
  rmdir /S /Q "..\SystemTools\WindowsTools\����"
)

if exist "KeyTao.7z" (
  del KeyTao.7z /S /Q
  echo ɾ�����ļ�
)

if exist "KeyTao.exe" (
  del KeyTao.exe /S /Q
  echo ɾ�����ļ�
)


echo ��ʼ����7zip
7z a -m1=LZMA KeyTao.7z ..\..\