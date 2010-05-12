XYZZY = xyzzy.exe
site-lisp/*.lc: site-lisp/*.l
	@$(XYZZY) -q -no-site-file -batch -eval "(and (byte-compile-file \"$<\") (kill-xyzzy))"
