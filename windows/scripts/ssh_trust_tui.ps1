#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Interactive SSH passwordless-login setup tool for Windows (PowerShell).
.DESCRIPTION
    Local machine: Windows (uses the built-in Windows OpenSSH Client).
    Remote machines: Ubuntu or CentOS Linux.

    Features:
      1. Auto-detect hosts from %USERPROFILE%\.ssh\config, pick and configure in batch
      2. Add host(s) into %USERPROFILE%\.ssh\config
      3. Edit/Delete host(s) in %USERPROFILE%\.ssh\config
      4. Manually enter hosts (fallback, session-only, NOT saved to config)
      5. View selected hosts
      6. Remove host(s) from selection
      7. Clear selection
      8. Start setup (generate local key, distribute, verify)
      9. Exit

    Notes:
      - This is a plain numbered console menu (no whiptail-equivalent needed on Windows).
      - There is no native "sshpass" on Windows. If PuTTY's plink.exe is found in PATH
        and you choose to use one shared password, it is used to automate login.
        Otherwise, ssh will prompt for the password interactively per host (native
        Windows OpenSSH behavior) - just type it when asked.
.EXAMPLE
    .\ssh_trust_tui.ps1
#>

$ErrorActionPreference = "Stop"
# PowerShell 7.3+ promotes ANY stderr line from native commands (ssh.exe, plink.exe)
# into a terminating error when $ErrorActionPreference = "Stop". That breaks this
# script's "capture output + check $LASTEXITCODE" pattern, since ssh routinely writes
# harmless text to stderr (e.g. "Warning: Permanently added ... to known hosts").
# Explicitly opt back into the legacy (pre-7.3) behavior so stderr stays plain text.
$PSNativeCommandUseErrorActionPreference = $false

# ==================== Globals ====================
# Each entry: [pscustomobject]@{ Target = "user@host"; Port = 22 }
$Script:Targets = New-Object System.Collections.Generic.List[object]
$Script:SharedPassword = $null   # SecureString, optional

function Get-SshConfigPath {
    $sshDir = Join-Path $env:USERPROFILE ".ssh"
    if (-not (Test-Path $sshDir)) {
        New-Item -ItemType Directory -Path $sshDir -Force | Out-Null
    }
    return (Join-Path $sshDir "config")
}

function Log-Info    { param([string]$Msg) Write-Host "[INFO] $Msg" -ForegroundColor Yellow }
function Log-Success { param([string]$Msg) Write-Host "[OK] $Msg" -ForegroundColor Green }
function Log-Err     { param([string]$Msg) Write-Host "[ERR] $Msg" -ForegroundColor Red }

function Pause-Continue {
    Write-Host ""
    Read-Host "Press Enter to continue" | Out-Null
}

# ==================== Dependency check ====================
function Test-Dependencies {
    $missing = @()
    if (-not (Get-Command ssh -ErrorAction SilentlyContinue))          { $missing += "ssh" }
    if (-not (Get-Command ssh-keygen -ErrorAction SilentlyContinue))   { $missing += "ssh-keygen" }

    if ($missing.Count -gt 0) {
        Write-Host ""
        Log-Err "Missing required command(s): $($missing -join ', ')"
        Log-Info "Enable Windows' built-in OpenSSH Client, e.g.:"
        Log-Info "  Settings > Apps > Optional Features > Add a feature > OpenSSH Client"
        Log-Info "  or run as admin: Add-WindowsCapability -Online -Name OpenSSH.Client~~~~0.0.1.0"
        Pause-Continue
        exit 1
    }

    if (-not (Get-Command plink -ErrorAction SilentlyContinue)) {
        Log-Info "plink.exe (PuTTY) not found - shared-password auto-login will be unavailable."
        Log-Info "Passwordless-key distribution still works; passwords will be typed interactively."
    }
}

# ==================== Host entry parsing ====================
# Supported manual-entry formats:
#   user@ip
#   user@ip -p 2222
function Parse-HostEntry {
    param([string]$Entry)

    $e = $Entry.Trim()
    if ([string]::IsNullOrWhiteSpace($e)) { return $null }

    $port = 22
    if ($e -match '^(?<host>.+\S)\s+-p\s+(?<port>\d+)$') {
        $e = $Matches['host']
        $port = [int]$Matches['port']
    }

    # If no "user@" prefix was given, prompt for the username interactively
    # (mirrors ssh-copy-id.ps1's Parse-Target behavior).
    if ($e -notmatch '@') {
        $u = Read-Host "Enter username for $e"
        if ([string]::IsNullOrWhiteSpace($u)) { return $null }
        $e = "$u@$e"
    }

    return [pscustomobject]@{
        Target = $e
        Port   = $port
    }
}

