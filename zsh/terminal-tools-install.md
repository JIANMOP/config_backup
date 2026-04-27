https://mp.weixin.qq.com/s/Dadn1I4j6aX4RmVTB2D9Uw

# eza (https://github.com/eza-community/eza)
终端文件图标、颜色、git 状态

```bash
sudo mkdir -p /etc/apt/keyrings
wget -qO- https://raw.githubusercontent.com/eza-community/eza/main/deb.asc | sudo gpg --dearmor -o /etc/apt/keyrings/gierens.gpg
echo "deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main" | sudo tee /etc/apt/sources.list.d/gierens.list
sudo apt update
sudo apt install eza

vim ~/.zshrc
# 使用 eza 代替传统的 ls，添加图标、显示 Git 状态、按目录优先排序
alias ls='eza --icons --git --group-directories-first'
alias ll='eza -lh --icons --git --group-directories-first'
alias lt='eza --tree --level=2 --icons' # 树状显示，洞察项目结构

source ~/.zshrc
```

# duf (https://github.com/muesli/duf)
终端磁盘空间查看工具，磁盘信息
```bash
sudo apt install duf

vim ~/.zshrc
# 替代 df
alias df='duf'

source ~/.zshrc
```

# bat (https://github.com/sharkdp/bat)
终端文件查看工具，语法高亮
```bash
sudo apt install bat

vim ~/.zshrc
alias bat='batcat'
alias batf='bat --paging=never'
```

# fastfetch (https://github.com/fastfetch-cli/fastfetch)
终端系统信息查看
```bash
wget https://github.com/fastfetch-cli/fastfetch/releases/download/2.62.1/fastfetch-linux-amd64.deb
sudo apt install ./fastfetch-linux-amd64.deb
```

# zoxide (https://github.com/ajeetdsouza/zoxide)
终端记忆跳转路径，记住敲过的路径快速跳转
```bash
curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh

vim ~/.zshrc
eval "$(zoxide init zsh)"
 
# 替换/增强（可选）
alias cd='z'

source ~/.zshrc
```

# lazygit (https://github.com/jesseduffield/lazygit)
终端 Git 界面
```bash
wget https://github.com/jesseduffield/lazygit/releases/download/v0.61.1/lazygit_0.61.1_linux_x86_64.tar.gz
tar -xzvf lazygit_0.61.1_linux_x86_64.tar.gz
sudo cp lazygit /usr/local/bin/
sudo chmod +x /usr/local/bin/lazygit
lazygit --version
```

# lazydocker (https://github.com/jesseduffield/lazydocker)
终端 Docker 界面
```bash
curl https://raw.githubusercontent.com/jesseduffield/lazydocker/master/scripts/install_update_linux.sh | bash
```
