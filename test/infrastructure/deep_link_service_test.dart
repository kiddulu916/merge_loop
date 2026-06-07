import 'package:flutter_test/flutter_test.dart';
import 'package:merge_loop/infrastructure/deep_link_service.dart';

void main() {
  group('DeepLinkService.parseInviteCode', () {
    test('parses custom scheme mergeloop://invite/<code>', () {
      expect(
        DeepLinkService.parseInviteCodeString('mergeloop://invite/ABCD2345'),
        'ABCD2345',
      );
    });

    test('parses https fallback', () {
      expect(
        DeepLinkService.parseInviteCodeString(
            'https://mergeloop.app/invite/WXYZ7654'),
        'WXYZ7654',
      );
    });

    test('returns null for non-invite custom-scheme links', () {
      expect(
        DeepLinkService.parseInviteCodeString('mergeloop://other/thing'),
        isNull,
      );
    });

    test('returns null for unrelated https links', () {
      expect(
        DeepLinkService.parseInviteCodeString('https://example.com/foo/bar'),
        isNull,
      );
    });

    test('returns null when code segment is missing', () {
      expect(
          DeepLinkService.parseInviteCodeString('mergeloop://invite/'), isNull);
      expect(DeepLinkService.parseInviteCodeString('mergeloop://invite'),
          isNull);
    });

    test('returns null for garbage', () {
      expect(DeepLinkService.parseInviteCodeString('not a uri at all ::: '),
          isNull);
    });
  });
}
