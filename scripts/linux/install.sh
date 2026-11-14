#!/bin/bash
rootDir=$(cd "$(dirname "$0")" && pwd) || exit 1
repoRoot=$(cd "$(dirname "$0")/../.." && pwd) || exit 1
if [ ! -f "$repoRoot/rime/keytao.phrase.dict.yaml" ]; then
	echo "Error: missing $repoRoot/rime/keytao.phrase.dict.yaml" >&2
	exit 1
fi
cd "$rootDir" || exit 1

clear

JD=""
YB=""
LB=""
rime="$HOME/.local/share/fcitx5/rime"

jd=$(pwd)
xkjd="$repoRoot"
xklb="$repoRoot/../rime_xklb"
xkyb="$repoRoot/../rime_xkybd"
schema="$repoRoot/schema/desktop"
extend_dicts="$repoRoot/extend-dicts"
userDict="./用户数据"

echo "获取键道最新词库..."
git pull
echo "获取两笔最新词库..."
cd "$xklb"
git pull
cd "$jd"
echo "获取一笔一道魔道最新词库..."
cd "$xkyb"
git pull
cd "$jd"

sleep 1

bak="./备份"
count=0

isHaveDict() {
	##	检测词库是否存在
	#	$1	词库名称
	#	$2	词库路径
	if [ ! -d "$2" ]; then
		echo "· 没有$1词库，跳过。"
	else
		read -p "· 检测到$1词库，是否同时安装？ y/n" -n 1 isInstall
		if [ -z "${isInstall}" ]; then
			isInstall=y
		fi
		if [[ $isInstall == [yY] ]]; then
			cp -rf "$2"/rime/* "$rime"
			echo "复制码表完成					完成"
			echo "复制所有文件					完成"
			count=$(expr $count + 1)
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
	if [ ! -f "$bak/$2" ]; then
		echo "· 没有备份$1用户词库跳过。"
	else
		cp -rf "$bak/$2" "$rime"
		echo "· 还原$1用户词库					完成"
	fi
}

#检测备份目录
if [ ! -d "$bak" ]; then
	mkdir "$bak"
else
	rm -rf "${bak:?}"/*
fi

if [ ! -d "$rime" ]; then
	echo "· 未发现$rime无需备份"
elif [ -z "$(ls -A "$rime" 2>/dev/null)" ]; then
	echo "· $rime 为空，无需备份"
else
	cp -rf "$rime"/. "$bak/"
	echo "· 备份“$rime”到“$bak”文件夹	完成"
fi

sleep 1

#清空Rime目录
if [ ! -d "$rime" ]; then
	mkdir "$rime"
else
	rm -rf "$rime"
	mkdir "$rime"
fi

isHaveDict "键道6" "$xkjd"
if [ $? == 1 ]; then
	cp -rf "$schema"/* "$rime/"
	JD="键道6"
fi
isHaveDict "一笔一道魔道" "$xkyb"
if [ $? == 1 ]; then
	cp -rf "$xkyb"/*.yaml "$rime/"
	echo " * 如有报错可忽略，稍后以输出目录文件数为准！"
	echo " * 如有报错可忽略，稍后以输出目录文件数为准！"
	echo " * 如有报错可忽略，稍后以输出目录文件数为准！"
	YB="一笔一道魔道"
fi
isHaveDict "两笔" "$xklb"
if [ $? == 1 ]; then
	LB="两笔"
fi

isHaveUserDict "键道6" keytao.user.dict.yaml
isHaveUserDict "键道6" keytao.extended.dict.yaml
isHaveUserDict "键道6" keytao-dz.extended.dict.yaml
isHaveUserDict "一笔" xkyb.user.dict.yaml
isHaveUserDict "两笔" xklb.user.dict.yaml

# 检测当前目录用户词库
if [ ! -d "$userDict" ]; then
	echo "未发现$userDict"
else
	cp -rf "$userDict"/* "$rime/"
	echo "· 当前目录用户词库					完成"
fi
sleep 2

echo "预览 $rime/"
echo "==========================================="
if [ ! -d "$rime" ]; then
	echo "未发现$rime"
else
	ls "$rime"
fi
echo "==========================================="
sleep 2
echo "==========================================="
echo "已安装方案：$count个 $JD $YB $LB"
sleep 1
echo "请前往输入法中部署"
echo "==========================================="
exit
