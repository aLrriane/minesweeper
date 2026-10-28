// ============================================================
// WEB-ONLY implementation. This directly listens for the
// browser's "contextmenu" event (the event that triggers the
// right-click popup) and calls preventDefault() on it, which is
// the reliable way to stop it — more reliable than
// BrowserContextMenu.disableContextMenu() from package:flutter,
// which doesn't always work depending on the web renderer.
// ============================================================
import 'dart:js_interop';

import 'package:web/web.dart' as web;

void disableRightClickMenu() {
  web.document.addEventListener(
    'contextmenu',
    ((web.Event event) => event.preventDefault()).toJS,
  );
}
