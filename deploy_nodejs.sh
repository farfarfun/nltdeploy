#!/bin/bash
# Node.js环境快速部署脚本
# Quick deployment script for Node.js environment

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

# 默认Node.js版本
NODE_VERSION=${NODE_VERSION:-"18"}

# 检查Node.js是否已安装
check_nodejs() {
    log_info "检查Node.js安装状态..."
    if command -v node &> /dev/null; then
        NODEJS_VERSION=$(node --version)
        log_info "已安装: Node.js $NODEJS_VERSION"
        if command -v npm &> /dev/null; then
            NPM_VERSION=$(npm --version)
            log_info "已安装: npm $NPM_VERSION"
        fi
        return 0
    else
        log_warn "未检测到Node.js"
        return 1
    fi
}

# 安装Node.js (Ubuntu/Debian)
install_nodejs_debian() {
    log_info "开始安装Node.js $NODE_VERSION..."
    
    # 安装NodeSource仓库
    curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION}.x | sudo -E bash -
    
    # 安装Node.js
    sudo apt-get install -y nodejs
    
    log_info "Node.js安装完成"
}

# 安装Node.js (CentOS/RHEL)
install_nodejs_rhel() {
    log_info "开始安装Node.js $NODE_VERSION..."
    
    # 安装NodeSource仓库
    curl -fsSL https://rpm.nodesource.com/setup_${NODE_VERSION}.x | sudo bash -
    
    # 安装Node.js
    sudo yum install -y nodejs
    
    log_info "Node.js安装完成"
}

# 使用nvm安装Node.js
install_nodejs_nvm() {
    log_info "使用nvm安装Node.js..."
    
    # 检查nvm是否已安装
    if [ ! -d "$HOME/.nvm" ]; then
        log_info "安装nvm..."
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
        
        # 加载nvm
        export NVM_DIR="$HOME/.nvm"
        [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    fi
    
    # 安装Node.js
    nvm install "$NODE_VERSION"
    nvm use "$NODE_VERSION"
    nvm alias default "$NODE_VERSION"
    
    log_info "Node.js安装完成"
}

# 配置npm
configure_npm() {
    log_info "配置npm..."
    
    # 设置npm镜像（可选，提高国内下载速度）
    # npm config set registry https://registry.npmmirror.com
    
    # 升级npm到最新版本
    sudo npm install -g npm@latest
    
    log_info "npm配置完成"
}

# 安装常用全局包
install_global_packages() {
    log_info "安装常用全局包..."
    
    # 安装yarn
    if ! command -v yarn &> /dev/null; then
        sudo npm install -g yarn
        log_info "已安装: yarn"
    fi
    
    # 安装pm2
    if ! command -v pm2 &> /dev/null; then
        sudo npm install -g pm2
        log_info "已安装: pm2"
    fi
    
    log_info "全局包安装完成"
}

# 安装项目依赖
install_dependencies() {
    local package_file=${1:-"package.json"}
    
    if [ -f "$package_file" ]; then
        log_info "检测到 $package_file，安装项目依赖..."
        
        if command -v yarn &> /dev/null; then
            log_info "使用yarn安装依赖..."
            yarn install
        else
            log_info "使用npm安装依赖..."
            npm install
        fi
        
        log_info "项目依赖安装完成"
    else
        log_warn "未找到 $package_file 文件"
    fi
}

# 主函数
main() {
    log_info "=== Node.js环境部署开始 ==="
    
    local use_nvm=false
    local install_globals=false
    local install_deps=false
    
    # 解析参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            --version)
                NODE_VERSION="$2"
                shift 2
                ;;
            --nvm)
                use_nvm=true
                shift
                ;;
            --globals)
                install_globals=true
                shift
                ;;
            --deps)
                install_deps=true
                shift
                ;;
            *)
                log_warn "未知参数: $1"
                shift
                ;;
        esac
    done
    
    # 检查并安装Node.js
    if ! check_nodejs; then
        if [ "$use_nvm" = true ]; then
            install_nodejs_nvm
        else
            # 检测操作系统
            if [ -f /etc/debian_version ]; then
                install_nodejs_debian
            elif [ -f /etc/redhat-release ]; then
                install_nodejs_rhel
            else
                log_error "不支持的操作系统，请使用 --nvm 参数或手动安装Node.js"
                exit 1
            fi
        fi
        
        # 配置npm
        configure_npm
    fi
    
    # 安装全局包
    if [ "$install_globals" = true ]; then
        install_global_packages
    fi
    
    # 安装项目依赖
    if [ "$install_deps" = true ]; then
        install_dependencies
    fi
    
    log_info "=== Node.js环境部署完成 ==="
    
    # 显示版本信息
    node --version
    npm --version
}

# 显示帮助信息
show_help() {
    cat << EOF
Node.js环境快速部署脚本

用法:
    $0 [选项]

选项:
    --version <version>  指定Node.js版本（默认: 18）
    --nvm               使用nvm安装Node.js
    --globals           安装常用全局包（yarn, pm2）
    --deps              安装项目依赖（从package.json）
    -h, --help          显示帮助信息

环境变量:
    NODE_VERSION        指定Node.js版本（默认: 18）

示例:
    $0 --version 18 --globals --deps
    $0 --nvm --version 20
    NODE_VERSION=20 $0 --globals
EOF
}

# 参数处理
if [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
    show_help
    exit 0
fi

main "$@"
