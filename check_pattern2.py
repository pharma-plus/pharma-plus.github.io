with open(r'C:\Users\Merouan\Documents\Default Project\pharma-maroc-gold\frontend\lib\features\suppliers\supplier_connectivity_page.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# The exact pattern from the error context
old = """        ]),
      ),
    )
  );
  }
}

class _AddSupplierDialog"""

new = """        ]),
      ),
    ),
    );
  }
}

class _AddSupplierDialog"""

# Try to find and replace using the exact context
idx = content.find('class _AddSupplierDialog')
if idx >= 0:
    # Look for the pattern before it
    before = content[idx-200:idx]
    print('Before context:')
    print(repr(before[-300:]))
    
    # Try to find the exact old pattern
    old_pattern = """        ]),\n      ),\n    )\n  );\n  }\n}\n\nclass _AddSupplierDialog"""
    if old_pattern in content:
        print('Found exact pattern')
    else:
        # Try to find the closest match
        idx2 = content.rfind('        ]),\n      ),\n    )\n  );\n  }\n}\n\nclass _AddSupplierDialog', 0, idx)
        if idx2 >= 0:
            print('Found at:', idx2)
        else:
            print('Not found')

with open(r'C:\Users\Merouan\Documents\Default Project\pharma-maroc-gold\frontend\lib\features\suppliers\supplier_connectivity_page.dart', 'w', encoding='utf-8') as f:
    f.write(content)
print('Done')