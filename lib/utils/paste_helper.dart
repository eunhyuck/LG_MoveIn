import 'paste_helper_stub.dart'
    if (dart.library.html) 'paste_helper_web.dart';

abstract class PasteHelper {
  factory PasteHelper() => getPasteHelper();
  void initPasteListener(void Function(String imagePathOrBase64) onImagePasted);
  void dispose();
}
