import 'dart:io';
import 'dart:typed_data';

import 'package:accounting_app/api/accounting_api_client.dart';
import 'package:accounting_app/attachments/attachment_cache_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const attachments = [
    AttachmentSummary(
      id: 'attachment-1',
      fileName: 'receipt.jpg',
      contentType: 'image/jpeg',
      storageDriver: 'local',
      storageKey: 'org-1/attachment-1/receipt.jpg',
      sizeBytes: 2048,
    ),
  ];

  test('memory attachment cache stores attachment summaries', () async {
    final repository = MemoryAttachmentCacheRepository();

    await repository.saveCached(attachments);

    final cached = await repository.loadCached();
    expect(cached.single.id, 'attachment-1');
    expect(cached.single.storageKey, 'org-1/attachment-1/receipt.jpg');
  });

  test(
    'file attachment cache persists and hydrates attachment summaries',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'ledger-attachment-cache-test',
      );
      addTearDown(() => directory.delete(recursive: true));
      final repository = FileAttachmentCacheRepository(
        File('${directory.path}/attachments.json'),
      );

      await repository.saveCached(attachments);

      final cached = await repository.loadCached();
      expect(cached, hasLength(1));
      expect(cached.single.fileName, 'receipt.jpg');
      expect(cached.single.sizeBytes, 2048);
    },
  );

  test('memory attachment binary cache stores downloaded bytes', () async {
    final repository = MemoryAttachmentBinaryCacheRepository();

    await repository.saveDownloaded(
      'attachment-1',
      AttachmentDownload(
        bytes: Uint8List.fromList('hello receipt'.codeUnits),
        contentType: 'text/plain',
        fileName: 'receipt.txt',
      ),
    );

    final cached = await repository.loadDownloaded('attachment-1');
    expect(cached, isNotNull);
    expect(String.fromCharCodes(cached!.bytes), 'hello receipt');
    expect(cached.fileName, 'receipt.txt');
  });

  test('file attachment binary cache persists downloaded bytes', () async {
    final directory = await Directory.systemTemp.createTemp(
      'ledger-attachment-binary-cache-test',
    );
    addTearDown(() => directory.delete(recursive: true));
    final repository = FileAttachmentBinaryCacheRepository(directory);

    await repository.saveDownloaded(
      'attachment-1',
      AttachmentDownload(
        bytes: Uint8List.fromList('hello receipt'.codeUnits),
        contentType: 'text/plain',
        fileName: 'receipt.txt',
      ),
    );

    final cached = await repository.loadDownloaded('attachment-1');
    expect(cached, isNotNull);
    expect(String.fromCharCodes(cached!.bytes), 'hello receipt');
    expect(cached.contentType, 'text/plain');
    expect(cached.fileName, 'receipt.txt');
  });
}
