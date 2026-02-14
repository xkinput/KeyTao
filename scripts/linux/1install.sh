#!/bin/bash
clear
Get_SysPack_Name(){
    if grep -Eqii "CentOS" /etc/issue || grep -Eq "CentOS" /etc/*-release; then
        DISTRO='CentOS'
        PM='yum'
    elif grep -Eqi "Red Hat Enterprise Linux Server" /etc/issue || grep -Eq "Red Hat Enterprise Linux Server" /etc/*-release; then
        DISTRO='RHEL'
        PM='yum'
    elif grep -Eqi "Arch" /etc/issue || grep -Eq "Arch" /etc/*-release; then
        DISTRO='Aliyun'
        PM='pacman'
    elif grep -Eqi "Aliyun" /etc/issue || grep -Eq "Aliyun" /etc/*-release; then
        DISTRO='Aliyun'
        PM='yum'
    elif grep -Eqi "Fedora" /etc/issue || grep -Eq "Fedora" /etc/*-release; then
        DISTRO='Fedora'
        PM='yum'
    elif grep -Eqi "Debian" /etc/issue || grep -Eq "Debian" /etc/*-release; then
        DISTRO='Debian'
        PM='apt'
    elif grep -Eqi "Deepin" /etc/issue || grep -Eq "Deepin" /etc/*-release; then
        DISTRO='Deepin'
        PM='apt'
    elif grep -Eqi "Manjaro" /etc/issue || grep -Eq "Deepin" /etc/*-release; then
        DISTRO='Manjaro'
        PM='pacman'
    elif grep -Eqi "Ubuntu" /etc/issue || grep -Eq "Ubuntu" /etc/*-release; then
        DISTRO='Ubuntu'
        PM='apt'
    elif grep -Eqi "Linuxmint" /etc/issue || grep -Eq "Ubuntu" /etc/*-release; then
        DISTRO='Linuxmint'
        PM='apt'
    else
        DISTRO='当前不支持你的系统'
    fi
	echo "==========================================="
    echo "*当前系统为"$DISTRO"，将执行"$PM"安装方法。";
	echo "==========================================="
}
Get_SysPack_Name
sleep 3
clear
echo "==========================================="
echo "欢迎使用Linux_Rime输入法Fcitx-rime引导程序"
echo "==========================================="
echo "向导："
echo "请在有网络环境下开始，否则请立即Ctrl+c停止！"
echo "若在无网络情况下卸载输入法，将无法安装输入法"
echo "安装分为4步："
echo "1、卸载旧版Fcitx程序。"
echo "2、安装Fcitx程序。"
echo "3、复制Rime用户配置文件。"
echo "4、注销或重启系统。"
echo "*过程可能较慢，请耐心等待。"
echo "                          shell by Qshu"
echo "==========================================="
echo "*请阅读向导，5秒后开始安装……"
sleep 5
clear
echo "==========================================="
echo "欢迎使用Linux_Rime输入法Fcitx-rime引导程序"
echo "==========================================="
echo "第一步 卸载系统Fcitx程序"
echo "==========================================="
echo "请输入Root用户密码："
RemoveOldFcitx(){
	if [ $PM = "apt" ]; then
		sudo apt-get remove fcitx* -y
	elif [ $PM = "yum" ]; then
		sudo yum remove fcitx* -y
	elif [ $PM = "pacman" ]; then
		sudo pacman -Rs fcitx* -y
	fi
}
RemoveOldFcitx
sleep 5
clear
echo "==========================================="
echo "欢迎使用LinuxRime输入法Fcitx-rime引导程序"
echo "==========================================="
echo "第二步 安装系统Fcitx程序"
echo "==========================================="
sleep 1
InstallFcitx(){
	if [ $PM = "apt" ]; then
		sudo apt install fcitx fcitx-rime fcitx-ui-classic fcitx-config-gtk -y
	elif [ $PM = "yum" ]; then
		sudo yum install fcitx fcitx-rime fcitx-ui-classic fcitx-config-gtk -y
	elif [ $PM = "pacman" ]; then
		sudo pacman -S fcitx fcitx-rime fcitx-ui-classic fcitx-config-gtk -y
	fi
}
InstallFcitx
sleep 3
clear
echo "==========================================="
echo "欢迎使用LinuxRime输入法Fcitx-rime引导程序"
echo "==========================================="
echo "第三步 复制Rime用户配置文件"
echo "==========================================="

JD=""
YB=""
LB=""
rime=~/.local/share/fcitx5/rime

xkjd=../../../KeyTao
xklb=../../../rime_xklb
xkyb=../../../rime_xkybd

bak=./备份
count=0

isHaveDict () {
##	检测词库是否存在
#	$1	词库名称
#	$2	词库路径
	if [ ! -d $2 ]; then
		echo "· 没有$1词库，跳过。"
	else
		echo "· 检测到$1词库，是否同时安装？ y/n"
		read isInstall
		if [[ "$isInstall" == [yY] ]]; then
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

isHaveUserDict "键道6" keytao.user.dict.yaml
isHaveUserDict "一笔" xkyb.user.dict.yaml
isHaveUserDict "两笔" xklb.user.dict.yaml

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
echo "请在fcitx重新部署后再尝试使用。"
echo "==========================================="
sleep 1
clear
echo " 注销 或 重启 系统后即可使用"
echo "==========================================="
echo "8秒后重启，若不想重启系统请Ctrl+C，并且手动注销"
echo "==========================================="
sleep 8
sudo reboot
