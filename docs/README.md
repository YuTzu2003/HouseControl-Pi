# HouseControl Pi 文件中心

此資料夾集中保存專案的架構、架設、測試、部署與簡報文件。

## 文件分類

### 架構

- [系統與專案架構](system-architecture.md)：App、MQTT、FastAPI、Raspberry Pi 服務、資料流與主要檔案職責。

### 安裝與部署

- [Raspberry Pi 架設指南](raspberry-pi.md)：套件、Mosquitto、硬體設定、啟動、自動執行與故障排查。
- [手機與模擬器指南](mobile.md)：Android 模擬器、實體手機測試、Release APK 與首次使用。

### 專案資料

- [HouseControl-Pi 專案簡報](HouseControl-Pi.pptx)

## 維護方式

- 快速開始與使用者入口放在根目錄 `README.md`。
- Raspberry Pi 詳細設定放在 `raspberry-pi.md`。
- 手機建置與部署放在 `mobile.md`。
- 架構或 MQTT/API 契約異動時，同步更新 `system-architecture.md`。
- 簡報與架構圖原檔直接放在此資料夾。
