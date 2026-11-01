with open(r'C:\Users\Merouan\Documents\Default Project\pharma-maroc-gold\frontend\lib\features\reference\reference_page.dart', 'rb') as f:
    content = f.read()

# Build exact pattern from the file
lines = [
    b'class _Facet {',
    b'  final String label;',
    b'  class _StatusChip extends StatelessWidget {',
    b'  final String? status;',
    b'  const _StatusChip(this.status);',
    b'  @override',
    b'  Widget build(BuildContext context) {',
    b"    final s = status ?? 'unknown';",
    b'    Color color;',
    b'    String label;',
    b'    switch (s) {',
    b"      case 'available': color = AppColors.success; label = 'Disponible'; break;",
    b"      case 'out_of_stock': color = AppColors.danger; label = 'Rupture'; break;",
    b"      case 'retired': color = Colors.grey; label = 'Retir\xc3\xa9'; break;",
    b'      default: color = Colors.grey; label = s;',
    b'    }',
    b'    return Container(',
    b'      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),',
    b'      decoration: BoxDecoration(',
    b'        color: color.withValues(alpha: 0.15),',
    b'        borderRadius: BorderRadius.circular(12),',
    b'        border: Border.all(color: color, width: 1),',
    b'      ),',
    b'      child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)),',
    b'    );',
    b'  }',
    b'  }',
    b'}',
]

old = b'\n'.join(lines)
new = b'\n'.join([
    b'class _Facet {',
    b'  final String label;',
    b'  final String value;',
    b'  final int total;',
    b"  const _Facet(this.label, [this.value = '', this.total = 0]);",
    b'}',
    b'',
    b'class _StatusChip extends StatelessWidget {',
    b'  final String? status;',
    b'  const _StatusChip(this.status);',
    b'  @override',
    b'  Widget build(BuildContext context) {',
    b"    final s = status ?? 'unknown';",
    b'    Color color;',
    b'    String label;',
    b'    switch (s) {',
    b"      case 'available': color = AppColors.success; label = 'Disponible'; break;",
    b"      case 'out_of_stock': color = AppColors.danger; label = 'Rupture'; break;",
    b"      case 'retired': color = Colors.grey; label = 'Retir\xc3\xa9'; break;",
    b'      default: color = Colors.grey; label = s;',
    b'    }',
    b'    return Container(',
    b'      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),',
    b'      decoration: BoxDecoration(',
    b'        color: color.withValues(alpha: 0.15),',
    b'        borderRadius: BorderRadius.circular(12),',
    b'        border: Border.all(color: color, width: 1),',
    b'      ),',
    b'      child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)),',
    b'    );',
    b'  }',
    b'}',
])

if old in content:
    content = content.replace(old, new)
    with open(r'C:\Users\Merouan\Documents\Default Project\pharma-maroc-gold\frontend\lib\features\reference\reference_page.dart', 'wb') as f:
        f.write(content)
    print('Fixed!')
else:
    print('Pattern not found')
    # Debug
    for i, (o, n) in enumerate(zip(old.split(b'\n'), new.split(b'\n'))):
        if o != n:
            print('Line {}: old={} vs new={}'.format(i, repr(o), repr(n)))