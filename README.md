# idle_flutter

A Flutter adapter for **idle / incremental games**, built on top of  
[`idle_core`](https://pub.dev/packages/idle_core) and  
[`idle_save`](https://pub.dev/packages/idle_save).

> Automatic lifecycle handling, safe persistence, and offline progress — without footguns.

---

## ✨ What is this?

`idle_flutter` connects a **pure Dart idle engine** to **Flutter apps** safely and ergonomically.

It solves the most common (and painful) problems in idle game development:

- Forgetting to save when the app goes to background
- Applying offline progress incorrectly
- Duplicated saves and race conditions
- Rewriting lifecycle + storage glue for every project

Instead, you get:

- Automatic Flutter lifecycle integration
- Safe save/load with debouncing and migration
- Deterministic offline progress replay
- Simple UI binding via controller + builder

---

## 🧠 Design Philosophy

`idle_flutter` follows a strict layered architecture:

```
idle_core   →   idle_save   →   idle_flutter
(pure Dart)     (pure Dart)     (Flutter only)
```

- **idle_core**  
  Deterministic idle engine (ticks, reducers, offline replay)

- **idle_save**  
  Versioned persistence, migration, backup, validation

- **idle_flutter** (this package)  
  Flutter lifecycle + storage adapters + UI bindings

Your game logic stays testable, portable, and framework-agnostic.

---

## 🚀 Features

### Automatic App Lifecycle Handling

- Listens to `resumed / paused / inactive / detached`
- Saves safely when the app goes to background
- Applies offline progress when returning

### Safe Persistence

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
```

---

## 🛠️ Basic Usage

### 1️⃣ Define your state

```dart
class GameState extends IdleState {
  final int gold;
  final int rate;

  const GameState({required this.gold, required this.rate});

  GameState copyWith({int? gold, int? rate}) {
    return GameState(
      gold: gold ?? this.gold,
      rate: rate ?? this.rate,
    );
  }

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
```

---

### 2️⃣ Define reducer and actions

```dart
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
```

---

### 3️⃣ Create the controller

```dart
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
```

---

## 🧩 UI Binding

```dart
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
```

---

## 📄 License

MIT
