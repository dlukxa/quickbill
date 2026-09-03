import re

file_path = "lib/services/sync_service.dart"

with open(file_path, "r") as f:
    content = f.read()

# Add _safeInvalidate method right after _safeRead
safe_invalidate_code = """
  void _safeInvalidate(dynamic provider) {
    if (_ref == null || _isDisposed) return;
    try {
      _ref!.invalidate(provider);
    } catch (e) {
      // ignore
    }
  }
"""
content = re.sub(r'(  T\? _safeRead<T>\(ProviderListenable<T> provider\) \{.*?\n  \})', r'\1' + safe_invalidate_code, content, flags=re.DOTALL)

content = content.replace('_ref!.invalidate(', '_safeInvalidate(')

with open(file_path, "w") as f:
    f.write(content)

print("Invalidate modifications applied.")
