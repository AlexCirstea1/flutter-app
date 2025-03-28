import 'package:get_it/get_it.dart';
import 'api_service.dart';
import 'storage_service.dart';
import '../main.dart' show navigatorKey;

final serviceLocator = GetIt.instance;

void setupServiceLocator() {
  serviceLocator.registerLazySingleton(() => StorageService());
  serviceLocator.registerLazySingleton(() => ApiService(navigatorKey: navigatorKey));
}