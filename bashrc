#!/bin/bash

# ثبت حزمة bash-completion للإكمال التلقائي

#===================================
#                      التهيئة الأساسية                         #
#===================================

if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
    export PATH="$PATH:$HOME/.local/bin"
fi

if [ ! -d "$HOME/.local/bin" ]; then
    mkdir -pm 700 "$HOME/.local/bin"
fi

#===================================
#                          الخروج إن لم تكن الصدفة تفاعلية                    #
#===================================

case $- in
  *i*) ;;        # interactive
  *) return ;;   # غير تفاعلي
esac

#===================================
#                         إعدادات السجل والصدفة                                #
#===================================

HISTCONTROL=ignoredups:ignorespace
shopt -s histappend
HISTSIZE=1000
HISTFILESIZE=2000

# تحسينات السلوك
shopt -s checkwinsize   # تحديث أبعاد النافذة
shopt -s globstar       # تفعيل البحث العميق **
shopt -s autocd         # الدخول للمجلدات بدون كتابة cd

#===================================
#                 اكتشاف بيئة Chroot أو Container                              #
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
#                       إعدادات الألوان لموجه الأوامر                          #
#===================================

prompt_frame_color_var="\[\033[38;2;55;88;138m\]"
prompt_success_indicator_color_var="\[\033[38;2;139;148;158m\]"
prompt_root_user_color_var="\[\033[38;2;255;0;0m\]"
prompt_regular_user_color_var="\[\033[38;2;55;88;138m\]"
prompt_at_symbol_color_var="\[\033[38;2;74;111;163m\]"
prompt_hostname_color_var="\[\033[38;2;137;165;214m\]"
prompt_current_dir_color_var="\[\033[38;2;137;165;214m\]"
prompt_reset_color_var="\[\033[0m\]"
prompt_end_symbol_color_var="\[\033[38;2;55;88;138m\]"

set_custom_prompt() {
  local exit_code=${1:-0}

  local exit_code_indicator=""
  if [ "$exit_code" -ne 0 ]; then
    exit_code_indicator="[${prompt_frame_color_var}✘${prompt_success_indicator_color_var}:$exit_code]"
  fi

  local user_info=""
  if [ ${EUID} -eq 0 ]; then
    user_info="${prompt_root_user_color_var}root${prompt_at_symbol_color_var}@"
  else
    user_info="${prompt_regular_user_color_var}\u${prompt_at_symbol_color_var}@"
  fi

  local prompt_symbol="$"
  if [ ${EUID} -eq 0 ]; then
    prompt_symbol="#"
  fi

  local venv=""
  if [ -n "$VIRTUAL_ENV" ]; then
    venv="(${VIRTUAL_ENV##*/}) "
  fi

  PS1="${prompt_frame_color_var}┌─${venv}${exit_code_indicator}─[${user_info}${prompt_hostname_color_var}\h${prompt_frame_color_var}]─[${prompt_current_dir_color_var}\w${prompt_frame_color_var}]\n└─${prompt_end_symbol_color_var}${prompt_symbol}${prompt_reset_color_var} "
}

if [ -t 1 ] && tput setaf 1 >/dev/null 2>&1; then
  PROMPT_COMMAND='last_exit=$?; history -a; history -c; history -r; set_custom_prompt $last_exit'
else
  PS1='${chroot_env:+($chroot_env)}\u@\h:\w\$ '
fi

case "$TERM" in
  xterm*|rxvt*|screen*|tmux*)
    PS1="\[\033]0;${chroot_env:+($chroot_env)}\u@\h: \w\007\]$PS1"
    ;;
esac

#===================================
#                        الأسماء المستعارة                                     #
#===================================

case "$OSTYPE" in
  linux*) alias ls='ls --color=auto' ;;
  bsd*)   alias ls='ls -G' ;;
esac

alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'

#===================================
#                  دالة فك الضغط بدعم صيغ حديثة وأكثر أماناً                   #
#===================================

