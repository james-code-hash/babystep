import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    excludeAppSupportFromBackup()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }

  /// 孩子的資料庫放在 Library/Application Support（lib/data/database_store.dart）。
  /// 整個資料夾標成不進 iCloud／電腦備份，資料只留在這台裝置（底線 8、docs/decisions.md G4）。
  /// 需要在實機上確認（設定 → iCloud → 管理儲存空間 → 備份 裡看不到這個 App 的資料）。
  private func excludeAppSupportFromBackup() {
    let fm = FileManager.default
    guard var dir = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return }
    do {
      try fm.createDirectory(at: dir, withIntermediateDirectories: true)
      var values = URLResourceValues()
      values.isExcludedFromBackup = true
      try dir.setResourceValues(values)
    } catch {
      NSLog("little_steps: could not exclude Application Support from backup")
    }
  }
}
