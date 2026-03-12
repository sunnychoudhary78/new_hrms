import 'package:flutter_riverpod/flutter_riverpod.dart';

enum GlobalActionType { loading, success, error }

class GlobalAction {
  final GlobalActionType type;
  final String message;

  const GlobalAction({required this.type, required this.message});
}

class GlobalActionNotifier extends Notifier<GlobalAction?> {
  @override
  GlobalAction? build() {
    return null;
  }

  void loading(String message) {
    state = GlobalAction(type: GlobalActionType.loading, message: message);
  }

  void success(String message) {
    state = GlobalAction(type: GlobalActionType.success, message: message);
  }

  void error(String message) {
    state = GlobalAction(type: GlobalActionType.error, message: message);
  }

  void clear() {
    state = null;
  }
}

final globalActionProvider =
    NotifierProvider<GlobalActionNotifier, GlobalAction?>(
      GlobalActionNotifier.new,
    );
