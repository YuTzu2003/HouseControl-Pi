# Android 模擬器與實體手機部署

## 1. 開發環境

建議準備：

- Flutter SDK 與 Dart SDK。
- Android Studio 及 Android Emulator。
- Java 17。
- Android SDK 37。
- 可連到 Raspberry Pi 的區域網路。

先確認環境：

```powershell
flutter doctor
flutter pub get
flutter devices
```

## 2. 使用 Android 模擬器

在 Android Studio 的 Device Manager 建立並啟動模擬器，或使用命令列：

```powershell
flutter emulators
flutter emulators --launch <模擬器 ID>
flutter devices
```

執行 App：

```powershell
flutter run -d emulator-5554
```

若裝置 ID 不同，請以 `flutter devices` 顯示的 ID 為準。

### 模擬器連線設定

第一次開啟 App 時：

1. 家庭連線位址：輸入 Raspberry Pi 的區域網路 IP。
2. 連線通道：預設 `1883`。
3. 家庭帳號、密碼：匿名 MQTT 環境保持空白。
4. 點「完成設定」。

模擬器必須能連到 Raspberry Pi 的 `1883` 與 `8000` 連接埠。若後端不是 Raspberry Pi，而是直接跑在開發電腦上，Android Emulator 通常以 `10.0.2.2` 連回電腦主機。

## 3. 實體手機開發測試

1. 在 Android 手機設定中開啟「開發人員選項」。
2. 開啟「USB 偵錯」。
3. 以 USB 連接電腦，並在手機允許此電腦進行偵錯。
4. 執行：

```powershell
flutter devices
flutter run -d <手機裝置 ID>
```

手機應與 Raspberry Pi 連接同一個 Wi-Fi。若 App 無法連線，可先用手機瀏覽器開啟：

```text
http://<Raspberry Pi IP>:8000/health
```

能看到健康狀態回應，代表手機至少可以連到 API。

## 4. 建立並安裝 Release APK

建立 APK：

```powershell
flutter clean
flutter pub get
flutter build apk --release
```

輸出位置：

```text
build/app/outputs/flutter-apk/app-release.apk
```

使用 ADB 安裝或更新：

```powershell
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

也可將 APK 傳到手機，點擊檔案後允許「安裝未知應用程式」並完成安裝。

### 減少 APK 大小

如需依手機架構分開產生 APK：

```powershell
flutter build apk --release --split-per-abi
```

一般近年的 Android 手機多半使用 `arm64-v8a` 版本。

## 5. 正式發佈注意事項

目前專案的 release build 仍使用開發用簽章，適合專題展示、測試與內部安裝。若要正式上架 Google Play，應先完成：

1. 將 `com.example.housecontrol_pi` 改成正式且唯一的 application ID。
2. 建立並妥善備份 release keystore。
3. 在 Android Gradle 設定正式 signing config，不再使用 debug signing。
4. 更新 `pubspec.yaml` 的版本號，例如 `1.0.1+2`。
5. 建立 App Bundle：

```powershell
flutter build appbundle --release
```

輸出檔位於：

```text
build/app/outputs/bundle/release/app-release.aab
```

## 6. App 使用方式

- 「控制」：燈光、攝影機、環境資訊、音樂與情境快捷操作。
- 「活動」：溫溼度與相關紀錄。
- 「自動化」：建立排程與情境模式。
- 「家庭」：新增家庭成員、綁定門卡與查看紀錄。
- 「設定」：重新設定家庭連線。

YouTube 音樂可直接在 App 貼上影片連結，也可從 YouTube App 點「分享」後選擇 HouseControl。

## 7. 常見問題

### Android SDK 版本錯誤

本專案目前使用 `compileSdk 37` 與 Android Gradle Plugin `9.1.1`。請在 Android Studio 的 SDK Manager 安裝 Android SDK 37。

### App 可以開啟，但設備無法控制

- 確認手機與 Raspberry Pi 在同一個網路。
- 確認家庭連線位址沒有輸入 `http://`。
- 確認 Raspberry Pi 的 `./start.sh status` 三個服務都在執行。
- 確認路由器或防火牆沒有阻擋 `1883`、`8000`。
- 在 Raspberry Pi 執行 `./start.sh logs` 查看即時控制紀錄。

### 更新 APK 後設定仍保留

使用 `adb install -r` 會保留 App 資料。若要完全清除設定，可解除安裝 App，或在 Android 的 App 資訊頁清除儲存空間。
