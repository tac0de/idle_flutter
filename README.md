# idle_flutter

A Flutter adapter for **idle / incremental games**, built on top of  
[`idle_core`](https://pub.dev/packages/idle_core) and  
[`idle_save`](https://pub.dev/packages/idle_save).

> **Automatic lifecycle handling, safe persistence, and offline progress — without footguns.**

---

## ✨ What is this?

`idle_flutter` connects a **pure Dart idle engine** to **Flutter apps** safely and ergonomically.

It solves the most common (and painful) problems in idle game development:

- ❌ Forgetting to save on app background
- ❌ Applying offline progress incorrectly
- ❌ Duplicated saves, race conditions, corrupted state
- ❌ Manually wiring lifecycle + storage + engine every time

Instead, you get:

- ✅ Automatic Flutter lifecycle integration
- ✅ Safe save/load with debouncing and migration
- ✅ Deterministic offline progress replay
- ✅ Simple UI binding via controller + builder

---

## 🧠 Design Philosophy

`idle_flutter` follows a strict layered architecture:

idle_core → idle_save → idle_flutter
(pure Dart) (pure Dart) (Flutter only)

yaml
Copy code

- **idle_core**  
  Deterministic idle engine (ticks, reducers, offline replay)

- **idle_save**  
  Versioned persistence, migration, backup, checks

- **idle_flutter** (this package)  
  Flutter lifecycle + storage adapters + UI bindings

This keeps your game logic testable, portable, and framework-agnostic.

---

## 🚀 Features

### Automatic App Lifecycle Handling

- Listens to `resumed / paused / inactive / detached`
- Saves safely when the app goes to background
- Applies offline progress when returning

### Safe Persistence (No Footguns)

- Debounced autosave
- Optional backup store
- Migration support via `Migrator`
- No concurrent save/load races

### Offline Progress Done Right

- Uses `lastSeenMs` contract from `idle_core`
- Applies bounded offline ticks
- Deterministic and replayable

### Flutter-Friendly API

- `IdleFlutterController` (ChangeNotifier)
- `IdleBuilder` widget for UI binding
- SharedPreferences & file storage helpers

---

## 📦 Installation

```yaml
dependencies:
  idle_flutter: ^0.1.0
🛠️ Basic Usage
1️⃣ Define your state
dart
Copy code
class GameState extends IdleState {
  final int gold;
  final int rate;

  const GameState({required this.gold, required this.rate});

  @override
  Map<String, dynamic> toJson() => {
    'gold': gold,
    'rate': rate,
  };

  static GameState fromJson(Map<String, dynamic> json) {
    return GameState(
      gold: json['gold'] as int? ?? 0,
      rate: json['rate'] as int? ?? 1,
    );
  }
}
2️⃣ Define reducer and actions
dart
Copy code
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
3️⃣ Create the controller
dart
Copy code
final controller = IdleFlutterController<GameState>(
  config: IdleConfig<GameState>(
    dtMs: 1000,
    maxOfflineMs: 24 * 60 * 60 * 1000,
    maxTicksTotal: 10_000,
  ),
  reducer: reducer,
  initialState: const GameState(gold: 0, rate: 1),
  stateDecoder: GameState.fromJson,
  store: SharedPreferencesStore('idle_save'),
  migrator: Migrator(latestVersion: 1),
);

await controller.start();
That’s it.

Saves automatically

Handles app lifecycle

Applies offline progress

Notifies UI

🧩 UI Binding
Using IdleBuilder
dart
Copy code
IdleBuilder<GameState>(
  controller: controller,
  builder: (context, c) {
    return Column(
      children: [
        Text('Gold: ${c.state.gold}'),
        Text('Rate: ${c.state.rate}/sec'),
        ElevatedButton(
          onPressed: () => c.dispatch(const UpgradeRate(1)),
          child: const Text('Upgrade'),
        ),
      ],
    );
  },
);
💾 Storage Options
SharedPreferences (simple & lightweight)
dart
Copy code
SharedPreferencesStore('idle_save_key')
File storage (via path_provider)
dart
Copy code
final store = await PathFileStore.documents('idle_save.json');
You can also implement your own SaveStore easily.

🔄 Migration Support
dart
Copy code
final migrator = Migrator(
  latestVersion: 2,
  steps: {
    1: (payload) {
      payload['rate'] ??= 1;
      return payload;
    },
  },
);
Migrations are automatically applied on startup.

🧪 Testing Friendly
Deterministic engine

Inject custom nowMs() for time control

In-memory SaveStore for fast tests

Flutter lifecycle fully testable

See test/idle_flutter_test.dart for examples.

❓ When should I use this?
Use idle_flutter if you want:

Idle / incremental games

Offline progress

Deterministic simulation

Safe persistence

Minimal boilerplate

If you only need a timer or animation loop, this package is probably overkill.

📚 Related Packages
idle_core – Core idle engine (pure Dart)

idle_save – Versioned save system (pure Dart)

🤝 Contributing
Issues, ideas, and PRs are welcome.

This package is opinionated by design:
it prefers safety and correctness over flexibility.

📄 License
MIT
```