# Supported "add to config" formats (one per line):
#   ALIAS user@ip
#   ALIAS user@ip -p 2222
function Parse-ConfigEntryLine {
    param([string]$Line)

    $l = $Line.Trim()
    if ([string]::IsNullOrWhiteSpace($l)) { return $null }

    if ($l -match '^(?<alias>\S+)\s+(?<user>[^\s@]+)@(?<hostip>\S+?)(?:\s+-p\s+(?<port>\d+))?$') {
        return [pscustomobject]@{
            Alias  = $Matches['alias']
            User   = $Matches['user']
            HostIp = $Matches['hostip']
            Port   = if ($Matches['port']) { [int]$Matches['port'] } else { 22 }
        }
    }
    return $null
}

# ==================== ~/.ssh/config helpers ====================

# Returns array of alias strings found in config (wildcard aliases like "Host *" excluded)
# NOTE: the leading "," on both return statements is required. Without it, PowerShell
# auto-unwraps a single-item collection into a bare scalar when it crosses the function
# return boundary - e.g. a 1-alias List<string> would come back as the raw string itself,
# and $aliases[0] on a plain string indexes its first CHARACTER, not the first element.
function Get-ConfigAliases {
    $config = Get-SshConfigPath
    if (-not (Test-Path $config)) { return , @() }

    $aliases = New-Object System.Collections.Generic.List[string]
    Get-Content $config | Where-Object { $_ -match '^\s*Host\s+' } | ForEach-Object {
        $tokens = ($_ -replace '^\s*Host\s+', '').Trim() -split '\s+'
        foreach ($t in $tokens) {
            if ($t -notmatch '[\*\?]') { $aliases.Add($t) }
        }
    }
    return , $aliases
}

# Uses "ssh -G <alias>" to resolve the effective hostname/user/port for an alias
function Get-AliasInfo {
    param([string]$Alias)

    $out = & ssh -G $Alias 2>$null
    $hostname = ($out | Where-Object { $_ -match '^hostname\s+' }) -replace '^hostname\s+', '' | Select-Object -First 1
    $user     = ($out | Where-Object { $_ -match '^user\s+' })     -replace '^user\s+', ''     | Select-Object -First 1
    $port     = ($out | Where-Object { $_ -match '^port\s+' })     -replace '^port\s+', ''     | Select-Object -First 1

    return [pscustomobject]@{ HostName = $hostname; User = $user; Port = $port }
}

# Finds the line range (1-based, inclusive) of "Host ALIAS" block.
# Returns $null if not found, otherwise @{ Start = n; End = m; Lines = ... }
function Get-ConfigBlockRange {
    param([string]$Alias)

    $config = Get-SshConfigPath
    if (-not (Test-Path $config)) { return $null }

    # Wrap with @(...) so a config with exactly 1 line is still treated as an array,
    # not unwrapped into a bare string (same class of issue as Get-ConfigAliases).
    $lines = @(Get-Content $config)
    $start = $null
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match "^\s*Host\s+$([regex]::Escape($Alias))\s*$") {
            $start = $i
            break
        }
    }
    if ($null -eq $start) { return $null }

    $end = $lines.Count - 1
    for ($i = $start + 1; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^\s*Host\s+') {
            $end = $i - 1
            break
        }
    }

    # convert to 1-based inclusive line numbers
    return @{ Start = $start + 1; End = $end + 1; Lines = $lines }
}

