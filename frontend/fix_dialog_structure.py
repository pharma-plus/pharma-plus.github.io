with open(r'C:\Users\Merouan\Documents\Default Project\pharma-maroc-gold\frontend\lib\features\super_admin\role_management_page.dart', 'r', encoding='utf-8') as f:
    content = f.read()

old = """),\n            )),\n          ],\n        const SizedBox(height: 16),\n        Row(\n          mainAxisAlignment: MainAxisAlignment.end,\n          children: [\n            TextButton(onPressed: () => Navigator.pop(context), child: Text(S.t('cancel', locale))),\n            const SizedBox(width: 12),\n            FilledButton(onPressed: _saving ? null : () { _save(); widget.onSaved(); }, child: Text(S.t('save', locale))),\n          ],\n        ),\n      ],\n    ),"""

new = """),\n            )),\n          ],\n          const SizedBox(height: 16),\n          Row(\n            mainAxisAlignment: MainAxisAlignment.end,\n            children: [\n              TextButton(onPressed: () => Navigator.pop(context), child: Text(S.t('cancel', locale))),\n              const SizedBox(width: 12),\n              FilledButton(onPressed: _saving ? null : () { _save(); widget.onSaved(); }, child: Text(S.t('save', locale))),\n            ],\n          ),\n        ],\n      ),"""

if old in content:
    content = content.replace(old, new)
    with open(r'C:\Users\Merouan\Documents\Default Project\pharma-maroc-gold\frontend\lib\features\super_admin\role_management_page.dart', 'w', encoding='utf-8') as f:
        f.write(content)
    print('REPLACED')
else:
    print('NOT FOUND')