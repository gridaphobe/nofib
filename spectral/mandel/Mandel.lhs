%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%     This is for when it is used in the report      %%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%         When used as a standalone document         %%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
\begin{onlystandalone}
\begin{code}
module Mandel where
import Data.Complex -- 1.3
import PortablePixmap
default ()
\end{code}
\end{onlystandalone}

	%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
The Mandelbrot set is the set of complex numbers for which the values
of the polynomial
\begin{equation}
\label{poly}
f_c(z) = z^2 + c
\end{equation}
are connected\cite{falconer}. A graphical representation of this set
can be rendered by plotting for different points in the complex plane
an intensity that is proportional to either the rate of divergence of
the above polynomial, or a constant if the polynomial is found to converge.

We present a \DPHaskell{} implementation of the mandelbrot set in a bottom up
manner that can be decomposed into the following stages :

\begin{enumerate}
\item	First we generate an infinite list of complex numbers caused by
	applying the mandelbrot polynomial to a single complex number
	in the complex plane.
\item	Next we walk over the list, determining the rate of divergence of
	the list of complex numbers.
\item 	We parallelize the above stages, by mapping the composition
	of the preceeding functions over the complex plain.
\item	Lastly we describe how the complex plain is initialised, and the
	results are graphically rendered.
\end{enumerate}

	%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
\section{Generating the list}

\begin{code}
mandel::(Num a) => a -> [a]
mandel c = infiniteMandel
           where
		infiniteMandel = c : (map (\z -> z*z +c) infiniteMandel)
\end{code}

The definition of @mandel@ uses the numerically overloaded functions
@*@ and @+@; operationally it generates an infinite list of numbers caused by
itearting a number (i.e an object that has a type that belongs to class @Num@),
with the function @\z -> z*z +c@. For example the evaluation of ``@mandel 2@''
would result in the list of integers :

\begin{pseudocode}
[2, 6, 38, 1446, 2090918, 4371938082726, 19113842599189892819591078,
365338978906606237729724396156395693696687137202086, ^C{Interrupted!}
\end{pseudocode}

, whereas if the function were applied to the complex number\footnote{complex
numbers are defined in Haskells prelude as the algebraic data type
@data (RealFloat a) => Complex a = a :+ a@} (1.0 :+ 2.0), then the functions
behaviour would be equivalent of the mandelbrot polynomial(\ref{poly}) in
which \hbox{$c = 1.0 + i2.0$} :

\begin{pseudocode}
[(1.0 :+ 2.0), (-2.0 :+ 6.0), (-31.0 :+ -22.0), (478.0 :+ 1366.0),
(-1637471.0 :+ 1305898.0), ^C{Interrupted!}
\end{pseudocode}

	%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
\section{Walking the list}

``@whenDiverge@'' determines the rate of divergence of a list of complex
numbers. If diveregence cannot be proved within a fixed number of
iteration of the mandelbrot polynomial, convergence is assumed.
This process is encoded in \DPHaskell{} by @take@ing a @limit@ of
complex numbers off the infinite stream generated by the mandel function.
This {\em finite} list is then traversed, each element of which is checked
for divergence.

\begin{code}
whenDiverge::  Int -> Double -> Complex Double -> Int
whenDiverge limit radius c
  = walkIt (take limit (mandel c))
  where
     walkIt []     = 0					 -- Converged
     walkIt (x:xs) | diverge x radius  = 0		 -- Diverged
	           | otherwise		 = 1 + walkIt xs -- Keep walking
\end{code}

\begin{equation}
\|x + iy\|_{2} = \sqrt{x^2 + y^2}
\end{equation}

We assume that divergence occurs if the norm ($\|x\|_{2}$) of a
complex number exceeds the radius of the region to be rendered.
The predicate @diverge@ encodes the divergence check, where @magnitude@
is the prelude function that calculates the euclidean norm
($\|x\|_{2}$) of a complex number.

\begin{code}
-- VERY IMPORTANT FUNCTION: sits in inner loop

diverge::Complex Double -> Double -> Bool
diverge cmplx radius =  magnitude cmplx > radius
\end{code}

	%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
\section{Parallelising the mandelbrot set}

The mandelbrot set can be trivially parallelised by ``mapping''
the @whenDiverge@ function over a complex plain of values.


\begin{code}
parallelMandel:: [Complex Double] -> Int -> Double -> [Int]
parallelMandel mat limit radius
   = map (whenDiverge limit radius) mat
\end{code}

\section{Initialisation of data and graphical rendering.}

We render the mandelbrot set by producing a PixMap file that
provides a portable representation of a 32bit RGB picture. The format of
this file is outside the scope of this paper, but we provide an interface
to this representation by defining an abstract data type @Pixmap@ that
has the functions @createPixmap@ (signature shown below), and @show@
defined (overloaded function from class @Text@).

\begin{pseudocode}
createPixmap :: Integer -> 		-- The width of the Pixmap
		Integer -> 		-- The height of the Pixmap
		Int -> 			-- The depth of of the RGB colour
		[(Int,Int,Int)]	->	-- A matrix of the RGB colours
		PixMap
\end{pseudocode}

@mandelset@ controls the evaluation and rendering of the mandelbrot set. The
function requires that a ``viewport'' on the complex plane is defined,
such that the region bounded by the viewport will be rendered in a ``Window''
represented by the pixmap.
\begin{code}
mandelset::Double -> 			-- Minimum X viewport
	   Double -> 			-- Minimum Y viewport
	   Double -> 			-- Maximum X viewport
	   Double ->			-- maximum Y viewport
	   Integer -> 			-- Window width
	   Integer -> 			-- Window height
	   Int -> 			-- Window depth
	   PixMap			-- result pixmap
mandelset x y x' y' screenX screenY lIMIT
   = createPixmap screenX screenY lIMIT (map prettyRGB result)
   where
\end{code}

@windowToViewport@ is a function that is defined within the scope of the
mandelset function (therefore arguments to mandelset will be in scope). The
function represents the relationship between the pixels in a window,
and points on a complex plain.

\begin{code}
      windowToViewport s t
           = ((x + (((coerce s) * (x' - x)) / (fromInteger screenX))) :+
	      (y + (((coerce t) * (y' - y)) / (fromInteger screenY))))

      coerce::Integer -> Double
      coerce  s   = encodeFloat (toInteger s) 0
\end{code}

The complex plain is initialised, and the mandelbrot set is calculated.
\begin{code}
      result = parallelMandel
		  [windowToViewport s t | t <- [1..screenY] , s<-[1..screenX]]
 		  lIMIT
		  ((max (x'-x) (y'-y)) / 2.0)

      prettyRGB::Int -> (Int,Int,Int)
      prettyRGB s = let t = (lIMIT - s) in (s,t,t)
\end{code}