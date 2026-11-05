# Raspberry Pi 端

此目錄包含 HouseControl 的 Raspberry Pi Python 服務、硬體測試與統一啟動腳本。

快速啟動：

```bash
uv sync
cp house_control.env.example house_control.env
chmod +x start.sh
./start.sh
```

完整的安裝、Mosquitto、GPIO、音響、攝影機、自動啟動與故障排查說明，請見：

- [Raspberry Pi 架設指南](../docs/raspberry-pi.md)
- [系統與專案架構](../docs/system-architecture.md)
