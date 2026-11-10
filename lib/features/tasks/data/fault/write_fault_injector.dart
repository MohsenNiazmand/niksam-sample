import '../../../../core/config/app_config.dart';

class InjectedWriteException implements Exception {
  final String message;
  const InjectedWriteException([this.message = 'Injected write fault']);

  @override
  String toString() => 'InjectedWriteException: $message';
}

abstract interface class WriteFaultInjector {
  WriteAttempt beginWrite();
}

abstract interface class WriteAttempt {
  void checkpoint(String name);
}

class NoFault implements WriteFaultInjector {
  const NoFault();

  @override
  WriteAttempt beginWrite() => const _NoOpWriteAttempt();
}

class _NoOpWriteAttempt implements WriteAttempt {
  const _NoOpWriteAttempt();

  @override
  void checkpoint(String name) {}
}

class ConfiguredFault implements WriteFaultInjector {
  final bool failWrites;
  final int failFirstWrites;
  int _failuresLeft;

  ConfiguredFault({
    this.failWrites = AppConfig.failWrites,
    this.failFirstWrites = AppConfig.failFirstWrites,
  }) : _failuresLeft = failFirstWrites;

  @override
  WriteAttempt beginWrite() {
    return _ConfiguredWriteAttempt(
      failWrites: failWrites,
      decrementFailure: () {
        if (_failuresLeft > 0) {
          _failuresLeft--;
          return true;
        }
        return false;
      },
    );
  }
}

class _ConfiguredWriteAttempt implements WriteAttempt {
  final bool failWrites;
  final bool Function() decrementFailure;
  bool? _shouldFail;

  _ConfiguredWriteAttempt({
    required this.failWrites,
    required this.decrementFailure,
  });

  @override
  void checkpoint(String name) {
    if (_shouldFail == null) {
      if (failWrites) {
        _shouldFail = true;
      } else {
        _shouldFail = decrementFailure();
      }
    }
    if (_shouldFail!) {
      throw InjectedWriteException('Simulated write failure at $name');
    }
  }
}
