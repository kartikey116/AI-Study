import 'dart:io';
import 'package:dio/dio.dart';
import '../../../../core/network/dio_client.dart';
import '../models/document_model.dart';

class DocumentsRepository {
  final DioClient _dioClient;
  final Dio _dio = Dio(); // Raw Dio for direct S3 uploads to avoid interceptors

  DocumentsRepository(this._dioClient);

  Future<List<Document>> getDocuments() async {
    final response = await _dioClient.dio.get('/documents');
    final List<dynamic> docs = response.data['documents'];
    return docs.map((e) => Document.fromJson(e)).toList();
  }

  Future<Document> uploadDocument(File file, String fileName, {Function(double)? onProgress}) async {
    final size = await file.length();
    
    // 1. Get signed upload URL
    final response = await _dioClient.dio.post('/documents/upload-url', data: {
      'fileName': fileName,
      'mimeType': 'application/pdf',
    });
    
    final String signedUrl = response.data['signedUrl'];
    final String storagePath = response.data['storagePath'];

    // 2. Upload file directly to Supabase S3 (PUT request)
    await _dio.put(
      signedUrl,
      data: file.openRead(),
      options: Options(
        headers: {
          'Content-Type': 'application/pdf',
          'Content-Length': size.toString(),
        },
      ),
      onSendProgress: (count, total) {
        if (total != -1 && onProgress != null) {
          onProgress(count / total);
        }
      },
    );

    // 3. Confirm upload with backend
    final confirmResponse = await _dioClient.dio.post('/documents', data: {
      'storagePath': storagePath,
      'originalName': fileName,
      'sizeBytes': size,
    });

    return Document.fromJson(confirmResponse.data['document']);
  }

  Future<void> deleteDocument(String id) async {
    await _dioClient.dio.delete('/documents/$id');
  }
}