# ==================== Menu: Feature 1 - scan config ====================
function Invoke-ScanSshConfig {
    $configPath = Get-SshConfigPath
    $aliases = Get-ConfigAliases
    if ($aliases.Count -eq 0) {
        Log-Info "No usable host alias found in $configPath"
        Pause-Continue
        return
    }

    Write-Host ""
    Write-Host "Reading config from: $configPath" -ForegroundColor DarkGray
    Write-Host "=== Hosts found in ~/.ssh/config ===" -ForegroundColor Cyan
    for ($i = 0; $i -lt $aliases.Count; $i++) {
        $info = Get-AliasInfo -Alias $aliases[$i]
        Write-Host ("  [{0}] {1}  ->  {2}@{3}:{4}" -f ($i + 1), $aliases[$i], $info.User, $info.HostName, $info.Port)
    }
    Write-Host ""
    $sel = Read-Host "Enter numbers to add (comma-separated), 'a' for all, or Enter to cancel"
    if ([string]::IsNullOrWhiteSpace($sel)) { return }

    $indexes = @()
    if ($sel.Trim().ToLower() -eq 'a') {
        $indexes = 1..$aliases.Count
    } else {
        $indexes = $sel -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -match '^\d+$' } | ForEach-Object { [int]$_ }
    }

    $added = 0
    foreach ($idx in $indexes) {
        if ($idx -ge 1 -and $idx -le $aliases.Count) {
            # Port left as $null: connecting via the alias itself already resolves the
            # right port through ~/.ssh/config, so no explicit -p is needed.
            $Script:Targets.Add([pscustomobject]@{ Target = $aliases[$idx - 1]; Port = $null })
            $added++
        }
    }
    Log-Success "Added $added host(s)"
    Pause-Continue
}

# ==================== Menu: Feature 2 - add to config ====================
function Invoke-AddToSshConfig {
    $config = Get-SshConfigPath
    if (-not (Test-Path $config)) { New-Item -ItemType File -Path $config -Force | Out-Null }

    Write-Host ""
    Write-Host "Enter host entries, one per line: ALIAS user@ip [-p PORT]" -ForegroundColor Cyan
    Write-Host "Example: web1 root@172.16.143.4 -p 17022" -ForegroundColor Cyan
    Write-Host "Empty line to finish." -ForegroundColor Cyan
    Write-Host ""

    $existing = Get-ConfigAliases
    $added = 0
    while ($true) {
        $line = Read-Host "Entry"
        if ([string]::IsNullOrWhiteSpace($line)) { break }

        $parsed = Parse-ConfigEntryLine -Line $line
        if (-not $parsed) {
            Log-Err "Invalid format, skipped: $line"
            continue
        }
        if ($existing -contains $parsed.Alias) {
            Log-Err "Alias '$($parsed.Alias)' already exists in config, skipped"
            continue
        }

        Log-Info "Parsed -> Host $($parsed.Alias) : $($parsed.User)@$($parsed.HostIp):$($parsed.Port)"
        $confirm = Read-Host "Write this to ~/.ssh/config? [Y/n]"
        if ($confirm.Trim().ToLower() -eq 'n') {
            Log-Info "Skipped"
            continue
        }

        Add-Content -Path $config -Value ""
        Add-Content -Path $config -Value "Host $($parsed.Alias)"
        Add-Content -Path $config -Value "    HostName $($parsed.HostIp)"
        Add-Content -Path $config -Value "    User $($parsed.User)"
        Add-Content -Path $config -Value "    Port $($parsed.Port)"

        $existing += $parsed.Alias
        Log-Success "Added '$($parsed.Alias)' -> $($parsed.User)@$($parsed.HostIp):$($parsed.Port)"
        $added++
    }

    Log-Success "Done. $added entrie(s) added to $config"
    Log-Info "Use 'Auto-detect hosts from ~/.ssh/config' to select them"
    Pause-Continue
}

