import 'package:go_router/go_router.dart';

import '../../core/routes.dart';
import 'month_screen.dart';

final monthRoutes = <RouteBase>[
  GoRoute(path: Routes.month, builder: (context, state) => const MonthScreen()),
];
