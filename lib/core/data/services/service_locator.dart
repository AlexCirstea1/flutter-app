import 'package:get_it/get_it.dart';
import 'package:vaultx_app/core/data/services/storage_service.dart';

import '../../../features/auth/data/services/auth_service.dart';
import '../../../features/chat/data/repositories/chat_request_repository.dart';
import '../../../features/chat/data/repositories/message_repository.dart';
import '../../../features/chat/data/services/chat_service.dart';
import '../../../features/chat/data/services/file_download_service.dart';
import '../../../features/chat/data/services/file_validation_service.dart';
import '../../../features/chat/data/services/key_management_service.dart';
import '../../../features/chat/data/services/message_crypto_service.dart';
import '../../../main.dart';
import '../database/app_database.dart';
import 'api_service.dart';
import 'data_preload_service.dart';

final serviceLocator = GetIt.instance;

void setupServiceLocator() {
  /* ── Core ───────────────────────────────────────────── */
  serviceLocator.registerLazySingleton<StorageService>(() => StorageService());
  serviceLocator.registerLazySingleton<ApiService>(
      () => ApiService(navigatorKey: navigatorKey));

  serviceLocator.registerLazySingleton<AuthService>(
      () => AuthService(serviceLocator<ApiService>()));

  /* ── Chat helpers ───────────────────────────────────── */
  serviceLocator.registerLazySingleton<KeyManagementService>(
      () => KeyManagementService(storageService: serviceLocator()));

  serviceLocator.registerLazySingleton<MessageCryptoService>(
      () => MessageCryptoService());

  serviceLocator.registerLazySingleton<AppDatabase>(() => AppDatabase());

  serviceLocator.registerLazySingleton<DataPreloadService>(() => DataPreloadService());

  serviceLocator.registerFactory<MessageRepository>(() => MessageRepository(
    storageService: serviceLocator<StorageService>(),
    cryptoService: serviceLocator<MessageCryptoService>(),
  ));

  serviceLocator.registerFactory<FileValidationService>(
        () => FileValidationService(storageService: serviceLocator<StorageService>()),
  );

  serviceLocator.registerLazySingleton<FileDownloadService>(
        () => FileDownloadService(
      storageService: serviceLocator<StorageService>(),
      cryptoService: serviceLocator<MessageCryptoService>(),
    ),
  );

  serviceLocator
      .registerLazySingleton<ChatRequestRepository>(() => ChatRequestRepository(
            storageService: serviceLocator(),
            keyManagementService: serviceLocator(),
            cryptoService: serviceLocator(),
          ));

  /* ── High-level façade ──────────────────────────────── */
  serviceLocator.registerLazySingleton<ChatService>(() => ChatService(
        storageService: serviceLocator(),
        keyManagement: serviceLocator(),
        cryptoService: serviceLocator(),
        messageRepository: serviceLocator(),
        requestRepository: serviceLocator(), // new
      ));
}
