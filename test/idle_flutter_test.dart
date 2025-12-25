// File: test/idle_flutter_test.dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:idle_core/idle_core.dart';
import 'package:idle_flutter/idle_flutter.dart';
import 'package:idle_save/idle_save.dart';

/// In-memory SaveStore for tests.
class MemoryStore extends SaveStore {
  String? _data;

  @override
  Future<String?> read() async => _data;

  @override
  Future<void> write(String data) async {
    _data = data;
  }

  @override
  Future<void> clear() async {
    _data = null;
  }
}

/// Simple state for tests.
class GameState extends IdleState {
  final int gold;
  final int rate;

  const GameState({required this.gold, required this.rate});

  GameState copyWith({int? gold, int? rate}) =>
      GameState(gold: gold ?? this.gold, rate: rate ?? this.rate);

  @override
  Map<String, dynamic> toJson() => {'gold': gold, 'rate': rate};

  static GameState fromJson(Map<String, dynamic> json) => GameState(
    gold: (json['gold'] as num?)?.toInt() ?? 0,
    rate: (json['rate'] as num?)?.toInt() ?? 1,
  );
}

class UpgradeRate extends IdleAction {
  final int delta;
  const UpgradeRate(this.delta);
}

GameState reducer(GameState state, IdleAction action) {
  if (action is IdleTickAction) {
    return state.copyWith(gold: state.gold + state.rate);
  }
  if (action is UpgradeRate) {
    return state.copyWith(rate: state.rate + action.delta);
  }
  return state;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('IdleFlutterController', () {
    test('start() persists an initial save when no save exists', () async {
      final store = MemoryStore();

      final c = IdleFlutterController<GameState>(
        config: IdleConfig<GameState>(
          dtMs: 1000,
          maxOfflineMs: 60 * 60 * 1000,
          maxTicksTotal: 10_000,
        ),
        reducer: reducer,
        initialState: const GameState(gold: 0, rate: 1),
        stateDecoder: GameState.fromJson,
        store: store,
        migrator: Migrator(latestVersion: 1),
        // deterministic time
        nowMs: () => 1_000_000,
        startTickingImmediately: false,
      );

      await c.start();

      final raw = await store.read();
      expect(
        raw,
        isNotNull,
        reason: 'Expected controller to write an initial save.',
      );

      // The SaveManager stores a JSON string with a payload that contains our blob fields.
      // We avoid depending on internal envelope layout by searching for our keys.
      final decoded = jsonDecode(raw!) as Map<String, dynamic>;
      final encodedString = jsonEncode(decoded);
      expect(encodedString.contains('lastSeenMs'), isTrue);
      expect(encodedString.contains('state'), isTrue);

      await c.dispose();
    });

    test('dispatch() updates state and schedules a save', () async {
      final store = MemoryStore();

      int now = 10_000;
      final c = IdleFlutterController<GameState>(
        config: IdleConfig<GameState>(
          dtMs: 1000,
          maxOfflineMs: 60_000,
          maxTicksTotal: 10_000,
        ),
        reducer: reducer,
        initialState: const GameState(gold: 0, rate: 1),
        stateDecoder: GameState.fromJson,
        store: store,
        migrator: Migrator(latestVersion: 1),
        nowMs: () => now,
        autosaveDebounce: const Duration(milliseconds: 10),
        startTickingImmediately: false,
      );

      await c.start();
      final before = await store.read();

      c.dispatch(const UpgradeRate(2));
      expect(c.state.rate, 3);

      // Wait a bit so debounce save fires.
      await Future<void>.delayed(const Duration(milliseconds: 30));
      final after = await store.read();

      expect(
        after,
        isNot(equals(before)),
        reason: 'Expected a new save after dispatch().',
      );
      await c.dispose();
    });

    testWidgets('paused->resumed applies offline progress using lastSeenMs', (
      tester,
    ) async {
      final store = MemoryStore();

      int now = 1000;
      final c = IdleFlutterController<GameState>(
        config: IdleConfig<GameState>(
          dtMs: 1000,
          maxOfflineMs: 60 * 60 * 1000,
          maxTicksTotal: 10_000,
        ),
        reducer: reducer,
        initialState: const GameState(gold: 0, rate: 5),
        stateDecoder: GameState.fromJson,
        store: store,
        migrator: Migrator(latestVersion: 1),
        nowMs: () => now,
        startTickingImmediately: false,
      );

      await c.start();

      // Simulate app going to background: should capture lastSeenMs = now.
      final binding = TestWidgetsFlutterBinding.instance;
      binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);

      // "Time passes" while app is paused.
      now = 6000; // 5 seconds later -> expected 5 ticks at dtMs=1000

      // Resume: should apply offline window and increase gold by rate * ticks.
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);

      // give microtask queue a moment
      await tester.pump();

      expect(
        c.state.gold,
        25,
        reason: '5 ticks * rate(5) = 25 gold expected from offline.',
      );

      await c.dispose();
    });
  });
}
