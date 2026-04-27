```bash
> sudo apt install zsh git curl vim -y

> echo $SHELL
/bin/bash

> which zsh
/usr/bin/zsh

> sudo vim /etc/shells                                                                                                                                                                                                                                      
/bin/sh
/bin/bash
/usr/bin/bash
/bin/rbash
/usr/bin/rbash
/usr/bin/sh
/bin/dash
/usr/bin/dash
/bin/zsh

/usr/bin/zsh    #将zsh路径加入

# 切换默认shell
> chsh -s $(which zsh)    # chsh -s /usr/bin/zsh

# 退出重进终端
# 选1：Continue to the main menu
# 选0：Exit，creating a blank ~/.zshrc file

# 安装zimfw框架 [Zim Framework](https://zimfw.sh/)
> curl -fsSL https://raw.githubusercontent.com/zimfw/install/master/install.zsh | zsh
# 安装好之后重进终端
# 修改 .zimrc 和 .zshrc
# 注意注释 .zimrc 里的 zmodule completion

# 安装 starship [Starship](https://starship.rs/zh-CN/)
> curl -sS https://starship.rs/install.sh | sh
# ~/.zshrc 添加
eval "$(starship init zsh)"
# 创建配置文件
> mkdir -p ~/.config && touch ~/.config/starship.toml

# 注意安装 Nerd Font 字体
# Maple Mono NF CN [GitHub Maple Mono](https://github.com/subframe7536/maple-font)
# 安装为系统字体（所有用户可用）
> sudo cp ./*.ttf /usr/share/fonts
# 安装为当前用户字体
> mkdir -p ~/.local/share/fonts
> cp ./*.ttf ~/.local/share/fonts/
# 更新字体缓存
> sudo fc-cache -f -v
```
