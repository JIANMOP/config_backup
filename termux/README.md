```sh
# 安装并配置zimfw [Zim Framework](https://zimfw.sh/)
> pkg install curl -y
> pkg install zsh -y
# 切换默认 shell，重启生效
> chsh -s zsh
# 验证
> echo $SHELL

> curl -fsSL https://raw.githubusercontent.com/zimfw/install/master/install.zsh | zsh
# 修改 .zimrc
# 重启

> pkg install git vim wget openssh -y

# 查看用户名
> whoami
# 设置用户密码（ssh必须做）
> passwd

# 安装 starship [Starship](https://starship.rs/zh-CN/)
> curl -sS https://starship.rs/install.sh | sh
# ~/.zshrc 添加
eval "$(starship init zsh)"
# 创建配置文件
> mkdir -p ~/.config && touch ~/.config/starship.toml

```

