import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/dio_client.dart';
import '../../data/models/document_model.dart';
import '../../data/repositories/documents_repository.dart';

final documentsRepositoryProvider = Provider<DocumentsRepository>((ref) {
  final dioClient = DioClient();
  return DocumentsRepository(dioClient);
});

final documentsProvider = StateNotifierProvider<DocumentsNotifier, AsyncValue<List<Document>>>((ref) {
  final repository = ref.watch(documentsRepositoryProvider);
  return DocumentsNotifier(repository);
});

class DocumentsNotifier extends StateNotifier<AsyncValue<List<Document>>> {
  final DocumentsRepository _repository;
  Timer? _pollTimer;

  DocumentsNotifier(this._repository) : super(const AsyncValue.loading()) {
    fetchDocuments();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  void _checkAndStartPolling(List<Document> docs) {
    final hasProcessing = docs.any((d) => d.status == 'UPLOADING' || d.status == 'PROCESSING');
    if (hasProcessing) {
      if (_pollTimer == null || !_pollTimer!.isActive) {
        _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
          await silentRefresh();
        });
      }
    } else {
      _pollTimer?.cancel();
      _pollTimer = null;
    }
  }

  Future<void> fetchDocuments() async {
    try {
      state = const AsyncValue.loading();
      final docs = await _repository.getDocuments();
      state = AsyncValue.data(docs);
      _checkAndStartPolling(docs);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> silentRefresh() async {
    try {
      final docs = await _repository.getDocuments();
      state = AsyncValue.data(docs);
      _checkAndStartPolling(docs);
    } catch (_) {}
  }

  Future<Document> uploadDocument(File file, String fileName, {Function(double)? onProgress}) async {
    try {
      final doc = await _repository.uploadDocument(file, fileName, onProgress: onProgress);
      final currentList = state.valueOrNull ?? [];
      final updatedList = [doc, ...currentList];
      state = AsyncValue.data(updatedList);
      _checkAndStartPolling(updatedList);
      return doc;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteDocument(String id) async {
    try {
      await _repository.deleteDocument(id);
      state = state.whenData((docs) => docs.where((d) => d.id != id).toList());
    } catch (e) {
      rethrow;
    }
  }
}
