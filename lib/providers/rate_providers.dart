import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/rate_table.dart';
import '../services/demo_data.dart';

/// The exchange-rate table.
///
/// Read straight from the bundle with no `JsonStore` behind it, unlike every
/// other entity here: rates are reference data, not state. The owner does
/// not edit them, so there is nothing to persist, and seeding them into
/// storage would only create a stale copy to go wrong. Point this at an API
/// and the screens do not change.
final rateTableProvider = FutureProvider<RateTable>(
    (ref) async => RateTable.fromJson(await DemoData.loadJson('rates.json')));
