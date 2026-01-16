{\rtf1\ansi\ansicpg936\cocoartf2821
\cocoatextscaling0\cocoaplatform0{\fonttbl\f0\fnil\fcharset0 HelveticaNeue;}
{\colortbl;\red255\green255\blue255;\red0\green0\blue0;}
{\*\expandedcolortbl;;\cssrgb\c0\c0\c0;}
\paperw11900\paperh16840\margl1440\margr1440\vieww11520\viewh8400\viewkind0
\deftab720
\pard\pardeftab720\partightenfactor0

\f0\fs28 \cf0 \expnd0\expndtw0\kerning0
\outl0\strokewidth0 \strokec2 # export_json.py\
import sys\
import os\
import json\
\
# \uc0\u23558 \u24403 \u21069 \u30446 \u24405 \u21152 \u20837  Python \u36335 \u24452 \u65292 \u20197 \u20415 \u23548 \u20837  stardict\
sys.path.append(os.getcwd())\
\
from stardict import DictCsv\
\
def main():\
    # \uc0\u20351 \u29992 \u23448 \u26041  DictCsv \u31867 \u21152 \u36733  ecdict.csv\
    print("\uc0\u27491 \u22312 \u21152 \u36733  ecdict.csv...")\
    d = DictCsv()\
    d.load('ecdict.csv')  # \uc0\u33258 \u21160 \u35782 \u21035 \u23383 \u27573 \
    \
    dictionary = \{\}\
    count = 0\
    max_words = 60000  # \uc0\u21487 \u35843 \u25972 \
    \
    # \uc0\u36941 \u21382 \u25152 \u26377 \u35789 \u26465 \
    for word in d.get_words():\
        entry = d.query(word)\
        if not entry:\
            continue\
            \
        trans = entry.get('translation', '').strip()\
        if trans and trans != 'NULL':\
            # \uc0\u28165 \u29702 \u25442 \u34892 \u65288 \u23448 \u26041 \u25968 \u25454 \u20013  \\n \u26159 \u30495 \u23454 \u25442 \u34892 \u65289 \
            clean_trans = trans.replace('\\n', '\uc0\u65307 ').replace('\\r', '').strip()\
            dictionary[word] = clean_trans\
            count += 1\
            \
            if count >= max_words:\
                break\
                \
        if count % 10000 == 0:\
            print(f"\uc0\u24050 \u22788 \u29702  \{count\} \u20010 \u35789 \u26465 ...")\
\
    # \uc0\u20445 \u23384 \u21040  assets/dict_en_zh.json\
    output_path = 'assets/dict_en_zh.json'\
    with open(output_path, 'w', encoding='utf-8') as f:\
        json.dump(dictionary, f, ensure_ascii=False)\
    \
    print(f"\uc0\u9989  \u25104 \u21151 \u23548 \u20986  \{len(dictionary)\} \u20010 \u35789 \u26465 \u21040  \{output_path\}")\
\
if __name__ == '__main__':\
    main()}