class SessionGuard {
  bool _expiredTriggered = false;

  void trigger(void Function() onExpired) {
    if (_expiredTriggered) return;

    _expiredTriggered = true;
    onExpired();
  }

  void reset() {
    _expiredTriggered = false;
  }
}
