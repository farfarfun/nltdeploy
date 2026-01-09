# Python 环境设置脚本 (Windows PowerShell)
# 使用 uv 创建 Python 环境并安装在 ~/opt/ 目录下
#
# 用法: .\setup_python_env.ps1 -PythonVersion <version>
# 示例: .\setup_python_env.ps1 -PythonVersion 3.12
#       .\setup_python_env.ps1 -PythonVersion 3.11
#

param(
    [Parameter(Mandatory=$true)]
    [string]$PythonVersion
)

# 颜色输出函数
function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Green
}

function Write-Warn {
    param([string]$Message)
    Write-Host "[WARN] $Message" -ForegroundColor Yellow
}

function Write-Error-Custom {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

# 设置变量
$PythonVersionShort = $PythonVersion -replace '\.',''
$OptDir = Join-Path $env:USERPROFILE "opt"
$PythonDir = Join-Path $OptDir "py$PythonVersionShort"

Write-Info "准备安装 Python $PythonVersion 到 $PythonDir"

# 创建 opt 目录
if (-not (Test-Path $OptDir)) {
    Write-Info "创建目录 $OptDir"
    New-Item -ItemType Directory -Path $OptDir -Force | Out-Null
}

# 检查 uv 是否已安装
$uvInstalled = $false
try {
    $uvVersion = uv --version 2>$null
    if ($LASTEXITCODE -eq 0) {
        $uvInstalled = $true
        Write-Info "uv 已安装: $uvVersion"
    }
} catch {
    $uvInstalled = $false
}

if (-not $uvInstalled) {
    Write-Warn "uv 未安装，正在安装 uv..."
    try {
        powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"
        
        # 刷新环境变量
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
        
        $uvVersion = uv --version 2>$null
        if ($LASTEXITCODE -ne 0) {
            Write-Error-Custom "uv 安装失败，请手动安装: powershell -ExecutionPolicy ByPass -c 'irm https://astral.sh/uv/install.ps1 | iex'"
            exit 1
        }
        Write-Info "uv 安装成功"
    } catch {
        Write-Error-Custom "uv 安装过程中发生错误: $_"
        exit 1
    }
}

# 检查目标目录是否已存在
if (Test-Path $PythonDir) {
    Write-Warn "目录 $PythonDir 已存在"
    $response = Read-Host "是否删除并重新安装? (y/N)"
    if ($response -match '^[Yy]$') {
        Write-Info "删除旧环境 $PythonDir"
        Remove-Item -Path $PythonDir -Recurse -Force
    } else {
        Write-Info "取消安装"
        exit 0
    }
}

# 使用 uv 安装 Python
Write-Info "使用 uv 安装 Python $PythonVersion..."
try {
    uv python install $PythonVersion
    if ($LASTEXITCODE -ne 0) {
        Write-Error-Custom "Python 安装失败"
        exit 1
    }
} catch {
    Write-Error-Custom "Python 安装过程中发生错误: $_"
    exit 1
}

# 创建虚拟环境
Write-Info "在 $PythonDir 创建虚拟环境..."
try {
    uv venv $PythonDir --python $PythonVersion
    if ($LASTEXITCODE -ne 0) {
        Write-Error-Custom "虚拟环境创建失败"
        exit 1
    }
} catch {
    Write-Error-Custom "虚拟环境创建过程中发生错误: $_"
    exit 1
}

# 验证安装
$PythonExe = Join-Path $PythonDir "Scripts\python.exe"
if (Test-Path $PythonExe) {
    $InstalledVersion = & $PythonExe --version 2>&1 | ForEach-Object { $_ -replace 'Python ','' }
    Write-Info "Python 环境创建成功!"
    Write-Info "Python 版本: $InstalledVersion"
    Write-Info "安装路径: $PythonDir"
    Write-Host ""
    Write-Info "使用此环境的方法:"
    Write-Host "  $PythonDir\Scripts\Activate.ps1"
    Write-Host ""
    Write-Info "或者直接使用 Python:"
    Write-Host "  $PythonExe"
    Write-Host "  $PythonDir\Scripts\pip.exe"
    Write-Host ""
    
    # 可选：添加到 PowerShell Profile
    Write-Info "提示: 可以添加以下别名到你的 PowerShell Profile (\$PROFILE):"
    Write-Host "  function Activate-Py$PythonVersionShort { & '$PythonDir\Scripts\Activate.ps1' }"
} else {
    Write-Error-Custom "Python 环境创建失败"
    exit 1
}

# 升级 pip 和基础工具
Write-Info "升级 pip 和基础工具..."
try {
    & $PythonExe -m pip install --upgrade pip setuptools wheel -q
} catch {
    Write-Warn "升级 pip 时发生警告，但环境已创建成功"
}

Write-Info "安装完成!"
