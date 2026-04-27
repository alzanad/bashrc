#!/bin/bash

#===================================
#                      التهيئة الأساسية
#===================================

if [ ! -d "$HOME/.local/bin" ]; then
    mkdir -p "$HOME/.local/bin"
fi

#===================================
#                          الخروج إن لم تكن الصدفة تفاعلية
#===================================

case $- in
  *i*) ;;
  *) return 0 ;;
esac

#===================================
#                         إعدادات السجل والصدفة
#===================================

HISTCONTROL=ignoreboth:erasedups
shopt -s histappend
HISTSIZE=10000
HISTFILESIZE=20000
HISTTIMEFORMAT="%F %T "

# تحسينات السلوك
shopt -s checkwinsize   # تحديث أبعاد النافذة
PROMPT_DIRTRIM=3   # تقصير المسار الطويل

#===================================
#                 اكتشاف بيئة Chroot أو Container
#===================================

get_chroot_environment() {
  if [ -f /run/systemd/container ] || [ -f /etc/lxc/.is_container ] ||
     [ -n "${container:-}" ] ||
     [ -f /.dockerenv ] || [ -f /run/.containerenv ]; then
    if [ -f /etc/hostname ]; then
      echo "( $(</etc/hostname) )"
    else
      echo "(container)"
    fi
  fi
}
chroot_env=$(get_chroot_environment)

#===================================
#                       إعدادات الألوان لموجه الأوامر
#===================================

set_custom_prompt() {
  local exit_code=${1:-0}

  local p_frame="\[\033[38;2;55;88;138m\]"
  local p_err="\[\033[38;2;139;148;158m\]"
  local p_root="\[\033[38;2;255;0;0m\]"
  local p_user="\[\033[38;2;55;88;138m\]"
  local p_at="\[\033[38;2;74;111;163m\]"
  local p_host="\[\033[38;2;137;165;214m\]"
  local p_dir="\[\033[38;2;137;165;214m\]"
  local p_rst="\[\033[0m\]"
  local p_venv="\[\033[38;2;34;139;34m\]"

  local exit_code_indicator=""
  if [ "$exit_code" -ne 0 ]; then
    exit_code_indicator="[${p_frame}✘${p_err}:$exit_code]"
  fi

  local user_info=""
  if [ ${EUID} -eq 0 ]; then
    user_info="${p_root}root${p_at}@"
  else
    user_info="${p_user}\u${p_at}@"
  fi

  local prompt_symbol="$"
  if [ ${EUID} -eq 0 ]; then
    prompt_symbol="#"
  fi

    local venv=""
  if [ -n "$VIRTUAL_ENV" ]; then
    venv="${p_venv}(${VIRTUAL_ENV##*/})${p_frame} "
  fi

  PS1="${p_frame}┌─${venv}${exit_code_indicator}─[${user_info}${p_host}\h${p_frame}]─[${p_dir}\w${p_frame}]\n└─${p_frame}${prompt_symbol}${p_rst} "
}

if [ -t 1 ] && tput setaf 1 >/dev/null 2>&1; then
  PROMPT_COMMAND='last_exit=$?; set_custom_prompt "$last_exit"; history -a'
else
  PS1='${chroot_env:+($chroot_env)}\u@\h:\w\$ '
fi

case "$TERM" in
  xterm*|rxvt*|screen*|tmux*)
    PS1="\[\033]0;${chroot_env:+($chroot_env)}\u@\h: \w\007\]$PS1"
    ;;
esac

#===================================
#                        الأسماء المستعارة
#===================================

case "$OSTYPE" in
  linux*) alias ls='ls --color=auto' ;;
  bsd*)   alias ls='ls -G' ;;
esac

#===================================
#                  دالة فك الضغط بدعم صيغ حديثة وأكثر أماناً
#===================================

