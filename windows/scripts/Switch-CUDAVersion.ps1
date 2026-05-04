# Optimized CUDA Version Switcher
# This script automates the process of switching between installed CUDA versions on Windows

param(
    [string]$Version,
    [switch]$ListVersions,
    [switch]$GetCurrent,
    [switch]$DebugMode,
    [switch]$AutoExit  # 新增参数：自动退出模式（默认关闭）
)

# 设置调试模式
if ($DebugMode) {
    $DebugPreference = "Continue"
}

# 全局变量存储已安装版本
$global:InstalledCUDAVersions = @()

# Function to display current nvcc version
function Show-NvccVersion {
    Write-Host "Current CUDA Compiler Version:" -ForegroundColor Yellow
    Write-Host "================================" -ForegroundColor Yellow
    
    try {
        # 尝试执行 nvcc -V 命令
        $nvccOutput = & nvcc -V 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            # 按行分割输出并逐行显示以保持格式
            $nvccOutput -split "`n" | ForEach-Object {
                if ($_.Trim() -ne "") {
                    Write-Host $_.TrimEnd() -ForegroundColor Cyan
                }
            }
        } else {
            Write-Host "nvcc command not found or failed to execute." -ForegroundColor Red
            Write-Host "This might indicate that CUDA is not properly installed or not in PATH." -ForegroundColor Red
        }
    }
    catch {
        Write-Host "Error executing nvcc command: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "Please ensure CUDA is properly installed and nvcc is in your PATH." -ForegroundColor Red
    }
    
    Write-Host "================================" -ForegroundColor Yellow
    Write-Host
}

# Function to get all installed CUDA versions
function Get-InstalledCUDAVersions {
    $cudaPath = "C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA"
    Write-Debug "Checking CUDA installation path: $cudaPath"
    
    if (-not (Test-Path $cudaPath)) {
        Write-Debug "Path not found: $cudaPath"
        return @()
    }
    
    $versions = @()
    Get-ChildItem $cudaPath -Directory | ForEach-Object {
        $dirName = $_.Name
        Write-Debug "Found directory: $dirName"
        
        # 精确匹配"v主版本.次版本"格式
        if ($dirName -match '^v(\d+)\.(\d+)$') {
            $version = "$($matches[1]).$($matches[2])"
            $versions += $version
            Write-Debug "Matched version: $version"
        }
    }
    
    # 保存到全局变量用于调试
    $global:InstalledCUDAVersions = $versions
    
    return $versions | Sort-Object -Descending { [Version]$_ }
}

# Function to get current CUDA version
function Get-CurrentCUDAVersion {
    $cudaPath = [Environment]::GetEnvironmentVariable("CUDA_PATH", [EnvironmentVariableTarget]::Machine)
    Write-Debug "Current CUDA_PATH: $cudaPath"
    
    if ($cudaPath -and (Test-Path $cudaPath)) {
        $dirName = Split-Path $cudaPath -Leaf
        Write-Debug "CUDA_PATH directory name: $dirName"
        
        if ($dirName -match '^v(\d+)\.(\d+)$') {
            $version = "$($matches[1]).$($matches[2])"
            Write-Debug "Current CUDA version: $version"
            return $version
        }
    }
    
    Write-Debug "No CUDA version detected."
    return $null
}

# Function to update environment variables
function Update-CUDAEnvironment($version) {
    $versionPath = "C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v$version"
    Write-Debug "Setting CUDA path to: $versionPath"
    
    # 验证路径是否存在
    if (-not (Test-Path $versionPath)) {
        Write-Host "Error: Path '$versionPath' does not exist." -ForegroundColor Red
        exit 1
    }
    
    # Update CUDA_PATH variables
    [Environment]::SetEnvironmentVariable("CUDA_PATH", $versionPath, [EnvironmentVariableTarget]::Machine)
    [Environment]::SetEnvironmentVariable("CUDA_PATH_V$($version -replace '\.', '_')", $versionPath, [EnvironmentVariableTarget]::Machine)
    Write-Debug "Set CUDA_PATH and CUDA_PATH_V$($version -replace '\.', '_')"

    # Update Path variable
    $path = [Environment]::GetEnvironmentVariable("Path", [EnvironmentVariableTarget]::Machine)
    $newPaths = @(
        "$versionPath\bin",
        "$versionPath\libnvvp"
    )
    
    # 验证bin和libnvvp目录是否存在
    foreach ($newPath in $newPaths) {
        if (-not (Test-Path $newPath)) {
            Write-Warning "Path '$newPath' does not exist and will not be added to PATH."
        }
    }
    
    $pathParts = $path -split ';' | Where-Object { $_ -notmatch 'NVIDIA GPU Computing Toolkit\\CUDA' }
    $validNewPaths = $newPaths | Where-Object { Test-Path $_ }
    $newPath = ($validNewPaths + $pathParts) -join ';'
    
    [Environment]::SetEnvironmentVariable("Path", $newPath, [EnvironmentVariableTarget]::Machine)
    Write-Debug "Updated PATH environment variable"
}

