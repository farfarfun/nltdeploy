#!/bin/bash
# Python环境快速部署脚本
# Quick deployment script for Python environment

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查Python是否已安装
check_python() {
    log_info "检查Python安装状态..."
    if command -v python3 &> /dev/null; then
        PYTHON_VERSION=$(python3 --version)
        log_info "已安装: $PYTHON_VERSION"
        return 0
    else
        log_warn "未检测到Python3"
        return 1
    fi
}

# 安装Python (Ubuntu/Debian)
install_python_debian() {
    log_info "开始安装Python3..."
    sudo apt-get update
    sudo apt-get install -y python3 python3-pip python3-venv
    log_info "Python3安装完成"
}

# 安装Python (CentOS/RHEL)
install_python_rhel() {
    log_info "开始安装Python3..."
    sudo yum install -y python3 python3-pip
    log_info "Python3安装完成"
}

# 创建虚拟环境
create_venv() {
    local venv_path=${1:-"venv"}
    log_info "创建Python虚拟环境: $venv_path"
    python3 -m venv "$venv_path"
    log_info "虚拟环境创建成功"
    log_info "激活命令: source $venv_path/bin/activate"
}

# 安装依赖
install_requirements() {
    local requirements_file=${1:-"requirements.txt"}
    if [ -f "$requirements_file" ]; then
        log_info "安装依赖包: $requirements_file"
        pip3 install -r "$requirements_file"
        log_info "依赖包安装完成"
    else
        log_warn "未找到 $requirements_file 文件"
    fi
}

# 主函数
main() {
    log_info "=== Python环境部署开始 ==="
    
    # 检查并安装Python
    if ! check_python; then
        # 检测操作系统
        if [ -f /etc/debian_version ]; then
            install_python_debian
        elif [ -f /etc/redhat-release ]; then
            install_python_rhel
        else
            log_error "不支持的操作系统，请手动安装Python3"
            exit 1
        fi
    fi
    
    # 升级pip
    log_info "升级pip..."
    python3 -m pip install --upgrade pip
    
    # 解析参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            --venv)
                create_venv "$2"
                shift 2
                ;;
            --requirements)
                install_requirements "$2"
                shift 2
                ;;
            *)
                log_warn "未知参数: $1"
                shift
                ;;
        esac
    done
    
    log_info "=== Python环境部署完成 ==="
}

# 显示帮助信息
show_help() {
    cat << EOF
Python环境快速部署脚本

用法:
    $0 [选项]

选项:
    --venv <path>          创建虚拟环境（默认: venv）
    --requirements <file>  安装依赖包（默认: requirements.txt）
    -h, --help            显示帮助信息

示例:
    $0 --venv myenv --requirements requirements.txt
    $0 --venv venv
EOF
}

# 参数处理
if [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
    show_help
    exit 0
fi

main "$@"
