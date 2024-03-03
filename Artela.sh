#!/bin/bash

# 脚本保存路径
SCRIPT_PATH="$HOME/Artela.sh"

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

# 检查命令是否存在
exists() {
  command -v "$1" >/dev/null 2>&1
}

# 检查curl是否安装，如果没有则安装
if exists curl; then
  echo 'curl 已安装'
else
  sudo apt update && sudo apt install curl -y
fi

# 设置变量
read -r -p "请输入节点名称: " NODE_MONIKER
export NODE_MONIKER=$NODE_MONIKER

# 更新和安装必要的软件
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl iptables build-essential git wget jq make gcc nano tmux htop nvme-cli pkg-config libssl-dev libleveldb-dev tar clang bsdmainutils ncdu unzip libleveldb-dev

# 安装Go
ver="1.20.3"
wget "https://golang.org/dl/go$ver.linux-amd64.tar.gz"
sudo rm -rf /usr/local/go
sudo tar -C /usr/local -xzf "go$ver.linux-amd64.tar.gz"
echo "export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin" >> $HOME/.bash_profile
source $HOME/.bash_profile
go version
sleep 1

# 安装所有二进制文件
cd $HOME
rm -rf artela
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

# 配置和快照
sed -i 's|^pruning *=.*|pruning = "custom"|g' $HOME/.artelad/config/app.toml
sed -i 's|^pruning-keep-recent  *=.*|pruning-keep-recent = "100"|g' $HOME/.artelad/config/app.toml
sed -i 's|^pruning-interval *=.*|pruning-interval = "10"|g' $HOME/.artelad/config/app.toml
sed -i 's|^snapshot-interval *=.*|snapshot-interval = 0|g' $HOME/.artelad/config/app.toml

# 配置最小燃料价格和普罗米修斯
sed -i 's|^minimum-gas-prices *=.*|minimum-gas-prices = "0.025art"|g' $HOME/.artelad/config/app.toml
sed -i 's|^prometheus *=.*|prometheus = true|' $HOME/.artelad/config/config.toml

# 创建服务文件
sudo tee /etc/systemd/system/artelad.service > /dev/null << EOF
[Unit]
Description=artela node
After=network-online.target

[Service]
User=$USER
ExecStart=$(which artelad) start
Restart=on-failure
RestartSec=10
LimitNOFILE=10000

[Install]
WantedBy=multi-user.target
EOF

# 重置Tendermint数据
artelad tendermint unsafe-reset-all --home $HOME/.artelad --keep-addr-book

# 安装lz4工具
sudo apt install snapd -y
sudo snap install lz4

# 下载并解压快照
curl -L https://t-ss.nodeist.net/artela/snapshot_latest.tar.lz4 | lz4 -dc - | tar -xf - -C $HOME/.artelad --strip-components 2

# 重新加载和启动服务
sudo systemctl daemon-reload
sudo systemctl enable artelad
sudo systemctl start artelad


# 完成设置
echo '====================== 安装完成 ==========================='

}

# 创建钱包
function add_wallet() {
    read -p "请输入钱包名称: " wallet_name
    artelad keys add "$wallet_name"
}

# 导入钱包
function import_wallet() {
    read -p "请输入钱包名称: " wallet_name
    artelad keys add "$wallet_name" --recover
}

# 查询余额
function check_balances() {
    read -p "请输入钱包地址: " wallet_address
    artelad query bank balances "$wallet_address" 
}

# 查看节点同步状态
function check_sync_status() {
    artelad status 2>&1 | jq .SyncInfo
}

# 查看babylon服务状态
function check_service_status() {
    systemctl status artelad
}

# 节点日志查询
function view_logs() {
    sudo journalctl -f -u artelad.service 
}

# 卸载脚本功能
function uninstall_script() {
    local alias_name="babylondf"
    local shell_rc_files=("$HOME/.bashrc" "$HOME/.zshrc")

    for shell_rc in "${shell_rc_files[@]}"; do
        if [ -f "$shell_rc" ]; then
            # 移除快捷键
            sed -i "/alias $alias_name='bash $SCRIPT_PATH'/d" "$shell_rc"
        fi
    done

    echo "快捷键 '$alias_name' 已从shell配置文件中移除。"
    read -p "是否删除脚本文件本身？(y/n): " delete_script
    if [[ "$delete_script" == "y" ]]; then
        rm -f "$SCRIPT_PATH"
        echo "脚本文件已删除。"
    else
        echo "脚本文件未删除。"
    fi
}

# 主菜单
function main_menu() {
    clear
    echo "脚本以及教程由推特用户大赌哥 @y95277777 编写，免费开源，请勿相信收费"
    echo "================================================================"
    echo "节点社区 Telegram 群组:https://t.me/niuwuriji"
    echo "节点社区 Telegram 频道:https://t.me/niuwuriji"
    echo "请选择要执行的操作:"
    echo "1. 安装节点"
    echo "2. 创建钱包"
    echo "3. 导入钱包"
    echo "4. 查看钱包地址余额"
    echo "5. 查看节点同步状态"
    echo "6. 查看当前服务状态"
    echo "7. 运行日志查询"
    echo "8. 卸载脚本"
    echo "9. 设置快捷键"  
    read -p "请输入选项（1-9）: " OPTION

    case $OPTION in
    1) install_node ;;
    2) add_wallet ;;
    3) import_wallet ;;
    4) check_balances ;;
    5) check_sync_status ;;
    6) check_service_status ;;
    7) view_logs ;;
    8) uninstall_script ;;
    9) check_and_set_alias ;;  
    *) echo "无效选项。" ;;
    esac
}

# 显示主菜单
main_menu
