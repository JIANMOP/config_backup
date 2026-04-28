#Start configuration added by Zim install {{{
#
# User configuration sourced by interactive shells
#

# -----------------
# Zsh configuration
# -----------------

#
# History
#

# Remove older command from the history if a duplicate is to be added.
setopt HIST_IGNORE_ALL_DUPS

#
# Input/output
#

# Set editor default keymap to emacs (`-e`) or vi (`-v`)
bindkey -e

# Prompt for spelling correction of commands.
#setopt CORRECT

# Customize spelling correction prompt.
#SPROMPT='zsh: correct %F{red}%R%f to %F{green}%r%f [nyae]? '

# Remove path separator from WORDCHARS.
WORDCHARS=${WORDCHARS//[\/]}

# -----------------
# Zim configuration
# -----------------

# Use degit instead of git as the default tool to install and update modules.
#zstyle ':zim:zmodule' use 'degit'

# --------------------
# Module configuration
# --------------------

#
# git
#

# Set a custom prefix for the generated aliases. The default prefix is 'G'.
#zstyle ':zim:git' aliases-prefix 'g'

#
# input
#

# Append `../` to your input for each `.` you type after an initial `..`
#zstyle ':zim:input' double-dot-expand yes

#
# termtitle
#

# Set a custom terminal title format using prompt expansion escape sequences.
# See http://zsh.sourceforge.net/Doc/Release/Prompt-Expansion.html#Simple-Prompt-Escapes
# If none is provided, the default '%n@%m: %~' is used.
#zstyle ':zim:termtitle' format '%1~'

#
# zsh-autosuggestions
#

# Disable automatic widget re-binding on each precmd. This can be set when
# zsh-users/zsh-autosuggestions is the last module in your ~/.zimrc.
ZSH_AUTOSUGGEST_MANUAL_REBIND=1

# Customize the style that the suggestions are shown with.
# See https://github.com/zsh-users/zsh-autosuggestions/blob/master/README.md#suggestion-highlight-style
#ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=242'

#
# zsh-syntax-highlighting
#

# Set what highlighters will be used.
# See https://github.com/zsh-users/zsh-syntax-highlighting/blob/master/docs/highlighters.md
ZSH_HIGHLIGHT_HIGHLIGHTERS=(main brackets)

# Customize the main highlighter styles.
# See https://github.com/zsh-users/zsh-syntax-highlighting/blob/master/docs/highlighters/main.md#how-to-tweak-it
#typeset -A ZSH_HIGHLIGHT_STYLES
#ZSH_HIGHLIGHT_STYLES[comment]='fg=242'

# ------------------
# Initialize modules
# ------------------

ZIM_HOME=${ZDOTDIR:-${HOME}}/.zim
# Download zimfw plugin manager if missing.
if [[ ! -e ${ZIM_HOME}/zimfw.zsh ]]; then
  if (( ${+commands[curl]} )); then
    curl -fsSL --create-dirs -o ${ZIM_HOME}/zimfw.zsh \
        https://github.com/zimfw/zimfw/releases/latest/download/zimfw.zsh
  else
    mkdir -p ${ZIM_HOME} && wget -nv -O ${ZIM_HOME}/zimfw.zsh \
        https://github.com/zimfw/zimfw/releases/latest/download/zimfw.zsh
  fi
fi
# Install missing modules, and update ${ZIM_HOME}/init.zsh if missing or outdated.
if [[ ! ${ZIM_HOME}/init.zsh -nt ${ZIM_CONFIG_FILE:-${ZDOTDIR:-${HOME}}/.zimrc} ]]; then
  source ${ZIM_HOME}/zimfw.zsh init
fi
# Initialize modules.
source ${ZIM_HOME}/init.zsh

# ------------------------------
# Post-init module configuration
# ------------------------------

#
# zsh-history-substring-search
#

zmodload -F zsh/terminfo +p:terminfo
# Bind ^[[A/^[[B manually so up/down works both before and after zle-line-init
for key ('^[[A' '^P' ${terminfo[kcuu1]}) bindkey ${key} history-substring-search-up
for key ('^[[B' '^N' ${terminfo[kcud1]}) bindkey ${key} history-substring-search-down
for key ('k') bindkey -M vicmd ${key} history-substring-search-up
for key ('j') bindkey -M vicmd ${key} history-substring-search-down
unset key
# }}} End configuration added by Zim install

# Created by newuser for 5.8.1

# >>> conda initialize >>>
# !! Contents within this block are managed by 'conda init' !!
__conda_setup="$('/home/lk/miniconda3/bin/conda' 'shell.bash' 'hook' 2> /dev/null)"
if [ $? -eq 0 ]; then
    eval "$__conda_setup"
else
    if [ -f "/home/lk/miniconda3/etc/profile.d/conda.sh" ]; then
        . "/home/lk/miniconda3/etc/profile.d/conda.sh"
    else
        export PATH="/home/lk/miniconda3/bin:$PATH"
    fi
fi
unset __conda_setup
# <<< conda initialize <<<


export PATH=/usr/local/cuda/bin:$PATH
export LD_LIBRARY_PATH=/usr/local/cuda/lib64:$LD_LIBRARY_PATH
export CUDA_HOME=/usr/local/cuda  # libtorch
export TORCH_CUDA_ARCH_LIST="7.5"

# List available CUDA versions
function cuda_list() {
    echo "Available CUDA versions:"
    ls -d /usr/local/cuda-* 2>/dev/null | grep -oP 'cuda-\K[\d]+\.[\d]+' | sort -V
}

# zsh版本switch-cuda
function switch-cuda() {
    # 显示当前CUDA版本（完整输出，不做任何过滤）
    echo "Current CUDA version:"
    if command -v nvcc &> /dev/null; then
        nvcc -V
    else
        echo "nvcc not found in PATH. No active CUDA version."
        echo "Checking symbol link status..."
        if [ -L "/usr/local/cuda" ]; then
            echo "Current symbol link: $(readlink /usr/local/cuda)"
        else
            echo "No /usr/local/cuda symbol link exists."
        fi
    fi
    echo "----------------------------------------"
    
    # 列出可用的CUDA版本并存储到数组
    local cuda_versions=($(ls -d /usr/local/cuda-* 2>/dev/null | grep -oP 'cuda-\K[\d]+\.[\d]+' | sort -V))
    
    # 检查是否有可用版本
    if [ ${#cuda_versions[@]} -eq 0 ]; then
        echo "No CUDA versions found in /usr/local/"
        return 1
    fi
    
    # 显示版本列表
    echo "Available CUDA versions:"
    for i in {1..${#cuda_versions[@]}}; do
        echo "$i. ${cuda_versions[$i]}"
    done
    
    # 提示用户选择
    read "choice?Enter the number of the version to switch to: "
    
    # 验证用户输入
    if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt "${#cuda_versions[@]}" ]; then
        echo "Invalid choice. Please enter a number between 1 and ${#cuda_versions[@]}"
        return 1
    fi
    
    # 获取选中的版本
    local selected_version="${cuda_versions[$choice]}"
    local cuda_path="/usr/local/cuda-$selected_version"
    
    # 验证CUDA路径存在
    if [ ! -d "$cuda_path" ]; then
        echo "Error: CUDA path $cuda_path does not exist!"
        return 1
    fi
    
    # 切换CUDA版本
    echo "Switching to CUDA $selected_version..."
    sudo rm -f /usr/local/cuda
    sudo ln -s "$cuda_path" /usr/local/cuda
    
    # 立即更新当前shell的环境变量
    export PATH="/usr/local/cuda/bin:$PATH"
    export LD_LIBRARY_PATH="/usr/local/cuda/lib64:$LD_LIBRARY_PATH"
    export CUDA_HOME="/usr/local/cuda"
    
    # 显示切换后的版本信息（完整输出）
    echo "----------------------------------------"
    echo "Successfully switched to CUDA version:"
    if [ -x "$cuda_path/bin/nvcc" ]; then
        "$cuda_path/bin/nvcc" -V
    else
        echo "Warning: nvcc not found in $cuda_path/bin"
    fi
}

# 共享代理开关函数
# 使用前需替换：SHARE_IP=你的共享IP（如192.168.1.100），PROXY_PORT=共享IP的HTTP代理端口（如10808）
#function proxy() {
#    local SHARE_IP="127.0.0.1"  
#    local PROXY_PORT="7890"          
#    local SOCKS5_PORT="7890"
#    local PROXY_URL="http://$SHARE_IP:$PROXY_PORT"
#
#    if [ "$1" = "on" ]; then
#        # 开启代理：设置HTTP/HTTPS/SOCKS5代理环境变量
#        export http_proxy="$PROXY_URL"
#        export https_proxy="$PROXY_URL"
#        export all_proxy="socks5://$SHARE_IP:$SOCKS5_PORT"  # 若需SOCKS5代理可保留，无需则删除
#        echo -e " 共享IP代理已开启\n服务器：$SHARE_IP:$PROXY_PORT"
#    elif [ "$1" = "off" ]; then
#        # 关闭代理：清空代理环境变量
#        unset http_proxy https_proxy all_proxy
#        echo -e " 共享IP代理已关闭"
#    elif [ "$1" = "status" ]; then
#        # 查看代理状态
#        if [ -n "$http_proxy" ]; then
#            echo -e " 当前代理状态：已开启"
#            echo "HTTP 代理：$http_proxy"
#            echo "HTTPS 代理：$https_proxy"
#            [ -n "$all_proxy" ] && echo "SOCKS5 代理：$all_proxy"
#        else
#            echo -e " 当前代理状态：已关闭"
#        fi
#    else
#        # 提示用法
#        echo " 局域网代理开关用法："
#        echo "  proxy on    - 开启代理（连接共享IP端口）"
#        echo "  proxy off   - 关闭代理"
#        echo "  proxy status- 查看代理状态"
#    fi
#}

function proxy() {
    local SHARE_IP="127.0.0.1"
    local PROXY_PORT="7890"
    local SOCKS5_PORT="7890"
    local PROXY_URL="http://$SHARE_IP:$PROXY_PORT"

    if [ "$1" = "on" ]; then
        # 开启代理：设置HTTP/HTTPS/SOCKS5代理环境变量
        export http_proxy="$PROXY_URL"
        export https_proxy="$PROXY_URL"
        export all_proxy="socks5://$SHARE_IP:$SOCKS5_PORT"
        echo -e "✅ 共享IP代理已开启"
        echo -e "服务器：$SHARE_IP:$PROXY_PORT"

    elif [ "$1" = "off" ]; then
        # 关闭代理：清空代理环境变量
        unset http_proxy https_proxy all_proxy
        echo -e "❌ 共享IP代理已关闭"

    elif [ "$1" = "status" ]; then
        # 查看代理状态 + 显示公网IP
        echo -e "\n=== 代理状态 ==="
        if [ -n "$http_proxy" ]; then
            echo -e "✅ 当前代理状态：已开启"
            echo "HTTP  代理：$http_proxy"
            echo "HTTPS 代理：$https_proxy"
            [ -n "$all_proxy" ] && echo "SOCKS5代理：$all_proxy"
        else
            echo -e "❌ 当前代理状态：已关闭"
        fi

        echo -e "\n=== 公网 IP 信息 ==="
        # 自动根据代理状态决定是否走代理查询 IP
        if [ -n "$http_proxy" ]; then
            curl -x "$http_proxy" -s ipinfo.io
        else
            curl -s ipinfo.io
        fi
        echo -e "\n"

    else
        # 提示用法
        echo -e "\n📌 局域网代理开关用法："
        echo "  proxy on     - 开启代理（连接共享IP端口）"
        echo "  proxy off    - 关闭代理"
        echo "  proxy status - 查看代理状态 + 公网IP信息"
        echo ""
    fi
}

export CC=/usr/bin/gcc
export CXX=/usr/bin/g++
export PATH="$HOME/.local/bin:$PATH"
export PATH="$HOME/.local/bin:$PATH"

[ ! -f "$HOME/.x-cmd.root/X" ] || . "$HOME/.x-cmd.root/X" # boot up x-cmd.

eval "$(starship init zsh)"

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
export VIRTUAL_ENV_DISABLE_PROMPT=1

bindkey -s '\e\e' '\C-asudo \C-e'

export PATH="$HOME/.npm-global/bin:$PATH"

# OpenClaw Completion
# source "/home/jianmop/.openclaw/completions/openclaw.zsh"
# alias oc='openclaw'

alias hm='hermes'

alias sshai="ssh 100.66.1.5 -p 2213"
export PATH=$PATH:/usr/local/go/bin

# >>> uv mirror managed block >>>
export UV_INSTALLER_GITHUB_BASE_URL="https://uv.agentsmirror.com/github"
export UV_PYTHON_DOWNLOADS_JSON_URL="https://uv.agentsmirror.com/metadata/python-downloads.json"
export UV_PYPY_INSTALL_MIRROR="https://uv.agentsmirror.com/pypy"
export UV_DEFAULT_INDEX="https://uv.agentsmirror.com/pypi/simple"
# <<< uv mirror managed block <<<
export UV_DEFAULT_INDEX="https://pypi.tuna.tsinghua.edu.cn/simple"

alias bat='batcat'
alias batf='bat --paging=never'

eval "$(zoxide init zsh)"
