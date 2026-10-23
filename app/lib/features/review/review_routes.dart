import 'package:go_router/go_router.dart';

import '../../core/routes.dart';
import 'review_screen.dart';

final reviewRoutes = <RouteBase>[
  GoRoute(path: Routes.review, builder: (context, state) => const ReviewFlowScreen()),
];
