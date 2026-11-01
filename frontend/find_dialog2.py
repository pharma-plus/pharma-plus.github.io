with open(r'C:\Users\Merouan\Documents\Default Project\pharma-maroc-gold\frontend\lib\features\super_admin\role_management_page.dart', 'r', encoding='utf-8') as f:
    content = f.read()

idx = content.find('class _PermissionMatrixDialogState')
idx2 = content.find('Widget build(BuildContext context)', idx)
print(content[idx2:idx2+2000])