import '../../data/models/user_model.dart';
import '../../../profile/data/models/user_details_model.dart';

class AuthState {
  final bool isLoading;
  final bool isInitializing; // NEW

  final User? authUser;
  final Userdetails? profile;

  final String profileUrl;
  final String companyLogoUrl;

  final bool isSubscriptionExpired;

  final List<String> permissions;

  const AuthState({
    this.isLoading = false,
    this.isInitializing = true, // start in initializing state
    this.authUser,
    this.profile,
    this.profileUrl = '',
    this.companyLogoUrl = '',
    this.permissions = const [],
    this.isSubscriptionExpired = false,
  });

  AuthState copyWith({
    bool? isLoading,
    bool? isInitializing,
    User? authUser,
    Userdetails? profile,
    String? profileUrl,
    String? companyLogoUrl,
    bool? isSubscriptionExpired,
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
    );
  }
}
