import 'package:flutter/material.dart';
import 'package:idle_core/idle_core.dart';
import 'package:idle_flutter/idle_flutter.dart';
import 'package:idle_save/idle_save.dart';

void main() {
  runApp(const MyApp());
}

class GameState extends IdleState {
  final int gold;
  final int rate;

  const GameState({required this.gold, required this.rate});

  GameState copyWith({int? gold, int? rate}) =>
      GameState(gold: gold ?? this.gold, rate: rate ?? this.rate);

  @override
  Map<String, dynamic> toJson() => {'gold': gold, 'rate': rate};

  static GameState fromJson(Map<String, dynamic> json) => GameState(
    gold: json['gold'] as int? ?? 0,
    rate: json['rate'] as int? ?? 1,
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

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  IdleFlutterController<GameState>? controller;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final store = SharedPreferencesStore('idle_demo_save');

    final c = IdleFlutterController<GameState>(
      config: IdleConfig<GameState>(
        dtMs: 1000,
        maxOfflineMs: 24 * 60 * 60 * 1000,
        maxTicksTotal: 10_000,
      ),
      reducer: reducer,
      initialState: const GameState(gold: 0, rate: 1),
      stateDecoder: GameState.fromJson,
      store: store,
      migrator: Migrator(latestVersion: 1),
      autosaveDebounce: const Duration(milliseconds: 500),
    );

    await c.start();

    setState(() => controller = c);
  }

  @override
  void dispose() {
    final c = controller;
    controller = null;
    c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('idle_flutter example')),
        body: c == null
            ? const Center(child: CircularProgressIndicator())
            : IdleBuilder<GameState>(
                controller: c,
                builder: (context, c) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Gold: ${c.state.gold}',
                          style: const TextStyle(fontSize: 28),
                        ),
                        const SizedBox(height: 8),
                        Text('Rate: ${c.state.rate}/sec'),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => c.dispatch(const UpgradeRate(1)),
                          child: const Text('Upgrade +1 rate'),
                        ),
                        const SizedBox(height: 16),
                        Text('lastSeenMs: ${c.lastSeenMs}'),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}
