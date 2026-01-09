"""
rollback 命令 - 回滚部署
"""

import click


@click.command()
def rollback():
    """回滚到上一个版本"""
    click.echo(click.style("[INFO] 回滚到上一个版本...", fg='green'))
    click.echo(click.style("[INFO] 此功能即将推出", fg='yellow'))
