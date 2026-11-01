with open(r'C:\Users\Merouan\Documents\Default Project\pharma-maroc-gold\frontend\lib\features\super_admin\super_admin_crm_page.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Find _InvoiceCard end
idx = content.find('class _InvoiceCard')
if idx >= 0:
    # Look for the end of _ProspectCard
    idx2 = content.rfind('      ]);\n    );\n  );\n  }\n}\n\nclass _InvoiceCard', 0, idx)
    if idx2 >= 0:
        print('Found _ProspectCard end at:', idx2)
        print(repr(content[idx2:idx2+100]))
    else:
        print('_ProspectCard end not found')
    
    # Look for _InvoiceCard end
    idx3 = content.find('      ]);\n    );\n  );\n  }\n}\n\nclass _TicketCard', idx)
    if idx3 >= 0:
        print('Found _InvoiceCard end at:', idx3)
        print(repr(content[idx3:idx3+100]))
    else:
        print('_InvoiceCard end not found')
    
    # Look for _TicketCard end
    idx4 = content.find('      ]);\n    );\n  );\n  }\n}\n\nclass _EmptyState', idx)
    if idx4 >= 0:
        print('Found _TicketCard end at:', idx4)
        print(repr(content[idx4:idx4+100]))
    else:
        print('_TicketCard end not found')