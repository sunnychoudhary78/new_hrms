import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/features/auth/presentation/providers/auth_provider.dart';
import 'package:lms/features/auth/presentation/providers/auth_state.dart';

import '../storage/token_storage.dart';
import '../network/dio_client.dart';
import '../network/api_service.dart';

// 🔐 Token storage provider
final tokenStorageProvider = Provider<TokenStorage>((ref) {
  return TokenStorage();
});

final dioClientProvider = Provider<DioClient>((ref) {
  final tokenStorage = ref.read(tokenStorageProvider);

  return DioClient(
    tokenStorage: tokenStorage,

    onSubscriptionExpired: () {
      ref.read(authProvider.notifier).forceSubscriptionExpired();
    },
  );
});

// 📡 Api service provider
final apiServiceProvider = Provider<ApiService>((ref) {
  final dioClient = ref.read(dioClientProvider);
  return ApiService(dioClient.dio);
});
