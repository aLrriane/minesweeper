// ============================================================
// This is the NON-WEB version. On mobile/desktop there is no
// browser right-click menu to disable, so this does nothing.
// The real, web-only implementation lives in
// disable_context_menu_web.dart and is swapped in automatically
// by the conditional import in main.dart.
// ============================================================
void disableRightClickMenu() {
  // No-op on non-web platforms.
}
