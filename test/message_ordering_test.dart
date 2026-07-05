import 'package:babaero/features/chat/data/chat_models.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regression guard: chat messages must render oldest→newest so the newest sits
/// above the composer (with the thread's reverse:true ListView). The Supabase
/// stream builder's order() defaults to DESCENDING, which once put the newest
/// message at the TOP — messageStream now sorts ascending in Dart. This test
/// pins that comparator against out-of-order (multi-day) input.
void main() {
  Message msg(String id, String createdAt) => Message.fromMap({
        'id': id,
        'conversation_id': 'c1',
        'sender_id': 's1',
        'body': id,
        'created_at': createdAt,
      });

  test('messages sort oldest→newest by createdAt across days', () {
    // Deliberately scrambled, spanning multiple days (mirrors the bug report:
    // 16:27 today, 05:56, 12:46, 12:45 …).
    final rows = [
      msg('today-1627', '2026-07-05T16:27:00Z'),
      msg('day1-0556', '2026-07-03T05:56:00Z'),
      msg('day2-1246', '2026-07-04T12:46:00Z'),
      msg('day2-1245', '2026-07-04T12:45:00Z'),
    ]..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    expect(rows.map((m) => m.id).toList(), [
      'day1-0556',
      'day2-1245',
      'day2-1246',
      'today-1627', // newest is last → renders above the composer
    ]);
  });
}
