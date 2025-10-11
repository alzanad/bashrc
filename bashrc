#!/bin/bash
# تفعيل التحقق من المتغيرات غير المعرّفة
set -u

################################################################################
#                      إضافة المسار إلى PATH مع التحقق                         #
################################################################################
if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
    export PATH="$PATH:$HOME/.local/bin"
fi

if [ ! -d "$HOME/.local/bin" ]; then
    mkdir -pm 700 "$HOME/.local/bin"
fi

################################################################################
#                          الخروج إن لم تكن الصدفة تفاعلية                    #
################################################################################
[ -z "${PS1:-}" ] && return

################################################################################
#                         إعدادات سجل الأوامر                                  #
################################################################################
HISTCONTROL=ignoredups:ignorespace
shopt -s histappend
HISTSIZE=1000
HISTFILESIZE=2000
export PROMPT_COMMAND="history -a; history -c; history -r; ${PROMPT_COMMAND:-}"

################################################################################
#                       تحسينات سلوك الصدفة                                    #
################################################################################
shopt -s checkwinsize
shopt -s globstar
shopt -s autocd

if type lesspipe >/dev/null 2>&1; then
  eval "$(SHELL=/bin/sh lesspipe)"
fi

################################################################################
#                 اكتشاف بيئة Chroot أو Container                              #
################################################################################
get_chroot_environment() {
  if [ -f /run/systemd/container ] || [ -f /etc/lxc/.is_container ] ||
     [ -n "${container:-}" ] ||
     [ -f /.dockerenv ] || [ -f /run/.containerenv ]; then
    if [ -f /etc/hostname ]; then
      echo "( $(cat /etc/hostname) )"
    else
      echo "(container)"
    fi
  fi
}
chroot_env=$(get_chroot_environment)

################################################################################
#                       إعدادات الألوان لموجه الأوامر                          #
################################################################################
prompt_frame_color_var="\[\033[38;5;39m\]"
prompt_success_indicator_color_var="\[\033[38;5;250m\]"
prompt_root_user_color_var="\[\033[38;5;196m\]"
prompt_regular_user_color_var="\[\033[38;5;82m\]"
prompt_at_symbol_color_var="\[\033[38;5;220m\]"
prompt_hostname_color_var="\[\033[38;5;45m\]"
prompt_current_dir_color_var="\[\033[38;5;51m\]"
prompt_reset_color_var="\[\033[0m\]"
prompt_end_symbol_color_var=""

set_custom_prompt() {
  local exit_code=$?
  local exit_code_indicator=""
  if [ $exit_code != 0 ]; then
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

  PS1="${prompt_frame_color_var}┌─${exit_code_indicator}─[${user_info}${prompt_hostname_color_var}\h${prompt_frame_color_var}]─[${prompt_current_dir_color_var}\w${prompt_frame_color_var}]\n└─${prompt_end_symbol_color_var}${prompt_symbol}${prompt_reset_color_var} "
}

if [ -t 1 ] && tput setaf 1 >/dev/null 2>&1; then
  set_custom_prompt
else
  PS1='${chroot_env:+($chroot_env)}\u@\h:\w\$ '
fi

case "$TERM" in
  xterm*|rxvt*|screen*|tmux*)
    PS1="\[\033]0;${chroot_env:+($chroot_env)}\u@\h: \w\007\]$PS1"
    ;;
esac

################################################################################
#                        الأسماء المستعارة                                     #
################################################################################
case "$OSTYPE" in
  linux*) alias ls='ls --color=auto' ;;
  bsd*)   alias ls='ls -G' ;;
esac

alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'

if type notify-send >/dev/null 2>&1; then
  alias alert='notify-send --urgency=low -i "$([ $? = 0 ] && echo terminal || echo error)" "$(history|tail -n1|sed -E '\''s/^\s*[0-9]+\s*//;s/[;&|]\s*alert$//'\'')"'
fi

if [ -f "$HOME/.bash_aliases" ]; then
  . "$HOME/.bash_aliases"
