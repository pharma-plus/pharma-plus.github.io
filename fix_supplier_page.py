with open(r'C:\Users\Merouan\Documents\Default Project\pharma-maroc-gold\frontend\lib\features\suppliers\supplier_connectivity_page.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Fix 1: Fix the _SupplierCard build method closing brackets
old_supplier_card = """        ]),
      ),
    );
  }
}

class _AddSupplierDialog extends StatefulWidget {"""

new_supplier_card = """        ]),
      ),
    );
  )
  );
  }
}

class _AddSupplierDialog extends StatefulWidget {"""

if old_supplier_card in content:
    content = content.replace(old_supplier_card, new_supplier_card)
    print('Fixed _SupplierCard closing brackets')
else:
    print('SupplierCard pattern not found')

# Fix 2: Fix _AddSupplierDialogState.build closing brackets
old_add_dialog = """            ],
        ),
      ),
    );
  }
}

  Future<void> _save() async {"""

new_add_dialog = """            ],
        ),
      ),
    ),
    );
  }
}

  Future<void> _save() async {"""

if old_add_dialog in content:
    content = content.replace(old_add_dialog, new_add_dialog)
    print('Fixed _AddSupplierDialog closing brackets')
else:
    print('AddDialog pattern not found')

# Fix 3: Fix _EditSupplierDialogState.build closing brackets
old_edit_dialog = """            ],
        ),
      ),
    );
  }
}

  Future<void> _save() async {"""

new_edit_dialog = """            ],
        ),
      ),
    ),
    );
  }
}

  Future<void> _save() async {"""

if old_edit_dialog in content:
    content = content.replace(old_edit_dialog, new_edit_dialog)
    print('Fixed _EditSupplierDialog closing brackets')
else:
    print('EditDialog pattern not found')

with open(r'C:\Users\Merouan\Documents\Default Project\pharma-maroc-gold\frontend\lib\features\suppliers\supplier_connectivity_page.dart', 'w', encoding='utf-8') as f:
    f.write(content)

print('Done')