// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $CachedMessagesTable extends CachedMessages
    with TableInfo<$CachedMessagesTable, CachedMessage> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedMessagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _chatUserIdMeta =
      const VerificationMeta('chatUserId');
  @override
  late final GeneratedColumn<String> chatUserId = GeneratedColumn<String>(
      'chat_user_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _senderMeta = const VerificationMeta('sender');
  @override
  late final GeneratedColumn<String> sender = GeneratedColumn<String>(
      'sender', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _recipientMeta =
      const VerificationMeta('recipient');
  @override
  late final GeneratedColumn<String> recipient = GeneratedColumn<String>(
      'recipient', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _ciphertextMeta =
      const VerificationMeta('ciphertext');
  @override
  late final GeneratedColumn<String> ciphertext = GeneratedColumn<String>(
      'ciphertext', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _ivMeta = const VerificationMeta('iv');
  @override
  late final GeneratedColumn<String> iv = GeneratedColumn<String>(
      'iv', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _encryptedKeyForSenderMeta =
      const VerificationMeta('encryptedKeyForSender');
  @override
  late final GeneratedColumn<String> encryptedKeyForSender =
      GeneratedColumn<String>('encrypted_key_for_sender', aliasedName, false,
          type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _encryptedKeyForRecipientMeta =
      const VerificationMeta('encryptedKeyForRecipient');
  @override
  late final GeneratedColumn<String> encryptedKeyForRecipient =
      GeneratedColumn<String>('encrypted_key_for_recipient', aliasedName, false,
          type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _senderKeyVersionMeta =
      const VerificationMeta('senderKeyVersion');
  @override
  late final GeneratedColumn<String> senderKeyVersion = GeneratedColumn<String>(
      'sender_key_version', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _recipientKeyVersionMeta =
      const VerificationMeta('recipientKeyVersion');
  @override
  late final GeneratedColumn<String> recipientKeyVersion =
      GeneratedColumn<String>('recipient_key_version', aliasedName, false,
          type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _plaintextMeta =
      const VerificationMeta('plaintext');
  @override
  late final GeneratedColumn<String> plaintext = GeneratedColumn<String>(
      'plaintext', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _timestampMeta =
      const VerificationMeta('timestamp');
  @override
  late final GeneratedColumn<DateTime> timestamp = GeneratedColumn<DateTime>(
      'timestamp', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _isReadMeta = const VerificationMeta('isRead');
  @override
  late final GeneratedColumn<bool> isRead = GeneratedColumn<bool>(
      'is_read', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_read" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _readTimestampMeta =
      const VerificationMeta('readTimestamp');
  @override
  late final GeneratedColumn<DateTime> readTimestamp =
      GeneratedColumn<DateTime>('read_timestamp', aliasedName, true,
          type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _oneTimeMeta =
      const VerificationMeta('oneTime');
  @override
  late final GeneratedColumn<bool> oneTime = GeneratedColumn<bool>(
      'one_time', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("one_time" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _fileDataMeta =
      const VerificationMeta('fileData');
  @override
  late final GeneratedColumn<String> fileData = GeneratedColumn<String>(
      'file_data', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        chatUserId,
        sender,
        recipient,
        ciphertext,
        iv,
        encryptedKeyForSender,
        encryptedKeyForRecipient,
        senderKeyVersion,
        recipientKeyVersion,
        plaintext,
        timestamp,
        isRead,
        readTimestamp,
        oneTime,
        fileData
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_messages';
  @override
  VerificationContext validateIntegrity(Insertable<CachedMessage> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('chat_user_id')) {
      context.handle(
          _chatUserIdMeta,
          chatUserId.isAcceptableOrUnknown(
              data['chat_user_id']!, _chatUserIdMeta));
    } else if (isInserting) {
      context.missing(_chatUserIdMeta);
    }
    if (data.containsKey('sender')) {
      context.handle(_senderMeta,
          sender.isAcceptableOrUnknown(data['sender']!, _senderMeta));
    } else if (isInserting) {
      context.missing(_senderMeta);
    }
    if (data.containsKey('recipient')) {
      context.handle(_recipientMeta,
          recipient.isAcceptableOrUnknown(data['recipient']!, _recipientMeta));
    } else if (isInserting) {
      context.missing(_recipientMeta);
    }
    if (data.containsKey('ciphertext')) {
      context.handle(
          _ciphertextMeta,
          ciphertext.isAcceptableOrUnknown(
              data['ciphertext']!, _ciphertextMeta));
    } else if (isInserting) {
      context.missing(_ciphertextMeta);
    }
    if (data.containsKey('iv')) {
      context.handle(_ivMeta, iv.isAcceptableOrUnknown(data['iv']!, _ivMeta));
    } else if (isInserting) {
      context.missing(_ivMeta);
    }
    if (data.containsKey('encrypted_key_for_sender')) {
      context.handle(
          _encryptedKeyForSenderMeta,
          encryptedKeyForSender.isAcceptableOrUnknown(
              data['encrypted_key_for_sender']!, _encryptedKeyForSenderMeta));
    } else if (isInserting) {
      context.missing(_encryptedKeyForSenderMeta);
    }
    if (data.containsKey('encrypted_key_for_recipient')) {
      context.handle(
          _encryptedKeyForRecipientMeta,
          encryptedKeyForRecipient.isAcceptableOrUnknown(
              data['encrypted_key_for_recipient']!,
              _encryptedKeyForRecipientMeta));
    } else if (isInserting) {
      context.missing(_encryptedKeyForRecipientMeta);
    }
    if (data.containsKey('sender_key_version')) {
      context.handle(
          _senderKeyVersionMeta,
          senderKeyVersion.isAcceptableOrUnknown(
              data['sender_key_version']!, _senderKeyVersionMeta));
    } else if (isInserting) {
      context.missing(_senderKeyVersionMeta);
    }
    if (data.containsKey('recipient_key_version')) {
      context.handle(
          _recipientKeyVersionMeta,
          recipientKeyVersion.isAcceptableOrUnknown(
              data['recipient_key_version']!, _recipientKeyVersionMeta));
    } else if (isInserting) {
      context.missing(_recipientKeyVersionMeta);
    }
    if (data.containsKey('plaintext')) {
      context.handle(_plaintextMeta,
          plaintext.isAcceptableOrUnknown(data['plaintext']!, _plaintextMeta));
    }
    if (data.containsKey('timestamp')) {
      context.handle(_timestampMeta,
          timestamp.isAcceptableOrUnknown(data['timestamp']!, _timestampMeta));
    } else if (isInserting) {
      context.missing(_timestampMeta);
    }
    if (data.containsKey('is_read')) {
      context.handle(_isReadMeta,
          isRead.isAcceptableOrUnknown(data['is_read']!, _isReadMeta));
    }
    if (data.containsKey('read_timestamp')) {
      context.handle(
          _readTimestampMeta,
          readTimestamp.isAcceptableOrUnknown(
              data['read_timestamp']!, _readTimestampMeta));
    }
    if (data.containsKey('one_time')) {
      context.handle(_oneTimeMeta,
          oneTime.isAcceptableOrUnknown(data['one_time']!, _oneTimeMeta));
    }
    if (data.containsKey('file_data')) {
      context.handle(_fileDataMeta,
          fileData.isAcceptableOrUnknown(data['file_data']!, _fileDataMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CachedMessage map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedMessage(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      chatUserId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}chat_user_id'])!,
      sender: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}sender'])!,
      recipient: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}recipient'])!,
      ciphertext: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}ciphertext'])!,
      iv: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}iv'])!,
      encryptedKeyForSender: attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}encrypted_key_for_sender'])!,
      encryptedKeyForRecipient: attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}encrypted_key_for_recipient'])!,
      senderKeyVersion: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}sender_key_version'])!,
      recipientKeyVersion: attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}recipient_key_version'])!,
      plaintext: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}plaintext']),
      timestamp: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}timestamp'])!,
      isRead: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_read'])!,
      readTimestamp: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}read_timestamp']),
      oneTime: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}one_time'])!,
      fileData: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}file_data']),
    );
  }

  @override
  $CachedMessagesTable createAlias(String alias) {
    return $CachedMessagesTable(attachedDatabase, alias);
  }
}

class CachedMessage extends DataClass implements Insertable<CachedMessage> {
  final String id;
  final String chatUserId;
  final String sender;
  final String recipient;
  final String ciphertext;
  final String iv;
  final String encryptedKeyForSender;
  final String encryptedKeyForRecipient;
  final String senderKeyVersion;
  final String recipientKeyVersion;
  final String? plaintext;
  final DateTime timestamp;
  final bool isRead;
  final DateTime? readTimestamp;
  final bool oneTime;
  final String? fileData;
  const CachedMessage(
      {required this.id,
      required this.chatUserId,
      required this.sender,
      required this.recipient,
      required this.ciphertext,
      required this.iv,
      required this.encryptedKeyForSender,
      required this.encryptedKeyForRecipient,
      required this.senderKeyVersion,
      required this.recipientKeyVersion,
      this.plaintext,
      required this.timestamp,
      required this.isRead,
      this.readTimestamp,
      required this.oneTime,
      this.fileData});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['chat_user_id'] = Variable<String>(chatUserId);
    map['sender'] = Variable<String>(sender);
    map['recipient'] = Variable<String>(recipient);
    map['ciphertext'] = Variable<String>(ciphertext);
    map['iv'] = Variable<String>(iv);
    map['encrypted_key_for_sender'] = Variable<String>(encryptedKeyForSender);
    map['encrypted_key_for_recipient'] =
        Variable<String>(encryptedKeyForRecipient);
    map['sender_key_version'] = Variable<String>(senderKeyVersion);
    map['recipient_key_version'] = Variable<String>(recipientKeyVersion);
    if (!nullToAbsent || plaintext != null) {
      map['plaintext'] = Variable<String>(plaintext);
    }
    map['timestamp'] = Variable<DateTime>(timestamp);
    map['is_read'] = Variable<bool>(isRead);
    if (!nullToAbsent || readTimestamp != null) {
      map['read_timestamp'] = Variable<DateTime>(readTimestamp);
    }
    map['one_time'] = Variable<bool>(oneTime);
    if (!nullToAbsent || fileData != null) {
      map['file_data'] = Variable<String>(fileData);
    }
    return map;
  }

  CachedMessagesCompanion toCompanion(bool nullToAbsent) {
    return CachedMessagesCompanion(
      id: Value(id),
      chatUserId: Value(chatUserId),
      sender: Value(sender),
      recipient: Value(recipient),
      ciphertext: Value(ciphertext),
      iv: Value(iv),
      encryptedKeyForSender: Value(encryptedKeyForSender),
      encryptedKeyForRecipient: Value(encryptedKeyForRecipient),
      senderKeyVersion: Value(senderKeyVersion),
      recipientKeyVersion: Value(recipientKeyVersion),
      plaintext: plaintext == null && nullToAbsent
          ? const Value.absent()
          : Value(plaintext),
      timestamp: Value(timestamp),
      isRead: Value(isRead),
      readTimestamp: readTimestamp == null && nullToAbsent
          ? const Value.absent()
          : Value(readTimestamp),
      oneTime: Value(oneTime),
      fileData: fileData == null && nullToAbsent
          ? const Value.absent()
          : Value(fileData),
    );
  }

  factory CachedMessage.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedMessage(
      id: serializer.fromJson<String>(json['id']),
      chatUserId: serializer.fromJson<String>(json['chatUserId']),
      sender: serializer.fromJson<String>(json['sender']),
      recipient: serializer.fromJson<String>(json['recipient']),
      ciphertext: serializer.fromJson<String>(json['ciphertext']),
      iv: serializer.fromJson<String>(json['iv']),
      encryptedKeyForSender:
          serializer.fromJson<String>(json['encryptedKeyForSender']),
      encryptedKeyForRecipient:
          serializer.fromJson<String>(json['encryptedKeyForRecipient']),
      senderKeyVersion: serializer.fromJson<String>(json['senderKeyVersion']),
      recipientKeyVersion:
          serializer.fromJson<String>(json['recipientKeyVersion']),
      plaintext: serializer.fromJson<String?>(json['plaintext']),
      timestamp: serializer.fromJson<DateTime>(json['timestamp']),
      isRead: serializer.fromJson<bool>(json['isRead']),
      readTimestamp: serializer.fromJson<DateTime?>(json['readTimestamp']),
      oneTime: serializer.fromJson<bool>(json['oneTime']),
      fileData: serializer.fromJson<String?>(json['fileData']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'chatUserId': serializer.toJson<String>(chatUserId),
      'sender': serializer.toJson<String>(sender),
      'recipient': serializer.toJson<String>(recipient),
      'ciphertext': serializer.toJson<String>(ciphertext),
      'iv': serializer.toJson<String>(iv),
      'encryptedKeyForSender': serializer.toJson<String>(encryptedKeyForSender),
      'encryptedKeyForRecipient':
          serializer.toJson<String>(encryptedKeyForRecipient),
      'senderKeyVersion': serializer.toJson<String>(senderKeyVersion),
      'recipientKeyVersion': serializer.toJson<String>(recipientKeyVersion),
      'plaintext': serializer.toJson<String?>(plaintext),
      'timestamp': serializer.toJson<DateTime>(timestamp),
      'isRead': serializer.toJson<bool>(isRead),
      'readTimestamp': serializer.toJson<DateTime?>(readTimestamp),
      'oneTime': serializer.toJson<bool>(oneTime),
      'fileData': serializer.toJson<String?>(fileData),
    };
  }

  CachedMessage copyWith(
          {String? id,
          String? chatUserId,
          String? sender,
          String? recipient,
          String? ciphertext,
          String? iv,
          String? encryptedKeyForSender,
          String? encryptedKeyForRecipient,
          String? senderKeyVersion,
          String? recipientKeyVersion,
          Value<String?> plaintext = const Value.absent(),
          DateTime? timestamp,
          bool? isRead,
          Value<DateTime?> readTimestamp = const Value.absent(),
          bool? oneTime,
          Value<String?> fileData = const Value.absent()}) =>
      CachedMessage(
        id: id ?? this.id,
        chatUserId: chatUserId ?? this.chatUserId,
        sender: sender ?? this.sender,
        recipient: recipient ?? this.recipient,
        ciphertext: ciphertext ?? this.ciphertext,
        iv: iv ?? this.iv,
        encryptedKeyForSender:
            encryptedKeyForSender ?? this.encryptedKeyForSender,
        encryptedKeyForRecipient:
            encryptedKeyForRecipient ?? this.encryptedKeyForRecipient,
        senderKeyVersion: senderKeyVersion ?? this.senderKeyVersion,
        recipientKeyVersion: recipientKeyVersion ?? this.recipientKeyVersion,
        plaintext: plaintext.present ? plaintext.value : this.plaintext,
        timestamp: timestamp ?? this.timestamp,
        isRead: isRead ?? this.isRead,
        readTimestamp:
            readTimestamp.present ? readTimestamp.value : this.readTimestamp,
        oneTime: oneTime ?? this.oneTime,
        fileData: fileData.present ? fileData.value : this.fileData,
      );
  CachedMessage copyWithCompanion(CachedMessagesCompanion data) {
    return CachedMessage(
      id: data.id.present ? data.id.value : this.id,
      chatUserId:
          data.chatUserId.present ? data.chatUserId.value : this.chatUserId,
      sender: data.sender.present ? data.sender.value : this.sender,
      recipient: data.recipient.present ? data.recipient.value : this.recipient,
      ciphertext:
          data.ciphertext.present ? data.ciphertext.value : this.ciphertext,
      iv: data.iv.present ? data.iv.value : this.iv,
      encryptedKeyForSender: data.encryptedKeyForSender.present
          ? data.encryptedKeyForSender.value
          : this.encryptedKeyForSender,
      encryptedKeyForRecipient: data.encryptedKeyForRecipient.present
          ? data.encryptedKeyForRecipient.value
          : this.encryptedKeyForRecipient,
      senderKeyVersion: data.senderKeyVersion.present
          ? data.senderKeyVersion.value
          : this.senderKeyVersion,
      recipientKeyVersion: data.recipientKeyVersion.present
          ? data.recipientKeyVersion.value
          : this.recipientKeyVersion,
      plaintext: data.plaintext.present ? data.plaintext.value : this.plaintext,
      timestamp: data.timestamp.present ? data.timestamp.value : this.timestamp,
      isRead: data.isRead.present ? data.isRead.value : this.isRead,
      readTimestamp: data.readTimestamp.present
          ? data.readTimestamp.value
          : this.readTimestamp,
      oneTime: data.oneTime.present ? data.oneTime.value : this.oneTime,
      fileData: data.fileData.present ? data.fileData.value : this.fileData,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedMessage(')
          ..write('id: $id, ')
          ..write('chatUserId: $chatUserId, ')
          ..write('sender: $sender, ')
          ..write('recipient: $recipient, ')
          ..write('ciphertext: $ciphertext, ')
          ..write('iv: $iv, ')
          ..write('encryptedKeyForSender: $encryptedKeyForSender, ')
          ..write('encryptedKeyForRecipient: $encryptedKeyForRecipient, ')
          ..write('senderKeyVersion: $senderKeyVersion, ')
          ..write('recipientKeyVersion: $recipientKeyVersion, ')
          ..write('plaintext: $plaintext, ')
          ..write('timestamp: $timestamp, ')
          ..write('isRead: $isRead, ')
          ..write('readTimestamp: $readTimestamp, ')
          ..write('oneTime: $oneTime, ')
          ..write('fileData: $fileData')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      chatUserId,
      sender,
      recipient,
      ciphertext,
      iv,
      encryptedKeyForSender,
      encryptedKeyForRecipient,
      senderKeyVersion,
      recipientKeyVersion,
      plaintext,
      timestamp,
      isRead,
      readTimestamp,
      oneTime,
      fileData);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedMessage &&
          other.id == this.id &&
          other.chatUserId == this.chatUserId &&
          other.sender == this.sender &&
          other.recipient == this.recipient &&
          other.ciphertext == this.ciphertext &&
          other.iv == this.iv &&
          other.encryptedKeyForSender == this.encryptedKeyForSender &&
          other.encryptedKeyForRecipient == this.encryptedKeyForRecipient &&
          other.senderKeyVersion == this.senderKeyVersion &&
          other.recipientKeyVersion == this.recipientKeyVersion &&
          other.plaintext == this.plaintext &&
          other.timestamp == this.timestamp &&
          other.isRead == this.isRead &&
          other.readTimestamp == this.readTimestamp &&
          other.oneTime == this.oneTime &&
          other.fileData == this.fileData);
}

class CachedMessagesCompanion extends UpdateCompanion<CachedMessage> {
  final Value<String> id;
  final Value<String> chatUserId;
  final Value<String> sender;
  final Value<String> recipient;
  final Value<String> ciphertext;
  final Value<String> iv;
  final Value<String> encryptedKeyForSender;
  final Value<String> encryptedKeyForRecipient;
  final Value<String> senderKeyVersion;
  final Value<String> recipientKeyVersion;
  final Value<String?> plaintext;
  final Value<DateTime> timestamp;
  final Value<bool> isRead;
  final Value<DateTime?> readTimestamp;
  final Value<bool> oneTime;
  final Value<String?> fileData;
  final Value<int> rowid;
  const CachedMessagesCompanion({
    this.id = const Value.absent(),
    this.chatUserId = const Value.absent(),
    this.sender = const Value.absent(),
    this.recipient = const Value.absent(),
    this.ciphertext = const Value.absent(),
    this.iv = const Value.absent(),
    this.encryptedKeyForSender = const Value.absent(),
    this.encryptedKeyForRecipient = const Value.absent(),
    this.senderKeyVersion = const Value.absent(),
    this.recipientKeyVersion = const Value.absent(),
    this.plaintext = const Value.absent(),
    this.timestamp = const Value.absent(),
    this.isRead = const Value.absent(),
    this.readTimestamp = const Value.absent(),
    this.oneTime = const Value.absent(),
    this.fileData = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CachedMessagesCompanion.insert({
    required String id,
    required String chatUserId,
    required String sender,
    required String recipient,
    required String ciphertext,
    required String iv,
    required String encryptedKeyForSender,
    required String encryptedKeyForRecipient,
    required String senderKeyVersion,
    required String recipientKeyVersion,
    this.plaintext = const Value.absent(),
    required DateTime timestamp,
    this.isRead = const Value.absent(),
    this.readTimestamp = const Value.absent(),
    this.oneTime = const Value.absent(),
    this.fileData = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        chatUserId = Value(chatUserId),
        sender = Value(sender),
        recipient = Value(recipient),
        ciphertext = Value(ciphertext),
        iv = Value(iv),
        encryptedKeyForSender = Value(encryptedKeyForSender),
        encryptedKeyForRecipient = Value(encryptedKeyForRecipient),
        senderKeyVersion = Value(senderKeyVersion),
        recipientKeyVersion = Value(recipientKeyVersion),
        timestamp = Value(timestamp);
  static Insertable<CachedMessage> custom({
    Expression<String>? id,
    Expression<String>? chatUserId,
    Expression<String>? sender,
    Expression<String>? recipient,
    Expression<String>? ciphertext,
    Expression<String>? iv,
    Expression<String>? encryptedKeyForSender,
    Expression<String>? encryptedKeyForRecipient,
    Expression<String>? senderKeyVersion,
    Expression<String>? recipientKeyVersion,
    Expression<String>? plaintext,
    Expression<DateTime>? timestamp,
    Expression<bool>? isRead,
    Expression<DateTime>? readTimestamp,
    Expression<bool>? oneTime,
    Expression<String>? fileData,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (chatUserId != null) 'chat_user_id': chatUserId,
      if (sender != null) 'sender': sender,
      if (recipient != null) 'recipient': recipient,
      if (ciphertext != null) 'ciphertext': ciphertext,
      if (iv != null) 'iv': iv,
      if (encryptedKeyForSender != null)
        'encrypted_key_for_sender': encryptedKeyForSender,
      if (encryptedKeyForRecipient != null)
        'encrypted_key_for_recipient': encryptedKeyForRecipient,
      if (senderKeyVersion != null) 'sender_key_version': senderKeyVersion,
      if (recipientKeyVersion != null)
        'recipient_key_version': recipientKeyVersion,
      if (plaintext != null) 'plaintext': plaintext,
      if (timestamp != null) 'timestamp': timestamp,
      if (isRead != null) 'is_read': isRead,
      if (readTimestamp != null) 'read_timestamp': readTimestamp,
      if (oneTime != null) 'one_time': oneTime,
      if (fileData != null) 'file_data': fileData,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CachedMessagesCompanion copyWith(
      {Value<String>? id,
      Value<String>? chatUserId,
      Value<String>? sender,
      Value<String>? recipient,
      Value<String>? ciphertext,
      Value<String>? iv,
      Value<String>? encryptedKeyForSender,
      Value<String>? encryptedKeyForRecipient,
      Value<String>? senderKeyVersion,
      Value<String>? recipientKeyVersion,
      Value<String?>? plaintext,
      Value<DateTime>? timestamp,
      Value<bool>? isRead,
      Value<DateTime?>? readTimestamp,
      Value<bool>? oneTime,
      Value<String?>? fileData,
      Value<int>? rowid}) {
    return CachedMessagesCompanion(
      id: id ?? this.id,
      chatUserId: chatUserId ?? this.chatUserId,
      sender: sender ?? this.sender,
      recipient: recipient ?? this.recipient,
      ciphertext: ciphertext ?? this.ciphertext,
      iv: iv ?? this.iv,
      encryptedKeyForSender:
          encryptedKeyForSender ?? this.encryptedKeyForSender,
      encryptedKeyForRecipient:
          encryptedKeyForRecipient ?? this.encryptedKeyForRecipient,
      senderKeyVersion: senderKeyVersion ?? this.senderKeyVersion,
      recipientKeyVersion: recipientKeyVersion ?? this.recipientKeyVersion,
      plaintext: plaintext ?? this.plaintext,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      readTimestamp: readTimestamp ?? this.readTimestamp,
      oneTime: oneTime ?? this.oneTime,
      fileData: fileData ?? this.fileData,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (chatUserId.present) {
      map['chat_user_id'] = Variable<String>(chatUserId.value);
    }
    if (sender.present) {
      map['sender'] = Variable<String>(sender.value);
    }
    if (recipient.present) {
      map['recipient'] = Variable<String>(recipient.value);
    }
    if (ciphertext.present) {
      map['ciphertext'] = Variable<String>(ciphertext.value);
    }
    if (iv.present) {
      map['iv'] = Variable<String>(iv.value);
    }
    if (encryptedKeyForSender.present) {
      map['encrypted_key_for_sender'] =
          Variable<String>(encryptedKeyForSender.value);
    }
    if (encryptedKeyForRecipient.present) {
      map['encrypted_key_for_recipient'] =
          Variable<String>(encryptedKeyForRecipient.value);
    }
    if (senderKeyVersion.present) {
      map['sender_key_version'] = Variable<String>(senderKeyVersion.value);
    }
    if (recipientKeyVersion.present) {
      map['recipient_key_version'] =
          Variable<String>(recipientKeyVersion.value);
    }
    if (plaintext.present) {
      map['plaintext'] = Variable<String>(plaintext.value);
    }
    if (timestamp.present) {
      map['timestamp'] = Variable<DateTime>(timestamp.value);
    }
    if (isRead.present) {
      map['is_read'] = Variable<bool>(isRead.value);
    }
    if (readTimestamp.present) {
      map['read_timestamp'] = Variable<DateTime>(readTimestamp.value);
    }
    if (oneTime.present) {
      map['one_time'] = Variable<bool>(oneTime.value);
    }
    if (fileData.present) {
      map['file_data'] = Variable<String>(fileData.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedMessagesCompanion(')
          ..write('id: $id, ')
          ..write('chatUserId: $chatUserId, ')
          ..write('sender: $sender, ')
          ..write('recipient: $recipient, ')
          ..write('ciphertext: $ciphertext, ')
          ..write('iv: $iv, ')
          ..write('encryptedKeyForSender: $encryptedKeyForSender, ')
          ..write('encryptedKeyForRecipient: $encryptedKeyForRecipient, ')
          ..write('senderKeyVersion: $senderKeyVersion, ')
          ..write('recipientKeyVersion: $recipientKeyVersion, ')
          ..write('plaintext: $plaintext, ')
          ..write('timestamp: $timestamp, ')
          ..write('isRead: $isRead, ')
          ..write('readTimestamp: $readTimestamp, ')
          ..write('oneTime: $oneTime, ')
          ..write('fileData: $fileData, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $CachedMessagesTable cachedMessages = $CachedMessagesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [cachedMessages];
}

typedef $$CachedMessagesTableCreateCompanionBuilder = CachedMessagesCompanion
    Function({
  required String id,
  required String chatUserId,
  required String sender,
  required String recipient,
  required String ciphertext,
  required String iv,
  required String encryptedKeyForSender,
  required String encryptedKeyForRecipient,
  required String senderKeyVersion,
  required String recipientKeyVersion,
  Value<String?> plaintext,
  required DateTime timestamp,
  Value<bool> isRead,
  Value<DateTime?> readTimestamp,
  Value<bool> oneTime,
  Value<String?> fileData,
  Value<int> rowid,
});
typedef $$CachedMessagesTableUpdateCompanionBuilder = CachedMessagesCompanion
    Function({
  Value<String> id,
  Value<String> chatUserId,
  Value<String> sender,
  Value<String> recipient,
  Value<String> ciphertext,
  Value<String> iv,
  Value<String> encryptedKeyForSender,
  Value<String> encryptedKeyForRecipient,
  Value<String> senderKeyVersion,
  Value<String> recipientKeyVersion,
  Value<String?> plaintext,
  Value<DateTime> timestamp,
  Value<bool> isRead,
  Value<DateTime?> readTimestamp,
  Value<bool> oneTime,
  Value<String?> fileData,
  Value<int> rowid,
});

class $$CachedMessagesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $CachedMessagesTable,
    CachedMessage,
    $$CachedMessagesTableFilterComposer,
    $$CachedMessagesTableOrderingComposer,
    $$CachedMessagesTableCreateCompanionBuilder,
    $$CachedMessagesTableUpdateCompanionBuilder> {
  $$CachedMessagesTableTableManager(
      _$AppDatabase db, $CachedMessagesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          filteringComposer:
              $$CachedMessagesTableFilterComposer(ComposerState(db, table)),
          orderingComposer:
              $$CachedMessagesTableOrderingComposer(ComposerState(db, table)),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> chatUserId = const Value.absent(),
            Value<String> sender = const Value.absent(),
            Value<String> recipient = const Value.absent(),
            Value<String> ciphertext = const Value.absent(),
            Value<String> iv = const Value.absent(),
            Value<String> encryptedKeyForSender = const Value.absent(),
            Value<String> encryptedKeyForRecipient = const Value.absent(),
            Value<String> senderKeyVersion = const Value.absent(),
            Value<String> recipientKeyVersion = const Value.absent(),
            Value<String?> plaintext = const Value.absent(),
            Value<DateTime> timestamp = const Value.absent(),
            Value<bool> isRead = const Value.absent(),
            Value<DateTime?> readTimestamp = const Value.absent(),
            Value<bool> oneTime = const Value.absent(),
            Value<String?> fileData = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              CachedMessagesCompanion(
            id: id,
            chatUserId: chatUserId,
            sender: sender,
            recipient: recipient,
            ciphertext: ciphertext,
            iv: iv,
            encryptedKeyForSender: encryptedKeyForSender,
            encryptedKeyForRecipient: encryptedKeyForRecipient,
            senderKeyVersion: senderKeyVersion,
            recipientKeyVersion: recipientKeyVersion,
            plaintext: plaintext,
            timestamp: timestamp,
            isRead: isRead,
            readTimestamp: readTimestamp,
            oneTime: oneTime,
            fileData: fileData,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String chatUserId,
            required String sender,
            required String recipient,
            required String ciphertext,
            required String iv,
            required String encryptedKeyForSender,
            required String encryptedKeyForRecipient,
            required String senderKeyVersion,
            required String recipientKeyVersion,
            Value<String?> plaintext = const Value.absent(),
            required DateTime timestamp,
            Value<bool> isRead = const Value.absent(),
            Value<DateTime?> readTimestamp = const Value.absent(),
            Value<bool> oneTime = const Value.absent(),
            Value<String?> fileData = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              CachedMessagesCompanion.insert(
            id: id,
            chatUserId: chatUserId,
            sender: sender,
            recipient: recipient,
            ciphertext: ciphertext,
            iv: iv,
            encryptedKeyForSender: encryptedKeyForSender,
            encryptedKeyForRecipient: encryptedKeyForRecipient,
            senderKeyVersion: senderKeyVersion,
            recipientKeyVersion: recipientKeyVersion,
            plaintext: plaintext,
            timestamp: timestamp,
            isRead: isRead,
            readTimestamp: readTimestamp,
            oneTime: oneTime,
            fileData: fileData,
            rowid: rowid,
          ),
        ));
}

class $$CachedMessagesTableFilterComposer
    extends FilterComposer<_$AppDatabase, $CachedMessagesTable> {
  $$CachedMessagesTableFilterComposer(super.$state);
  ColumnFilters<String> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get chatUserId => $state.composableBuilder(
      column: $state.table.chatUserId,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get sender => $state.composableBuilder(
      column: $state.table.sender,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get recipient => $state.composableBuilder(
      column: $state.table.recipient,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get ciphertext => $state.composableBuilder(
      column: $state.table.ciphertext,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get iv => $state.composableBuilder(
      column: $state.table.iv,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get encryptedKeyForSender => $state.composableBuilder(
      column: $state.table.encryptedKeyForSender,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get encryptedKeyForRecipient =>
      $state.composableBuilder(
          column: $state.table.encryptedKeyForRecipient,
          builder: (column, joinBuilders) =>
              ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get senderKeyVersion => $state.composableBuilder(
      column: $state.table.senderKeyVersion,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get recipientKeyVersion => $state.composableBuilder(
      column: $state.table.recipientKeyVersion,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get plaintext => $state.composableBuilder(
      column: $state.table.plaintext,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<DateTime> get timestamp => $state.composableBuilder(
      column: $state.table.timestamp,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<bool> get isRead => $state.composableBuilder(
      column: $state.table.isRead,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<DateTime> get readTimestamp => $state.composableBuilder(
      column: $state.table.readTimestamp,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<bool> get oneTime => $state.composableBuilder(
      column: $state.table.oneTime,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get fileData => $state.composableBuilder(
      column: $state.table.fileData,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));
}

class $$CachedMessagesTableOrderingComposer
    extends OrderingComposer<_$AppDatabase, $CachedMessagesTable> {
  $$CachedMessagesTableOrderingComposer(super.$state);
  ColumnOrderings<String> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get chatUserId => $state.composableBuilder(
      column: $state.table.chatUserId,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get sender => $state.composableBuilder(
      column: $state.table.sender,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get recipient => $state.composableBuilder(
      column: $state.table.recipient,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get ciphertext => $state.composableBuilder(
      column: $state.table.ciphertext,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get iv => $state.composableBuilder(
      column: $state.table.iv,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get encryptedKeyForSender => $state.composableBuilder(
      column: $state.table.encryptedKeyForSender,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get encryptedKeyForRecipient =>
      $state.composableBuilder(
          column: $state.table.encryptedKeyForRecipient,
          builder: (column, joinBuilders) =>
              ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get senderKeyVersion => $state.composableBuilder(
      column: $state.table.senderKeyVersion,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get recipientKeyVersion => $state.composableBuilder(
      column: $state.table.recipientKeyVersion,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get plaintext => $state.composableBuilder(
      column: $state.table.plaintext,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<DateTime> get timestamp => $state.composableBuilder(
      column: $state.table.timestamp,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<bool> get isRead => $state.composableBuilder(
      column: $state.table.isRead,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<DateTime> get readTimestamp => $state.composableBuilder(
      column: $state.table.readTimestamp,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<bool> get oneTime => $state.composableBuilder(
      column: $state.table.oneTime,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get fileData => $state.composableBuilder(
      column: $state.table.fileData,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));
}

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$CachedMessagesTableTableManager get cachedMessages =>
      $$CachedMessagesTableTableManager(_db, _db.cachedMessages);
}
