import 'paste_helper.dart';

PasteHelper getPasteHelper() => PasteHelperStub();

class PasteHelperStub implements PasteHelper {
  @override
  void initPasteListener(void Function(String imagePathOrBase64) onImagePasted) {}
  @override
  void dispose() {}
}
