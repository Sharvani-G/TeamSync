import 'file_delivery_service_stub.dart'
    if (dart.library.html) 'file_delivery_service_web.dart' as impl;

class FileDeliveryService {
  FileDeliveryService._();

  static final FileDeliveryService instance = FileDeliveryService._();

  Future<void> downloadFromUrl({
    required String url,
    required String fileName,
  }) {
    return impl.downloadFromUrl(url: url, fileName: fileName);
  }
}