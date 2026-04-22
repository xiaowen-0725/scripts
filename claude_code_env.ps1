$ErrorActionPreference = "Stop"

# ========================
#       常量定义
# ========================
$NODE_MIN_VERSION = 18
$NODE_INSTALL_VERSION = "22.15.0"
$NODE_MSI_URL = "https://nodejs.org/dist/v$NODE_INSTALL_VERSION/node-v$NODE_INSTALL_VERSION-x64.msi"
$NODE_MSI_PATH = "$env:TEMP\node-installer.msi"
$CLAUDE_PACKAGE = "@anthropic-ai/claude-code"
$CONFIG_DIR = Join-Path $env:USERPROFILE ".claude"
$CONFIG_FILE = Join-Path $CONFIG_DIR "settings.json"
$CLAUDE_JSON_FILE = Join-Path $env:USERPROFILE ".claude.json"
$API_BASE_URL = "https://open.bigmodel.cn/api/anthropic"
$API_KEY_URL = "https://open.bigmodel.cn/usercenter/proj-mgmt/apikeys"
$API_TIMEOUT_MS = "3000000"
$SCRIPT_URL = "https://raw.githubusercontent.com/xiaowen-0725/scripts/main/claude_code_env.ps1"

# ========================
#       工具函数
# ========================

function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message"
}

function Write-Ok {
    param([string]$Message)
    Write-Host "[OK] $Message" -ForegroundColor Green
}

function Write-Err {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

function Ensure-DirExists {
    param([string]$Dir)
    if (-not (Test-Path $Dir)) {
        New-Item -ItemType Directory -Path $Dir -Force | Out-Null
    }
}

# ========================
#     管理员权限检测
# ========================

function Request-Admin {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    $isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

    if (-not $isAdmin) {
        Write-Info "Requesting administrator privileges..."
        if ($PSCommandPath -and (Test-Path $PSCommandPath)) {
            Start-Process PowerShell -Verb RunAs -ArgumentList "-ExecutionPolicy Bypass -File `"$PSCommandPath`""
        } else {
            $tempFile = Join-Path $env:TEMP "claude_code_env.ps1"
            Write-Info "Saving script for elevation..."
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            Invoke-WebRequest -Uri $SCRIPT_URL -OutFile $tempFile -UseBasicParsing
            Start-Process PowerShell -Verb RunAs -ArgumentList "-ExecutionPolicy Bypass -File `"$tempFile`""
        }
        exit 0
    }
    Write-Ok "Running with administrator privileges"
}

# ========================
#     Node.js 安装函数
# ========================

function Install-NodeJS {
    Write-Info "Downloading Node.js v$NODE_INSTALL_VERSION..."
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri $NODE_MSI_URL -OutFile $NODE_MSI_PATH -UseBasicParsing
    } catch {
        Write-Err "Failed to download Node.js: $_"
        exit 1
    }

    Write-Info "Installing Node.js v$NODE_INSTALL_VERSION (silent)..."
    $msiArgs = "/i `"$NODE_MSI_PATH`" /quiet /norestart"
    $process = Start-Process msiexec.exe -ArgumentList $msiArgs -Wait -PassThru

    if ($process.ExitCode -ne 0) {
        Write-Err "Node.js installation failed with exit code $($process.ExitCode)"
        Remove-Item $NODE_MSI_PATH -Force -ErrorAction SilentlyContinue
        exit 1
    }

    # 清理安装包
    Remove-Item $NODE_MSI_PATH -Force -ErrorAction SilentlyContinue

    # 刷新环境变量
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

    # 验证安装
    $nodePath = Join-Path $env:ProgramFiles "nodejs\node.exe"
    if (-not (Test-Path $nodePath)) {
        Write-Err "Node.js installation verification failed"
        exit 1
    }

    $nodeVer = & $nodePath -v
    Write-Ok "Node.js installed: $nodeVer"
    $npmVer = & (Join-Path $env:ProgramFiles "nodejs\npm.cmd") -v
    Write-Ok "npm version: $npmVer"
}

# ========================
#     Node.js 检查函数
# ========================

function Check-NodeJS {
    $nodeExe = Get-Command node -ErrorAction SilentlyContinue
    if ($null -ne $nodeExe) {
        $currentVersion = (& node -v) -replace '^v', ''
        $majorVersion = $currentVersion.Split('.')[0]

        if ([int]$majorVersion -ge $NODE_MIN_VERSION) {
            Write-Ok "Node.js is already installed: v$currentVersion"
            return
        } else {
            Write-Info "Node.js v$currentVersion is installed but version < $NODE_MIN_VERSION. Upgrading..."
        }
    } else {
        Write-Info "Node.js not found. Installing..."
    }
    Install-NodeJS
}

# ========================
#     Claude Code 安装
# ========================

function Install-ClaudeCode {
    $claudeExe = Get-Command claude -ErrorAction SilentlyContinue
    if ($null -ne $claudeExe) {
        $ver = & claude --version
        Write-Ok "Claude Code is already installed: $ver"
    } else {
        Write-Info "Installing Claude Code..."
        & npm install -g $CLAUDE_PACKAGE
        if ($LASTEXITCODE -ne 0) {
            Write-Err "Failed to install claude-code"
            exit 1
        }
        Write-Ok "Claude Code installed successfully"
    }
}

# ========================
#   跳过 onboarding
# ========================

function Configure-ClaudeJson {
    $content = @{}
    if (Test-Path $CLAUDE_JSON_FILE) {
        $content = Get-Content $CLAUDE_JSON_FILE -Raw | ConvertFrom-Json -AsHashtable
    }
    $content["hasCompletedOnboarding"] = $true
    $content | ConvertTo-Json -Depth 10 | Set-Content $CLAUDE_JSON_FILE -Encoding UTF8
}

# ========================
#     API Key 配置
# ========================

function Configure-Claude {
    Write-Info "Configuring Claude Code..."
    Write-Host "   You can get your API key from: $API_KEY_URL"

    $apiKey = Read-Host "Please enter your ZHIPU API key" -AsSecureString
    $plainKey = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($apiKey)
    )

    if ([string]::IsNullOrWhiteSpace($plainKey)) {
        Write-Err "API key cannot be empty. Please run the script again."
        exit 1
    }

    Ensure-DirExists $CONFIG_DIR

    # 读取已有配置
    $settings = @{}
    if (Test-Path $CONFIG_FILE) {
        $settings = Get-Content $CONFIG_FILE -Raw | ConvertFrom-Json -AsHashtable
    }

    # 写入新配置
    $settings["env"] = @{
        ANTHROPIC_AUTH_TOKEN = $plainKey
        ANTHROPIC_BASE_URL = $API_BASE_URL
        API_TIMEOUT_MS = $API_TIMEOUT_MS
        CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC = 1
    }

    $settings | ConvertTo-Json -Depth 10 | Set-Content $CONFIG_FILE -Encoding UTF8
    Write-Ok "Claude Code configured successfully"
}

# ========================
#        主流程
# ========================

Write-Host "Starting Claude Code Environment Setup"
Write-Ok "Platform: Windows"

Request-Admin
Check-NodeJS
Install-ClaudeCode
Configure-ClaudeJson
Configure-Claude

Write-Host ""
Write-Ok "Installation completed successfully!"
Write-Host ""
Write-Host "You can now start using Claude Code with:"
Write-Host "   claude"
