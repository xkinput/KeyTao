#!/bin/bash
clear

JD=""
YB=""
LB=""
rime=~/.local/share/fcitx5/rime

jd=$(pwd);
xkjd=../../../../Rime_JD
xklb=../../../../rime_xklb
xkyb=../../../../rime_xkybd
userDict=./用户数据
echo "获取键道最新词库..."
git pull
echo "获取两笔最新词库..."
cd $xklb
git pull
cd $jd
echo "获取一笔一道魔道最新词库..."
cd $xkyb
git pull
cd $jd

sleep 1

bak=./备份
count=0

isHaveDict () {
##	检测词库是否存在
#	$1	词库名称
#	$2	词库路径
	if [ ! -d $2 ]; then
		echo "· 没有$1词库，跳过。"
	else
        read -p "· 检测到$1词库，是否同时安装？ y/n" -n 1 isInstall
        if [ -z "${isInstall}" ];then
            isInstall=y
        fi
        if [[ $isInstall == [yY] ]]; then
			cp -rf $2/rime/* "$rime"
			echo "复制码表完成					完成"
			echo "复制所有文件					完成"
			count=`expr $count + 1`
			return 1
		else
			echo "已拒绝安装。"
			return 0
		fi
	fi
}
isHaveUserDict() {
##	检测用户词库存在
#	$1	方案名称
#	$2	用户词库文件
	if [ ! -f $bak/$2 ]; then
		echo "· 没有备份$1用户词库跳过。"
	else
		cp -rf $bak/$2 "$rime"
		echo "· 还原$1用户词库					完成"
	fi
}

#检测备份目录
if [ ! -d "./备份" ]; then
	clear
	mkdir 备份
else
	rm -rf 备份/*
fi

if [ ! -f "$rime/default.yaml" ]; then
	echo "· 未发现$rime无需备份"
else
	cp -rf $rime/* ./备份/
	echo "· 备份“$rime”到“$bak”文件夹	完成"
fi

sleep 1

#清空Rime目录
if [ ! -d $rime ]; then
	mkdir $rime
else
	rm -rf $rime
	mkdir $rime
fi
clear

isHaveDict "键道6" $xkjd
if [ $? == 1 ]; then
	cp -rf ../rime/*.yaml $rime/
	cp -rf ../rime/Linux/* $rime/
	JD="键道6"
fi
isHaveDict "一笔一道魔道" $xkyb
if [ $? == 1 ]; then
	cp -rf $xkyb/*.yaml $rime/
	echo " * 如有报错可忽略，稍后以输出目录文件数为准！"
	echo " * 如有报错可忽略，稍后以输出目录文件数为准！"
	echo " * 如有报错可忽略，稍后以输出目录文件数为准！"
	YB="一笔一道魔道"
fi
isHaveDict "两笔" $xklb
if [ $? == 1 ]; then
	LB="两笔"
fi

sleep 1
clear

if [ ! -d $rime ]; then
	echo ""
else
	cp -rf ../*.yaml $rime/
	echo "· 全局配置文件						完成"
fi

isHaveUserDict "键道6" xkjd6.user.dict.yaml
isHaveUserDict "键道6" xkjd6.extended.dict.yaml
isHaveUserDict "键道6" xkjd6dz.extended.dict.yaml
isHaveUserDict "一笔" xkyb.user.dict.yaml
isHaveUserDict "两笔" xklb.user.dict.yaml

# 检测当前目录用户词库
if [ ! -d $userDict ]; then
	echo "未发现$userDict"
else
	cp -rf $userDict/* $rime/
	echo "· 当前目录用户词库					完成"
fi
sleep 2

clear
echo "预览 $rime/"
echo "==========================================="
if [ ! -d $rime ]; then
	echo "未发现$rime"
else
	ls "$rime"
fi
echo "==========================================="
sleep 2
clear
echo "==========================================="
echo "已安装方案：$count个 $JD $YB $LB"
sleep 1
fcitx -r
echo "正在自动部署中……"
echo "检查部署成功后若未退出请Ctrl + C 结束"
echo "==========================================="
exit
