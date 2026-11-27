#!/usr/bin/env bash
# macOS/Linux run `bash scripts/install.sh`; Windows 请右键 scripts/install.ps1 →「使用 PowerShell 运行」
set -euo pipefail

main() {
  local os here repo source rime backup first entry name
  os=$(uname -s)
  case "$os" in
    Darwin|Linux) ;;
    *) printf '不支持的系统：%s（Windows 请右键 scripts/install.ps1 →「使用 PowerShell 运行」）\n' "$os" >&2; return 1 ;;
  esac

  here=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
  repo=$(dirname -- "$here")
  source="$repo/rime"
  if [[ -f "$source/keytao.schema.yaml" && -e "$repo/.git" ]] && command -v git >/dev/null; then
    if ! GIT_TERMINAL_PROMPT=0 git -C "$repo" pull --ff-only; then
      printf '警告：仓库更新失败，继续安装。\n' >&2
    fi
  fi
  if [[ ! -f "$source/keytao.schema.yaml" ]]; then
    printf '缺少方案文件：%s/keytao.schema.yaml\n' "$source" >&2
    return 1
  fi

  case "$os" in
    Darwin) rime="$HOME/Library/Rime" ;;
    Linux)
      rime="$HOME/.local/share/fcitx5/rime"
      if [[ ! -d "$rime" && -d "$HOME/.config/ibus/rime" ]]; then
        rime="$HOME/.config/ibus/rime"
      fi
      ;;
  esac

  backup="$here/备份"
  if [[ -d "$rime" ]]; then
    local rime_path
    rime_path=$(CDPATH='' cd -- "$rime" && pwd -P)
    if [[ "$rime" -ef "$backup" || "$rime/" == "$backup/"* ||
      "${rime_path%/}/" == "$backup/"* || "$backup/" == "${rime_path%/}/"* ]]; then
      printf 'Rime 目录与备份目录重叠，安装已停止。\n' >&2
      return 1
    fi
    first=$(find "$rime/." -mindepth 1 -maxdepth 1 -print -quit)
    if [[ -n "$first" ]]; then
      rm -rf "$backup"
      mkdir -p "$backup"
      cp -R "$rime/." "$backup/"
      printf '已备份至：%s\n' "$backup"
    fi
  fi

  mkdir -p "$rime"
  shopt -s dotglob
  for entry in "$source"/*; do
    name=${entry##*/}
    case "$name" in
      *.userdb|user.yaml|installation.yaml|sync|build) continue ;;
      default.custom.yaml|keytao.user.dict.yaml|keytao.extended.dict.yaml|keytao-dz.extended.dict.yaml)
        [ -e "$rime/$name" ] || cp -R "$entry" "$rime/"
        ;;
      *) cp -R "$entry" "$rime/" ;;
    esac
  done
  rm -f "$rime/keytao.dict.yaml" "$rime/keytao-dz.dict.yaml"

  if [[ -e "$rime/default.custom.yaml" ]] &&
    ! grep -Eq '^[[:blank:]]*-[[:blank:]]+schema:[[:blank:]]+keytao([[:blank:]]+#.*)?[[:space:]]*$' "$rime/default.custom.yaml"; then
    printf '请在 default.custom.yaml 的 schema_list 下添加 - schema: keytao。\n' >&2
  fi

  case "$os" in
    Darwin)
      local squirrel='/Library/Input Methods/Squirrel.app/Contents/MacOS/Squirrel'
      if [[ ! -x "$squirrel" ]] || ! "$squirrel" --reload; then
        printf '请在鼠须管中重新部署\n' >&2
      fi
      ;;
    Linux) printf '请在输入法中重新部署。\n' ;;
  esac
  printf '已更新 Rime 目录：%s\n' "$rime"
}

main "$@"
