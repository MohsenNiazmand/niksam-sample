import 'package:niksam/features/tasks/data/fault/write_fault_injector.dart';

class TestFaultInjector implements WriteFaultInjector {
  final Set<String> failAtCheckpoints;
  bool failNextWrite;
  int writeCount = 0;

  TestFaultInjector({
    Set<String>? failAtCheckpoints,
    this.failNextWrite = false,
  }) : failAtCheckpoints = failAtCheckpoints ?? <String>{};

  @override
  WriteAttempt beginWrite() {
    writeCount++;
    return _TestWriteAttempt(
      failAtCheckpoints: failAtCheckpoints,
      failNextWrite: failNextWrite,
    );
  }
}

class _TestWriteAttempt implements WriteAttempt {
  final Set<String> failAtCheckpoints;
  final bool failNextWrite;

  _TestWriteAttempt({
    required this.failAtCheckpoints,
    required this.failNextWrite,
  });

  @override
  void checkpoint(String name) {
    if (failNextWrite || failAtCheckpoints.contains(name)) {
      throw InjectedWriteException('Test fault injected at checkpoint: $name');
    }
  }
}
