import 'dart:async';
import 'dart:html' as html;
import 'paste_helper.dart';

PasteHelper getPasteHelper() => PasteHelperWeb();

class PasteHelperWeb implements PasteHelper {
  StreamSubscription? _pasteSubscription;
  StreamSubscription? _dropSubscription;
  StreamSubscription? _dragOverSubscription;

  @override
  void initPasteListener(void Function(String imagePathOrBase64) onImagePasted) {
    // 1. Paste event listener
    _pasteSubscription = html.document.onPaste.listen((html.ClipboardEvent event) {
      final clipboardData = event.clipboardData;
      if (clipboardData != null && clipboardData.files != null && clipboardData.files!.isNotEmpty) {
        final file = clipboardData.files![0];
        if (file.type.startsWith('image/')) {
          final reader = html.FileReader();
          reader.readAsDataUrl(file);
          reader.onLoadEnd.listen((loadEvent) {
            final result = reader.result;
            if (result is String) {
              onImagePasted(result);
            }
          });
        }
      }
    });

    // 2. Drag over event listener (to allow dropping)
    _dragOverSubscription = html.document.onDragOver.listen((html.MouseEvent event) {
      event.preventDefault();
    });

    // 3. Drop event listener
    _dropSubscription = html.document.onDrop.listen((html.MouseEvent event) {
      event.preventDefault();
      final dynamic dragEvent = event;
      try {
        final dragData = dragEvent.dataTransfer;
        if (dragData != null && dragData.files != null && dragData.files!.isNotEmpty) {
          final file = dragData.files![0];
          if (file.type.startsWith('image/')) {
            final reader = html.FileReader();
            reader.readAsDataUrl(file);
            reader.onLoadEnd.listen((loadEvent) {
              final result = reader.result;
              if (result is String) {
                onImagePasted(result);
              }
            });
          }
        }
      } catch (_) {
        // Fallback for non-drag events that might trigger this
      }
    });
  }

  @override
  void dispose() {
    _pasteSubscription?.cancel();
    _dropSubscription?.cancel();
    _dragOverSubscription?.cancel();
  }
}
