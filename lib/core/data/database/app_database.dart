import 'package:drift/drift.dart';
import 'dart:io';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'app_database.g.dart';

class CachedMessages extends Table {
  TextColumn get id => text()();
  TextColumn get chatUserId => text()();
  TextColumn get sender => text()();
  TextColumn get recipient => text()();
  TextColumn get ciphertext => text()();
  TextColumn get iv => text()();
  TextColumn get encryptedKeyForSender => text()();
  TextColumn get encryptedKeyForRecipient => text()();
  TextColumn get senderKeyVersion => text()();
  TextColumn get recipientKeyVersion => text()();
  TextColumn get plaintext => text().nullable()();
  DateTimeColumn get timestamp => dateTime()();
  BoolColumn get isRead => boolean().withDefault(const Constant(false))();
  DateTimeColumn get readTimestamp => dateTime().nullable()();
  BoolColumn get oneTime => boolean().withDefault(const Constant(false))();
  TextColumn get fileData => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [CachedMessages])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  // Get messages for a specific chat
  Future<List<CachedMessage>> getMessagesForChat(String chatUserId) {
    return (select(cachedMessages)
      ..where((tbl) => tbl.chatUserId.equals(chatUserId))
      ..orderBy([(t) => OrderingTerm.asc(t.timestamp)]))
        .get();
  }

  // Get latest message timestamp for a chat
  Future<DateTime?> getLatestMessageTimestamp(String chatUserId) async {
    final query = select(cachedMessages)
      ..where((tbl) => tbl.chatUserId.equals(chatUserId))
      ..orderBy([(t) => OrderingTerm.desc(t.timestamp)])
      ..limit(1);

    final result = await query.getSingleOrNull();
    return result?.timestamp;
  }

  // Cache multiple messages
  Future<void> cacheMessages(List<CachedMessagesCompanion> messages) async {
    await batch((batch) {
      batch.insertAllOnConflictUpdate(cachedMessages, messages);
    });
  }

  // Clear cache for a specific chat
  Future<void> clearChatCache(String chatUserId) {
    return (delete(cachedMessages)
      ..where((tbl) => tbl.chatUserId.equals(chatUserId)))
        .go();
  }

  // Clear all cached messages
  Future<void> clearAllCache() {
    return delete(cachedMessages).go();
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'db.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}