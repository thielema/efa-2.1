-- | Demonstriert, wie man ein eta als Funktion definiert.

module Main where

import qualified EFA.Equation.Env as Env
import qualified EFA.Equation.Absolute as EqGen
import EFA.Equation.System ((=.=))
import EFA.Equation.Absolute ((.=))
import EFA.Equation.Result (Result(Determined, Undetermined))
import EFA.Example.Utility (constructSeqTopo, edgeVar, makeEdges)

import qualified EFA.Graph.Topology.Index as Idx
import qualified EFA.Graph.Topology.Node as Node
import qualified EFA.Graph.Topology as TD
import qualified EFA.Graph.Draw as Draw
import qualified EFA.Utility.Stream as Stream
import EFA.Utility.Stream (Stream((:~)))
import EFA.Utility (checkedLookup)
import EFA.Graph (mkGraph)

import Data.Ratio ((%))

import Data.Monoid (mconcat, (<>))


sec0 :: Idx.Section
sec0 :~ _ = Stream.enumFrom $ Idx.Section 0

data Node = Sink | Source deriving (Ord, Eq, Enum, Show)

instance Node.C Node where
   display = Node.displayDefault
   subscript = Node.subscriptDefault
   dotId = Node.dotIdDefault


linearOne :: TD.Topology Node
linearOne = mkGraph nodes (makeEdges edges)
  where nodes = [(Sink, TD.AlwaysSink), (Source, TD.AlwaysSource)]
        edges = [(Sink, Source)]

seqTopo :: TD.SequFlowGraph Node
seqTopo = constructSeqTopo linearOne [0]

enRange :: [Rational]
enRange = (1%100):[1%2, 1 .. 9]


type Expr s a x = EqGen.Expression Node s a x

c :: Idx.Power Node
c = edgeVar Idx.Power sec0 Source Sink

eta :: Idx.Eta Node
eta = edgeVar Idx.Eta sec0 Source Sink


functionEta :: (Fractional a) => Expr s a a -> Expr s a a
functionEta p = 0.2 * p

given :: Rational -> EqGen.EquationSystem Node s Rational
given p =
   mconcat $
   (Idx.DTime sec0 .= 1) :
   (c .= p) :
   []


solve :: Rational -> String
solve p =
  show p ++ "\t"
        ++ case Env.unAbsolute $ checkedLookup (Env.etaMap $ solveEnv p) eta of
              Undetermined -> "undetermined"
              Determined x -> show x

solveEnv ::
  Rational -> Env.Env Node (Env.Absolute (Result Rational))
solveEnv p =
  EqGen.solve
    ((EqGen.getVar eta =.= functionEta (EqGen.getVar c)) <> given p)
    seqTopo

main :: IO ()
main = do
  putStrLn $ unlines $ map solve enRange


  let env = solveEnv 0.5

  Draw.sequFlowGraphAbsWithEnv seqTopo env