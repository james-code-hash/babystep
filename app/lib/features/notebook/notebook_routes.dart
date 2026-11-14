import 'package:go_router/go_router.dart';

import '../../core/routes.dart';
import 'notebook_screen.dart';

final notebookRoutes = <RouteBase>[
  GoRoute(path: Routes.notebook, builder: (context, state) => const NotebookScreen()),
];
