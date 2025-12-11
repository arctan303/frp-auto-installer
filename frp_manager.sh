#!/bin/bash

# ========== 基本变量 ==========
FRP_VERSION="0.65.0"
INSTALL_DIR="$HOME/frp"
CONFIG_FILE="$INSTALL_DIR/frpc.toml"
SERVICE_FILE="/etc/systemd/system/frpc.service"

# ========== 删除某个代理块的函数（按 name） ==========
delete_proxy_by_name() {
    local name="$1"
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "配置文件不存在：$CONFIG_FILE"
        return 1
    fi

    awk -v target="$name" '
    BEGIN{
        inblock=0
        keepblock=1
        block=""
    }
    # 遇到一个新的 [[proxies]] 块
    /^\[\[proxies\]\]/{
        # 之前积累的块，如果需要保留，就输出
        if(block != "" && keepblock==1){
            printf "%s", block
        }
        # 开始新块
        block=$0 ORS
        inblock=1
        keepblock=1
        next
    }
    {
        if(inblock){
            block = block $0 ORS
            # 在块中发现 name = "xxx" 时判断是否为目标
            if($0 ~ "name *= *\""target"\""){
                keepblock=0
            }
        } else {
            # 非块内的普通行（例如 serverAddr 等），直接输出
            print
        }
    }
    END{
        # 最后一个块如果需要保留，就输出
        if(block != "" && keepblock==1){
            printf "%s", block
        }
    }' "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
}

# ========== 主菜单 ==========
echo "============================="
echo "  FRP 客户端一键管理脚本"
echo "============================="
echo "1. 初次安装"
echo "2. 配置维护"
read -p "请输入选择（1 或 2）： " mode

