<#
.SYNOPSIS
    clawsetup - Install or update the custom OpenClaw fork with full agent autonomy.
.DESCRIPTION
    One-liner: iwr -useb https://raw.githubusercontent.com/caydenchapple/openclaw/main/scripts/clawsetup.ps1 | iex
    Installs Node, Git, pnpm if needed, clones the fork, builds, applies trust settings,
    and sets up automation-mcp for desktop control.
.PARAMETER InstallDir
    Base directory for the install (default: $env:USERPROFILE\.clawsetup).
.PARAMETER SkipAutomation
    Skip automation-mcp setup.
.PARAMETER DryRun
    Print what would happen without making changes.
#>
param(
    [string]$InstallDir = "$env:USERPROFILE\.clawsetup",
    [switch]$SkipAutomation,
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"
$RepoUrl = "https://github.com/caydenchapple/openclaw.git"
$AutomationRepoUrl = "https://github.com/ashwwwin/automation-mcp.git"
$RepoDir = Join-Path $InstallDir "openclaw"
$BinDir = Join-Path $env:USERPROFILE ".local\bin"
$AutomationDir = Join-Path $env:USERPROFILE ".local\share\automation-mcp"

function Write-Step { param([string]$Msg) Write-Host "`n>> $Msg" -ForegroundColor Cyan }
function Write-Ok   { param([string]$Msg) Write-Host "   $Msg" -ForegroundColor Green }
function Write-Warn { param([string]$Msg) Write-Host "   $Msg" -ForegroundColor Yellow }
function Write-Err  { param([string]$Msg) Write-Host "   $Msg" -ForegroundColor Red }

function Test-Command { param([string]$Name) return [bool](Get-Command $Name -ErrorAction SilentlyContinue) }

function Install-WithWinget {
    param([string]$PackageId, [string]$Name)
    if (Test-Command "winget") {
        Write-Ok "Installing $Name via winget..."
        if (-not $DryRun) { winget install --id $PackageId --accept-source-agreements --accept-package-agreements -e }
        return $true
    }
    return $false
}

function Install-WithChoco {
    param([string]$Package, [string]$Name)
    if (Test-Command "choco") {
        Write-Ok "Installing $Name via chocolatey..."
        if (-not $DryRun) { choco install $Package -y }
        return $true
    }
    return $false
}

function Install-WithScoop {
    param([string]$Package, [string]$Name)
    if (Test-Command "scoop") {
        Write-Ok "Installing $Name via scoop..."
        if (-not $DryRun) { scoop install $Package }
        return $true
    }
    return $false
}

function Ensure-Tool {
    param([string]$Cmd, [string]$WingetId, [string]$ChocoName, [string]$ScoopName, [string]$Label)
    if (Test-Command $Cmd) {
        Write-Ok "$Label already installed."
        return
    }
    Write-Step "Installing $Label..."
    $ok = (Install-WithWinget $WingetId $Label) -or
          (Install-WithChoco $ChocoName $Label) -or
          (Install-WithScoop $ScoopName $Label)
    if (-not $ok) {
        Write-Err "Could not install $Label. Please install it manually and re-run this script."
        exit 1
    }
    # Refresh PATH for this session
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" +
                [System.Environment]::GetEnvironmentVariable("Path", "User")
    if (-not (Test-Command $Cmd)) {
        Write-Warn "$Label installed but not on PATH yet. You may need to restart your terminal after setup."
    }
}

# ── Banner ──
Write-Host ""
Write-Host "  clawsetup - Custom OpenClaw Installer" -ForegroundColor Cyan
Write-Host "  github.com/caydenchapple/openclaw" -ForegroundColor DarkGray
Write-Host ""
if ($DryRun) { Write-Warn "DRY RUN - no changes will be made." }

# ── 1. Prerequisites ──
Write-Step "Checking prerequisites..."

Ensure-Tool "git"  "Git.Git"             "git"    "git"    "Git"
Ensure-Tool "node" "OpenJS.NodeJS.LTS"   "nodejs" "nodejs" "Node.js"

# Check Node version
if (Test-Command "node") {
    $nodeVer = (node -v) -replace '^v',''
    $major = [int]($nodeVer.Split('.')[0])
    if ($major -lt 22) {
        Write-Warn "Node.js $nodeVer found but 22+ is required. Attempting upgrade..."
        Ensure-Tool "node" "OpenJS.NodeJS.LTS" "nodejs" "nodejs" "Node.js 22+"
    } else {
        Write-Ok "Node.js v$nodeVer"
    }
}

# Ensure pnpm
if (-not (Test-Command "pnpm")) {
    Write-Step "Installing pnpm..."
    if (-not $DryRun) { npm install -g pnpm }
}
Write-Ok "pnpm ready."

# ── 2. Clone or update the repo ──
Write-Step "Setting up OpenClaw..."
if (-not (Test-Path $InstallDir)) {
    if (-not $DryRun) { New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null }
}

if (Test-Path (Join-Path $RepoDir ".git")) {
    Write-Ok "Existing install found. Updating..."
    if (-not $DryRun) {
        Push-Location $RepoDir
        git pull --rebase origin main
        Pop-Location
    }
} else {
    Write-Ok "Cloning from $RepoUrl..."
    if (-not $DryRun) { git clone $RepoUrl $RepoDir }
}

# ── 3. Build ──
Write-Step "Building OpenClaw..."
if (-not $DryRun) {
    Push-Location $RepoDir
    pnpm install
    pnpm build
    Pop-Location
}
Write-Ok "Build complete."

# ── 4. Add to PATH ──
Write-Step "Adding openclaw to PATH..."
if (-not (Test-Path $BinDir)) {
    if (-not $DryRun) { New-Item -ItemType Directory -Path $BinDir -Force | Out-Null }
}

$wrapperPath = Join-Path $BinDir "openclaw.cmd"
$wrapperContent = "@echo off`r`nnode `"$RepoDir\dist\cli.js`" %*"
if (-not $DryRun) {
    Set-Content -Path $wrapperPath -Value $wrapperContent -Encoding ASCII
}

$userPath = [System.Environment]::GetEnvironmentVariable("Path", "User")
if ($userPath -notlike "*$BinDir*") {
    if (-not $DryRun) {
        [System.Environment]::SetEnvironmentVariable("Path", "$userPath;$BinDir", "User")
    }
    Write-Ok "Added $BinDir to user PATH."
} else {
    Write-Ok "$BinDir already on PATH."
}
$env:Path = "$env:Path;$BinDir"

# ── 5. Apply custom settings ──
Write-Step "Applying clawsetup settings (full agent autonomy)..."
$openclawCmd = "node `"$RepoDir\dist\cli.js`""
if (-not $DryRun) {
    Invoke-Expression "$openclawCmd approvals trust"
}
Write-Ok "Agent trusted with full autonomous control."

# ── 6. Automation-mcp (optional) ──
if (-not $SkipAutomation) {
    Write-Step "Setting up automation-mcp (desktop control)..."

    # Ensure bun
    if (-not (Test-Command "bun")) {
        Write-Ok "Installing Bun runtime..."
        if (-not $DryRun) {
            irm bun.sh/install.ps1 | iex
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" +
                        [System.Environment]::GetEnvironmentVariable("Path", "User")
        }
    }

    if (Test-Path (Join-Path $AutomationDir ".git")) {
        Write-Ok "automation-mcp already installed. Updating..."
        if (-not $DryRun) {
            Push-Location $AutomationDir
            git pull
            bun install
            Pop-Location
        }
    } else {
        Write-Ok "Cloning automation-mcp..."
        if (-not $DryRun) {
            git clone $AutomationRepoUrl $AutomationDir
            Push-Location $AutomationDir
            bun install
            Pop-Location
        }
    }

    # Configure mcporter if available
    if (Test-Command "mcporter") {
        Write-Ok "Configuring mcporter server..."
        if (-not $DryRun) {
            mcporter config add automation --transport stdio --command "bun run $AutomationDir\index.ts --stdio"
        }
    } else {
        Write-Warn "mcporter not found. To enable MCP automation tools, install mcporter and run:"
        Write-Warn "  mcporter config add automation --transport stdio --command `"bun run $AutomationDir\index.ts --stdio`""
    }

    Write-Ok "automation-mcp ready."
} else {
    Write-Warn "Skipped automation-mcp setup (--SkipAutomation)."
}

# ── Done ──
Write-Host ""
Write-Host "  ============================================" -ForegroundColor Green
Write-Host "  clawsetup complete!" -ForegroundColor Green
Write-Host "  ============================================" -ForegroundColor Green
Write-Host ""
Write-Host "  OpenClaw:       $RepoDir" -ForegroundColor White
Write-Host "  CLI wrapper:    $wrapperPath" -ForegroundColor White
Write-Host "  Dashboard:      http://127.0.0.1:18789/" -ForegroundColor White
Write-Host ""
Write-Host "  Quick start:" -ForegroundColor Cyan
Write-Host "    openclaw models set          # pick a model (interactive)" -ForegroundColor White
Write-Host "    openclaw gateway run         # start the gateway + dashboard" -ForegroundColor White
Write-Host "    openclaw tui                 # terminal chat UI" -ForegroundColor White
Write-Host "    openclaw dashboard           # open the web dashboard" -ForegroundColor White
Write-Host ""
Write-Host "  Update later:" -ForegroundColor Cyan
Write-Host "    iwr -useb https://raw.githubusercontent.com/caydenchapple/openclaw/main/scripts/clawsetup.ps1 | iex" -ForegroundColor DarkGray
Write-Host ""