# Function to switch CUDA version
function Switch-CUDAVersion($version) {
    $installedVersions = Get-InstalledCUDAVersions
    Write-Debug "Installed versions: $($installedVersions -join ', ')"
    
    if ($installedVersions -notcontains $version) {
        Write-Host "Error: CUDA version $version is not installed." -ForegroundColor Red
        Write-Host "Installed versions: $($installedVersions -join ', ')"
        exit 1
    }
    
    Update-CUDAEnvironment $version
    Write-Host "CUDA version switched to $version. Please restart your command prompt or applications for the changes to take effect." -ForegroundColor Green
}

# 字符串编码转换函数
function Convert-StringEncoding {
    param (
        [string]$InputString
    )
    
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($InputString)
    return [System.Text.Encoding]::Default.GetString($bytes)
}

# 等待用户按键函数
function Wait-ForUser {
    param (
        [string]$Message = "Press any key to exit..."
    )
    
    Write-Host
    Write-Host $Message -ForegroundColor Cyan
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

# Main script logic
Write-Debug "Starting CUDA Version Switcher script"

# 显示当前CUDA编译器版本信息
Show-NvccVersion

$installedVersions = Get-InstalledCUDAVersions
Write-Debug "Final installed versions array: $($installedVersions -join ', ')"

if ($installedVersions.Count -eq 0) {
    Write-Host "No CUDA versions found. Please install CUDA Toolkit." -ForegroundColor Yellow
    if (-not $AutoExit) { Wait-ForUser }
    exit 1
}

# 调试输出：显示全局变量和实际显示的版本
Write-Debug "Global InstalledCUDAVersions: $($global:InstalledCUDAVersions -join ', ')"

if ($ListVersions) {
    Write-Host "Installed CUDA versions:" -ForegroundColor Cyan
    $installedVersions | ForEach-Object { Write-Host $_ }
    if (-not $AutoExit) { Wait-ForUser }
    exit 0
}

if ($GetCurrent) {
    $currentVersion = Get-CurrentCUDAVersion
    if ($currentVersion) {
        Write-Host "Current CUDA version: $currentVersion" -ForegroundColor Cyan
    } else {
        Write-Host "No CUDA version is currently set." -ForegroundColor Yellow
    }
    if (-not $AutoExit) { Wait-ForUser }
    exit 0
}

if ($Version) {
    Switch-CUDAVersion $Version
} else {
    Write-Host "Available CUDA versions:" -ForegroundColor Cyan
    
    # 直接显示全局变量中的版本，用于验证
    Write-Debug "Global versions for display: $($global:InstalledCUDAVersions -join ', ')"
    
    # 创建一个有序的版本列表（升序排列，让低版本在前）
    $sortedVersions = $installedVersions | Sort-Object { [Version]$_ }
    Write-Debug "Sorted versions: $($sortedVersions -join ', ')"
    
    for ($i = 0; $i -lt $sortedVersions.Count; $i++) {
        $versionStr = $sortedVersions[$i]
        
        # 尝试编码转换
        $displayVersion = Convert-StringEncoding -InputString $versionStr
        Write-Debug "Original version: '$versionStr'"
        Write-Debug "Converted version: '$displayVersion'"
        Write-Debug "Version object type: $($versionStr.GetType().FullName)"
        
        # 确保使用完整的版本字符串
        $safeVersion = [string]$versionStr
        Write-Debug "Safe version: '$safeVersion'"
        
        Write-Host "$($i + 1). $safeVersion"
    }

    $selection = Read-Host "Enter the number of the CUDA version you want to switch to"
    
    if ($selection -match '^\d+$' -and $selection -ge 1 -and $selection -le $sortedVersions.Count) {
        # 使用排序后的版本列表进行选择
        $selectedVersion = $sortedVersions[$selection - 1]
        Write-Debug "Selected version: $selectedVersion"
        Switch-CUDAVersion $selectedVersion
    } else {
        Write-Host "Invalid selection. No changes made." -ForegroundColor Red
    }
}

# 等待用户按键（默认等待，除非启用AutoExit）
if (-not $AutoExit) {
    Wait-ForUser
}