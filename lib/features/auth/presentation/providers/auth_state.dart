import '../../data/models/user_model.dart';
import '../../../profile/data/models/user_details_model.dart';

class AuthState {
  final bool isLoading;
  final bool isInitializing;

  final User? authUser;
  final Userdetails? profile;

  final String profileUrl;
  final String companyLogoUrl;

  final bool isSubscriptionExpired;

  /// JWT was present; restore/profile fetch failed for a non-auth reason.
  final bool restoreFailed;

  /// A JWT is (or was) in secure storage for this session attempt.
  final bool hasStoredSession;

  final List<String> permissions;
  final Map<String, dynamic> features;
  final String? roleName;
  final bool featuresLoaded;
  final bool mustChangePassword;

  const AuthState({
    this.isLoading = false,
    this.isInitializing = true,
    this.authUser,
    this.profile,
    this.profileUrl = '',
    this.companyLogoUrl = '',
    this.permissions = const [],
    this.features = const {},
    this.roleName,
    this.featuresLoaded = false,
    this.isSubscriptionExpired = false,
    this.restoreFailed = false,
    this.hasStoredSession = false,
    this.mustChangePassword = false,
  });

  AuthState copyWith({
    bool? isLoading,
    bool? isInitializing,
    User? authUser,
    Userdetails? profile,
    String? profileUrl,
    String? companyLogoUrl,
    bool? isSubscriptionExpired,
    bool? restoreFailed,
    bool? hasStoredSession,
    List<String>? permissions,
    Map<String, dynamic>? features,
    String? roleName,
    bool? featuresLoaded,
    bool? mustChangePassword,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      isInitializing: isInitializing ?? this.isInitializing,
      authUser: authUser ?? this.authUser,
      profile: profile ?? this.profile,
      profileUrl: profileUrl ?? this.profileUrl,
      companyLogoUrl: companyLogoUrl ?? this.companyLogoUrl,
      permissions: permissions ?? this.permissions,
      features: features ?? this.features,
      roleName: roleName ?? this.roleName,
      featuresLoaded: featuresLoaded ?? this.featuresLoaded,
      isSubscriptionExpired:
          isSubscriptionExpired ?? this.isSubscriptionExpired,
      restoreFailed: restoreFailed ?? this.restoreFailed,
      hasStoredSession: hasStoredSession ?? this.hasStoredSession,
      mustChangePassword: mustChangePassword ?? this.mustChangePassword,
    );
  }
}
