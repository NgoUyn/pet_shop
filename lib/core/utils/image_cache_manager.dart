import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Custom disk cache manager for pet shop images.
/// Caches images for 30 days, max 500 files, to reduce network usage.
class PetShopCacheManager extends CacheManager {
  static const String key = 'petshop_images';

  static PetShopCacheManager? _instance;
  static PetShopCacheManager get instance {
    _instance ??= PetShopCacheManager._();
    return _instance!;
  }

  PetShopCacheManager._()
      : super(Config(
          key,
          stalePeriod: const Duration(days: 30),
          maxNrOfCacheObjects: 500,
          repo: JsonCacheInfoRepository(databaseName: key),
          fileService: HttpFileService(),
        ));
}
