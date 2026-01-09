#!/bin/bash
# 
# Python 环境设置脚本
# 使用 uv 创建 Python 环境并安装在 ~/opt/ 目录下
#
# 用法: ./setup_python_env.sh <python_version>
# 示例: ./setup_python_env.sh 3.12
#       ./setup_python_env.sh 3.11
#

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 打印信息函数
info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查参数
if [ $# -eq 0 ]; then
    error "请指定 Python 版本"
    echo "用法: $0 <python_version>"
    echo "示例: $0 3.12"
    echo "      $0 3.11"
    echo "      $0 3.10"
    exit 1
fi

PYTHON_VERSION=$1
PYTHON_VERSION_SHORT=$(echo $PYTHON_VERSION | sed 's/\.//')
OPT_DIR="$HOME/opt"
PYTHON_DIR="$OPT_DIR/py${PYTHON_VERSION_SHORT}"

info "准备安装 Python ${PYTHON_VERSION} 到 ${PYTHON_DIR}"

# 创建 opt 目录
if [ ! -d "$OPT_DIR" ]; then
    info "创建目录 $OPT_DIR"
    mkdir -p "$OPT_DIR"
fi

# 检查 uv 是否已安装
if ! command -v uv &> /dev/null; then
    warn "uv 未安装，正在安装 uv..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
    
    # 添加 uv 到 PATH
    export PATH="$HOME/.cargo/bin:$PATH"
    
    if ! command -v uv &> /dev/null; then
        error "uv 安装失败，请手动安装: curl -LsSf https://astral.sh/uv/install.sh | sh"
        exit 1
    fi
    info "uv 安装成功"
else
    info "uv 已安装: $(uv --version)"
fi

# 检查目标目录是否已存在
if [ -d "$PYTHON_DIR" ]; then
    warn "目录 $PYTHON_DIR 已存在"
    read -p "是否删除并重新安装? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        info "删除旧环境 $PYTHON_DIR"
        rm -rf "$PYTHON_DIR"
    else
        info "取消安装"
        exit 0
    fi
fi

# 使用 uv 安装 Python
info "使用 uv 安装 Python ${PYTHON_VERSION}..."
uv python install ${PYTHON_VERSION}

# 创建虚拟环境
info "在 ${PYTHON_DIR} 创建虚拟环境..."
uv venv "$PYTHON_DIR" --python ${PYTHON_VERSION}

# 验证安装
if [ -f "$PYTHON_DIR/bin/python" ]; then
    INSTALLED_VERSION=$("$PYTHON_DIR/bin/python" --version 2>&1 | awk '{print $2}')
    info "Python 环境创建成功!"
    info "Python 版本: ${INSTALLED_VERSION}"
    info "安装路径: ${PYTHON_DIR}"
    echo ""
    info "使用此环境的方法:"
    echo "  source ${PYTHON_DIR}/bin/activate"
    echo ""
    info "或者直接使用 Python:"
    echo "  ${PYTHON_DIR}/bin/python"
    echo "  ${PYTHON_DIR}/bin/pip"
    echo ""
    
    # 可选：添加到 .bashrc 或 .zshrc
    info "提示: 可以添加以下别名到你的 shell 配置文件 (~/.bashrc 或 ~/.zshrc):"
    echo "  alias py${PYTHON_VERSION_SHORT}='source ${PYTHON_DIR}/bin/activate'"
else
    error "Python 环境创建失败"
    exit 1
fi

# 升级 pip 和基础工具
info "升级 pip 和基础工具..."
"$PYTHON_DIR/bin/python" -m pip install --upgrade pip setuptools wheel -q

info "安装完成!"
