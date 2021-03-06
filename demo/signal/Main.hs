{- | Script to demonstrate Calculations and other Operations on Signals -}

-- module Demo_Signal where

import qualified EFA.Signal.Plot as Plot

import qualified EFA.Signal.Signal as S
import EFA.Signal.SignalFill ((.-), (./), (.*))
import EFA.Signal.Signal (PSignal, TSignal, Scal, FFSignal)

import EFA.Utility.Async (concurrentlyMany_)

import EFA.Signal.Typ (Typ, A, D, P, N, Tt)

import qualified Graphics.Gnuplot.Advanced as GnuPlot
import qualified Graphics.Gnuplot.Terminal.Default as DefaultTerm
import qualified Graphics.Gnuplot.Plot.TwoDimensional as Plot2D
import qualified Graphics.Gnuplot.Graph.TwoDimensional as Graph2D
import qualified Graphics.Gnuplot.LineSpecification as LineSpec
import qualified Graphics.Gnuplot.ColorSpecification as Colour
import qualified Graphics.Gnuplot.Frame as Frame
import qualified Graphics.Gnuplot.Frame.OptionSet as Opts

import Control.Functor.HT (void)
import Data.Monoid ((<>))


-- Generate objects to work with
offset :: Scal (Typ D P Tt) Double
offset = S.toScalar 0

-- Time Vector
time :: TSignal [] Double
time = S.fromList ([0,0.1..pi]++[pi])

-- constant efficiency
n1 :: Scal (Typ A N Tt) Double
n1 = S.toScalar 0.8

-- Generate two Power Signals
pSig1, pSig2 :: PSignal [] Double
pSig1 =
   ((S.changeType (S.map sin time)) .- offset)
   .*
   (S.toScalar 1000 :: Scal (Typ A N Tt) Double)
pSig2 = pSig1 .* n1

-- Make Time-Step-Integration to get 1D energy flow signals
fSig1, fSig2 :: FFSignal [] Double
fSig1 = S.partIntegrate time pSig1
fSig2 = S.partIntegrate time pSig2

nVal2 :: Scal (Typ A N Tt) Double
nVal2 = S.sum fSig2 ./ S.sum fSig1



myPlotStyle ::
  Plot2D.T x y -> Plot2D.T x y
myPlotStyle =
  fmap (Graph2D.lineSpec $
    LineSpec.pointSize 0.1 $
    LineSpec.pointType 0 $
    LineSpec.lineColor Colour.lightSalmon $
    LineSpec.lineWidth 10 LineSpec.deflt)



myPlotStyle2 ::
  LineSpec.T -> LineSpec.T
myPlotStyle2 =
    ( LineSpec.pointSize 0.1 .
      LineSpec.pointType 0 .
      LineSpec.lineColor Colour.lightSalmon .
      LineSpec.lineWidth 10)

histoStyle ::
  LineSpec.T -> LineSpec.T
histoStyle =
    ( LineSpec.pointSize 10 .
      LineSpec.pointType 2 .
      LineSpec.lineColor Colour.lightSalmon .
      LineSpec.lineWidth 10)

terminate ::
  (LineSpec.T -> LineSpec.T) ->
  Plot2D.T x y -> Plot2D.T x y
terminate func = fmap (Graph2D.lineSpec $ func $ LineSpec.deflt)


myFrameStyle ::
  Plot2D.T Double Double ->
  Frame.T (Graph2D.T Double Double)
myFrameStyle = Frame.cons $
  Opts.title "Dies ist der Titel!!!" $
  Opts.grid True $
  Opts.deflt


histograms :: Plot2D.T Double Double
histograms =
  Plot2D.list Graph2D.boxes (zip [1,1.2..] [102, 213, 378, 408, 840,  920])

lists :: Plot2D.T Double Double
lists =
  Plot2D.list Graph2D.lines [(1, 200.0), (2.7, 160), (4, 700)]

plot :: Plot2D.T Double Double
plot = Plot.xy id time $ map (Plot.label "bla") [pSig1, pSig2]

main :: IO ()
main = do

  concurrentlyMany_ [

    void $ GnuPlot.plotSync DefaultTerm.cons $ plot,

    void $ GnuPlot.plotSync DefaultTerm.cons $
           myPlotStyle plot,

    void $ GnuPlot.plotSync DefaultTerm.cons $
           myFrameStyle $
           terminate (myPlotStyle2) $ plot,

    void $ GnuPlot.plotSync DefaultTerm.cons $
         (terminate histoStyle histograms <> lists),

    putStrLn (S.disp nVal2) ]


