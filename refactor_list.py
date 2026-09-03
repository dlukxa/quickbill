import re

def refactor_file(file_path):
    with open(file_path, 'r') as f:
        content = f.read()

    # Find the ListView.builder
    listview_pattern = re.compile(r'ListView\.builder\(\s*padding: const EdgeInsets\.all\(16\),\s*itemCount: (items\.length),\s*itemBuilder: \(context, index\) \{')
    
    if not listview_pattern.search(content):
        print(f"Could not find ListView.builder in {file_path}")
        return

    gridview_code = """GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 450,
                        mainAxisExtent: 140,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                      ),
                      itemCount: items.length,
                      itemBuilder: (context, index) {"""

    content = listview_pattern.sub(gridview_code, content)

    # Make the Summary Header responsive as well
    # Wrap the header Container in a Center or constrained box on tablets.
    # We can use constraints: BoxConstraints(maxWidth: 800) in the Container
    container_pattern = re.compile(r'Container\(\s*width: double\.infinity,\s*padding: const EdgeInsets\.all\(24\),\s*margin: const EdgeInsets\.fromLTRB\(16, 16, 16, 8\),')
    
    constrained_container = """Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxWidth: 800),
                padding: const EdgeInsets.all(24),
                margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),"""
                
    content = container_pattern.sub(constrained_container, content)

    # Wrap the Summary Header Container in a Center widget to center it if it gets constrained
    # This requires more careful regex, so we'll just add the constraints and let it align to the left if it doesn't wrap in Center, 
    # but actually we can just put `alignment: Alignment.center` in a wrapping `Align` or `Center` via simple replace if we find the exact block.
    # For now, just adding BoxConstraints is fine, but Column crossAxisAlignment is center by default.
    
    with open(file_path, 'w') as f:
        f.write(content)
    print(f"Refactored {file_path}")

refactor_file('lib/screens/reports/damage_report_screen.dart')
refactor_file('lib/screens/reports/supplier_returns_report_screen.dart')
