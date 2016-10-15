#!/bin/bash
#
# catcsv.sh 1.01 (c)F.MORIMOTO 2016
#
# usage:
#    sh catcsv.sh func-name [args...] [csv-files]
#    sh catcsv.sh file-name [args...] [csv-files]
#    sh catcsv.sh code [args...] [csv-files]
#
#    func-name：ビルトイン関数
#
#               dump       :各カラムごとに出力
#               print      :カンマ区切りデータを、「|」で区切って出力
#               csv2tsv    :カンマ区切りデータを、TSVで出力
#               access2tsv :空白で区切って、TSVで出力
#
#                       出力の際に、改行は\\n、タブは\\t、\は\\に置き換える
#                       この変換を抑制するには、-v NOESC=1 を引数に渡す
#
#    file-name：自作出力プログラムファイル名
#
#               例： your.awk
#
#       以下の3つの関数を定義すること
#               function doBegin() {...} 処理開始前に呼び出される
#               function doLine(line,num,csv) {...} line:行番号 num:カラム数,csv[i]: カラ ムデータ
#               function doEnd() {...} 最終行処理後に呼び出される
#
#    code：自作出力awkプログラムコード
#
#               function doLine(line,num,csv)  { ... } の...の部分。line:行番号 num:カラム数,csv[i]: カラムデータ
#
#               例： 'for(i=1;i<=num:csv[i]){print i"="csv[i];}'
#
#               ビルトインユーティリティ関数
#                       xjoin(arr,sep)： arrをsepを挟んで連結する
#
#   args： [-v awkスクリプト内変数名=値] このセットを空白で区切って繰り返す
#
#       定義済みawkスクリプト内変数
#       ISEP ：入力ファイル区切り文字(1文字)。正規表現は不可。your.awk内のdoBegin{}で定義 しても良い
#       OSEP：出力ファイル区切り文字。
#       DBG ：1 デバッグ表示する 0 表示しない
#
#       例: -v "ISEP=," -v 'OSEP=<br>' -v DBG=1
#
# ex:
#       cat /etc/httpd/logs/access_log | sh catcsv.sh access2tsv
#       sh catcsv.sh access2tsv /etc/httpd/logs/access_log
#       sh x.sh 'for(i=1;i<=n:c[i]){print xjoin(c,"|");}' -v ISEP="," text.csv
#
# 技術情報
#       awkスクリプト内グローバル変数名
#          LIN: 処理中の論理行番号
#          IDX: 処理中のカラム番号、兼、最大カラム番号
#          DATA: 処理中の行データ。doLineを呼び出すときは、空になっている
#          CSV： カラムデータ保持配列(CSV[1]...CSV[IDX])
#
#       確認したgawkのバージョン: gawk 3.1.5
#

AWKSCRIPT=/tmp/awkscript$$.txt

if [ "$1" == "dump" -o "$1" == "debug" ]; then
        if [ "$1" == "debug" ]; then
                AG=(-v 'OSEP=|'  -v "ISEP=," -v "DBG=1")
        fi
        cat > $AWKSCRIPT <<'EOS'
#ビルトイン関数(dump)
function doBegin() {
}
function doLine(line,num,csv,    i) {
        for(i=1;i<=num;i++) {
                print "COL"i"=["csv[i]"]";
        }
        print "";
}
function doEnd() {
}
EOS
elif [ "$1" == "print" -o "$1" == "csv2tsv" -o "$1" == "access2tsv" ]; then
        if [ "$1" == "print" ]; then
                AG=(-v 'OSEP=|'  -v "ISEP=,")
        elif [ "$1" == "access2tsv" ]; then
                AG=(-v "OSEP=\t" -v "ISEP= ")
        else
                AG=(-v "OSEP=\t" -v "ISEP=,")
        fi

        cat > $AWKSCRIPT <<'EOS'
#ビルトイン関数(csv2tsv)
#csvをtsvにして出力
function doBegin() {
        if(ISEP=="") {
                ISEP=",";
        }
        if(OSEP=="") {
                OSEP="\t";
        }
}
function doLine(line,num,csv,  i) { # 配列csv[1]からcsv[N]までデータが入っている
        print xjoin(csv,OSEP);
}
function doEnd() {
}
EOS
else
        if [ -f "$1" ]; then
                cat $1 > $AWKSCRIPT
        else
                echo 'function doBegin() {}'        > $AWKSCRIPT
                echo 'function doLine(line,num,csv) {'  >> $AWKSCRIPT
                echo "$1"                          >> $AWKSCRIPT
                echo '}'                           >> $AWKSCRIPT
                echo 'function doEnd() {}'         >> $AWKSCRIPT
        fi
