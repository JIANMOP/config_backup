#!/usr/bin/env pwsh
<#
.SYNOPSIS
    PowerShell implementation of ssh-copy-id for Windows
.DESCRIPTION
    Copies SSH public key to remote host's authorized_keys file to enable passwordless login
.PARAMETER Target
    Username@hostname or hostname (will prompt for username if not provided)
.PARAMETER IdentityFile
    Path to SSH public key file (defaults to ~/.ssh/id_rsa.pub)
.PARAMETER Port
    SSH port (defaults to 22)
.EXAMPLE
    .\ssh-copy-id.ps1 user@example.com
.EXAMPLE
    .\ssh-copy-id.ps1 -Target user@example.com -IdentityFile ~/.ssh/id_ed25519.pub
#>

param(
    [Parameter(Mandatory=$true, Position=0)]
    [string]$Target,
    
    [Parameter(Mandatory=$false)]
    [string]$IdentityFile = "",
    
    [Parameter(Mandatory=$false)]
    [int]$Port = 22
)

# Function to find SSH public key
function Find-SSHPublicKey {
    param([string]$SpecifiedKey)
    
    if ($SpecifiedKey -and (Test-Path $SpecifiedKey)) {
        return $SpecifiedKey
    }
    
    $sshDir = Join-Path $env:USERPROFILE ".ssh"
    $keyTypes = @("id_rsa.pub", "id_ed25519.pub", "id_ecdsa.pub", "id_dsa.pub")
    
    foreach ($keyType in $keyTypes) {
        $keyPath = Join-Path $sshDir $keyType
        if (Test-Path $keyPath) {
            return $keyPath
        }
    }
    
    return $null
}

# Function to parse target (username@host or just host)
function Parse-Target {
    param([string]$Target)
    
    if ($Target -match "^(.+)@(.+)$") {
        return @{
            Username = $matches[1]
            Hostname = $matches[2]
        }
    } else {
        $username = Read-Host "Enter username for $Target"
        return @{
            Username = $username
            Hostname = $Target
        }
    }
}

# Main script
try {
    Write-Host "SSH Copy ID - PowerShell Implementation" -ForegroundColor Green
    Write-Host "=======================================" -ForegroundColor Green
    
    # Parse target
    $targetInfo = Parse-Target -Target $Target
    $username = $targetInfo.Username
    $hostname = $targetInfo.Hostname
    
    Write-Host "Target: $username@$hostname" -ForegroundColor Cyan
    
    # Find SSH public key
    $publicKeyPath = Find-SSHPublicKey -SpecifiedKey $IdentityFile
    if (-not $publicKeyPath) {
        Write-Error "No SSH public key found. Please generate one with 'ssh-keygen' first."
        exit 1
    }
    
    Write-Host "Using public key: $publicKeyPath" -ForegroundColor Cyan
    
    # Read the public key
    $publicKey = Get-Content $publicKeyPath -Raw
    $publicKey = $publicKey.Trim()
    
    if (-not $publicKey) {
        Write-Error "Public key file is empty or invalid: $publicKeyPath"
        exit 1
    }
    
    Write-Host "Public key loaded successfully" -ForegroundColor Green
    
    # Get password securely
    $credential = Get-Credential -UserName $username -Message "Enter password for $username@$hostname"
    if (-not $credential) {
        Write-Host "Authentication cancelled." -ForegroundColor Yellow
        exit 1
    }
    
    Write-Host "Connecting to $hostname..." -ForegroundColor Yellow
    
    # Based on the error, the remote host is running PowerShell
    # Let's use PowerShell commands directly
    Write-Host "Using PowerShell commands for remote host" -ForegroundColor Cyan
    
    # PowerShell commands for Windows (using semicolon separators)
    $sshCommand = "if (!(Test-Path ~/.ssh)) { New-Item -ItemType Directory -Path ~/.ssh -Force }; " +
                 "Add-Content -Path ~/.ssh/authorized_keys -Value '$publicKey'; " +
                 "Write-Host 'SSH key added successfully'"
    
    # Execute SSH command
    $sshArgs = @(
        "-o", "StrictHostKeyChecking=no"
        "-p", $Port
        "$username@$hostname"
        $sshCommand
    )
    
    try {
        
        Write-Host "Attempting to connect and copy SSH key..." -ForegroundColor Yellow
        Write-Host "You will be prompted for your password..." -ForegroundColor Yellow
        
        # Execute SSH command
        $result = & ssh @sshArgs
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "" -ForegroundColor Green
            Write-Host "SUCCESS!" -ForegroundColor Green
            Write-Host "SSH public key has been copied to $username@$hostname" -ForegroundColor Green
            Write-Host "You should now be able to log in without a password:" -ForegroundColor Green
            Write-Host "  ssh $username@$hostname" -ForegroundColor Cyan
        } else {
            Write-Error "Failed to copy SSH key. Exit code: $LASTEXITCODE"
            Write-Host "Please ensure:" -ForegroundColor Yellow
            Write-Host "  1. SSH is installed and in your PATH" -ForegroundColor Yellow
            Write-Host "  2. The remote host is accessible" -ForegroundColor Yellow
            Write-Host "  3. Your credentials are correct" -ForegroundColor Yellow
            Write-Host "  4. The remote host allows SSH key authentication" -ForegroundColor Yellow
        }
        
    } catch {
        Write-Error "Error executing SSH command: $($_.Exception.Message)"
        Write-Host "" -ForegroundColor Yellow
        Write-Host "Alternative manual method:" -ForegroundColor Yellow
        Write-Host "1. Copy this public key:" -ForegroundColor Yellow
        Write-Host $publicKey -ForegroundColor Cyan
        Write-Host "" -ForegroundColor Yellow
        Write-Host "2. SSH to the remote host manually:" -ForegroundColor Yellow
        Write-Host "   ssh $username@$hostname" -ForegroundColor Cyan
        Write-Host "" -ForegroundColor Yellow
        Write-Host "3. Run these commands on the remote host:" -ForegroundColor Yellow
        Write-Host "   mkdir -p ~/.ssh" -ForegroundColor Cyan
        Write-Host "   chmod 700 ~/.ssh" -ForegroundColor Cyan
        Write-Host "   echo 'YOUR_PUBLIC_KEY_HERE' >> ~/.ssh/authorized_keys" -ForegroundColor Cyan
        Write-Host "   chmod 600 ~/.ssh/authorized_keys" -ForegroundColor Cyan
    }
    
} catch {
    Write-Error "Script error: $($_.Exception.Message)"
    exit 1
}