import 'package:json_annotation/json_annotation.dart';

part 'file_info.g.dart';

@JsonSerializable()
class FileInfo {
  final String fileId;
  final String fileName;
  final String mimeType;
  final int sizeBytes;

  const FileInfo({
    required this.fileId,
    required this.fileName,
    required this.mimeType,
    required this.sizeBytes,
  });

  factory FileInfo.fromJson(Map<String, dynamic> json) => _$FileInfoFromJson(json);
  Map<String, dynamic> toJson() => _$FileInfoToJson(this);
}