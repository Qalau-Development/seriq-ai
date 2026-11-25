import 'package:flutter/foundation.dart';

import '../core/exercises.dart';
import 'api_client.dart';

// catalog — каталог упражнений с сервера; null, пока ответ не пришёл
final catalog = ValueNotifier<List<CatalogEntry>?>(null);

// refreshCatalog — запрашивает каталог заново; при ошибке сервера в каталог попадает запасной список
Future<void> refreshCatalog([ApiClient? api]) async {
  final entries = await (api ?? ApiClient()).fetchCatalog();
  catalog.value = entries;
}
