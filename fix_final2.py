with open(r'C:\Users\Merouan\Documents\Default Project\pharma-maroc-gold\frontend\lib\features\suppliers\supplier_connectivity_page.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Fix the _SupplierCard build method - need to add closing bracket for outer Row children list
old = """        ]),
      ),
    )
  );
  }
}

class _AddSupplierDialog"""

new = """        ]),
      ),
    ],
    ),
    );
  }
}

class _AddSupplierDialog"""

if old in content:
    content = content.replace(old, new)
    print('Fixed!')
else:
    print('NOT FOUND')
    idx = content.find('class _AddSupplierDialog')
    if idx >= 0:
        print('Found at:', idx)
        print(repr(content[idx-200:idx+50]))

with open(r'C:\Users\Merouan\Documents\Default Project\pharma-maroc-gold\frontend\lib\features\suppliers\supplier_connectivity_page.dart', 'w', encoding='utf-8') as f:
    f.write(content)
print('Done')