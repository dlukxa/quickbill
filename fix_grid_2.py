import re

file_path = '/Users/dlukxa/Development/projects/POS/quickbill/lib/screens/billing/billing_screen.dart'
with open(file_path, 'r') as f:
    content = f.read()

pattern = re.compile(
    r"        \],\n      \),\n    \);\n  Widget _buildCartArea",
    re.DOTALL
)

corrected = """        ],
      ),
    );
  }

  Widget _buildCartArea"""

new_content = re.sub(pattern, corrected, content)
with open(file_path, 'w') as f:
    f.write(new_content)
