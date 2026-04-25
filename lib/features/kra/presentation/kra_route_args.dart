import 'package:lms/features/kra/presentation/providers/kra_provider.dart';

/// Pass as [RouteSettings.arguments] for `/kra` to open a specific KRA sub-tab.
class KraRouteArgs {
  final KraTabTarget tab;
  final bool openCreateForm;

  const KraRouteArgs({required this.tab, this.openCreateForm = false});

  static const myRating = KraRouteArgs(tab: KraTabTarget.myRating);
  static const teamRating = KraRouteArgs(tab: KraTabTarget.teamRating);
  static const departmentRating = KraRouteArgs(tab: KraTabTarget.departmentRating);
  static const allRatings = KraRouteArgs(tab: KraTabTarget.allRatings);
  static const myKras = KraRouteArgs(tab: KraTabTarget.myKras);
  static const setup = KraRouteArgs(tab: KraTabTarget.setup);
  static const cycles = KraRouteArgs(tab: KraTabTarget.cycles);

  /// Opens KRA Setup, then the create KRA & KPI bottom sheet.
  static const createKra = KraRouteArgs(
    tab: KraTabTarget.setup,
    openCreateForm: true,
  );
}

enum KraTabTarget {
  myRating,
  teamRating,
  departmentRating,
  allRatings,
  myKras,
  setup,
  cycles,
}

/// Resolves the [DefaultTabController] index for the current user’s visible tabs.
int resolveKraInitialTabIndex({
  required List<KraReviewMode> modes,
  required bool canManage,
  required int tabCount,
  KraTabTarget? target,
}) {
  if (target == null || tabCount == 0) return 0;

  int firstReviewOrZero(KraReviewMode m) {
    final i = modes.indexOf(m);
    return i >= 0 ? i : 0;
  }

  int setupIndex() {
    if (!canManage) return 0;
    var n = modes.length;
    if (modes.contains(KraReviewMode.self)) n += 1;
    return n;
  }

  int cyclesIndex() {
    if (!canManage) return 0;
    return setupIndex() + 1;
  }

  int index;
  switch (target) {
    case KraTabTarget.myRating:
      index = firstReviewOrZero(KraReviewMode.self);
      break;
    case KraTabTarget.teamRating:
      index = firstReviewOrZero(KraReviewMode.team);
      break;
    case KraTabTarget.departmentRating:
      index = firstReviewOrZero(KraReviewMode.department);
      break;
    case KraTabTarget.allRatings:
      index = firstReviewOrZero(KraReviewMode.all);
      break;
    case KraTabTarget.myKras:
      if (modes.contains(KraReviewMode.self)) {
        index = modes.length;
      } else {
        index = 0;
      }
      break;
    case KraTabTarget.setup:
      index = setupIndex();
      break;
    case KraTabTarget.cycles:
      index = cyclesIndex();
      break;
  }

  if (index < 0) return 0;
  if (index >= tabCount) return tabCount - 1;
  return index;
}

KraRouteArgs? kraArgsFromRoute(Object? arguments) {
  if (arguments is KraRouteArgs) return arguments;
  return null;
}
