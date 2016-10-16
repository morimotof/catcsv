## catcsv.sh とは

csvファイルを単純なキーワードで検索する場合はgrepを使えば十分な結果を得られるが、
あるカラムの値に応じて別のカラムを検索する、といったような少し複雑な条件で検索
するような場合は、awkを使いたくなる。
しかし、データにカンマが含まれる場合や、改行が含まれる場合は、awkといえども
そお単純には行かない。

catcsv.shは、csvファイルの論理的な1行をカラム毎に分解し、awkで処理を行う
プログラムを支援するツールである。

## catcsv.shの利用例

catcsv.shは3つの使い方がある。

### 1.組み込み関数

1つ目は、組み込み関数を使ってcsvファイルの処理を行う方法で、

```
dump       :各カラムごとに出力
print      :カンマ区切りデータを、「|」で区切って出力
csv2tsv    :カンマ区切りデータを、TSVで出力
access2tsv :空白で区切って、TSVで出力
```

の4つが定義されている。
呼び出し方の一般形式は、

`sh catcsv.sh func-name [args...] [csv-files]`

である。func-nameに上記の、dump,print,csv2tsv,access2tsvのいずれか
を指定する。argsには、catcsvの内部で呼び出しているawkへのパラメーターを
指定する。
たとえば、apacheのaccess_logをtsv形式で出力するには、

`sh catcsv.sh access2tsv /etc/httpd/logs/access_log`

とする。

### 2.awk関数を記述したファイルを指定

2つ目は、awk関数を記述したファイルを指定する方法である。
呼び出し方の一般形式は、

`sh catcsv.sh file-name [args...] [csv-files]`

である。file-nameにawk関数を記述したファイルを指定する。
このファイルには以下の3つの関数を定義することが必要で、特段の処理が
ない場合でも、関数の定義だけは記載する必要がある。

```
function doBegin() {...} 処理開始前に呼び出される
function doLine(line,num,csv) {...} line:行番号 num:カラム数,csv[i]: カラ ムデータ
function doEnd() {...} 最終行処理後に呼び出される
```

### 3.awkのコードを指定

3つ目は、awkのコードを引数に記述する方法ある。
呼び出し方の一般形式は、

`sh catcsv.sh code [args...] [csv-files]`

である。codeの箇所にawkのコードを記述する。
たとえば、

'for(i=1;i<=num:csv[i]){print i"="csv[i];}'

のようなコードを記述すると、「カラム番号=カラムの値」の形式で
表示される。
numおよびcsvはcatcsv.shの予約変数で、numは、カラムの最大値、csv[i]は、
i番目のカラムの値、が格納されている

### args

argsは、内部呼び出すawkへのパラメーターを指定するものであるが、具体的には
[-v awkスクリプト内変数名=値] のセットを空白で区切って繰り返すのもを想定している。
これを用いて、下記の定義済みawkスクリプト内変数の値を変更することができる。

```
ISEP ：入力ファイル区切り文字(1文字)。正規表現は不可。your.awk内のdoBegin{}で定義 しても良い
OSEP：出力ファイル区切り文字。
DBG ：1 デバッグ表示する 0 表示しない
```

## 技術情報

awkスクリプト内グローバル変数名

```
LIN:処理中の論理行番号
IDX:処理中のカラム番号、兼、最大カラム番号
DATA:処理中の行データ。doLineを呼び出すときは、空になっている
CSV：カラムデータ保持配列(CSV[1]...CSV[IDX])
```

## 対応可能なcsvフォーマット

- 区切り文字

カンマ区切り(ISEPを変更することで他のセパレータに対応可能)

- カラムにカンマ、改行をデータに含める場合

カラムにカンマ、改行をデータに含める場合は、カラム全体を"でくくる
```
例：
  入力が aaa,"bb,cc",dd の場合、[aaa][bb,cc][dd]の3つであると解釈する
```

- カラムにダブルクオートをデータに含める場合

カラムにダブルクオートをデータに含める場合は、ダブルクオートを""とした上でカラム全体を"でくくる

```
例：
  入力が aaa,"bb""cc",dd の場合、[aaa][bb"cc][dd] の3つであると解釈する
```

## その他

確認したawkのバージョン:gawk3.1.5
