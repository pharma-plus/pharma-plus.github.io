with open(r'C:\Users\Merouan\Documents\Default Project\pharma-maroc-gold\frontend\lib\features\super_admin\role_management_page.dart', 'r', encoding='utf-8') as f:
    content = f.read()

old = """]),
            ),
          ],
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(S.t('cancel', locale))),
            const SizedBox(width: 12),
            FilledButton(onPressed: _saving ? null : () { _save(); widget.onSaved(); }, child: Text(S.t('save', locale))),
          ],
        ),
      ],
    ),
  );
}
}"""

new = """]),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(onPressed: () => Navigator.pop(context), child: Text(S.t('cancel', locale))),
              const SizedBox(width: 12),
              FilledButton(onPressed: _saving ? null : () { _save(); widget.onSaved(); }, child: Text(S.t('save', locale))),
            ],
          ),
        ],
      ),
    ),
  );
}
}"""

if old in content:
    content = content.replace(old, new)
    with open(r'C:\Users\Merouan\Documents\Default Project\pharma-maroc-gold\frontend\lib\features\super_admin\role_management_page.dart', 'w', encoding='utf-8') as f:
        f.write(content)
    print('REPLACED')
else:
    print('NOT FOUND')
    # Find the exact text
    idx = content.find('const SizedBox(height: 16)')
    if idx >= 0:
        print('Found at:', idx)
        print(content[idx:idx+500])