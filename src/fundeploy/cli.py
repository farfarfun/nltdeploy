"""
命令行接口入口
"""

import sys
import click
from nltdeploy.commands import create, init, deploy, status, rollback


@click.group()
@click.version_option()
def main():
    """nltdeploy - 快速部署环境的脚本工具集"""
    pass


# 注册命令
main.add_command(create.create)
main.add_command(init.init)
main.add_command(deploy.deploy)
main.add_command(status.status)
main.add_command(rollback.rollback)


if __name__ == "__main__":
    sys.exit(main())
