# Dictionary data attribution

`cedict.sqlite` is a transformed, read-only extract of CC-CEDICT, published by
MDBG and maintained by CC-CEDICT contributors. CC-CEDICT builds on CEDICT,
Copyright (C) 1997, 1998 Paul Andrew Denisowski.

- Source: https://cc-cedict.org/editor/editor_export_cedict.php?c=gz
- Export date (UTC): 2026-11-07T03:55:59Z
- Source SHA-256: `8a506d01724a4f528db965bf3598efaf3be3ade121749f5c2730262996a80ad1`
- License: Creative Commons Attribution-ShareAlike 4.0 International,
  https://creativecommons.org/licenses/by-sa/4.0/

The export was filtered to the 3,500 simplified characters in the first-level
list of the 2013 *General Standard Chinese Characters* (通用规范汉字表). The database
stores their single-character CC-CEDICT pronunciations and two- or
three-character dictionary words composed of characters in that list. Pinyin
tone numbers were converted to tone marks; capitalization differences were
collapsed. No dictionary definitions were rewritten.

The character list is included at `scripts/data/common_3500.txt`. It was
digitized by the `shengdoushi/common-standard-chinese-characters-table`
project from the official Chinese character standard.

- Digitized list: https://github.com/shengdoushi/common-standard-chinese-characters-table/blob/master/level-1.txt
- List SHA-256: `79a6c710013cc86617d5db65871f59b2d67dee72415d380a2cc7145a51450fe4`
- Official standard: https://www.moe.gov.cn/jyb_sjzl/ziliao/A19/201306/t20130601_186002.html

The SQLite file is already generated and bundled with the app. No Python
script is needed to install or use it. The source URLs and SHA-256 checksums
above document the inputs used to create this copy.

The exported CC-CEDICT copy used here is the editor site's latest
non-verified export. The app must make this attribution and license link
accessible to users before distribution.
