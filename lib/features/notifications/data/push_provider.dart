import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'push_repository.dart';

final pushRepositoryProvider =
    Provider<PushRepository>((_) => PushRepository());
