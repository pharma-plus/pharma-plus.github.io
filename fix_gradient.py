with open(r'C:\Users\Merouan\Documents\Default Project\pharma-maroc-gold\frontend\lib\features\suppliers\supplier_connectivity_page.dart', 'r', encoding='utf-8') as f:
    content = f.read()

old = """decoration: BoxDecoration(
            gradient: config.enabled ? AppColors.goldGradient : Colors.grey,
            borderRadius: BorderRadius.circular(12),
          ),"""

new = """decoration: BoxDecoration(
            gradient: config.enabled ? AppColors.goldGradient : null,
            color: config.enabled ? null : Colors.grey,
            borderRadius: BorderRadius.circular(12),
          ),"""

if old in content:
    content = content.replace(old, new)
    with open(r'C:\Users\Merouan\Documents\Default Project\pharma-maroc-gold\frontend\lib\features\suppliers\supplier_connectivity_page.dart', 'w', encoding='utf-8') as f:
        f.write(content)
    print('REPLACED')
else:
    print('NOT FOUND')