# ==================== Menu: Feature 3 - edit/delete config entries ====================
function Invoke-EditConfigEntry {
    param([string]$Alias)

    $range = Get-ConfigBlockRange -Alias $Alias
    if (-not $range) {
        Log-Err "Could not locate block for '$Alias'"
        Pause-Continue
        return
    }

    $lines = $range.Lines
    $blockLines = $lines[($range.Start - 1)..($range.End - 1)]

    $curHostName = ($blockLines | Where-Object { $_ -match '^\s*HostName\s+' }) -replace '^\s*HostName\s+', '' | Select-Object -First 1
    $curUser     = ($blockLines | Where-Object { $_ -match '^\s*User\s+' })     -replace '^\s*User\s+', ''     | Select-Object -First 1
    $curPort     = ($blockLines | Where-Object { $_ -match '^\s*Port\s+' })     -replace '^\s*Port\s+', ''     | Select-Object -First 1
    if ([string]::IsNullOrWhiteSpace($curPort)) { $curPort = "22" }

    Write-Host ""
    Log-Info "Saving will rewrite this block with only Alias/HostName/User/Port."
    Log-Info "Any other custom options in this block will be removed."
    Write-Host ""

    $newAlias    = Read-Host "Alias [$Alias]"
    if ([string]::IsNullOrWhiteSpace($newAlias)) { $newAlias = $Alias }

    if ($newAlias -ne $Alias -and (Get-ConfigAliases) -contains $newAlias) {
        Log-Err "Alias '$newAlias' already exists"
        Pause-Continue
        return
    }

    $newHostName = Read-Host "HostName [$curHostName]"
    if ([string]::IsNullOrWhiteSpace($newHostName)) { $newHostName = $curHostName }

    $newUser     = Read-Host "User [$curUser]"
    if ([string]::IsNullOrWhiteSpace($newUser)) { $newUser = $curUser }

    $newPort     = Read-Host "Port [$curPort]"
    if ([string]::IsNullOrWhiteSpace($newPort)) { $newPort = $curPort }

    $config = Get-SshConfigPath
    $before = if ($range.Start -gt 1) { $lines[0..($range.Start - 2)] } else { @() }
    $after  = if ($range.End -lt $lines.Count) { $lines[$range.End..($lines.Count - 1)] } else { @() }

    $newBlock = @(
        "Host $newAlias",
        "    HostName $newHostName",
        "    User $newUser",
        "    Port $newPort"
    )

    $final = @()
    $final += $before
    $final += $newBlock
    $final += $after
    Set-Content -Path $config -Value $final

    Log-Success "Updated: Host $newAlias ($newUser@$newHostName`:$newPort)"
    Pause-Continue
}

function Invoke-DeleteConfigEntry {
    param([string]$Alias)

    $range = Get-ConfigBlockRange -Alias $Alias
    if (-not $range) {
        Log-Err "Could not locate block for '$Alias'"
        Pause-Continue
        return
    }

    $confirm = Read-Host "Delete host '$Alias' from ~/.ssh/config? This cannot be undone. [y/N]"
    if ($confirm.Trim().ToLower() -ne 'y') { return }

    $config = Get-SshConfigPath
    $lines = $range.Lines
    $before = if ($range.Start -gt 1) { $lines[0..($range.Start - 2)] } else { @() }
    $after  = if ($range.End -lt $lines.Count) { $lines[$range.End..($lines.Count - 1)] } else { @() }

    $final = @()
    $final += $before
    $final += $after
    Set-Content -Path $config -Value $final

    Log-Success "Deleted '$Alias' from $config"
    Pause-Continue
}

function Invoke-ManageSshConfig {
    while ($true) {
        $configPath = Get-SshConfigPath
        $aliases = Get-ConfigAliases
        if ($aliases.Count -eq 0) {
            Log-Info "No editable host alias found in $configPath"
            Pause-Continue
            return
        }

        Write-Host ""
        Write-Host "Reading config from: $configPath" -ForegroundColor DarkGray
        Write-Host "=== Edit/Delete host(s) in ~/.ssh/config ===" -ForegroundColor Cyan
        for ($i = 0; $i -lt $aliases.Count; $i++) {
            $info = Get-AliasInfo -Alias $aliases[$i]
            Write-Host ("  [{0}] {1}  ->  {2}@{3}:{4}" -f ($i + 1), $aliases[$i], $info.User, $info.HostName, $info.Port)
        }
        Write-Host "  [0] Back"
        Write-Host ""
        $sel = Read-Host "Pick a host number"
        if ($sel -eq '0' -or [string]::IsNullOrWhiteSpace($sel)) { return }
        if ($sel -notmatch '^\d+$' -or [int]$sel -lt 1 -or [int]$sel -gt $aliases.Count) {
            Log-Err "Invalid selection"
            continue
        }

        $alias = $aliases[[int]$sel - 1]
        $action = Read-Host "Host '$alias' - (E)dit or (D)elete? [e/d, Enter to cancel]"
        switch ($action.Trim().ToLower()) {
            'e' { Invoke-EditConfigEntry -Alias $alias }
            'd' { Invoke-DeleteConfigEntry -Alias $alias }
            default { }
        }
    }
}

