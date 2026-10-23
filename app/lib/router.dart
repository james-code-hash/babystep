import 'package:go_router/go_router.dart';

import 'core/routes.dart';
import 'features/home/home_routes.dart';
import 'features/notebook/notebook_routes.dart';
import 'features/parent/parent_routes.dart';
import 'features/path/path_routes.dart';
import 'features/plan/plan_routes.dart';
import 'features/review/review_routes.dart';
import 'features/settings/settings_routes.dart';

GoRouter buildRouter() => GoRouter(
      initialLocation: Routes.home,
      routes: [
        ...homeRoutes,
        ...planRoutes,
        ...reviewRoutes,
        ...notebookRoutes,
        ...pathRoutes,
        ...settingsRoutes,
        ...parentRoutes,
      ],
    );