extract() {
    local file="$1"
    if [[ -z "$file" ]]; then
        echo "الاستخدام: extract <اسم الملف>"
        return 2
    fi
    if [[ ! -f "$file" ]]; then
        echo "⚠️ الملف غير موجود: $file"
        return 1
    fi
    case "$file" in
        *.tar.bz2)   tar xvjf "$file"   ;;
        *.tar.gz)    tar xvzf "$file"   ;;
        *.tar.xz)    tar xvJf "$file"   ;;
        *.tar.zst)   tar --zstd -xvf "$file" ;;
        *.tbz2)      tar xvjf "$file"   ;;
        *.tgz)       tar xvzf "$file"   ;;
        *.tar)       tar xvf "$file"    ;;
        *.bz2)       bunzip2 "$file"    ;;
        *.gz)        gunzip "$file"     ;;
        *.lzma)      unlzma "$file"     ;;
        *.xz)        unxz "$file"       ;;
        *.zst)
            if ! type unzstd >/dev/null 2>&1; then echo "⚠️ الأمر 'unzstd' غير مثبت."; return 1; fi
            unzstd "$file"
            ;;
        *.Z)         uncompress "$file" ;;
        *.zip)       unzip "$file"      ;;
        *.rar)
            if ! type unrar >/dev/null 2>&1; then echo "⚠️ الأمر 'unrar' غير مثبت."; return 1; fi
            unrar x "$file"
            ;;
        *.7z)
            if ! type 7z >/dev/null 2>&1; then echo "⚠️ الأمر '7z' غير مثبت."; return 1; fi
            7z x "$file"
            ;;
        *)
            echo "⚠️ صيغة غير مدعومة: $file"
            return 2
            ;;
    esac
}

#===================================
#                   إعدادات أمان إضافية                                       #
#===================================

umask 027
set -o noclobber

#===================================
#           دالة لمسح مجلدات __pycache__ وغيرها من مخلفات التطوير               #
#===================================

# تشغيلها بكتابة: remove
remove() {
    # قائمة المجلدات والملفات المؤقتة المراد حذفها
    local patterns=(
        __pycache__ .pytest_cache .mypy_cache .ruff_cache
        .cache *.egg-info .coverage
    )
    local find_args=()
    for pattern in "${patterns[@]}"; do
        find_args+=(-o -name "$pattern")
    done

    local deleted_count
    # نبحث عن مجلدات (-type d) أو ملفات (-type f) تطابق الأنماط
    deleted_count=$(find . \( -type d -o -type f \) \( "${find_args[@]:1}" \) -print -exec rm -rf {} + 2>/dev/null | wc -l)

    if [ "$deleted_count" -gt 0 ]; then
        echo "✅ تم حذف ${deleted_count} من مجلدات وملفات المخلفات."
    else
        echo "👍 لم يتم العثور على أي مخلفات."
    fi
}

#                 إدارة الأوامر المفضلة                 #
fav() {
    local fav_file="$HOME/.bash_favorites"
    [ ! -f "$fav_file" ] && touch "$fav_file"
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
#                   دالة للتنقل السريع بين المجلدات للأعلى                     #
#===================================

# الاستخدام:
#   up    # يصعد مجلدًا واحدًا للأعلى (مثل cd ..)
#   up 3  # يصعد ثلاثة مجلدات للأعلى
up() {
    local count=${1:-1} # إذا لم يتم تحديد رقم، الافتراضي هو 1
    local path=""
    for ((i=0; i<count; i++)); do
        path+="../"
    done
    cd "$path" || return
}

#===================================
#                   بعض توزيعات لينكس بها قيود على تحميل ب pip                     #
#===================================

pip() {
    command pip "$@" --break-system-packages
}

#===================================
#                   عرض ذكر عشوائي مزين عند فتح الطرفية                           #
#===================================

# قائمة الأذكار
AZKAR=(
"سبحان الله وبحمده"
"لا إله إلا الله"
"الله أكبر"
"الحمد لله"
"أستغفر الله"
"سبحان الله العظيم"
"لا حول ولا قوة إلا بالله"
"اللَّهُمَّ ‌صَلِّ وسلم ‌عَلَى ‌مُحَمَّد"
)

# لون الذكر
AZKAR_FRAME_COLOR="\033[38;2;55;88;138m"
AZKAR_TEXT_COLOR="\033[38;2;139;148;158m"
AZKAR_RESET="\033[0m"

# دالة لاختيار ذكر عشوائي وعرضه
random_azkar() {
    local count=${#AZKAR[@]}
    local index=$(( RANDOM % count ))
    local azkar="${AZKAR[$index]}"

    # تصميم الإطار
    local line_length=${#azkar}
    local border
    border=$(printf '%*s' $((line_length + 6)) '' | tr ' ' '*')

    echo -e "${AZKAR_FRAME_COLOR}${border}${AZKAR_RESET}"
    echo -e "${AZKAR_FRAME_COLOR}* ${AZKAR_TEXT_COLOR}${azkar}${AZKAR_FRAME_COLOR} *${AZKAR_RESET}"
    echo -e "${AZKAR_FRAME_COLOR}${border}${AZKAR_RESET}"
}

# استدعاء الدالة عند تحميل الصدفة
[[ $- == *i* ]] && random_azkar
