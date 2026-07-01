import codecs
import json

file_path = 'lib/core/localization/app_localizations.dart'

with codecs.open(file_path, 'r', 'utf-8') as f:
    lines = f.readlines()

for i, line in enumerate(lines):
    if ':' in line:
        parts = line.split(':', 1)
        val = parts[1].strip()
        if '_' in val and val.startswith("'"):
            print(f'Line {i+1}: {line.strip()}')
