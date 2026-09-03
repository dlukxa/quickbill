import re

file_path = "lib/services/sync_service.dart"

with open(file_path, "r") as f:
    content = f.read()

# 1. Add `_isDisposed`, `markDisposed()`, and `_safeRead` methods
additions = """
  bool _isDisposed = false;

  void setRef(Ref ref) {
    _ref = ref;
    _isDisposed = false;
  }

  void markDisposed() {
    _isDisposed = true;
  }

  T? _safeRead<T>(ProviderListenable<T> provider) {
    if (_ref == null || _isDisposed) return null;
    try {
      return _ref!.read(provider);
    } catch (e) {
      return null;
    }
  }
"""

content = re.sub(r'  void setRef\(Ref ref\) \{\n    _ref = ref;\n  \}', additions.strip(), content)

# 2. Update provider definition
provider_update = """final syncServiceProvider = Provider<SyncService>((ref) {
  SyncService.instance.setRef(ref);
  ref.onDispose(() {
    SyncService.instance.stopSync();
    SyncService.instance.markDisposed();
  });
  return SyncService.instance;
});"""

content = re.sub(r'final syncServiceProvider = Provider<SyncService>\(\(ref\) \{.*?\n\}\);', provider_update, content, flags=re.DOTALL)

# 3. Replace all `_ref!.read(...)` calls safely
content = re.sub(r'_ref!\.read\((.*?)\)\.state', r'_safeRead(\1)?.state', content)
content = re.sub(r'_ref!\.read\((.*?)\)\.refreshBranches', r'_safeRead(\1)?.refreshBranches', content)
content = re.sub(r'_ref!\.read\((.*?)\)\.autoSync', r'(_safeRead(\1)?.autoSync ?? false)', content)
# For lines 140, 141 (direct assignment)
content = re.sub(r'final settingsNotifier = _ref!\.read\(settingsProvider\.notifier\);', r'final settingsNotifier = _safeRead(settingsProvider.notifier);', content)
content = re.sub(r'final settings = _ref!\.read\(settingsProvider\);', r'final settings = _safeRead(settingsProvider);', content)

# Remove the try/catch block I added for autoSyncEnabled recently, since we use `_safeRead` now.
try_catch_block = """    bool autoSyncEnabled = false;
    try {
      autoSyncEnabled = (_safeRead(settingsProvider)?.autoSync ?? false);
    } catch (e) {
      return; // ref disposed during async gaps
    }
    if (!autoSyncEnabled) return;"""

replacement_block = """    final autoSyncEnabled = _safeRead(settingsProvider)?.autoSync ?? false;
    if (!autoSyncEnabled) return;"""
content = content.replace(try_catch_block, replacement_block)

# 4. Fix StockAlertService
content = content.replace("if (_ref != null) StockAlertService.instance.checkAndNotify(_ref!);", "if (_ref != null && !_isDisposed) StockAlertService.instance.checkAndNotify(_ref!);")

with open(file_path, "w") as f:
    f.write(content)

print("Modifications applied successfully.")
