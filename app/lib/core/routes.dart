/// 路由路徑。各 feature 在自己的 `<feature>_routes.dart` 宣告 GoRoute。
abstract final class Routes {
  static const home = '/';
  static const plan = '/plan';
  static const review = '/review';
  static const notebook = '/notebook';
  static const path = '/path';
  static const explore = '/explore';
  static const month = '/month';
  static const settings = '/settings';
  static const dressUp = '/settings/dress-up';
  static const petName = '/settings/name';
  static const parent = '/parent';
  static const pocket = '/pocket';
  static const pocketNew = '/pocket/new';

  /// 翻一張：`/pocket/card/<id>`；改一張：`/pocket/edit/<id>`。
  static String pocketCard(String id) => '/pocket/card/$id';
  static String pocketEdit(String id) => '/pocket/edit/$id';
}
