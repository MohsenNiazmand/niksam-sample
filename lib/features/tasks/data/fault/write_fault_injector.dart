import '../../../../core/config/app_config.dart';

class InjectedWriteException implements Exception {
  final String message;
  const InjectedWriteException([this.message = 'Injected write fault']);

  @override
  String toString() => 'InjectedWriteException: $message';
}

abstract interface class WriteFaultInjector {
  void beginWrite();
  void checkpoint(String name);
}

class NoFault implements WriteFaultInjector {
  const NoFault();

  @override
  void beginWrite() {}

  @override
  void checkpoint(String name) {}
}

class ConfiguredFault implements WriteFaultInjector {
  final bool failWrites;
  final int failFirstWrites;
  int _writeCount = 0;

  ConfiguredFault({
    this.failWrites = AppConfig.failWrites,
    this.failFirstWrites = AppConfig.failFirstWrites,
  });

  @override
  void beginWrite() {
    _writeCount++;
  }

  @override
  void checkpoint(String name) {
    if (failWrites) {
      throw InjectedWriteException('Simulated write failure (FAIL_WRITES=true) at $name');
    }
    if (failFirstWrites > 0 && _writeCount <= failFirstWrites) {
      throw InjectedWriteException(
        'Simulated transient failure (write $_writeCount of $failFirstWrites) at $name',
      );
    }
  }
}

class TestFaultInjector implements WriteFaultInjector {
  final Set<String> failAtCheckpoints;
  bool failNextWrite;
  int writeCount = 0;

  TestFaultInjector({
    Set<String>? failAtCheckpoints,
    this.failNextWrite = false,
  }) : failAtCheckpoints = failAtCheckpoints ?? <String>{};

  @override
  void beginWrite() {
    writeCount++;
  }

  @override
  void checkpoint(String name) {
    if (failNextWrite || failAtCheckpoints.contains(name)) {
      throw InjectedWriteException('Test fault injected at checkpoint: $name');
    }
  }
}
