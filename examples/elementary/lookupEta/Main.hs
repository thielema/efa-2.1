
module Main where

import qualified EFA.Equation.Env as Env
import qualified EFA.Equation.System as EqGen
import EFA.Equation.System ((=.=))

import qualified EFA.Graph.Topology.Index as Idx
import qualified EFA.Graph.Topology as TD
import qualified EFA.Utility.Stream as Stream
import EFA.Utility.Stream (Stream((:~)))
import EFA.Utility (checkedLookup)
import EFA.Graph (mkGraph)
import EFA.Example.Utility ((.=), constructSeqTopo, edgeVar, makeEdges, recAbs)

import qualified EFA.Report.Format as Format
import EFA.Report.FormatValue (formatValue)

import qualified UniqueLogic.ST.Expression as Expr
import qualified UniqueLogic.ST.System as Sys

import Data.Monoid ((<>))
import Data.Foldable (foldMap)


sec0 :: Idx.Section
sec0 :~ _ = Stream.enumFrom $ Idx.Section 0

sink, source :: Idx.Node
sink :~ (source :~ _) = Stream.enumFrom $ Idx.Node 0

linearOne :: TD.Topology
linearOne = mkGraph nodes (makeEdges edges)
  where nodes = [(sink, TD.AlwaysSink), (source, TD.AlwaysSource)]
        edges = [(source, sink)]

seqTopo :: TD.SequFlowGraph
seqTopo = constructSeqTopo linearOne [0]

enRange :: [Double]
enRange = 0.01:[0.5, 1 .. 9]

c :: EqGen.ExprWithVars s a
c = edgeVar EqGen.power sec0 source sink

n :: EqGen.ExprWithVars s a
n = edgeVar EqGen.eta sec0 source sink

eval :: [(Double, Double)] -> Double -> Double
eval lt pin =
  case dropWhile ((< pin) . fst) lt of
       [] -> 0
       (_, v):_ -> v


lookupEta :: EqGen.ExprWithVars s Double -> EqGen.ExprWithVars s Double
lookupEta = EqGen.liftV $ Expr.fromRule2 $ Sys.assignment2 "lookupTable" $ eval table
  where table = zip [0..9] [0, 0.1, 0.3, 0.6, 0.7, 0.65, 0.6, 0.4, 0.35, 0.1]

given :: Double -> EqGen.EquationSystem s Double
given p =
   foldMap (uncurry (.=)) $
   (EqGen.dtime sec0, 1) :
   (edgeVar EqGen.power sec0 source sink, p) : []

eta :: Idx.Eta
eta = edgeVar (Idx.Eta recAbs) sec0 source sink


solve :: Double -> String
solve p =
  let env = EqGen.solve ((n =.= lookupEta c) <> given p) seqTopo
  in  show p ++ " " ++
      Format.unUnicode (formatValue (checkedLookup (Env.etaMap env) eta))

main :: IO ()
main =
  putStrLn $ unlines $ map solve enRange