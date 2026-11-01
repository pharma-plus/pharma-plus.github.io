with open(r'C:\Users\Merouan\Documents\Default Project\pharma-maroc-gold\frontend\lib\features\super_admin\super_admin_crm_page.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Fix _InvoiceCard
old = """      ]);\n    );\n  );\n  }\n}\n\nclass _TicketCard"""

new = """      ]);\n    )\n  );\n  }\n}\n\nclass _TicketCard"""

if old in content:
    content = content.replace(old, new)
    with open(r'C:\Users\Merouan\Documents\Default Project\pharma-maroc-gold\frontend\lib\features\super_admin\super_admin_crm_page.dart', 'w', encoding='utf-8') as f:
        f.write(content)
    print('REPLACED InvoiceCard')
else:
    print('InvoiceCard NOT FOUND')

# Fix _TicketCard
old2 = """      ]);\n    );\n  );\n  }\n}\n\nclass _EmptyState"""

new2 = """      ]);\n    )\n  );\n  }\n}\n\nclass _EmptyState"""

if old2 in content:
    content = content.replace(old2, new2)
    with open(r'C:\Users\Merouan\Documents\Default Project\pharma-maroc-gold\frontend\lib\features\super_admin\super_admin_crm_page.dart', 'w', encoding='utf-8') as f:
        f.write(content)
    print('REPLACED TicketCard')
else:
    print('TicketCard NOT FOUND')