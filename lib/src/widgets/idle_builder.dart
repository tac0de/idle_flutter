import 'package:flutter/widgets.dart';
import 'package:idle_core/idle_core.dart';

import '../controller/idle_flutter_controller.dart';

typedef IdleWidgetBuilder<S extends IdleState> =
    Widget Function(BuildContext context, IdleFlutterController<S> controller);

class IdleBuilder<S extends IdleState> extends StatelessWidget {
  const IdleBuilder({
    super.key,
    required this.controller,
    required this.builder,
  });

  final IdleFlutterController<S> controller;
  final IdleWidgetBuilder<S> builder;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => builder(context, controller),
    );
  }
}
