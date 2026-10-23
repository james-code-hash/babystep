import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../../core/config.dart';
import 'llm_lesson_service.dart';

/// 透過 Cloud Function `bubuLearn`（callable，asia-east1）呼叫 LLM 代理。
///
/// 這層刻意很薄：只把最小 payload 原樣送出、把回應轉成 Map。驗證、重試、逾時、退回範本都在
/// [LlmLessonService]。沒有 Analytics／Crashlytics（docs/decisions.md A2）。
class FirebaseLessonLlmClient implements LessonLlmClient {
  FirebaseLessonLlmClient(this._functions);

  final FirebaseFunctions _functions;

  static const functionName = 'bubuLearn';
  static const region = 'asia-east1';

  @override
  Future<Map<String, Object?>> bubuLearn(Map<String, Object?> payload) async {
    final callable = _functions.httpsCallable(
      functionName,
      options: HttpsCallableOptions(timeout: AppConfig.llmTimeout),
    );
    final result = await callable.call<Object?>(payload);
    final data = result.data;
    if (data is! Map) throw const FormatException('bubuLearn: response is not a map');
    return {for (final e in data.entries) e.key.toString(): e.value};
  }
}

/// 建立 LLM client 的開發設定，全部用 `--dart-define` 帶入：
///
/// | 名稱 | 預設 | 用途 |
/// |---|---|---|
/// | `LLM_EMULATOR_HOST` | （空） | Functions emulator 的主機；**沒帶就不碰 Firebase**（[AppConfig.functionsEmulatorHost]） |
/// | `LLM_EMULATOR_PORT` | 5001 | Functions emulator 的埠（[AppConfig.functionsEmulatorPort]） |
/// | `LLM_AUTH_EMULATOR_PORT` | 9099 | Auth emulator 的埠（匿名登入用；0 = 不用 Auth emulator） |
/// | `FIREBASE_API_KEY` | `demo-api-key` | FirebaseOptions.apiKey |
/// | `FIREBASE_APP_ID` | `1:000000000000:android:0000000000000000` | FirebaseOptions.appId |
/// | `FIREBASE_PROJECT_ID` | `little-steps-dev` | FirebaseOptions.projectId |
/// | `FIREBASE_SENDER_ID` | `000000000000` | FirebaseOptions.messagingSenderId |
///
/// 例：`fvm flutter run --dart-define=LLM_EMULATOR_HOST=localhost`
abstract final class FirebaseLlmEnv {
  static const apiKey = String.fromEnvironment('FIREBASE_API_KEY', defaultValue: 'demo-api-key');
  static const appId =
      String.fromEnvironment('FIREBASE_APP_ID', defaultValue: '1:000000000000:android:0000000000000000');
  static const projectId = String.fromEnvironment('FIREBASE_PROJECT_ID', defaultValue: 'little-steps-dev');
  static const senderId = String.fromEnvironment('FIREBASE_SENDER_ID', defaultValue: '000000000000');

}

/// 有設定 emulator 才建立 client；其他情況（包含任何錯誤）回傳 null，App 維持範本模式。
///
/// 步驟：用最小的手動 [FirebaseOptions] 初始化 Firebase → 連到 Functions emulator →
/// （有 Auth emulator 就連上）匿名登入 → 回傳 client。不初始化 Analytics、Crashlytics。
Future<LessonLlmClient?> createLessonLlmClient() async {
  const host = AppConfig.functionsEmulatorHost;
  if (host.isEmpty) return null;
  try {
    final app = Firebase.apps.isNotEmpty
        ? Firebase.app()
        : await Firebase.initializeApp(
            options: const FirebaseOptions(
              apiKey: FirebaseLlmEnv.apiKey,
              appId: FirebaseLlmEnv.appId,
              messagingSenderId: FirebaseLlmEnv.senderId,
              projectId: FirebaseLlmEnv.projectId,
            ),
          );
    final functions = FirebaseFunctions.instanceFor(app: app, region: FirebaseLessonLlmClient.region)
      ..useFunctionsEmulator(host, AppConfig.functionsEmulatorPort);
    final auth = FirebaseAuth.instanceFor(app: app);
    if (AppConfig.authEmulatorPort > 0) {
      await auth.useAuthEmulator(host, AppConfig.authEmulatorPort);
    }
    if (auth.currentUser == null) await auth.signInAnonymously().timeout(AppConfig.llmTimeout);
    return FirebaseLessonLlmClient(functions);
  } catch (_) {
    return null;
  }
}
