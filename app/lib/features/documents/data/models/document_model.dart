class Document {
  final String id;
  final String name;
  final String status; // UPLOADING, PROCESSING, READY, FAILED
  final int? pageCount;
  final int sizeBytes;
  final String? errorMessage;
  final DateTime createdAt;
  final int chunkCount;

  Document({
    required this.id,
    required this.name,
    required this.status,
    this.pageCount,
    required this.sizeBytes,
    this.errorMessage,
    required this.createdAt,
    required this.chunkCount,
  });

  factory Document.fromJson(Map<String, dynamic> json) {
    return Document(
      id: json['id'],
      name: json['name'],
      status: json['status'],
      pageCount: json['pageCount'],
      sizeBytes: json['sizeBytes'] ?? 0,
      errorMessage: json['errorMessage'],
      createdAt: DateTime.parse(json['createdAt']),
      chunkCount: json['_count']?['chunks'] ?? 0,
    );
  }
}
