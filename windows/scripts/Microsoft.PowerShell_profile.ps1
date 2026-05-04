Import-Module PSReadLine
Invoke-Expression (&starship init powershell)
function Invoke-Starship-TransientFunction {
    "$(&starship prompt --profile transient) "
}

Enable-TransientPrompt


Set-PSReadlineKeyHandler -Chord Tab -Function MenuComplete
Set-PSReadLineOption -PredictionSource History
# Set-PSReadLineOption -PredictionViewStyle ListView
(& uv generate-shell-completion powershell) | Out-String | Invoke-Expression

# ========== 新增：移植 cmd alias 到 PowerShell ==========
# ========== 修复后的 alias/函数配置（替换原有 ll/ls） ==========
# 1. ll = dir /w （精简列显示，兼容所有 PowerShell 版本）
function ll {
    # Format-Wide 模拟 dir /w 的宽列表显示效果
    Get-ChildItem -Force | Format-Wide -Column 4  # -Column 4 对应 dir /w 的列数
}

# 2. grep = findstr $* （文本匹配，兼容 cmd 用法）
function grep {
    param(
        [Parameter(Position=0, Mandatory=$true)]
        [string]$Pattern,
        [Parameter(Position=1, Mandatory=$false)]
        [string]$Path = $null
    )
    if ($Path) {
        Select-String -Path $Path -Pattern $Pattern
    } else {
        $input | Select-String -Pattern $Pattern
    }
}

# 3. ls = dir $* （完整显示目录，和 cmd dir 效果一致）
function ls {
    # Format-Table 模拟 dir 的完整列表显示
    Get-ChildItem -Force | Format-Table -AutoSize Mode, LastWriteTime, Length, Name
}

# 4. omd = defuddle parse （保留）
function omd {
    npx defuddle parse @args
}
