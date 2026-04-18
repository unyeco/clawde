// deep_link_test.dart — Unit tests for parseDesktopDeepLink.
//
// Tests cover all five URI variants handled by the desktop deep link service:
// session, file, folder, command, and unknown/malformed.

import 'package:flutter_test/flutter_test.dart';
import 'package:clawde/features/deep_link/deep_link_service.dart';

void main() {
  group('parseDesktopDeepLink', () {
    test('parses session URI', () {
      final target = parseDesktopDeepLink(
        Uri.parse('clawde://session/abc123'),
      );
      expect(target, isA<SessionTarget>());
      expect((target as SessionTarget).sessionId, 'abc123');
    });

    test('parses file URI', () {
      final target = parseDesktopDeepLink(
        Uri.parse('clawde://file?path=/home/user/main.dart'),
      );
      expect(target, isA<FileTarget>());
      expect((target as FileTarget).path, '/home/user/main.dart');
    });

    test('parses folder URI', () {
      final target = parseDesktopDeepLink(
        Uri.parse('clawde://folder?path=/home/user/my-project'),
      );
      expect(target, isA<FolderTarget>());
      expect((target as FolderTarget).path, '/home/user/my-project');
    });

    test('parses command URI', () {
      final target = parseDesktopDeepLink(
        Uri.parse('clawde://command?name=new_session'),
      );
      expect(target, isA<CommandTarget>());
      expect((target as CommandTarget).name, 'new_session');
    });

    test('parses command URI — search', () {
      final target = parseDesktopDeepLink(
        Uri.parse('clawde://command?name=search'),
      );
      expect(target, isA<CommandTarget>());
      expect((target as CommandTarget).name, 'search');
    });

    test('parses command URI — settings', () {
      final target = parseDesktopDeepLink(
        Uri.parse('clawde://command?name=settings'),
      );
      expect(target, isA<CommandTarget>());
      expect((target as CommandTarget).name, 'settings');
    });

    test('returns null for unknown host', () {
      final target = parseDesktopDeepLink(
        Uri.parse('clawde://unknown/something'),
      );
      expect(target, isNull);
    });

    test('returns null for wrong scheme', () {
      final target = parseDesktopDeepLink(
        Uri.parse('https://clawde.io/session/abc'),
      );
      expect(target, isNull);
    });

    test('returns null for session URI with no id', () {
      final target = parseDesktopDeepLink(
        Uri.parse('clawde://session'),
      );
      expect(target, isNull);
    });

    test('returns null for file URI with missing path param', () {
      final target = parseDesktopDeepLink(
        Uri.parse('clawde://file'),
      );
      expect(target, isNull);
    });

    test('returns null for folder URI with missing path param', () {
      final target = parseDesktopDeepLink(
        Uri.parse('clawde://folder'),
      );
      expect(target, isNull);
    });

    test('returns null for command URI with missing name param', () {
      final target = parseDesktopDeepLink(
        Uri.parse('clawde://command'),
      );
      expect(target, isNull);
    });

    test('preserves spaces and special characters in file path', () {
      final target = parseDesktopDeepLink(
        Uri.parse(
          'clawde://file?path=${Uri.encodeComponent('/home/user/my project/main.dart')}',
        ),
      );
      expect(target, isA<FileTarget>());
      expect((target as FileTarget).path, '/home/user/my project/main.dart');
    });
  });
}
