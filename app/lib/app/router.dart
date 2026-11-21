// Routes. Real paths (no #), so a link to /devices or /activity can be shared;
// the server answers every non-API path with index.html.
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../data/model.dart';
import '../pages/activity_page.dart';
import '../pages/devices_page.dart';
import '../pages/network_page.dart';
import '../pages/map_page.dart';
import 'shell.dart';

/// Pages swap instantly: no transition, so the old page is never seen
/// under the new one.
NoTransitionPage<void> _page(GoRouterState state, Widget child) =>
    NoTransitionPage<void>(key: child.key is ValueKey ? ValueKey('page-${(child.key! as ValueKey).value}') : state.pageKey, child: child);

GoRouter buildRouter({String initialLocation = '/'}) => GoRouter(
  initialLocation: initialLocation,
  routes: [
    ShellRoute(
      builder: (context, state, child) => AppShell(location: state.uri.path, child: child),
      routes: [
        GoRoute(path: '/', pageBuilder: (context, state) => _page(state, const MapPage())),
        GoRoute(
          path: '/devices',
          pageBuilder: (context, state) => _page(state, const DevicesPage(key: ValueKey('devices'))),
        ),
        // a sibling, not a child: list and list+detail are the same page, so
        // the list keeps its filters and scroll when a device is picked
        GoRoute(
          path: '/devices/:id',
          pageBuilder: (context, state) => _page(state, DevicesPage(key: const ValueKey('devices'), selected: state.pathParameters['id'])),
        ),
        GoRoute(
          path: '/activity',
          pageBuilder: (context, state) =>
              _page(state, ActivityPage(filter: EventFilter.values.where((f) => f.name == state.uri.queryParameters['f']).firstOrNull)),
        ),
        GoRoute(path: '/network', pageBuilder: (context, state) => _page(state, const NetworkPage())),
      ],
    ),
  ],
);
