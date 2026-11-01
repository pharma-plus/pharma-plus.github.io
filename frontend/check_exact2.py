with open(r'C:\Users\Merouan\Documents\Default Project\pharma-maroc-gold\frontend\lib\features\super_admin\role_management_page.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# The issue is at position 16819 area
# We need to change:
#           ],
#           const SizedBox(height: 16),
#           Row(
# to be inside the Column children, not outside

# Find the exact pattern
idx = content.find('           ],\n          const SizedBox(height: 16),\n          Row(')
if idx >= 0:
    print('Found at:', idx)
    print(repr(content[idx:idx+300]))
else:
    print('Pattern not found')
    # Try without exact spaces
    idx2 = content.find('],\n          const SizedBox(height: 16),\n          Row(')
    if idx2 >= 0:
        print('Found variant at:', idx2)
        print(repr(content[idx2:idx2+300]))