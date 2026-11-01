import 'package:flutter/widgets.dart';

/// Route chứa [context] có đang ở trên cùng không, xét cả các Navigator lồng nhau:
/// màn trong tab có thể là route trên cùng của Navigator của tab nhưng vẫn bị một
/// màn ở Navigator gốc đè lên.
bool isRouteChainCurrent(BuildContext context) {
  var route = ModalRoute.of(context);
  while (route != null) {
    if (!route.isCurrent) return false;
    final navigatorContext = route.navigator?.context;
    route = navigatorContext == null ? null : ModalRoute.of(navigatorContext);
  }
  return true;
}
