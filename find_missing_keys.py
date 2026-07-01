import os
import re
import codecs

lib_dir = 'lib'
loc_file = 'lib/core/localization/app_localizations.dart'

# Extract all keys from app_localizations.dart 'en' section
with codecs.open(loc_file, 'r', 'utf-8') as f:
    loc_text = f.read()

# Very basic extraction of keys from the file (this just grabs everything left of a colon in single quotes)
existing_keys = set(re.findall(r"'(.*?)'\s*:", loc_text))

missing_keys = set()

# Walk through all dart files and find .tr(context) calls
for root, _, files in os.walk(lib_dir):
    for file in files:
        if file.endswith('.dart'):
            path = os.path.join(root, file)
            with codecs.open(path, 'r', 'utf-8') as f:
                content = f.read()
                
                # match 'some_key'.tr(context)
                matches = re.findall(r"'([^']+)'\.tr\(", content)
                matches_double = re.findall(r'"([^"]+)"\.tr\(', content)
                
                for m in matches + matches_double:
                    if m not in existing_keys:
                        missing_keys.add(m)

if missing_keys:
    print("Found missing keys:")
    for k in sorted(list(missing_keys)):
        if '_' in k:
            print(k)
else:
    print("No missing keys found.")
