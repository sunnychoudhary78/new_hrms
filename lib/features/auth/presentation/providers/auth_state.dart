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

  const AuthState({
    this.isLoading = false,
    this.isInitializing = true,
    this.authUser,
    this.profile,
    this.profileUrl = '',
    this.companyLogoUrl = '',
    this.permissions = const [],
    this.isSubscriptionExpired = false,
    this.restoreFailed = false,
    this.hasStoredSession = false,
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
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      isInitializing: isInitializing ?? this.isInitializing,
      authUser: authUser ?? this.authUser,
      profile: profile ?? this.profile,
      profileUrl: profileUrl ?? this.profileUrl,
      companyLogoUrl: companyLogoUrl ?? this.companyLogoUrl,
      permissions: permissions ?? this.permissions,
      isSubscriptionExpired:
          isSubscriptionExpired ?? this.isSubscriptionExpired,
      restoreFailed: restoreFailed ?? this.restoreFailed,
      hasStoredSession: hasStoredSession ?? this.hasStoredSession,
    );
  }
}
