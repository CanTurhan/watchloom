import 'package:flutter_test/flutter_test.dart';
import 'package:watchloom/features/community/domain/community_models.dart';
import 'package:watchloom/features/community/domain/community_policy.dart';

void main() {
  test('public identity requires explicit handle/nickname, never an email', () {
    final profile = CommunityPolicy.identity(
      handle: '  series_fan ',
      displayMode: CommunityDisplayMode.handle,
    );
    expect(profile.publicName, '@series_fan');
    expect(
      CommunityPolicy.identity(
        handle: 'series_fan',
        nickname: 'Dizi Dostu',
        displayMode: CommunityDisplayMode.nickname,
      ).publicName,
      'Dizi Dostu',
    );
    for (final handle in ['person@example.com', 'a', 'person.name', '😀😀😀']) {
      expect(
        () => CommunityPolicy.identity(
          handle: handle,
          displayMode: CommunityDisplayMode.handle,
        ),
        throwsA(isA<CommunityException>()),
      );
    }
    expect(
      () => CommunityPolicy.identity(
        handle: 'series_fan',
        displayMode: CommunityDisplayMode.nickname,
      ),
      throwsA(isA<CommunityException>()),
    );
  });
  test(
    'international text, emoji, spoiler discussion and normal words compose',
    () {
      for (final body in [
        'Final harikaydı 🎬',
        'Great finale!',
        '素晴らしい物語',
        'Shiitake soup scene',
        'Birinci satır\nİkinci satır',
        'Cafe\u0301',
      ]) {
        expect(CommunityPolicy.body(body), body);
      }
    },
  );
  test(
    'known abuse, contacts and invisible format/control points are rejected',
    () {
      for (final body in [
        'fuck you',
        's1ktir',
        'mail@example.com',
        'www.example.com',
        'https://example.com',
        'safe\u200Bhidden',
        'safe\u202Ehidden',
        'safe\u0000hidden',
        '',
        ' ' * 4,
        'a' * 1201,
      ]) {
        expect(
          () => CommunityPolicy.body(body),
          throwsA(isA<CommunityException>()),
          reason: body,
        );
      }
    },
  );
  test('only stable TVMaze series keys are accepted for this release', () {
    CommunityPolicy.content('tvmaze:show:123', CommunityContentKind.series);
    for (final key in [
      '123',
      'local:uuid',
      'tvmaze:show:0',
      'tvmaze:show:123/other',
    ]) {
      expect(
        () => CommunityPolicy.content(key, CommunityContentKind.series),
        throwsA(isA<CommunityException>()),
      );
    }
    expect(
      () => CommunityPolicy.content(
        'manual:movie:abc',
        CommunityContentKind.movie,
      ),
      throwsA(isA<CommunityException>()),
    );
  });
}