unpack() {
    local file="$1"

    if [[ -z "$file" ]]; then
        echo "الاستخدام: unpack <ملف>"
        return 2
    fi

    if [[ ! -f "$file" ]]; then
        echo "خطأ: '$file' ليس ملفاً صحيحاً"
        return 1
    fi

    case "${file,,}" in
        *.tar)              tar -xvf "$file" ;;
        *.tar.gz|*.tgz)     tar -xvzf "$file" ;;
        *.tar.bz2|*.tbz2)   tar -xvjf "$file" ;;
        *.tar.xz|*.txz)     tar -xvJf "$file" ;;
        *.tar.zst|*.tzst)   tar --zstd -xvf "$file" ;;
        *.gz)               gunzip "$file" ;;
        *.bz2)              bunzip2 "$file" ;;
        *.xz)               unxz "$file" ;;
        *.zst)              unzstd "$file" ;;
        *.zip)              unzip "$file" ;;
        *.rar)              command -v unrar >/dev/null && unrar x "$file" || echo "unrar غير مثبت" ;;
        *.7z)               command -v 7z >/dev/null && 7z x "$file" || echo "7z غير مثبت" ;;
        *.Z)                uncompress "$file" ;;
        *)
            # fallback ذكي باستخدام file
            local type
            type=$(file -b "$file")

            case "$type" in
                *gzip*)     gunzip -k "$file" ;;
                *bzip2*)    tar -xvjf "$file" 2>/dev/null || bunzip2 "$file" ;;
                *XZ*)       tar -xvJf "$file" 2>/dev/null || unxz "$file" ;;
                *Zstandard*) tar --zstd -xvf "$file" ;;
                *Zip*)      unzip "$file" ;;
                *)
                    echo "صيغة غير مدعومة: $file"
                    return 3
                    ;;
            esac
        ;;
    esac
}

#===================================
#                   إعدادات أمان إضافية
#===================================

umask 027
set -o noclobber

#===================================
#           دالة لمسح مجلدات __pycache__ وغيرها من مخلفات التطوير
#===================================

# تشغيلها بكتابة: cln
cln() {
    mapfile -d '' targets < <(find . \( \
        -type d -name "__pycache__" -o \
        -type d -name ".pytest_cache" -o \
        -type d -name ".mypy_cache" -o \
        -type d -name ".ruff_cache" -o \
        -type d -name ".cache" -o \
        -name "*.egg-info" -o \
        -name ".coverage" \
    \) -print0 2>/dev/null)

    local total=${#targets[@]}
    [[ $total -eq 0 ]] && { echo "✅ البيئة نظيفة سلفاً."; return 0; }

    local deleted_count=0

    for item in "${targets[@]}"; do
        if rm -rf "$item" 2>/dev/null; then
            ((deleted_count++))
        fi
    done

    echo "📦 عدد العناصر المحذوفة فعلياً: $deleted_count"

    if (( deleted_count < total )); then
        echo "⚠️ فشل حذف $((total - deleted_count)) عنصر بسبب قيود الصلاحيات." >&2
    fi
}

#===================================
#                 إدارة الأوامر المفضلة
#===================================

fav() {
    local fav_file="$HOME/.bash_favorites"
    if [ ! -f "$fav_file" ]; then
        touch "$fav_file"
        chmod 600 "$fav_file"
    fi
    if [ -z "$1" ]; then
        if [ ! -s "$fav_file" ]; then
            echo "⚠️ القائمة فارغة. أضف أوامر عبر: fav add <command>"
        else
            nl -w3 -s". " "$fav_file"
        fi
        return
    fi

    case "$1" in
        add)
            shift
            if [ -z "$*" ]; then
                echo "⚠️ الاستخدام: fav add <الأمر>"
            else
                echo "$*" >> "$fav_file"
                echo "✅ تمت الإضافة."
            fi
            ;;
        del)
            if [[ ! "$2" =~ ^[0-9]+$ ]]; then
                echo "⚠️ الاستخدام: fav del <رقم السطر>"
            else
                sed -i "${2}d" "$fav_file"
                echo "🗑️ تم حذف السطر $2."
            fi
            ;;
        *)
            if [[ "$1" =~ ^[0-9]+$ ]]; then
                local cmd=$(sed -n "${1}p" "$fav_file")
                if [ -n "$cmd" ]; then
                    echo "🚀 تشغيل: $cmd"
                    eval "$cmd"
                else
                    echo "⚠️ الرقم $1 غير موجود."
                fi
            else
                echo "الاستخدام: fav [add <أمر> | del <رقم> | <رقم التشغيل>]"
            fi
            ;;
    esac
}

#===================================
#                   دالة للتنقل السريع بين المجلدات للأعلى
#===================================

# الاستخدام:
#   up    # يصعد مجلدًا واحدًا للأعلى (مثل cd ..)
#   up 3  # يصعد ثلاثة مجلدات للأعلى
up() {
    local levels=${1:-1}
    [[ ! "$levels" =~ ^[0-9]+$ ]] && return 1
    local path=""
    for ((i=0; i<levels; i++)); do
        path+="../"
    done

    cd "$path" || return
}
