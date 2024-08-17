# My Project
部分应用的分流规则直接调用即可

监控VPS出站流量,达到阈值时自动关机,每3分钟自动执行一次,适合监控AWS/Azure/GCP的虚拟机的出站流量避免超出流量后扣费,使用前自行替换网卡名称与流量
## 如何使用
例如网卡名称是ens4,出站流量达到200G后自动关机,请运行以下命令：
```bash
wget -O monitor_outbound_traffic.sh https://raw.githubusercontent.com/whereisxiaobaobei/code-kitchen/main/monitor_outbound_traffic.sh && chmod +x monitor_outbound_traffic.sh && ./monitor_outbound_traffic.sh ens4 200

