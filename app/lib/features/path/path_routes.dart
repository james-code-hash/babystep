import 'package:go_router/go_router.dart';

import '../../core/routes.dart';
import 'path_screen.dart';

final pathRoutes = <RouteBase>[
  GoRoute(path: Routes.path, builder: (context, state) => const PathScreen()),
];
