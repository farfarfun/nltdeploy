"""
create 命令 - 创建 Python 环境
"""

import os
import sys
import subprocess
import platform
import click


@click.command()
@click.argument('python_env', required=True)
@click.option('--path', default=None, help='自定义安装路径，默认为 ~/opt/')
def create(python_env, path):
    """创建 Python 环境
    
    示例:
        fundeploy create py312  - 创建 Python 3.12 环境
        fundeploy create py311  - 创建 Python 3.11 环境
        fundeploy create py310  - 创建 Python 3.10 环境
    """
    # 解析 Python 版本
    if python_env.startswith('py'):
        version_short = python_env[2:]
    else:
        version_short = python_env.replace('.', '')
    
    # 转换为标准版本格式 (例如: 312 -> 3.12)
    if len(version_short) == 2:
        python_version = f"{version_short[0]}.{version_short[1]}"
    elif len(version_short) == 3:
        python_version = f"{version_short[0]}.{version_short[1:]}"
    else:
        click.echo(click.style(f"错误: 无效的 Python 版本格式: {python_env}", fg='red'))
        click.echo("支持的格式: py312, py311, py310, 312, 3.12")
        sys.exit(1)
    
    # 确定安装路径
    if path is None:
        opt_dir = os.path.expanduser("~/opt")
    else:
        opt_dir = os.path.expanduser(path)
    
    python_dir = os.path.join(opt_dir, f"py{version_short}")
    
    click.echo(click.style(f"[INFO] 准备创建 Python {python_version} 环境", fg='green'))
    click.echo(click.style(f"[INFO] 安装路径: {python_dir}", fg='green'))
    
    # 检查 uv 是否已安装
    if not check_uv_installed():
        click.echo(click.style("[WARN] uv 未安装，正在安装 uv...", fg='yellow'))
        if not install_uv():
            click.echo(click.style("[ERROR] uv 安装失败", fg='red'))
            sys.exit(1)
        click.echo(click.style("[INFO] uv 安装成功", fg='green'))
    
    # 检查目标目录是否已存在
    if os.path.exists(python_dir):
        click.echo(click.style(f"[WARN] 目录 {python_dir} 已存在", fg='yellow'))
        if click.confirm('是否删除并重新安装?', default=False):
            import shutil
            click.echo(click.style(f"[INFO] 删除旧环境 {python_dir}", fg='green'))
            shutil.rmtree(python_dir)
        else:
            click.echo(click.style("[INFO] 取消安装", fg='green'))
            return
    
    # 创建目录
    os.makedirs(opt_dir, exist_ok=True)
    
    # 使用 uv 安装 Python
    click.echo(click.style(f"[INFO] 使用 uv 安装 Python {python_version}...", fg='green'))
    try:
        subprocess.run(['uv', 'python', 'install', python_version], check=True)
    except subprocess.CalledProcessError as e:
        click.echo(click.style(f"[ERROR] Python 安装失败: {e}", fg='red'))
        sys.exit(1)
    
    # 创建虚拟环境
    click.echo(click.style(f"[INFO] 在 {python_dir} 创建虚拟环境...", fg='green'))
    try:
        subprocess.run(['uv', 'venv', python_dir, '--python', python_version], check=True)
    except subprocess.CalledProcessError as e:
        click.echo(click.style(f"[ERROR] 虚拟环境创建失败: {e}", fg='red'))
        sys.exit(1)
    
    # 验证安装
    python_exe = get_python_executable(python_dir)
    if os.path.exists(python_exe):
        try:
            result = subprocess.run([python_exe, '--version'], 
                                  capture_output=True, text=True, check=True)
            installed_version = result.stdout.strip().replace('Python ', '')
            
            click.echo(click.style("\n[INFO] Python 环境创建成功!", fg='green', bold=True))
            click.echo(click.style(f"[INFO] Python 版本: {installed_version}", fg='green'))
            click.echo(click.style(f"[INFO] 安装路径: {python_dir}", fg='green'))
            click.echo()
            click.echo(click.style("[INFO] 使用此环境的方法:", fg='green'))
            
            if platform.system() == 'Windows':
                activate_cmd = os.path.join(python_dir, 'Scripts', 'Activate.ps1')
                click.echo(f"  {activate_cmd}")
                click.echo()
                click.echo(click.style("[INFO] 或者直接使用 Python:", fg='green'))
                click.echo(f"  {python_exe}")
                click.echo(f"  {os.path.join(python_dir, 'Scripts', 'pip.exe')}")
            else:
                activate_cmd = os.path.join(python_dir, 'bin', 'activate')
                click.echo(f"  source {activate_cmd}")
                click.echo()
                click.echo(click.style("[INFO] 或者直接使用 Python:", fg='green'))
                click.echo(f"  {python_exe}")
                click.echo(f"  {os.path.join(python_dir, 'bin', 'pip')}")
            
            # 升级 pip 和基础工具
            click.echo()
            click.echo(click.style("[INFO] 升级 pip 和基础工具...", fg='green'))
            try:
                subprocess.run([python_exe, '-m', 'pip', 'install', 
                              '--upgrade', 'pip', 'setuptools', 'wheel', '-q'], 
                             check=True)
                click.echo(click.style("[INFO] 安装完成!", fg='green', bold=True))
            except subprocess.CalledProcessError:
                click.echo(click.style("[WARN] pip 升级失败，但环境已创建成功", fg='yellow'))
        
        except subprocess.CalledProcessError as e:
            click.echo(click.style(f"[ERROR] 验证安装失败: {e}", fg='red'))
            sys.exit(1)
    else:
        click.echo(click.style("[ERROR] Python 环境创建失败", fg='red'))
        sys.exit(1)


def check_uv_installed():
    """检查 uv 是否已安装"""
    try:
        subprocess.run(['uv', '--version'], 
                      capture_output=True, check=True)
        return True
    except (subprocess.CalledProcessError, FileNotFoundError):
        return False


def install_uv():
    """安装 uv"""
    system = platform.system()
    
    try:
        if system == 'Windows':
            # Windows 使用 PowerShell 安装
            cmd = ['powershell', '-ExecutionPolicy', 'ByPass', '-c',
                   "irm https://astral.sh/uv/install.ps1 | iex"]
            subprocess.run(cmd, check=True)
        else:
            # Linux/macOS 使用 curl 安装
            cmd = ['sh', '-c', 'curl -LsSf https://astral.sh/uv/install.sh | sh']
            subprocess.run(cmd, check=True)
        
        return check_uv_installed()
    except subprocess.CalledProcessError:
        return False


def get_python_executable(python_dir):
    """获取 Python 可执行文件路径"""
    if platform.system() == 'Windows':
        return os.path.join(python_dir, 'Scripts', 'python.exe')
    else:
        return os.path.join(python_dir, 'bin', 'python')
