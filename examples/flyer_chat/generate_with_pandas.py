# generate_and_fix.py
import pandas as pd
import json
import os
import re

def contains_chinese(text):
    return bool(re.search(r'[\u4e00-\u9fff]', str(text)))

# === 第一步：用 pandas 生成主词典 ===
print("1. 加载 ecdict.csv...")
df = pd.read_csv('ecdict.csv', on_bad_lines='skip', encoding='utf-8')

dictionary = {}
count = 0
max_words = 80000

for _, row in df.iterrows():
    try:
        word = str(row['word']).strip()
        trans = str(row['translation']).strip()
    except:
        continue

    if word in ('nan', '') or trans in ('nan', '', 'NULL'):
        continue

    if contains_chinese(trans):
        clean = trans.replace('\n', '；').replace('\r', '').strip()
        dictionary[word] = clean
        count += 1
        if count >= max_words:
            break

print(f"2. 主词典生成完成: {len(dictionary)} 词条")

# === 第二步：手动确保 hello 存在 ===
hello_trans = None

# 方法 A: 从原始 CSV 中用 grep + awk 提取（最可靠）
import subprocess
try:
    result = subprocess.run(
        ["grep", "-m1", "^hello,", "ecdict.csv"],
        capture_output=True,
        text=True,
        encoding='utf-8'
    )
    if result.returncode == 0 and result.stdout.strip():
        line = result.stdout.strip()
        # 用 csv 模块解析这一行（安全）
        import csv
        from io import StringIO
        reader = csv.reader(StringIO(line))
        row = next(reader)
        if len(row) > 3:
            hello_trans = row[3].strip().replace('\n', '；').replace('\r', '').strip()
except Exception as e:
    print("⚠️ 手动提取 hello 失败:", e)

# 方法 B: 兜底
if not hello_trans or not contains_chinese(hello_trans):
    hello_trans = "你好；喂"

dictionary['hello'] = hello_trans
print("3. 已确保包含 hello:", hello_trans)

# === 保存 ===
os.makedirs('assets', exist_ok=True)
with open('assets/dict_en_zh.json', 'w', encoding='utf-8') as f:
    json.dump(dictionary, f, ensure_ascii=False)

print("✅ 完成！")