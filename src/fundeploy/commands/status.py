"""
status 命令 - 查看部署状态
"""

import click


@click.command()
def status():
    """查看部署状态"""
    click.echo(click.style("[INFO] 查看部署状态...", fg='green'))
    click.echo(click.style("[INFO] 此功能即将推出", fg='yellow'))
