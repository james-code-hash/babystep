/// 路由路徑。各 feature 在自己的 `<feature>_routes.dart` 宣告 GoRoute。
abstract final class Routes {
  static const home = '/';
  static const plan = '/plan';
  static const review = '/review';
  static const notebook = '/notebook';
  static const path = '/path';
  static const settings = '/settings';
  static const dressUp = '/settings/dress-up';
  static const parent = '/parent';
}
