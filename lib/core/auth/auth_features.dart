/// Mirrors `frontend-new-hrms/src/utils/companyFeatures.js` + Sidebar permission checks.

Map<String, dynamic> mapFromDynamic(dynamic raw) {
  if (raw is Map<String, dynamic>) return raw;
  if (raw is Map) return Map<String, dynamic>.from(raw);
  return {};
}

Map<String, dynamic> extractAuthUserMap(dynamic response) {
  final root = mapFromDynamic(response);
  final user = root['user'];
  if (user is Map) return mapFromDynamic(user);
  final data = root['data'];
  if (data is Map) {
    final nested = mapFromDynamic(data);
    if (nested['user'] is Map) return mapFromDynamic(nested['user']);
    return nested;
  }
  return root;
}

List<String> normalizePermissionNames(dynamic raw) {
  dynamic list = raw;
  if (raw is Map) {
    list = raw['permissions'] ?? raw['data'] ?? raw['list'];
  }
  if (list is! List) return const [];
  final out = <String>[];
  for (final p in list) {
    if (p is String) {
      final name = p.trim();
      if (name.isNotEmpty) out.add(name);
      continue;
    }
    if (p is Map) {
      final name = (p['name'] ?? p['displayName'] ?? '').toString().trim();
      if (name.isNotEmpty) out.add(name);
    }
  }
  return out;
}

List<String> permissionsFromAuthUser(Map<String, dynamic> user) {
  final role = user['role'] ?? user['Role'];
  if (role is Map) {
    return normalizePermissionNames(role['permissions']);
  }
  return normalizePermissionNames(user['permissions']);
}

String? roleNameFromAuthUser(Map<String, dynamic> user) {
  final role = user['role'] ?? user['Role'];
  if (role is Map) {
    final name = role['name']?.toString().trim();
    if (name != null && name.isNotEmpty) return name;
  }
  if (role is String && role.trim().isNotEmpty) return role.trim();
  return null;
}

Map<String, dynamic> mergeFeatureLayers(Iterable<dynamic> layers) {
  var acc = <String, dynamic>{};
  for (final layer in layers) {
    if (layer is! Map) continue;
    acc = {...acc, ...mapFromDynamic(layer)};
  }
  return acc;
}

/// Same as web `resolveAuthFeatures(user)`.
Map<String, dynamic> resolveAuthFeatures(Map<String, dynamic> user) {
  if (user.isEmpty) return {};

  final plan = mapFromDynamic(user['plan']);
  final company = mapFromDynamic(user['company']);
  final rootCompany = mapFromDynamic(
    user['rootCompany'] ?? user['root_company'],
  );
  final rootPlan = mapFromDynamic(rootCompany['plan']);

  final planFeatures = mapFromDynamic(plan['features']);
  final companyFeatures = mapFromDynamic(company['features']);
  final rootFeatures = mapFromDynamic(rootCompany['features']);
  final rootPlanFeatures = mapFromDynamic(rootPlan['features']);

  final companyId = (user['companyId'] ?? company['id'])?.toString();
  final rootCompanyId =
      (user['rootCompanyId'] ??
              rootCompany['id'] ??
              user['root_company_id'])
          ?.toString();
  final isSubCompany =
      company['parent_id'] != null ||
      company['parentId'] != null ||
      (rootCompanyId != null &&
          companyId != null &&
          rootCompanyId.isNotEmpty &&
          companyId.isNotEmpty &&
          rootCompanyId != companyId);

  if (isSubCompany) {
    return mergeFeatureLayers([
      planFeatures,
      companyFeatures,
      rootPlanFeatures,
      rootFeatures,
    ]);
  }
  return mergeFeatureLayers([planFeatures, companyFeatures]);
}

/// JS `!!value` for feature flags (`true`, `1`, `"true"`).
bool isFeatureFlagOn(dynamic value) {
  if (value == null || value == false) return false;
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final s = value.trim().toLowerCase();
    if (s.isEmpty || s == 'false' || s == '0' || s == 'no' || s == 'null') {
      return false;
    }
    return true;
  }
  return true;
}

/// Same as web `isFeatureEnabledForUser` / Sidebar `isFeatureEnabled`.
bool isFeatureEnabledForUser({
  required Map<String, dynamic> features,
  required String feature,
  String? roleName,
}) {
  if (feature.isEmpty) return true;
  if (roleName == 'SuperAdmin') return true;
  return isFeatureFlagOn(features[feature]);
}

bool hasAnyPermission(List<String> mine, List<String> required) {
  if (required.isEmpty) return true;
  return required.any(mine.contains);
}

const meetingJoinPermission = 'meeting.join';
const meetingCreatePermission = 'meeting.create';
const meetingManagePermission = 'meeting.manage';
const meetingsFeatureKey = 'meetings';

/// Web sidebar: `perms: ["meeting.join", "meeting.create"]` (any).
/// App route / API doc also allow `meeting.manage`.
const meetingMenuPermissions = [
  meetingJoinPermission,
  meetingCreatePermission,
  meetingManagePermission,
];

bool canAccessMeetingsMenu({
  required List<String> permissions,
  required Map<String, dynamic> features,
  String? roleName,
  bool featuresLoaded = true,
}) {
  if (roleName == 'SuperAdmin') return true;
  if (!hasAnyPermission(permissions, meetingMenuPermissions)) return false;
  if (!featuresLoaded) return true;
  return isFeatureEnabledForUser(
    features: features,
    feature: meetingsFeatureKey,
    roleName: roleName,
  );
}

bool canCreateMeetings(List<String> permissions, {bool? metaCanCreate}) {
  if (permissions.contains(meetingCreatePermission)) return true;
  return metaCanCreate == true;
}

bool canEditMeetings(List<String> permissions) {
  return permissions.contains(meetingCreatePermission) ||
      permissions.contains(meetingManagePermission);
}
