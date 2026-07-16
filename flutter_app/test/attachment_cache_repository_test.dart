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

  test('memory attachment upload manifest upserts queued blobs', () async {
    final repository = MemoryAttachmentUploadManifestRepository();

    await repository.upsert(
      AttachmentUploadManifestEntry(
        operationId: 'attachment-upload-1',
        fileName: 'receipt.txt',
        localFilePath: '/tmp/receipt.txt',
        sizeBytes: 128,
        createdAt: DateTime.utc(2026, 7, 16, 9),
        contentType: 'text/plain',
      ),
    );
    await repository.upsert(
      AttachmentUploadManifestEntry(
        operationId: 'attachment-upload-1',
        fileName: 'receipt-updated.txt',
        localFilePath: '/tmp/receipt-updated.txt',
        sizeBytes: 256,
        createdAt: DateTime.utc(2026, 7, 16, 9, 5),
      ),
    );

    final pending = await repository.loadPending();
    expect(pending, hasLength(1));
    expect(pending.single.fileName, 'receipt-updated.txt');
    expect(pending.single.sizeBytes, 256);
  });

  test('file attachment upload manifest persists queued blobs', () async {
    final directory = await Directory.systemTemp.createTemp(
      'ledger-attachment-upload-manifest-test',
    );
    addTearDown(() => directory.delete(recursive: true));
    final repository = FileAttachmentUploadManifestRepository(
      File('${directory.path}/manifest.json'),
    );

    await repository.upsert(
      AttachmentUploadManifestEntry(
        operationId: 'attachment-upload-1',
        fileName: 'receipt.txt',
        localFilePath: '/tmp/receipt.txt',
        sizeBytes: 128,
        createdAt: DateTime.utc(2026, 7, 16, 9),
        contentType: 'text/plain',
      ),
    );

    final hydrated = FileAttachmentUploadManifestRepository(
      File('${directory.path}/manifest.json'),
    );
    final pending = await hydrated.loadPending();
    expect(pending, hasLength(1));
    expect(pending.single.operationId, 'attachment-upload-1');
    expect(pending.single.localFilePath, '/tmp/receipt.txt');
    expect(pending.single.createdAt, DateTime.utc(2026, 7, 16, 9));
    expect(pending.single.contentType, 'text/plain');
  });
}
