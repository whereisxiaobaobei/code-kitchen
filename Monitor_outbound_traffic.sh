#!/bin/bash

# 函数：显示使用说明
show_usage() {
    echo "Usage: $0 -i <interface> -l <limit>"
    echo "  -i: Network interface (e.g., eth0, ens3)"
    echo "  -l: Traffic limit in GB"
    exit 1
}

# 检测操作系统类型并安装 bc（如果尚未安装）
install_bc() {
    if ! command -v bc &> /dev/null; then
        echo "bc is not installed. Attempting to install..."
        if [ -f /etc/debian_version ]; then
            # Ubuntu/Debian
            sudo apt-get update && sudo apt-get install -y bc
        elif [ -f /etc/redhat-release ]; then
            # CentOS/Rocky
            sudo yum install -y bc
        else
            echo "Unsupported operating system. Please install bc manually."
            exit 1
        fi
    fi
}

# 解析命令行参数
while getopts ":i:l:" opt; do
    case ${opt} in
        i ) interface_name=$OPTARG ;;
        l ) traffic_limit=$OPTARG ;;
        \? ) show_usage ;;
    esac
done

# 检查必要参数是否提供
if [ -z "$interface_name" ] || [ -z "$traffic_limit" ]; then
    show_usage
fi

# 调用安装函数
install_bc

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
