import 'package:flutter/cupertino.dart';

// Database constants
const String kBoxDatabase = 'database';

// Color constants - Grape Purple
const Color kPrimary = Color(0xFF6F2DA8);

// Dialog helper — respects current app theme
Future<T?> showThemedDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) {
  return showCupertinoDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: builder,
  );
}

// Dialog helper — always light, purple primary (for signin/signup pages)
Future<T?> showLightDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) {
  return showCupertinoDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (ctx) => CupertinoTheme(
      data: const CupertinoThemeData(
        brightness: Brightness.light,
        primaryColor: kPrimary,
        textTheme: CupertinoTextThemeData(primaryColor: kPrimary),
      ),
      child: Builder(builder: builder),
    ),
  );
}

