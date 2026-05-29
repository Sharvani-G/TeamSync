// Web ringtone implementation may rely on JS interop. Provide a safe no-op
// implementation here so the analyzer and non-web builds do not fail.
class CallRingtoneService {
  Future<void> start() async {
    // No-op in environments without JS interop.
    return;
  }

  Future<void> stop() async {
    // No-op
    return;
  }
}