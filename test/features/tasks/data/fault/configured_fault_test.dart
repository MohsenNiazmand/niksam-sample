import 'package:flutter_test/flutter_test.dart';
import 'package:niksam/features/tasks/data/fault/write_fault_injector.dart';

void main() {
  group('ConfiguredFault', () {
    test('defaults (false, 0) never throw', () {
      final fault = ConfiguredFault(failWrites: false, failFirstWrites: 0);
      final attempt = fault.beginWrite();
      expect(() => attempt.checkpoint('test'), returnsNormally);
    });

    test('failWrites: true throws at first checkpoint of every attempt', () {
      final fault = ConfiguredFault(failWrites: true, failFirstWrites: 0);
      final attempt1 = fault.beginWrite();
      expect(
        () => attempt1.checkpoint('checkpoint_1'),
        throwsA(isA<InjectedWriteException>()),
      );

      final attempt2 = fault.beginWrite();
      expect(
        () => attempt2.checkpoint('checkpoint_1'),
        throwsA(isA<InjectedWriteException>()),
      );
    });

    test(
      'failFirstWrites: 2, 5 sequential attempts -> first 2 fail, rest pass',
      () {
        final fault = ConfiguredFault(failWrites: false, failFirstWrites: 2);

        // Attempt 1: should fail
        final a1 = fault.beginWrite();
        expect(
          () => a1.checkpoint('cp'),
          throwsA(isA<InjectedWriteException>()),
        );

        // Attempt 2: should fail
        final a2 = fault.beginWrite();
        expect(
          () => a2.checkpoint('cp'),
          throwsA(isA<InjectedWriteException>()),
        );

        // Attempt 3: should pass
        final a3 = fault.beginWrite();
        expect(() => a3.checkpoint('cp'), returnsNormally);

        // Attempt 4: should pass
        final a4 = fault.beginWrite();
        expect(() => a4.checkpoint('cp'), returnsNormally);

        // Attempt 5: should pass
        final a5 = fault.beginWrite();
        expect(() => a5.checkpoint('cp'), returnsNormally);
      },
    );

    test('failFirstWrites: 1, interleaved attempts -> exactly 1 fails', () {
      final fault = ConfiguredFault(failWrites: false, failFirstWrites: 1);

      // Two attempts started before either reaches a checkpoint
      final a1 = fault.beginWrite();
      final a2 = fault.beginWrite();

      // a1 reaches checkpoint first -> fails
      expect(() => a1.checkpoint('cp'), throwsA(isA<InjectedWriteException>()));

      // a2 reaches checkpoint -> passes (since budget 1 was consumed by a1)
      expect(() => a2.checkpoint('cp'), returnsNormally);
    });

    test('attempt that never reaches checkpoint does not consume budget', () {
      final fault = ConfiguredFault(failWrites: false, failFirstWrites: 1);

      // Attempt 1 starts but never calls checkpoint (no-op)
      final a1 = fault.beginWrite();
      // ignore: unused_local_variable
      final _ = a1;

      // Attempt 2 calls checkpoint -> should fail because budget 1 is still intact
      final a2 = fault.beginWrite();
      expect(() => a2.checkpoint('cp'), throwsA(isA<InjectedWriteException>()));
    });
  });
}
