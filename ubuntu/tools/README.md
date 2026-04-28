# [monolith](https://github.com/Y2Z/monolith)
终端网页打包工具 html
```bash
tar -xzvf monolith.tar.gz
sudo cp monolith /usr/local/bin
sudo chmod +x /usr/local/bin/monolith

monolith https://*** -o %title%.%timestamp%.html
```

# [defuddle](https://github.com/kepano/defuddle)
终端网页打包工具 markdown
```bash
npx defuddle parse https://*** -m -o **.md
```

# [omny](https://github.com/timhartmann7/omnyssh)
终端服务器监控、ssh、sftp工具
```bash
tar -xzvf omny.tar.gz
sudo cp omny /usr/local/bin
sudo chmod +x /usr/local/bin/omny
```

# [termscp](https://github.com/veeso/termscp)
终端sftp、scp、ftp、webdav、smb工具
```bash
tar -xzvf termscp.tar.gz
sudo cp termscp /usr/local/bin
sudo chmod +x /usr/local/bin/termscp
```

# [lazygit](https://github.com/jesseduffield/lazygit)
终端git工具
```bash
tar -xzvf lazygit.tar.gz
sudo cp lazygit /usr/local/bin
sudo chmod +x /usr/local/bin/lazygit
```

# port_forward_ssh
ssh终端端口转发工具
```bash
tar -xzvf port_forward_ssh.tar.gz
sudo cp port_forward_ssh /usr/local/bin
sudo chmod +x /usr/local/bin/port_forward_ssh
```

# [nvtop](https://github.com/Syllo/nvtop)
GPU 终端监控工具
```bash
sudo apt install nvtop
```

# [x-cmd](https://cn.x-cmd.com/)
最强工具
```bash
eval "$(curl https://get.x-cmd.com)"

x env use yazi
x env use btop
x ifconfig

x **		# 直接使用二进制包，零安装，即用即跑，不改PATH
x env use **	# x‑cmd 私有包管理，用户级、可迁移、纯净环境；下载到～/.x‑cmd 目录，加入用户 PATH，永久生效；无需 root、不污染系统
x install ** 	# 自动识别系统，调用 apt/brew/dnf/winget 等，或官方脚本；装到系统全局，所有程序可调用；依赖系统环境，可能需要权限；适合系统级软件（docker、git等）
```

# [uv](https://github.com/astral-sh/uv)
# [uv-custom 国内镜像](https://gitee.com/wangnov/uv-custom)
新一代极速 python 虚拟环境管理器，代替 conda
```bash
# 使用 uv-custom 安装会自动换源，具体查看项目 README

# On macOS and Linux.
curl -LsSf https://astral.sh/uv/install.sh | sh
# or
curl -LsSf https://uv.agentsmirror.com/install-cn.sh | sh


# On Windows.
powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"
# or
powershell -ExecutionPolicy ByPass -c "irm https://uv.agentsmirror.com/install-cn.ps1 | iex"

# update
uv self update
```

