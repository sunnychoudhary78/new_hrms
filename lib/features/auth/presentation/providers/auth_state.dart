import '../../data/models/user_model.dart';
import '../../../profile/data/models/user_details_model.dart';

class AuthState {
  final bool isLoading;
  final User? authUser;
  final Userdetails? profile;

  final String profileUrl;

  /// 🏢 NEW — company logo url
  final String companyLogoUrl;

  final bool isSubscriptionExpired; // NEW

  final List<String> permissions;

  const AuthState({
    this.isLoading = true,
    this.authUser,
    this.profile,
    this.profileUrl = '',
    this.companyLogoUrl = '',
    this.permissions = const [],
    this.isSubscriptionExpired = false,
  });

  AuthState copyWith({
    bool? isLoading,
    User? authUser,
    Userdetails? profile,
    String? profileUrl,
    String? companyLogoUrl,
    bool? isSubscriptionExpired,

    List<String>? permissions,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      authUser: authUser ?? this.authUser,
      isSubscriptionExpired:
          isSubscriptionExpired ?? this.isSubscriptionExpired,
      profile: profile ?? this.profile,
      profileUrl: profileUrl ?? this.profileUrl,
      companyLogoUrl: companyLogoUrl ?? this.companyLogoUrl,
      permissions: permissions ?? this.permissions,
    );
  }
}