fi

cat >> $AWKSCRIPT <<'EOS'
#配列の要素の個数を数える
function xsize(arr,    n,i) {
        n=0;
        for (i in arr) {
                n++;
        }
        return n;
}
#配列の要素をsepをはさんで連結する
function xjoin(arr, sep,      r, i)
{
    r = arr[1];
    for (i = 2; i <= xsize(arr); i++) {
        r = r""sep""arr[i];
    }
    return r;
}
#csv内の\,\t,\nをエスケープシーケンスに置き換える
function xescape(arr,    n,i) {
        n = xsize(arr);
        for(i=1;i<=n;i++) {
                if(NOESC!=1) {
                        # エスケープ処理
                        gsub(/\\/,"\\\\",arr[i]);
                        gsub(/\t/,"\\t",arr[i]);
                        gsub(/\n/,"\\n",arr[i]);
                }
        }
}
function main(    n,arr,i,x,r,a) {
        if(DBG == 1) {
                print "debug:LINE:"NR":"$0;
        }
        # awkの区切りを使うと、改行とカンマのどちらが原因か
        # 分からないので、自前で分割する
        n= split($0,arr,ISEP);
        for(i=1;i<=n;i++) {
                DATA=DATA""arr[i];

                # ダブルクオートの数を数え、奇数なら次のデータと連結する
                x=DATA; #置き換えをして何個置き換えたかを数えるので仮の値を用意する
                r = gsub(/\"/,"X",x);
                if((r % 2) == 1) {
                        # 「"」が閉じていない
                        if(i==n) {
                                # 改行が原因なら次の行と連結。
                                DATA=DATA"\n";
                        } else  {
                                #カンマが原因なら次のカラムと連結
                                DATA=DATA""ISEP;
                        }
                } else {
                        # 1カラム分のデータが揃った

                        # 「"」と「"」に囲まれた範囲にある「""」を「"」に置き換える
                        # (gawk3.1.5の正規表現でスマートに処理できないものか？)
                        a="x"DATA
                        while(a != DATA) {
                                a=DATA;
                                DATA=gensub(/\"/,"","1",a);
                                while(a != DATA) {
                                        a=DATA
                                        DATA=gensub(/^([^\"]*)(\"\")/,"\\1\v","1",a);
                                }
                                a=DATA
                                DATA=gensub(/\"/,"","1",a);
                        }
                        gsub(/\v/,"\"",DATA);

                        # 配列に格納
                        IDX++;
                        CSV[IDX]=DATA;
                        DATA="";
                }
        }
        if(DATA=="") {
                # 1行分のデータが揃ったので、処理関数を呼ぶ
                LIN++;
                xescape(CSV);
                doLine(LIN,IDX,CSV);

                # 変数を初期化
                delete CSV;
                IDX=0;
        } else {
                # 継続行の処理を行う
        }
}
function post() {
        if(DATA!="") {
                # 最終行の最後の"が閉じていないので強制的に閉じる
                # 行の途中で改行したと想定して付加した改行は不要なので除く
                gsub(/\n$/,"",DATA);

                # 最後のデータを配列に格納
                IDX++;
                CSV[IDX]=DATA;

                # 1行分のデータが揃ったので、処理関数を呼ぶ
                xescape(CSV);
                LIN++;
                doLine(LIN,IDX,CSV);
        }
        doEnd();
}
BEGIN {
        doBegin();
        DATA=""; # 1カラム分のデータを保存
        IDX=0;   # カラム位置
        LIN=0;   # 論理的行番号
        if(ISEP == "") {
                ISEP=","
        }
        if(OSEP == "") {
                OSEP="\t";
        }
        if(DBG == 1) {
                print "debug:DBG=[1]";
                print "debug:ISEP=["ISEP"]";
                print "debug:OSEP=["OSEP"]";
        }
}
{
        main();
}
END {
        post();
}
EOS

shift
awk -f $AWKSCRIPT "${AG[@]}" $*
rm $AWKSCRIPT

