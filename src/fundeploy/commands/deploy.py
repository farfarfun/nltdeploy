"""
deploy 命令 - 部署应用
"""

import click


@click.command()
@click.option('--env', default='dev', help='部署环境 (dev, test, prod)')
def deploy(env):
    """部署应用到指定环境"""
    click.echo(click.style(f"[INFO] 部署到 {env} 环境...", fg='green'))
    click.echo(click.style("[INFO] 此功能即将推出", fg='yellow'))
