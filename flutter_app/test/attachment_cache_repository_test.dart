import 'dart:io';
import 'dart:typed_data';

import 'package:accounting_app/api/accounting_api_client.dart';
import 'package:accounting_app/attachments/attachment_cache_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

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

  test('sqlite attachment cache persists attachment summaries', () async {
    final database = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (database, _) => createAttachmentCacheTables(database),
      ),
    );
    addTearDown(database.close);
    final repository = SqliteAttachmentCacheRepository(database);

    await repository.saveCached(attachments);

    final cached = await repository.loadCached();
    expect(cached, hasLength(1));
    expect(cached.single.fileName, 'receipt.jpg');
    expect(cached.single.storageDriver, 'local');
    expect(cached.single.storageKey, 'org-1/attachment-1/receipt.jpg');
  });

  test('sqlite attachment cache orders and replaces snapshots', () async {
    final database = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (database, _) => createAttachmentCacheTables(database),
      ),
    );
    addTearDown(database.close);
    final repository = SqliteAttachmentCacheRepository(database);

    await repository.saveCached(attachments);
    await repository.saveCached([
      const AttachmentSummary(
        id: 'attachment-b',
        fileName: 'z-receipt.pdf',
        contentType: 'application/pdf',
        storageDriver: 'local',
        storageKey: 'org-1/attachment-b/z-receipt.pdf',
        sizeBytes: 4096,
      ),
      const AttachmentSummary(
        id: 'attachment-a',
        fileName: 'a-receipt.jpg',
        contentType: 'image/jpeg',
        storageDriver: 'local',
        storageKey: 'org-1/attachment-a/a-receipt.jpg',
        sizeBytes: 1024,
      ),
    ]);

    final cached = await repository.loadCached();
    expect(cached.map((attachment) => attachment.id), [
      'attachment-a',
      'attachment-b',
    ]);
    expect(cached.any((attachment) => attachment.id == 'attachment-1'), false);
  });

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

  test(
    'sqlite attachment upload manifest persists and orders queued blobs',
    () async {
      final database = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (database, _) =>
              createAttachmentUploadManifestTables(database),
        ),
      );
      addTearDown(database.close);
      final repository = SqliteAttachmentUploadManifestRepository(database);

      await repository.savePending([
        AttachmentUploadManifestEntry(
          operationId: 'attachment-upload-2',
          fileName: 'later.txt',
          localFilePath: '/tmp/later.txt',
          sizeBytes: 256,
          createdAt: DateTime.utc(2026, 7, 16, 10),
        ),
        AttachmentUploadManifestEntry(
          operationId: 'attachment-upload-1',
          fileName: 'receipt.txt',
          localFilePath: '/tmp/receipt.txt',
          sizeBytes: 128,
          createdAt: DateTime.utc(2026, 7, 16, 9),
          contentType: 'text/plain',
        ),
      ]);

      final pending = await repository.loadPending();
      expect(pending.map((entry) => entry.operationId), [
        'attachment-upload-1',
        'attachment-upload-2',
      ]);
      expect(pending.first.fileName, 'receipt.txt');
      expect(pending.first.contentType, 'text/plain');
    },
  );

  test('sqlite attachment upload manifest upserts queued blobs', () async {
    final database = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (database, _) =>
            createAttachmentUploadManifestTables(database),
      ),
    );
    addTearDown(database.close);
    final repository = SqliteAttachmentUploadManifestRepository(database);

    await repository.upsert(
      AttachmentUploadManifestEntry(
        operationId: 'attachment-upload-1',
        fileName: 'receipt.txt',
        localFilePath: '/tmp/receipt.txt',
        sizeBytes: 128,
        createdAt: DateTime.utc(2026, 7, 16, 9),
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
    expect(pending.single.localFilePath, '/tmp/receipt-updated.txt');
    expect(pending.single.sizeBytes, 256);
  });
}
