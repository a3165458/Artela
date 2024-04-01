#!/bin/bash

# 检查是否以root用户运行脚本
if [ "$(id -u)" != "0" ]; then
    echo "此脚本需要以root用户权限运行。"
    echo "请尝试使用 'sudo -i' 命令切换到root用户，然后再次运行此脚本。"
    exit 1
fi

# 检查并安装 Node.js 和 npm
function install_nodejs_and_npm() {
    if command -v node > /dev/null 2>&1; then
        echo "Node.js 已安装"
    else
        echo "Node.js 未安装，正在安装..."
        curl -fsSL https://deb.nodesource.com/setup_16.x | sudo -E bash -
        sudo apt-get install -y nodejs
    fi

    if command -v npm > /dev/null 2>&1; then
        echo "npm 已安装"
    else
        echo "npm 未安装，正在安装..."
        sudo apt-get install -y npm
    fi
}

# 检查并安装 PM2
function install_pm2() {
    if command -v pm2 > /dev/null 2>&1; then
        echo "PM2 已安装"
    else
        echo "PM2 未安装，正在安装..."
        npm install pm2@latest -g
    fi
}

# 自动设置快捷键的功能
function check_and_set_alias() {
    local alias_name="art"
    local shell_rc="$HOME/.bashrc"

    # 对于Zsh用户，使用.zshrc
    if [ -n "$ZSH_VERSION" ]; then
        shell_rc="$HOME/.zshrc"
    elif [ -n "$BASH_VERSION" ]; then
        shell_rc="$HOME/.bashrc"
    fi

    # 检查快捷键是否已经设置
    if ! grep -q "$alias_name" "$shell_rc"; then
        echo "设置快捷键 '$alias_name' 到 $shell_rc"
        echo "alias $alias_name='bash $SCRIPT_PATH'" >> "$shell_rc"
        # 添加提醒用户激活快捷键的信息
        echo "快捷键 '$alias_name' 已设置。请运行 'source $shell_rc' 来激活快捷键，或重新打开终端。"
    else
        # 如果快捷键已经设置，提供一个提示信息
        echo "快捷键 '$alias_name' 已经设置在 $shell_rc。"
        echo "如果快捷键不起作用，请尝试运行 'source $shell_rc' 或重新打开终端。"
    fi
}

# 节点安装功能
function install_node() {
    install_nodejs_and_npm
    install_pm2

    # 检查curl是否安装，如果没有则安装
    if ! command -v curl > /dev/null; then
        sudo apt update && sudo apt install curl -y
    fi

    # 设置变量
    read -r -p "请输入节点名称: " NODE_MONIKER
    export NODE_MONIKER=$NODE_MONIKER

    # 更新和安装必要的软件
    sudo apt update && sudo apt upgrade -y
    sudo apt install -y curl iptables build-essential git wget jq make gcc nano tmux htop nvme-cli pkg-config libssl-dev libleveldb-dev tar clang bsdmainutils ncdu unzip libleveldb-dev lz4 snapd

    # 安装Go
    sudo rm -rf /usr/local/go
    curl -L https://go.dev/dl/go1.22.0.linux-amd64.tar.gz | sudo tar -xzf - -C /usr/local
    echo 'export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin' >> $HOME/.bash_profile
    source $HOME/.bash_profile

    # 安装所有二进制文件
    cd $HOME
    git clone https://github.com/artela-network/artela
    cd artela
    git checkout v0.4.7-rc6
    make install

    # 配置artelad
    artelad config chain-id artela_11822-1
    artelad init "$NODE_MONIKER" --chain-id artela_11822-1

    # 获取初始文件和地址簿
    curl -s https://t-ss.nodeist.net/artela/genesis.json > $HOME/.artelad/config/genesis.json
    curl -s https://t-ss.nodeist.net/artela/addrbook.json > $HOME/.artelad/config/addrbook.json

    # 配置节点
    SEEDS=""
    PEERS="b23bc610c374fd071c20ce4a2349bf91b8fbd7db@65.108.72.233:11656"
    sed -i 's|^seeds *=.*|seeds = "'$SEEDS'"|; s|^persistent_peers *=.*|persistent_peers = "'$PEERS'"|' $HOME/.artelad/config/config.toml

    # 使用 PM2 启动节点进程
    pm2 start artelad --name artela-node -- start
    pm2 save
    pm2 startup systemd

    echo '====================== 安装完成 ==========================='
    echo '安装完成请重新连接VPS，以启用对应快捷键功能'
}

# 查看Avail服务状态
function check_service_status() {
    pm2 list
}

# Avail 节点日志查询
function view_logs() {
    pm2 logs artela-node
}

# 卸载节点功能
function uninstall_node() {
    pm2 delete artela-node
    echo "节点程序卸载完成。"
}

# 主菜单
function main_menu() {
    while true; do
        clear
        echo "脚本以及教程由推特用户大赌哥 @y95277777 编写，免费开源，请勿相信收费"
        echo "================================================================"
        echo "节点社区 Telegram 群组:https://t.me/niuwuriji"
        echo "节点社区 Telegram 频道:https://t.me/niuwuriji"
        echo "退出脚本，请按键盘ctrl c退出即可"
        echo "请选择要执行的操作:"
        echo "1. 安装节点"
        echo "2. 查看服务状态"
        echo "3. 运行日志查询"
        echo "4. 卸载节点"
        echo "9. 设置快捷键"  
        read -p "请输入选项（1-4, 9）: " OPTION

        case $OPTION in
        1) install_node ;;
        2) check_service_status ;;
        3) view_logs ;;
        4) uninstall_node ;;
        9) check_and_set_alias ;;
        *) echo "无效选项。" ;;
        esac
        echo "按任意键返回主菜单..."
        read -n 1
    done
}

# 显示主菜单
main_menu
