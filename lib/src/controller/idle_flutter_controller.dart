import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:idle_core/idle_core.dart';
import 'package:idle_save/idle_save.dart';

/// idle_core 계약 그대로: state.toJson + lastSeenMs만 저장 :contentReference[oaicite:2]{index=2}
@immutable
class IdleSaveBlob<S extends IdleState> {
  final S state;
  final int lastSeenMs;

  const IdleSaveBlob({required this.state, required this.lastSeenMs});

  Map<String, dynamic> toJson() => {
    'state': state.toJson(),
    'lastSeenMs': lastSeenMs,
  };

  static IdleSaveBlob<S> fromJson<S extends IdleState>({
    required Map<String, dynamic> json,
    required S Function(Map<String, dynamic>) stateDecoder,
  }) {
    final stateJson = Map<String, dynamic>.from(json['state'] as Map);
    final lastSeenMs = (json['lastSeenMs'] as int?) ?? 0;
    return IdleSaveBlob(state: stateDecoder(stateJson), lastSeenMs: lastSeenMs);
  }
}

typedef NowMs = int Function();

class IdleFlutterController<S extends IdleState> extends ChangeNotifier
    with WidgetsBindingObserver {
  IdleFlutterController({
    required IdleConfig<S> config,
    required IdleReducer<S> reducer,
    required S initialState,
    required S Function(Map<String, dynamic>) stateDecoder,
    required SaveStore store,
    SaveStore? backupStore,
    SaveCodec codec = const JsonSaveCodec(),
    required Migrator migrator,
    NowMs? nowMs,
    Duration? autosaveDebounce,
    bool startTickingImmediately = true,
  }) : _config = config,
       _reducer = reducer,
       _initialState = initialState,
       _stateDecoder = stateDecoder,
       _nowMs = nowMs ?? (() => DateTime.now().millisecondsSinceEpoch),
       _autosaveDebounce = autosaveDebounce ?? const Duration(seconds: 1) {
    _saveManager = SaveManager<IdleSaveBlob<S>>(
      store: store,
      backupStore: backupStore,
      codec: codec,
      migrator: migrator,
      encoder: (blob) => blob.toJson(),
      decoder: (payload) =>
          IdleSaveBlob.fromJson<S>(json: payload, stateDecoder: _stateDecoder),
    ); // SaveManager API :contentReference[oaicite:3]{index=3}

    _engine = IdleEngine<S>(
      config: _config,
      reducer: _reducer,
      state: _initialState,
    ); // IdleEngine API :contentReference[oaicite:4]{index=4}

    if (startTickingImmediately) {
      start();
    }
  }

  final IdleConfig<S> _config;
  final IdleReducer<S> _reducer;
  final S _initialState;
  final S Function(Map<String, dynamic>) _stateDecoder;

  late SaveManager<IdleSaveBlob<S>> _saveManager;
  late IdleEngine<S> _engine;

  final NowMs _nowMs;
  final Duration _autosaveDebounce;

  Timer? _tickTimer;
  Timer? _saveTimer;

  int _lastSeenMs = 0;
  bool _started = false;

  /// ---- Public getters ----
  S get state => _engine.state;
  int get lastSeenMs => _lastSeenMs;
  bool get started => _started;

  /// ---- Lifecycle wiring ----
  Future<void> start() async {
    if (_started) return;
    _started = true;

    WidgetsBinding.instance.addObserver(this);

    // 1) Load + migrate, if exists :contentReference[oaicite:5]{index=5}
    final loaded = await _saveManager.migrateIfNeeded();
    if (loaded case LoadSuccess<IdleSaveBlob<S>>(:final value)) {
      _restoreFromBlob(value);
    } else {
      // no save or failure: start fresh
      _lastSeenMs = _nowMs();
      await _persistNow();
    }

    // 2) Start realtime ticking while app is active
    _startTickLoop();

    notifyListeners();
  }

  @override
  Future<void> dispose() async {
    WidgetsBinding.instance.removeObserver(this);
    _tickTimer?.cancel();
    _saveTimer?.cancel();
    // best-effort final save
    await _persistNow();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 여기서 실수 방지 UX가 생김: paused 때 lastSeen 저장 + save
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _handlePauseLike();
    } else if (state == AppLifecycleState.resumed) {
      _handleResume();
    }
  }

  /// ---- Game actions ----
  void dispatch(IdleAction action) {
    _engine.dispatch(action); // :contentReference[oaicite:6]{index=6}
    _scheduleAutosave();
    notifyListeners();
  }

  /// 수동 tick도 제공 (테스트/특수상황)
  void tick({int count = 1}) {
    _engine.tick(count: count); // :contentReference[oaicite:7]{index=7}
    _scheduleAutosave();
    notifyListeners();
  }

  /// ---- Internals ----
  void _restoreFromBlob(IdleSaveBlob<S> blob) {
    // IdleEngine.state는 setter가 없으니 새로 만든다 :contentReference[oaicite:8]{index=8}
    _engine = IdleEngine<S>(
      config: _config,
      reducer: _reducer,
      state: blob.state,
    );

    final now = _nowMs();

    // offline 반영 (applyOfflineWindow) :contentReference[oaicite:9]{index=9}
    final offline = _engine.applyOfflineWindow(
      lastSeenMs: blob.lastSeenMs,
      nowMs: now,
    );

    _engine = IdleEngine<S>(
      config: _config,
      reducer: _reducer,
      state: offline.state,
    );

    _lastSeenMs = offline.nextLastSeenMs(blob.lastSeenMs);
  }

  void _startTickLoop() {
    _tickTimer?.cancel();
    final dt = Duration(milliseconds: _config.dtMs);
    _tickTimer = Timer.periodic(dt, (_) {
      _engine.tick(count: 1);
      _scheduleAutosave();
      notifyListeners();
    });
  }

  void _handlePauseLike() {
    // “앱이 멈추는 순간”의 now를 lastSeen으로 기록
    _lastSeenMs = _nowMs();
    _scheduleAutosave(flushSoon: true);
  }

  void _handleResume() {
    final now = _nowMs();
    final offline = _engine.applyOfflineWindow(
      lastSeenMs: _lastSeenMs,
      nowMs: now,
    ); // :contentReference[oaicite:10]{index=10}

    _engine = IdleEngine<S>(
      config: _config,
      reducer: _reducer,
      state: offline.state,
    );
    _lastSeenMs = offline.nextLastSeenMs(_lastSeenMs);

    _scheduleAutosave(flushSoon: true);
    notifyListeners();
  }

  void _scheduleAutosave({bool flushSoon = false}) {
    _saveTimer?.cancel();
    _saveTimer = Timer(flushSoon ? Duration.zero : _autosaveDebounce, () async {
      await _persistNow();
    });
  }

  Future<void> _persistNow() async {
    final blob = IdleSaveBlob<S>(state: _engine.state, lastSeenMs: _lastSeenMs);
    await _saveManager.save(blob); // :contentReference[oaicite:11]{index=11}
  }
}
