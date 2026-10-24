import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

const MethodChannel _channel = MethodChannel('sixam/fullscreen');

Future<void> toggleFullscreen() async {
  try {
    final isFull = await _channel.invokeMethod<bool>('isFullScreen') ?? false;
    await _channel.invokeMethod<void>('setFullScreen', !isFull);
  } catch (_) {
    return;
  }
}

Future<void> exitFullscreen() async {
  try {
    await _channel.invokeMethod<void>('setFullScreen', false);
  } catch (_) {
    return;
  }
}

Map<ShortcutActivator, VoidCallback> fullscreenShortcuts() => {
  const SingleActivator(LogicalKeyboardKey.keyF): toggleFullscreen,
  const SingleActivator(LogicalKeyboardKey.escape): exitFullscreen,
};
