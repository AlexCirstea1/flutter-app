// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'file_info.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FileInfo _$FileInfoFromJson(Map<String, dynamic> json) => FileInfo(
      fileId: json['fileId'] as String,
      fileName: json['fileName'] as String,
      mimeType: json['mimeType'] as String,
      sizeBytes: (json['sizeBytes'] as num).toInt(),
    );

Map<String, dynamic> _$FileInfoToJson(FileInfo instance) => <String, dynamic>{
      'fileId': instance.fileId,
      'fileName': instance.fileName,
      'mimeType': instance.mimeType,
      'sizeBytes': instance.sizeBytes,
    };
