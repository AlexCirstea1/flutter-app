import 'package:get_it/get_it.dart';

import '../main.dart' show navigatorKey;
import 'api_service.dart';
import 'auth_service.dart';
import 'storage_service.dart';

final serviceLocator = GetIt.instance;

void setupServiceLocator() {
  serviceLocator.registerLazySingleton(() => StorageService());
  serviceLocator
      .registerLazySingleton(() => ApiService(navigatorKey: navigatorKey));
  serviceLocator
      .registerFactory(() => AuthService(serviceLocator<ApiService>()));
}
