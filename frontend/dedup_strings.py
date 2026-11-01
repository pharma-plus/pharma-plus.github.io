import re

# Read the file
with open(r'C:\Users\Merouan\Documents\Default Project\pharma-maroc-gold\frontend\lib\core\l10n\strings.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Find the three language sections
# Pattern: 'fr': { ... }, 'ar': { ... }, 'en': { ... }

# We need to parse each language section and deduplicate keys
def deduplicate_map_section(content, lang_marker):
    """Deduplicate keys in a language map section."""
    # Find the section start
    start_idx = content.find(f"'{lang_marker}': {{")
    if start_idx == -1:
        return content
    
    # Find the matching closing brace
    brace_count = 0
    in_string = False
    escape = False
    end_idx = -1
    
    for i in range(start_idx, len(content)):
        char = content[i]
        if escape:
            escape = False
            continue
        if char == '\\':
            escape = True
            continue
        if char == "'" and not escape:
            in_string = not in_string
            continue
        if not in_string:
            if char == '{':
                brace_count += 1
            elif char == '}':
                brace_count -= 1
                if brace_count == 0:
                    end_idx = i
                    break
    
    if end_idx == -1:
        return content
    
    # Extract the section
    section = content[start_idx:end_idx+1]
    
    # Parse key-value pairs
    # Pattern: 'key': 'value',
    pairs = {}
    # Simple regex to find key-value pairs (handles multiline values)
    # This is a simplified approach - we'll do line-by-line parsing
    
    lines = section.split('\n')
    new_lines = []
    seen_keys = set()
    
    for line in lines:
        # Check if line contains a key
        match = re.match(r"^\s*'([^']+)':\s*", line)
        if match:
            key = match.group(1)
            if key in seen_keys:
                # Skip duplicate
                continue
            seen_keys.add(key)
        new_lines.append(line)
    
    new_section = '\n'.join(new_lines)
    return content[:start_idx] + new_section + content[end_idx+1:]

# Deduplicate all three sections
for lang in ['fr', 'ar', 'en']:
    content = deduplicate_map_section(content, lang)

# Write back
with open(r'C:\Users\Merouan\Documents\Default Project\pharma-maroc-gold\frontend\lib\core\l10n\strings.dart', 'w', encoding='utf-8') as f:
    f.write(content)

print("Deduplication complete")