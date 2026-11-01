with open(r'C:\Users\Merouan\Documents\Default Project\pharma-maroc-gold\frontend\lib\features\reference\reference_page.dart', 'rb') as f:
    content = f.read()

# The exact bytes we want to replace
old = b"class _Facet {\n  final String label;\n  class _StatusChip extends StatelessWidget {\n  final String? status;\n  const _StatusChip(this.status);\n  @override\n  Widget build(BuildContext context) {\n    final s = status ?? 'unknown';\n    Color color;\n    String label;\n    switch (s) {\n      case 'available': color = AppColors.success; label = 'Disponible'; break;\n      case 'out_of_stock': color = AppColors.danger; label = 'Rupture'; break;\n      case 'retired': color = Colors.grey; label = 'Retir\xc3\xa9'; break;\n      default: color = Colors.grey; label = s;\n    }\n    return Container(\n      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),\n      decoration: BoxDecoration(\n        color: color.withValues(alpha: 0.15),\n        borderRadius: BorderRadius.circular(12),\n        border: Border.all(color: color, width: 1),\n      ),\n      child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)),\n    );\n  }\n  }\n}"

new = b"class _Facet {\n  final String label;\n  final String value;\n  final int total;\n  const _Facet(this.label, [this.value = '', this.total = 0]);\n}\n\nclass _StatusChip extends StatelessWidget {\n  final String? status;\n  const _StatusChip(this.status);\n  @override\n  Widget build(BuildContext context) {\n    final s = status ?? 'unknown';\n    Color color;\n    String label;\n    switch (s) {\n      case 'available': color = AppColors.success; label = 'Disponible'; break;\n      case 'out_of_stock': color = AppColors.danger; label = 'Rupture'; break;\n      case 'retired': color = Colors.grey; label = 'Retir\xc3\xa9'; break;\n      default: color = Colors.grey; label = s;\n    }\n    return Container(\n      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),\n      decoration: BoxDecoration(\n        color: color.withValues(alpha: 0.15),\n        borderRadius: BorderRadius.circular(12),\n        border: Border.all(color: color, width: 1),\n      ),\n      child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)),\n    );\n  }\n}"

if old in content:
    content = content.replace(old, new)
    with open(r'C:\Users\Merouan\Documents\Default Project\pharma-maroc-gold\frontend\lib\features\reference\reference_page.dart', 'wb') as f:
        f.write(content)
    print('Fixed!')
else:
    print('Pattern NOT found in file')
    # Debug: check if old is subset
    for i in range(0, len(old), 100):
        chunk = old[i:i+100]
        if chunk not in content:
            print(f'Missing at offset {i}: {repr(chunk)}')
            break