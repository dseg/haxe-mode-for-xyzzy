("name" . "shield.jp")
("author" . "Daichi Shinozaki <shinozaki.daichi@classmethod.jp>")
("url" . "http://github.com/dseg/")
("description" . "")
("packages"
 (("name" . "haxe-mode")
  ("version" . "0.1")
  ("author" . "Daichi Shinozaki <shinozaki.daichi@classmethod.jp>")
  ("file" . "haxemode01.zip")
  ("src" . "http://shield.jp/~dseg/xyzzy/haxemode01.zip")
  ("description" . "A major-mode for haXe programming language.")
  ("category" "Editing")
  ("md5" . "5eea487c22974f246fd4bacb33acddb3")
  ("time" . 3482149579)
  ("depends" "xml-parser-modoki")
  ("changes" . "
2010-05-?? v0.1 initial release.
")
  ("notice" . "")
  ("load-after-install" . "")
  ("load-before-uninstall" . ""))

 (("name" . "actionscript-mode")
  ("version" . "0.4")
  ("author" . "Daichi Shinozaki <shinozaki.daichi@classmethod.jp>")
  ("file" . "asmode04.zip")
  ("src" . "http://shield.jp/~dseg/xyzzy/asmode04.zip")
  ("description" . "A major-mode for ActionScript 1.0/2.0 code.")
  ("category" "Editing")
  ("md5" . "095fbab350cbe48d1432c47930c41a15")
  ("time" . 1136869126)
  ("depends")
  ("changes" . "
Fri Jan 6 2006 (v0.4)
- UTF-8で*自動*保存する際に選択する文字コードを、「UTF8」にした。
  v0.3で文字コードを「UTF8n」にしたが、まずいことがわかったので。
  (ActionScript2.0のクラスファイルをコンパイルする際、
  文字コードが「UTF8n」だとコンパイルできない場合がある)
  また、UTF8での自動保存を有効にしていた場合、
  xyzzyで「名前を付けて保存」などを選び、文字コードを明示的に指定した際に、
  その文字コードが無視され、いつでもUTF8で保存されてしまう不具合を修正。
- F1キーで、ActionScriptのヘルプを開けるようにした。
- ActionScript 2.0の、明示的に型付けされて宣言される変数の型名補完、
  ActionScript 1.0での、「型ヒント接辞子」を用いて名付けられた変数
  (例: var s_str)の、メソッドとプロパティの補完をできるようにした。
- グローバル関数等に対し、MacromediaのIDEのActionScriptエディタ互換の
  コードヒントを、ポップアップ形式で表示するようにした。

Thu Dec 9 2005 - (v0.3)
- Ming/MTASCを使ったシンタックスチェック機能を追加
- 配布zipにバイトコンパイル済みのファイルを含めるようにした。
- MTASC/Mingを使ったActionScript 2.0/1.0のシンタックスチェックが可能に
- MacromediaのFlash IDE互換のキーバインディングを60種類弱追加した。

Mon Dec 05 2005 (v0.2)
- Flash8で追加されたキーワードを追加。
- キーワードのハイライトのために記述していた正規表現のパターンをほぼ全て削除し、
　キーワードファイル($XYZZY_HOME/etc/ActionScript)に移した。
  簡素化と高速化のため。
- インデント時、タブを多く使うようにした。
  (本当はタブのみでインデントしたい。MacromediaのFlash IDEと合わせたいので)
- コード補完時の挙動を、Emacs風なものから、popup-listを使うよう変更した。

Sat Aug 10 2004 (v0.1)
- 初版公開。
"))
