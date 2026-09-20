# clink
[clink v1.9.17](https://github.com/chrisant996/clink/releases?page=2#release-v1.9.17)
建议安装 v1.9.17 版本

# starship
[starship](https://github.com/starship/starship)
# cmd
```sh
clink autorun show
clink autorun uninstall
clink autorun install -- --quiet

clink info

# 创建 C:\Users\<username>\AppData\Local\clink\starship.lua
# 写入

-- starship.lua

load(io.popen('starship init cmd'):read("*a"))()

```

# powershell
```sh
# 创建 C:\Users\<username>\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1

# 写入
Invoke-Expression (&starship init powershell)
```
