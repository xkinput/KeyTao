#!/bin/bash
outFileName=键道6词库.txt
if [ ! -f "./$outFileName" ];then
  echo "将创建词库文件"
else
  rm -rf ./$outFileName
  echo "删除旧词库文件"
fi

cat >>./$outFileName<< EOF
--多多键道6--
EOF

if [ ! -f "../../rime/xkjd6.danzi.dict.yaml" ];then
  echo "合并单字失败  ERR"
else
  cat ../../rime/xkjd6.danzi.dict.yaml >> ./$outFileName
  echo "合并单字  OK"
fi

if [ ! -f "../../rime/xkjd6.wxw.dict.yaml" ];then
  echo "合并声笔失败  ERR"
else
  cat ../../rime/xkjd6.wxw.dict.yaml >> ./$outFileName
  echo "合并声笔  OK"
fi

if [ ! -f "../../rime/xkjd6.cizu.dict.yaml" ];then
  echo "合并词组失败  ERR"
else
  cat ../../rime/xkjd6.cizu.dict.yaml >> ./$outFileName
  echo "合并词组  OK"
fi

if [ ! -f "../../rime/xkjd6.buchong.dict.yaml" ];then
  echo "合并补充失败  ERR"
else
  cat ../../rime/xkjd6.buchong.dict.yaml >> ./$outFileName
  echo "合并补充  OK"
fi

if [ ! -f "../../rime/xkjd6.chaojizici.dict.yaml" ];then
  echo "合并超级字词失败  ERR"
else
  cat ../../rime/xkjd6.chaojizici.dict.yaml >> ./$outFileName
  echo "合并超级字词  OK"
fi

if [ ! -f "../../rime/xkjd6.yingwen.dict.yaml" ];then
  echo "合并英文失败  ERR"
else
  cat ../../rime/xkjd6.yingwen.dict.yaml >> ./$outFileName
  echo "合并英文  OK"
fi

if [ ! -f "../../rime/xkjd6.biaodian.dict.yaml" ];then
  echo "合并标点失败  ERR"
else
  cat ../../rime/xkjd6.biaodian.dict.yaml >> ./$outFileName
  echo "合并标点  OK"
fi

if [ ! -f "../../rime/xkjd6.fuhao.dict.yaml" ];then
  echo "合并符号失败  ERR"
else
  cat ../../rime/xkjd6.fuhao.dict.yaml >> ./$outFileName
  echo "合并符号  OK"
fi

if [ ! -f "../../rime/xkjd6.lianjie.dict.yaml" ];then
  echo "合并链接失败  ERR"
else
  cat ../../rime/xkjd6.lianjie.dict.yaml >> ./$outFileName
  echo "合并链接  OK"
fi

sed -i ":a;N;s/\n*---\n*//g;ta" ./$outFileName
sed -i ":a;N;s/\n*\.\.\.\n*//g;ta" ./$outFileName
sed -i ":a;N;s/\n*name:\s.*\n*//g;ta" ./$outFileName
sed -i ":a;N;s/\n*version:\s.*\n*//g;ta" ./$outFileName
sed -i ":a;N;s/\n*sort:\s.*\n*//g;ta" ./$outFileName
echo "去除各头信息 OK"

cat >>./$outFileName<< EOF
\$ddcmd(run(calc.exe),[计算器])	ojs
\$ddcmd(run(notepad.exe),[记事本])	oje
\$ddcmd(run(mspaint.exe),[画图])	oht
\$ddcmd(config(/do 剪贴板反查),[剪贴板反查])	ojw
\$ddcmd(config(/do 输出反查),[反查]：<last.1>)	oew
\$ddcmd(config(/do 在线加词),[在线加词])	ojc
\$ddcmd(config(/do 码表),[码表])	omb
\$ddcmd(run(https://github.com/xkinput/KeyTao/wikis/pages),[入门文档])	orm
\$ddcmd(run(http://www.zdic.net/sousuo/?q=<last.1>),[汉典]:<last.1>)	ohd
\$ddcmd(<date.yyyy>年<date.m>月<date.d>日,<date.yyyy>年<date.m>月<date.d>日)	orq
\$ddcmd(<date.yyyy>-<date.mm>-<date.dd>,<date.yyyy>-<date.mm>-<date.dd>)	orq
\$ddcmd(<date.YYYY>年<date.M>月<date.D>日,<date.YYYY>年<date.M>月<date.D>日)	orq
\$ddcmd(keyboard(<35><36+Shift><46><36>),[删当前行])	oee
\$ddcmd(<date.z> <time.h>:<time.mm>,<date.z> <time.h>:<time.mm>)	oej
\$ddcmd(convert(繁体输出,切换),[简繁切换])	ojf
\$ddcmd(run(https://739497722.docs.qq.com/ipGva4mn5bo#BB08J2),[申请表加词])	oeq
EOF

echo "添加多多脚本 OK"
echo "生成多多词库 $outFileName OK"