# ========== 1. 初次安装 ==========
if [ "$mode" -eq 1 ]; then
    echo "开始安装 frp 客户端（frpc）..."

    # 安装必要工具
    sudo apt-get update
    sudo apt-get install -y wget tar systemd

    # 创建安装目录
    mkdir -p "$INSTALL_DIR"
    cd "$INSTALL_DIR" || exit 1

    # 下载并解压 frp
    echo "下载 frp v${FRP_VERSION}..."
    wget -q "https://github.com/fatedier/frp/releases/download/v${FRP_VERSION}/frp_${FRP_VERSION}_linux_amd64.tar.gz"
    if [ $? -ne 0 ]; then
        echo "下载失败，请检查网络或版本号。"
        exit 1
    fi

    tar -xzf "frp_${FRP_VERSION}_linux_amd64.tar.gz"
    mv "frp_${FRP_VERSION}_linux_amd64"/* .
    rm -r "frp_${FRP_VERSION}_linux_amd64" "frp_${FRP_VERSION}_linux_amd64.tar.gz"

    # ===== 交互配置 =====
    echo "请输入服务器的 IP / 域名（例如：1.1.1.1）："
    read server_ip

    read -p "请输入 frps 的端口（回车默认为 7000）： " server_port
    server_port=${server_port:-7000}

    echo "请输入 frp token（例如：token）："
    read token

    echo "请输入要穿透的端口（格式：localPort remotePort，例如：22 6700）："
    read local_port remote_port

    # 自动生成规则名称： 22_to_6700 之类
    proxy_name="${local_port}_to_${remote_port}"
    echo "将自动使用规则名称：${proxy_name}"

    # 生成配置文件
    cat > "$CONFIG_FILE" <<EOL
serverAddr = "$server_ip"
serverPort = $server_port

auth.method = "token"
auth.token  = "$token"

[[proxies]]
name = "$proxy_name"
type = "tcp"
localIP = "127.0.0.1"
localPort = $local_port
remotePort = $remote_port
EOL

    echo "已生成配置文件：$CONFIG_FILE"
    echo "内容如下："
    cat "$CONFIG_FILE"
    echo "-----------------------------"

    # 创建 systemd 服务
    echo "创建 systemd 服务：$SERVICE_FILE"
    sudo bash -c "cat > $SERVICE_FILE <<EOL
[Unit]
Description=frp Client Service (frpc)
After=network.target

[Service]
Type=simple
ExecStart=$INSTALL_DIR/frpc -c $CONFIG_FILE
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOL"

    # 重新加载 systemd 并启用自启动
    sudo systemctl daemon-reload
    sudo systemctl enable frpc
    sudo systemctl start frpc

    echo "========================================"
    echo "frp 客户端安装完成，并已设置为开机自启。"
    echo "当前服务状态简要信息："
    sudo systemctl is-active --quiet frpc && echo "frpc 当前状态：running" || echo "frpc 当前状态：not running"
    echo "如需查看详细状态，请执行："
    echo "  sudo systemctl status frpc"
    echo "如需查看日志，请执行："
    echo "  journalctl -u frpc -f"
    echo "========================================"
    exit 0
fi

# ========== 2. 配置维护 ==========
if [ "$mode" -eq 2 ]; then
    echo "进入配置维护模式..."

    if [ ! -f "$CONFIG_FILE" ]; then
        echo "未找到配置文件：$CONFIG_FILE"
        echo "请先执行【初次安装】（选择 1）。"
        exit 1
    fi

    echo "当前 frpc 配置文件路径：$CONFIG_FILE"
    echo "----------------------------------------"
    cat "$CONFIG_FILE"
    echo "----------------------------------------"

    echo "请选择维护操作："
    echo "1. 修改现有映射（按 name，删掉后按同名重建）"
    echo "2. 添加新映射"
    echo "3. 删除映射"
    echo "4. 重启 frpc 服务"
    echo "5. 取消自启动"
    echo "6. 启用自启动"
    echo "7. 退出"
    read -p "请输入选择（1-7）： " action

    case "$action" in
        1)
            echo "请输入要修改的映射名称（name），例如：22_to_6700："
            read proxy_name

            # 先删除旧的
            delete_proxy_by_name "$proxy_name"
            echo "已删除原有映射：$proxy_name"

            echo "请输入新的 localPort："
            read new_local_port
            echo "请输入新的 remotePort："
            read new_remote_port

            # 保持原 name 不变，只改端口
            cat >> "$CONFIG_FILE" <<EOL

[[proxies]]
name = "$proxy_name"
type = "tcp"
localIP = "127.0.0.1"
localPort = $new_local_port
remotePort = $new_remote_port
EOL
            echo "已按同名重建映射：$proxy_name （$new_local_port -> $new_remote_port）"
            ;;

        2)
            echo "请输入新的 localPort："
            read new_local_port
            echo "请输入新的 remotePort："
            read new_remote_port

            default_name="${new_local_port}_to_${new_remote_port}"
            read -p "请输入映射名称（回车使用默认：$default_name）： " new_proxy_name
            new_proxy_name=${new_proxy_name:-$default_name}

            cat >> "$CONFIG_FILE" <<EOL

[[proxies]]
name = "$new_proxy_name"
type = "tcp"
localIP = "127.0.0.1"
localPort = $new_local_port
remotePort = $new_remote_port
EOL
            echo "已添加新映射：$new_proxy_name （$new_local_port -> $new_remote_port）"
            ;;

        3)
            echo "请输入要删除的映射名称（name）："
            read delete_name
            delete_proxy_by_name "$delete_name"
            echo "已删除映射：$delete_name（如果存在的话）"
            ;;

        4)
            sudo systemctl restart frpc
            echo "已重启 frpc 服务。"
            ;;

        5)
            sudo systemctl disable frpc
            echo "已取消 frpc 服务开机自启。"
            ;;

        6)
            sudo systemctl enable frpc
            echo "已启用 frpc 服务开机自启。"
            ;;

        7)
            echo "已退出。"
            exit 0
            ;;

        *)
            echo "无效选择。"
            exit 1
            ;;
    esac

    echo "操作已完成，如有修改配置，建议执行： sudo systemctl restart frpc"
    exit 0
fi

echo "无效模式选择，请重新运行脚本。"
exit 1
