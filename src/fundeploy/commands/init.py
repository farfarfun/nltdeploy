"""
init 命令 - 初始化部署环境
"""

import click


@click.command()
def init():
    """初始化部署环境"""
    click.echo(click.style("[INFO] 初始化部署环境...", fg='green'))
    click.echo(click.style("[INFO] 此功能即将推出", fg='yellow'))
