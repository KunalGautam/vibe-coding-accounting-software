import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../api/accounting_api_client.dart';

Future<AttachmentCacheRepository>
createDefaultAttachmentCacheRepository() async {
  final directory = await getApplicationSupportDirectory();
  return FileAttachmentCacheRepository(
    File('${directory.path}/cached-attachments.json'),
  );
}

Future<AttachmentBinaryCacheRepository>
createDefaultAttachmentBinaryCacheRepository() async {
  final directory = await getApplicationSupportDirectory();
  return FileAttachmentBinaryCacheRepository(
    Directory('${directory.path}/attachment-binaries'),
  );
}

abstract interface class AttachmentCacheRepository {
  Future<List<AttachmentSummary>> loadCached();

  Future<void> saveCached(List<AttachmentSummary> attachments);
}

abstract interface class AttachmentBinaryCacheRepository {
  Future<void> saveDownloaded(String attachmentId, AttachmentDownload download);

  Future<AttachmentDownload?> loadDownloaded(String attachmentId);
}

class MemoryAttachmentCacheRepository implements AttachmentCacheRepository {
  MemoryAttachmentCacheRepository([List<AttachmentSummary>? seed])
    : _attachments = [...?seed];

  final List<AttachmentSummary> _attachments;

  @override
  Future<List<AttachmentSummary>> loadCached() async {
    return List.unmodifiable(_attachments);
  }

  @override
  Future<void> saveCached(List<AttachmentSummary> attachments) async {
    _attachments
      ..clear()
      ..addAll(attachments);
  }
}

class FileAttachmentCacheRepository implements AttachmentCacheRepository {
  const FileAttachmentCacheRepository(this.file);

  final File file;

  @override
  Future<List<AttachmentSummary>> loadCached() async {
    if (!await file.exists()) {
      return [];
    }

    final contents = await file.readAsString();
    if (contents.trim().isEmpty) {
      return [];
    }

    final decoded = jsonDecode(contents);
    if (decoded is! List) {
      throw const FormatException('Expected attachment cache JSON array');
    }

    return decoded
        .cast<Map<String, Object?>>()
        .map(AttachmentSummary.fromJson)
        .toList(growable: false);
  }

  @override
  Future<void> saveCached(List<AttachmentSummary> attachments) async {
    await file.parent.create(recursive: true);
    final tempFile = File('${file.path}.tmp');
    final encoded = jsonEncode(
      attachments
          .map((attachment) => attachment.toJson())
          .toList(growable: false),
    );

    await tempFile.writeAsString(encoded, flush: true);
    if (await file.exists()) {
      await file.delete();
    }
    await tempFile.rename(file.path);
  }
}

class MemoryAttachmentBinaryCacheRepository
    implements AttachmentBinaryCacheRepository {
  final Map<String, AttachmentDownload> _downloads = {};

  @override
  Future<void> saveDownloaded(
    String attachmentId,
    AttachmentDownload download,
  ) async {
    _downloads[attachmentId] = download;
  }

  @override
  Future<AttachmentDownload?> loadDownloaded(String attachmentId) async {
    return _downloads[attachmentId];
  }
}

class FileAttachmentBinaryCacheRepository
    implements AttachmentBinaryCacheRepository {
  const FileAttachmentBinaryCacheRepository(this.directory);

  final Directory directory;

  @override
  Future<void> saveDownloaded(
    String attachmentId,
    AttachmentDownload download,
  ) async {
    await directory.create(recursive: true);
    final tempFile = File('${_pathFor(attachmentId)}.tmp');
    await tempFile.writeAsBytes(download.bytes, flush: true);
    final destination = File(_pathFor(attachmentId));
    if (await destination.exists()) {
      await destination.delete();
    }
    await tempFile.rename(destination.path);

    final metadata = {
      'file_name': download.fileName,
      'content_type': download.contentType,
    }..removeWhere((_, value) => value == null);
    await File(
      '${_pathFor(attachmentId)}.json',
    ).writeAsString(jsonEncode(metadata), flush: true);
  }

  @override
  Future<AttachmentDownload?> loadDownloaded(String attachmentId) async {
    final file = File(_pathFor(attachmentId));
    if (!await file.exists()) {
      return null;
    }

    String? fileName;
    var contentType = 'application/octet-stream';
    final metadataFile = File('${_pathFor(attachmentId)}.json');
    if (await metadataFile.exists()) {
      final decoded = jsonDecode(await metadataFile.readAsString());
      if (decoded is Map<String, Object?>) {
        fileName = decoded['file_name'] as String?;
        contentType =
            decoded['content_type'] as String? ?? 'application/octet-stream';
      }
    }

    return AttachmentDownload(
      bytes: await file.readAsBytes(),
      contentType: contentType,
      fileName: fileName,
    );
  }

  String _pathFor(String attachmentId) {
    return '${directory.path}/$attachmentId.bin';
  }
}
