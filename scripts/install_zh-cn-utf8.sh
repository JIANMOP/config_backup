#!/bin/bash
set -e
sudo apt update -y
sudo apt install -y language-pack-zh-hans
sudo locale-gen zh_CN.UTF-8
grep -q "set encoding=utf-8" /etc/vim/vimrc || sudo tee -a /etc/vim/vimrc >/dev/null <<'EOF'
set encoding=utf-8
set fileencodings=utf-8,gb18030,gbk,gb2312,ucs-bom
set termencoding=utf-8
EOF


# 仅安装中文UTF-8支持，系统保持英文界面
# 修复Vim中文乱码，不修改系统默认语言
# only install zh-cn-utf8 package,system still use English
# resolve vim Chinese garbled text