fi

if [ -f /etc/bash_completion ] && ! shopt -oq posix; then
  . /etc/bash_completion
fi

################################################################################
#                  دالة فك الضغط بدعم صيغ حديثة وأكثر أماناً                   #
################################################################################
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

################################################################################
#                   إعدادات أمان إضافية                                       #
################################################################################
umask 027
set -o noclobber

################################################################################
#           دالة لمسح مجلدات __pycache__ وغيرها من مخلفات التطوير               #
################################################################################
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

################################################################################
#                 إدارة الأوامر المفضلة (حفظ + اختيار تفاعلي)                 #
################################################################################
FAV_FILE="$HOME/.bash_favorites"

fav() {
    # التأكد من وجود الملف والدليل
    mkdir -p "$(dirname "$FAV_FILE")" && touch "$FAV_FILE"

    # الحالة: تشغيل أمر مباشرة برقمه (مثل: fav 1)
    if [[ "$1" =~ ^[0-9]+$ ]]; then
        local cmd
        cmd=$(sed -n "${1}p" "$FAV_FILE")
        if [[ -z "$cmd" ]]; then
            echo "⚠️ الرقم $1 غير موجود في القائمة."
            return 1
        fi
        echo "▶️  تشغيل: $cmd"
        eval "$cmd"
        return
    fi

    # الحالات الأخرى (add, del, list, interactive)
    case "$1" in
        add)
            shift
            if [[ -z "$*" ]]; then
                echo "⚠️ الرجاء كتابة الأمر المراد إضافته"
                return 1
            fi
            echo "$*" >> "$FAV_FILE"
            echo "✅ تمت إضافة الأمر إلى المفضلة."
            ;;
        del)
            if ! [[ "$2" =~ ^[0-9]+$ ]]; then
                echo "⚠️ الرجاء تحديد رقم صحيح للأمر المراد حذفه"
                return 1
            fi
            sed -i.bak "${2}d" "$FAV_FILE" && rm "$FAV_FILE.bak"
            echo "🗑️ تم حذف الأمر رقم $2."
            ;;
        list)
            if [[ ! -s "$FAV_FILE" ]]; then
                echo "⚠️ لا توجد أوامر مفضلة محفوظة."
            else
                nl -w3 -s". " "$FAV_FILE"
            fi
            ;;
        "")
            if [[ ! -s "$FAV_FILE" ]]; then
                echo "⚠️ لا توجد أوامر مفضلة لتشغيلها."
                return 0
            fi
            echo "الأوامر المفضلة:"
            nl -w3 -s". " "$FAV_FILE"
            read -r -p "اختر رقم الأمر لتشغيله (أو اترك فارغًا للإلغاء): " choice
            if [[ "$choice" =~ ^[0-9]+$ ]]; then
                fav "$choice" # إعادة استدعاء الدالة نفسها لتشغيل الرقم
            fi
            ;;
        *)
            echo "الاستخدام:"
            echo "  fav add <أمر>   # لإضافة أمر للمفضلة"
            echo "  fav del <رقم>   # لحذف أمر"
            echo "  fav list        # عرض القائمة"
            echo "  fav             # عرض القائمة واختيار رقم للتشغيل"
            echo "  fav <رقم>       # تشغيل الأمر مباشرة"
            ;;
    esac
}

################################################################################
#                   دالة للتنقل السريع بين المجلدات للأعلى                     #
################################################################################
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


################################################################################
#                   بعض توزيعات لينكس بها قيود على تحميل ب pip                     #
################################################################################

pip() {
    command pip "$@" --break-system-packages
}


################################################################################
#                   عرض ذكر عشوائي عند فتح الطرفية                           #
################################################################################
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

# ألوان وزينة
AZKAR_FRAME_COLOR="\033[38;5;45m"   # أزرق سماوي
AZKAR_TEXT_COLOR="\033[38;5;220m"   # أصفر ذهبي
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
random_azkar
