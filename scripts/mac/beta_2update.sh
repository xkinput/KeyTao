#!/bin/bash

# set -x
rootDir=$(cd "$(dirname "$0")" && pwd) || exit 1
repoRoot=$(cd "$rootDir/../.." && pwd) || exit 1
if [ ! -f "$repoRoot/rime/keytao.phrase.dict.yaml" ]; then
    echo "Error: KeyTao dictionary not found in $repoRoot/rime" >&2
    exit 1
fi
cd "$rootDir" || exit 1
xk_ID="keytao"
xk_name="键道6"
xk_path="$repoRoot/rime"
my_default="default.custom.yaml"
rime="$HOME/Library/Rime"

testHasSchema(){

    mkdir -p "$rime" || exit 1
    echo "==========================================="
    echo "检测是否配置「 $xk_name 」方案: "
    if [ -f "$rime/$my_default" ]; then
        xk_is_ID=$(grep "^[^#]*schema: $xk_ID$" "$rime/$my_default")
	if [[ -z $xk_is_ID ]]; then
            sed -i '' -E $'/schema_list:/s/$/\\\n    - schema: '"$xk_ID"'/g' "$rime/$my_default"
            echo -e "添加${xk_name}方案到 $my_default ..................完成"
	else
            echo -e "已设置$xk_name"
	fi
    else
	cp "$repoRoot/rime/$my_default" "$rime/"
	echo "复制Rime用户配置文件...................完成"
    fi
    echo -e "---------------------\n"
    # Dicts removed upstream; rsync (no --delete) would otherwise leave them behind
    rm -f "$rime/keytao.dict.yaml" "$rime/keytao-dz.dict.yaml"
    rsync -avhI --progress \
      "$xk_path/" \
      --exclude="keytao.extended.dict.yaml" \
      --exclude="keytao-dz.extended.dict.yaml" \
      --include="*.dict.yaml" \
      --include="*.schema.yaml" \
      --include=/opencc \
      --include=/lua \
      --exclude='/*' \
      "$rime/"
    rsync -avhI --progress "$repoRoot/schema/desktop/" "$repoRoot/schema/mac/" "$rime/"

}

echo "开始备份"
rm -rf 备份/*
# 删除原有备份文件
mkdir 备份 2> /dev/null
cp -r "$rime"/* ./备份/
echo "备份原内容到当前目录下“备份”文件夹.....完成"
echo "==========================================="
echo "码表更新，请选择升级方式："
echo -e "  1) [更新] 码表/schema/opencc (1)\n  2) 备份并覆盖现有 Rime 配置  (2)"
echo "-----------------------------------"
echo -e "( 若不确定该选择何种方式，请按 ctrl+c 中断脚本执行，并参阅 help.txt )\n"
echo -n "选择 (1/2): "
read my_select

case $my_select in
  "1")
    testHasSchema
  ;;
  "2")
    ./2update.sh
    exit
  ;;
  *)
    echo "退出当前脚本执行"
    exit
  ;;
esac

echo "==========================================="
sleep 3
clear
echo "已安装方案：$xk_name"
/Library/Input\ Methods/Squirrel.app/Contents/MacOS/Squirrel --reload
if [ "$?" -ne 0 ]; then
    echo "请在鼠须管重新部署后再尝试使用。"
else
    echo "部署进行中，请待部署完成后，再尝试使用。"
fi
echo "==========================================="
sleep 1
exit
