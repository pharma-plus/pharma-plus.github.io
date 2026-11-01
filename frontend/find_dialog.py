with open(r'C:\Users\Merouan\Documents\Default Project\pharma-maroc-gold\frontend\lib\features\super_admin\role_management_page.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Find the PermissionMatrixDialog section
idx = content.find('class _PermissionMatrixDialogState')
if idx >= 0:
    # Find the Dialog build method in this class
    idx2 = content.find('Widget build(BuildContext context)', idx)
    if idx2 >= 0:
        print('Dialog build at:', idx2)
        print(content[idx2:idx2+800])
else:
    print('Not found')