# ==================== Menu: Feature 4 - manual input (session-only) ====================
function Invoke-ManualInput {
    Write-Host ""
    Write-Host "Fallback, session-only, NOT saved to ~/.ssh/config" -ForegroundColor Cyan
    Write-Host "One or more hosts per line, comma-separated for multiple." -ForegroundColor Cyan
    Write-Host "Format: user@ip   or   user@ip -p PORT" -ForegroundColor Cyan
    Write-Host "Empty line to finish." -ForegroundColor Cyan
    Write-Host ""

    $count = 0
    while ($true) {
        $line = Read-Host "Host(s)"
        if ([string]::IsNullOrWhiteSpace($line)) { break }

        foreach ($piece in ($line -split ',')) {
            $parsed = Parse-HostEntry -Entry $piece
            if ($parsed) {
                $Script:Targets.Add($parsed)
                $count++
            }
        }
    }
    Log-Success "Added $count host(s)"
    Pause-Continue
}

# ==================== Menu: Feature 5 - view selected ====================
function Show-SelectedTargets {
    if ($Script:Targets.Count -eq 0) {
        Log-Info "List is empty"
    } else {
        Write-Host ""
        Write-Host "=== Selected hosts ===" -ForegroundColor Cyan
        for ($i = 0; $i -lt $Script:Targets.Count; $i++) {
            $t = $Script:Targets[$i]
            if ($t.Port) {
                Write-Host ("  [{0}] {1} (-p {2})" -f ($i + 1), $t.Target, $t.Port)
            } else {
                Write-Host ("  [{0}] {1}" -f ($i + 1), $t.Target)
            }
        }
    }
    Pause-Continue
}

# ==================== Menu: Feature 6 - remove from selection ====================
function Show-SelectedTargetsNoPause {
    if ($Script:Targets.Count -eq 0) { return }
    Write-Host ""
    for ($i = 0; $i -lt $Script:Targets.Count; $i++) {
        $t = $Script:Targets[$i]
        if ($t.Port) {
            Write-Host ("  [{0}] {1} (-p {2})" -f ($i + 1), $t.Target, $t.Port)
        } else {
            Write-Host ("  [{0}] {1}" -f ($i + 1), $t.Target)
        }
    }
    Write-Host ""
}

function Invoke-RemoveTargets {
    if ($Script:Targets.Count -eq 0) {
        Log-Info "List is empty, nothing to remove"
        Pause-Continue
        return
    }

    Show-SelectedTargetsNoPause
    $sel = Read-Host "Enter numbers to remove (comma-separated), or Enter to cancel"
    if ([string]::IsNullOrWhiteSpace($sel)) { return }

    $indexes = $sel -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -match '^\d+$' } | ForEach-Object { [int]$_ } | Sort-Object -Descending -Unique

    $removed = 0
    foreach ($idx in $indexes) {
        if ($idx -ge 1 -and $idx -le $Script:Targets.Count) {
            $Script:Targets.RemoveAt($idx - 1)
            $removed++
        }
    }
    Log-Success "Removed $removed host(s), $($Script:Targets.Count) remaining"
    Pause-Continue
}

# ==================== Core: key generation / distribution / verification ====================

function Find-SSHPublicKey {
    $sshDir = Join-Path $env:USERPROFILE ".ssh"
    $keyTypes = @("id_rsa.pub", "id_ed25519.pub", "id_ecdsa.pub", "id_dsa.pub")
    foreach ($k in $keyTypes) {
        $p = Join-Path $sshDir $k
        if (Test-Path $p) { return $p }
    }
    return $null
}

function Ensure-LocalKey {
    $existing = Find-SSHPublicKey
    if ($existing) {
        Log-Success "Local key already exists: $existing"
        return $existing
    }

    Log-Info "No local SSH key found, generating id_rsa..."
    $sshDir = Join-Path $env:USERPROFILE ".ssh"
    if (-not (Test-Path $sshDir)) { New-Item -ItemType Directory -Path $sshDir -Force | Out-Null }
    $keyPath = Join-Path $sshDir "id_rsa"
    & ssh-keygen -t rsa -N '""' -f $keyPath -q
    Log-Success "Local key generated: $keyPath.pub"
    return "$keyPath.pub"
}

