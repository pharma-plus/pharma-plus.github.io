with open(r'C:\Users\Merouan\Documents\Default Project\pharma-maroc-gold\import_cnops_excel.py', 'r', encoding='utf-8') as f:
    content = f.read()

# Replace all non-ASCII characters
replacements = {
    '\ufe0f': '',      # variation selector
    '\u2022': '*',     # bullet
    '\u2013': '-',     # en dash
    '\u2014': '--',    # em dash
    '\u2018': "'",     # left single quote
    '\u2019': "'",     # right single quote
    '\u201c': '"',     # left double quote
    '\u201d': '"',     # right double quote
    '\u2026': '...',   # ellipsis
    '\u00e0': 'a',     # a grave
    '\u00e9': 'e',     # e acute
    '\u00ea': 'e',     # e circumflex
    '\u00ee': 'i',     # i circumflex
    '\u00f4': 'o',     # o circumflex
    '\u00fb': 'u',     # u circumflex
    '\u00e7': 'c',     # c cedilla
    '\u00e8': 'e',     # e grave
    '\u00f9': 'u',     # u grave
    '\u00ef': 'i',     # i diaeresis
    '\u00fc': 'u',     # u diaeresis
    '\u2795': '[+]',   # plus
    '\u274c': '[X]',   # cross
    '\u26a0': '[!]',   # warning
    '\u2705': '[OK]',  # check
    '\u27a1': '[->]',  # arrow
    '\u2753': '[?]',   # question
    '\u2754': '[!]',   # exclamation
    '\u2755': '[!!]',  # double exclamation
    '\u2757': '[!]',   # heavy exclamation
    '\u274c': '[X]',   # cross
    '\u274e': '[X]',   # negative cross
    '\u2796': '[-]',   # minus
    '\u2797': '[x]',   # multiply
    '\u27b0': '[*]',   # asterisk
    '\u27bf': '[*]',   # asterisk
    '\u2b06': '[^]',   # up
    '\u2b07': '[v]',   # down
    '\u2b50': '[*]',   # star
    '\u2b55': '[O]',   # circle
    '\U0001f4d6': '[BOOK]',
    '\U0001f4c6': '[CHART]',
    '\U0001f4dd': '[MEMO]',
    '\U0001f4c4': '[PAGE]',
    '\U0001f4cc': '[CLIP]',
    '\U0001f4d1': '[BOOKMARK]',
    '\U0001f4a1': '[IDEA]',
    '\U0001f4ca': '[CHART]',
    '\U0001f4cb': '[CLIPBOARD]',
    '\U0001f4c8': '[CHART2]',
    '\U0001f4c9': '[CHART3]',
    '\U0001f4ca': '[CHART]',
    '\U0001f501': '[REFRESH]',
    '\U0001f514': '[BELL]',
    '\U0001f515': '[BELL2]',
}

for k, v in replacements.items():
    content = content.replace(k, v)

# Also clean any remaining non-ASCII in string literals
import re

def clean_string(match):
    s = match.group(0)
    quote = s[0]
    inner = s[1:-1]
    cleaned = ''.join(ch if ord(ch) < 128 else '?' for ch in inner)
    return quote + cleaned + quote

# Pattern for double-quoted strings
content = re.sub(r'"[^"]*"', clean_string, content)
# Pattern for single-quoted strings
content = re.sub(r"'[^']*'", clean_string, content)

with open(r'C:\Users\Merouan\Documents\Default Project\pharma-maroc-gold\import_cnops_excel.py', 'w', encoding='utf-8') as f:
    f.write(content)

print('Done cleaning all non-ASCII')