import 'dart:developer' as dev;
import 'dart:io' show Platform;

import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';

/// Global hotkey service for ClawDE desktop.
///
/// Registers a system-wide "quick summon" shortcut that fires even when
/// the ClawDE window is hidden or in the background:
///   - macOS: ⌘⇧Space
///   - Windows / Linux: Ctrl+Shift+Space
///
/// Usage:
/// ```dart
/// await HotkeyService.instance.init(onActivated: () {
///   windowManager.show();
///   windowManager.focus();
/// });
/// ```
class HotkeyService {
  HotkeyService._();
  static final HotkeyService instance = HotkeyService._();

  HotKey? _summonKey;

  /// Register the global summon hotkey.
  ///
  /// [onActivated] is called on the main isolate each time the hotkey fires.
  /// Calling [init] a second time is a no-op; call [dispose] first to
  /// re-register with a different callback.
  Future<void> init({required VoidCallback onActivated}) async {
    if (_summonKey != null) return;

    await hotKeyManager.unregisterAll();

    final modifiers = Platform.isMacOS
        ? [HotKeyModifier.meta, HotKeyModifier.shift]
        : [HotKeyModifier.control, HotKeyModifier.shift];

    _summonKey = HotKey(
      key: LogicalKeyboardKey.space,
      modifiers: modifiers,
      scope: HotKeyScope.system,
    );

    await hotKeyManager.register(
      _summonKey!,
      keyDownHandler: (_) => onActivated(),
    );

    dev.log(
      'summon hotkey registered (${Platform.isMacOS ? '⌘⇧Space' : 'Ctrl+Shift+Space'})',
      name: 'HotkeyService',
    );
  }

  /// Unregister all hotkeys managed by this service.
  ///
  /// Call during app disposal to release the system-level hook.
  Future<void> dispose() async {
    if (_summonKey != null) {
      await hotKeyManager.unregister(_summonKey!);
      _summonKey = null;
    }
    dev.log('hotkeys unregistered', name: 'HotkeyService');
  }
}
