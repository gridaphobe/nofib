module Main ( mainPrimIO ) where

import PreludeGlaST

data CList = CNil | CCons Int# CList

mk :: Int# -> CList
mk n  = if (n ==# 0#)
	then CNil
	else CCons 1# (mk (n `minusInt#` 1#))

clen :: CList -> Int#
clen CNil = 0#
clen (CCons _ cl) = 1# +# (clen cl)

mainPrimIO = case (clen list4) of
		len4 ->
		  case (len4 +# len4) of
		    8# -> finish 65#	-- 'A'
		    _  -> finish 66#	-- 'B'
      where
      list4	= mk 4#

finish :: Int# -> PrimIO ()
finish n = _ccall_ putchar (C# (chr# n)) `seqPrimIO` returnPrimIO ()