#!/bin/bash

# 检测操作系统类型并安装 bc（如果尚未安装）
install_bc() {
    if ! command -v bc &> /dev/null; then
        echo "bc is not installed. Attempting to install..."
        if [ -f /etc/os-release ]; then
            . /etc/os-release
            distro=$ID
        else
            echo "Unsupported operating system. Please install bc manually."
            exit 1
        fi

        case "$distro" in
            ubuntu|debian)
                sudo apt-get update && sudo apt-get install -y bc
                ;;
            centos|rocky|fedora|rhel)
                sudo yum install -y bc
                ;;
            *)
                echo "Unsupported operating system: $distro. Please install bc manually."
                exit 1
                ;;
        esac
    fi
}

# 检查输入参数
if [ -z "$1" ] || [ -z "$2" ]; then
    echo "Usage: $0 <interface> <traffic_limit_in_GB>"
    exit 1
fi

interface_name=$1
traffic_limit=$2

# 调用安装函数
install_bc

# 核心功能部分
check_traffic() {
    # 更新网卡记录
    vnstat -i "$interface_name"

    # 获取本月的出站流量（TX）
    TX_BYTES=$(vnstat --oneline b -i "$interface_name" | awk -F';' '{print $10}')

    # 检查是否获取到数据
    if [[ -z "$TX_BYTES" ]]; then
        echo "Error: Not enough data available yet."
        exit 1
    fi

    # 将出站流量转换为GB，并确保结果至少有一位小数
    TX_GB=$(echo "scale=2; x = $TX_BYTES / 1073741824; if(x<1) print 0; x" | bc)

    # 检查转换后的流量是否为有效数字（允许小于 1 的小数）
    if ! [[ "$TX_GB" =~ ^[0-9]*\.?[0-9]+$ ]]; then
        echo "Error: Invalid traffic data. TX: $TX_BYTES, Converted: $TX_GB"
        exit 1
    fi

    echo "Current month's outbound traffic: $TX_GB GB"

    # 比较出站流量是否超过限制
    if (( $(echo "$TX_GB > $traffic_limit" | bc -l) )); then
        echo "Outbound traffic limit exceeded. Shutting down..."
        sudo /usr/sbin/shutdown -h now
    else
        echo "Outbound traffic is within limits."
    fi
}

# 执行一次流量检查
check_traffic

# 自动添加cron任务
cron_job="*/3 * * * * /bin/bash $(realpath $0) $interface_name $traffic_limit >> /var/log/traffic_monitor.log 2>&1"

# 检查是否已经存在相同的cron任务
(crontab -l 2>/dev/null | grep -Fv "$cron_job"; echo "$cron_job") | crontab -