# Convert a SecureString to plain text (only used right before calling plink)
function ConvertFrom-SecureToPlain {
    param([System.Security.SecureString]$Secure)
    if (-not $Secure) { return $null }
    $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Secure)
    try {
        return [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
    } finally {
        [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
    }
}

# Builds the remote bash command that appends our public key to authorized_keys.
# The key is base64-encoded to sidestep any quoting issues.
function Build-RemoteInstallCommand {
    param([string]$PublicKey)

    $bytes = [System.Text.Encoding]::UTF8.GetBytes($PublicKey.Trim())
    $b64 = [Convert]::ToBase64String($bytes)

    $template = 'umask 077 && mkdir -p ~/.ssh && KEY=$(echo "__B64__" | base64 -d) && (grep -qxF "$KEY" ~/.ssh/authorized_keys 2>/dev/null || echo "$KEY" >> ~/.ssh/authorized_keys) && chmod 700 ~/.ssh && chmod 600 ~/.ssh/authorized_keys && echo REMOTE_OK'
    return $template.Replace('__B64__', $b64)
}

function Show-ManualFallback {
    param([string]$Target, [Nullable[int]]$Port, [string]$PublicKey)

    $portNote = if ($Port) { " -p $Port" } else { "" }
    Write-Host ""
    Log-Info "Alternative manual method for $Target :"
    Write-Host "1. Copy this public key:" -ForegroundColor Yellow
    Write-Host "   $PublicKey" -ForegroundColor Cyan
    Write-Host "2. SSH to the remote host manually:" -ForegroundColor Yellow
    Write-Host "   ssh$portNote $Target" -ForegroundColor Cyan
    Write-Host "3. Run these commands on the remote host:" -ForegroundColor Yellow
    Write-Host "   mkdir -p ~/.ssh && chmod 700 ~/.ssh" -ForegroundColor Cyan
    Write-Host "   echo 'PASTE_YOUR_PUBLIC_KEY_HERE' >> ~/.ssh/authorized_keys" -ForegroundColor Cyan
    Write-Host "   chmod 600 ~/.ssh/authorized_keys" -ForegroundColor Cyan
    Write-Host ""
}

function Invoke-KeyDistribution {
    param(
        [string]$Target,
        [Nullable[int]]$Port,
        [string]$PublicKey
    )

    $remoteCmd = Build-RemoteInstallCommand -PublicKey $PublicKey
    $label = if ($Port) { "$Target (-p $Port)" } else { $Target }
    Log-Info "Configuring: $label"

    $plink = Get-Command plink -ErrorAction SilentlyContinue
    $usePlink = ($plink -and $Script:SharedPassword)

    try {
        if ($usePlink) {
            $plain = ConvertFrom-SecureToPlain -Secure $Script:SharedPassword
            $plinkArgs = @("-ssh", "-batch")
            if ($Port) { $plinkArgs += @("-P", "$Port") }
            $plinkArgs += @("-pw", $plain, $Target, $remoteCmd)
            $result = & plink @plinkArgs 2>&1
        } else {
            $sshArgs = @("-o", "StrictHostKeyChecking=no")
            if ($Port) { $sshArgs += @("-p", "$Port") }
            $sshArgs += @($Target, $remoteCmd)
            $result = & ssh @sshArgs 2>&1
        }

        if ($LASTEXITCODE -eq 0 -and ($result -match 'REMOTE_OK')) {
            Log-Success "$label key distributed"
        } else {
            Log-Err "$label key distribution failed"
            Show-ManualFallback -Target $Target -Port $Port -PublicKey $PublicKey
        }
    } catch {
        Log-Err "$label error: $($_.Exception.Message)"
        Show-ManualFallback -Target $Target -Port $Port -PublicKey $PublicKey
    }
}

function Invoke-VerifyTrust {
    param([string]$Target, [Nullable[int]]$Port)

    $label = if ($Port) { "$Target (-p $Port)" } else { $Target }
    $sshArgs = @("-o", "BatchMode=yes", "-o", "ConnectTimeout=5")
    if ($Port) { $sshArgs += @("-p", "$Port") }
    $sshArgs += @($Target, "echo OK")

    try {
        $result = & ssh @sshArgs 2>$null
        if ($result -match '^OK$') {
            Log-Success "$label verified OK"
        } else {
            Log-Err "$label verification failed"
        }
    } catch {
        Log-Err "$label verification failed: $($_.Exception.Message)"
    }
}

function Get-DedupedTargets {
    $seen = New-Object System.Collections.Generic.HashSet[string]
    $uniq = New-Object System.Collections.Generic.List[object]
    foreach ($t in $Script:Targets) {
        $key = "$($t.Target)|$($t.Port)"
        if ($seen.Add($key)) { $uniq.Add($t) }
    }
    # Same single-item unwrap issue as Get-ConfigAliases - guard with leading comma.
    return , $uniq
}

function Invoke-RunSetup {
    if ($Script:Targets.Count -eq 0) {
        Log-Info "No hosts added yet, please select or enter hosts first"
        Pause-Continue
        return
    }

    $deduped = Get-DedupedTargets
    $Script:Targets = $deduped

    Write-Host ""
    Write-Host "=== About to configure passwordless login for $($Script:Targets.Count) host(s) ===" -ForegroundColor Cyan
    Show-SelectedTargetsNoPause
    $confirm = Read-Host "Continue? [y/N]"
    if ($confirm.Trim().ToLower() -ne 'y') { return }

    $useShared = Read-Host "Use one shared password for all hosts? [y/N] (No = type password per host)"
    if ($useShared.Trim().ToLower() -eq 'y') {
        # Get-Credential gives a native Windows credential prompt (mirrors ssh-copy-id.ps1).
        # The username field here is only a label; each host still connects as its own
        # configured user - only the password is reused across hosts.
        $cred = Get-Credential -UserName "shared-password" -Message "Enter the password to use for all selected hosts"
        if (-not $cred) {
            Log-Info "Cancelled - falling back to interactive ssh password prompts"
        } else {
            $Script:SharedPassword = $cred.Password
        }
        if (-not (Get-Command plink -ErrorAction SilentlyContinue)) {
            Log-Info "plink.exe not found - falling back to interactive ssh password prompts"
        }
    }

    Clear-Host
    Write-Host "================================================" -ForegroundColor Green
    Write-Host "   Starting SSH passwordless login setup" -ForegroundColor Green
    Write-Host "================================================" -ForegroundColor Green

    $pubKeyPath = Ensure-LocalKey
    $publicKey = (Get-Content $pubKeyPath -Raw).Trim()
    if ([string]::IsNullOrWhiteSpace($publicKey)) {
        Log-Err "Public key file is empty or invalid: $pubKeyPath"
        exit 1
    }

    foreach ($t in $Script:Targets) {
        Invoke-KeyDistribution -Target $t.Target -Port $t.Port -PublicKey $publicKey
    }

    Write-Host ""
    Log-Info "Verifying passwordless login..."
    foreach ($t in $Script:Targets) {
        Invoke-VerifyTrust -Target $t.Target -Port $t.Port
    }

    Write-Host ""
    Log-Info "Setup finished, exiting"
    exit 0
}

# ==================== Main menu ====================
function Show-MainMenu {
    while ($true) {
        Clear-Host
        Write-Host "================================================" -ForegroundColor Green
        Write-Host "   SSH Trust Setup (Windows -> Linux)" -ForegroundColor Green
        Write-Host "================================================" -ForegroundColor Green
        Write-Host " [1] Auto-detect hosts from ~/.ssh/config"
        Write-Host " [2] Add host(s) to ~/.ssh/config"
        Write-Host " [3] Edit/Delete host(s) in ~/.ssh/config"
        Write-Host " [4] Manually enter hosts (fallback, session-only)"
        Write-Host " [5] View selected hosts ($($Script:Targets.Count))"
        Write-Host " [6] Remove host(s) from selection"
        Write-Host " [7] Clear selection"
        Write-Host " [8] Start setup"
        Write-Host " [9] Exit"
        Write-Host ""
        $choice = Read-Host "Choose an action"

        switch ($choice.Trim()) {
            '1' { Invoke-ScanSshConfig }
            '2' { Invoke-AddToSshConfig }
            '3' { Invoke-ManageSshConfig }
            '4' { Invoke-ManualInput }
            '5' { Show-SelectedTargets }
            '6' { Invoke-RemoveTargets }
            '7' { $Script:Targets = New-Object System.Collections.Generic.List[object]; Log-Success "Cleared"; Pause-Continue }
            '8' { Invoke-RunSetup }
            '9' { exit 0 }
            default { }
        }
    }
}

Test-Dependencies
Show-MainMenu