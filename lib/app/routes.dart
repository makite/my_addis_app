/// Centralised route path constants.
///
/// Use these instead of hard-coded strings so that every
/// `context.go()` / `context.push()` call is type-safe and
/// refactor-friendly.
///
/// ```dart
/// context.go(Routes.home);
/// context.push(Routes.products);
/// ```
class Routes {
  Routes._();

  static const String home = '/';

  // ══════ RIVERFLOW_ROUTE_NAMES ══════
}
