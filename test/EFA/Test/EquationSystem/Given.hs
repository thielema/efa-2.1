{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE Rank2Types #-}

module EFA.Test.EquationSystem.Given where

import qualified EFA.Example.Topology.Tripod.Given as TripodGiven
import EFA.Example.Topology.Tripod (Node, node0, node1, node2, node3)

import qualified EFA.Flow.Sequence.Absolute as EqSys
import qualified EFA.Flow.Sequence.Quantity as SeqFlow
import qualified EFA.Flow.Sequence.Index as XIdx
import qualified EFA.Flow.SequenceState.Index as Idx

import qualified EFA.Equation.Verify as Verify
import qualified EFA.Equation.Pair as Pair
import qualified EFA.Equation.Arithmetic as Arith
import EFA.Equation.Result (Result(Determined, Undetermined))

import EFA.Symbolic.SumProduct ( Term )

import qualified EFA.Report.Format as Format

import qualified EFA.Utility.Stream as Stream
import EFA.Utility.Stream (Stream((:~)))

import qualified Control.Monad.Exception.Synchronous as ME

import Data.Tuple.HT (mapFst)
import Data.Monoid (Endo(Endo), appEndo)
import Data.Foldable (foldMap)


sec0, sec1, sec2 :: Idx.Section
sec0 :~ sec1 :~ sec2 :~ _ = Stream.enumFrom $ Idx.section0

seci :: Idx.InitOrSection
seci = XIdx.initSection

sece :: Idx.SectionOrExit
sece = XIdx.exitSection

bndi, bnd0, bnd1, bnd2 :: Idx.Boundary
bndi :~ bnd0 :~ bnd1 :~ bnd2 :~ _ =
   Stream.enumFrom $ Idx.initial


type ResultGraph a v = SeqFlow.Graph Node (Result a) (Result v)

flowGraph :: ResultGraph a v
flowGraph = TripodGiven.seqFlowGraph


-- Hilfsfunktion, um das fullGiven-Gleichungssystem zu bauen.
-- Man übergibt ein gelösten Graphen.
-- Es muessen noch die richtigen Werte eingetragen werden.

{-
ME.switch undefined (putStrLn . formatGiven) $ fst fullGraph
-}
formatGiven :: ResultGraph Rational Rational -> String
formatGiven gr =
   "fullGiven :: EquationSystem s\n" ++
   "fullGiven = mconcat $\n" ++
   appEndo
      (SeqFlow.foldMap Endo Endo $ SeqFlow.mapGraphWithVar g g gr)
      "   []"
  where g :: (Show idx, Show a) => idx -> Result a -> ShowS
        g idx v =
           showString "   ((" . shows idx .
           showString ") .= " . showValue v . showString ") :\n"
        showValue v =
          case v of
            Determined x -> shows x
            Undetermined -> showString "?"


fullGraph, solvedGraph ::
   (ME.Exceptional
      (Verify.Exception Format.Unicode)
      (ResultGraph Rational Rational),
    Verify.Assigns Format.Unicode)
fullGraph =
   mapFst (fmap numericGraph) $
   EqSys.solveTracked flowGraph fullGiven

solvedGraph =
   mapFst (fmap numericGraph) $
   EqSys.solveTracked flowGraph partialGiven

numericGraph ::
   ResultGraph (Pair.T at an) (Pair.T vt vn) ->
   ResultGraph an vn
numericGraph =
   SeqFlow.mapGraph (fmap Pair.second) (fmap Pair.second)


type TrackedSignal = Pair.T (EqSys.SignalTerm Term Node) Rational
type TrackedScalar = Pair.T (EqSys.ScalarTerm Term Node) Rational

type EquationSystem s =
        EqSys.EquationSystem
           (Verify.Track Format.Unicode)
           Node s TrackedScalar TrackedSignal

data
   Equation mode a v =
      Equation {
         getEquation :: forall s.
            EqSys.EquationSystem mode Node s a v
      }


infix 0 .=

(.=) ::
   (Arith.Constant x, Verify.LocalVar mode x,
    x ~ SeqFlow.Element idx a v, SeqFlow.Lookup idx) =>
   idx Node -> Rational -> Equation mode a v
var .= val  =
   Equation (var EqSys..= Arith.fromRational val)


partialGiven :: EquationSystem s
partialGiven = foldMap getEquation partialEquations

partialEquations ::
   (Verify.LocalVar mode a, Arith.Constant a,
    Verify.LocalVar mode v, Arith.Constant v) =>
   [Equation mode a v]
partialEquations =
   (XIdx.dTime sec0 .= 1 / 1) :
   (XIdx.dTime sec1 .= 2 / 1) :
   (XIdx.dTime sec2 .= 1 / 1) :

   (XIdx.storage (Idx.afterSection sec2) node3 .= 10 / 1) :

   (XIdx.x sec0 node2 node3 .= 8 / 25) :

   (XIdx.power sec0 node2 node3 .= 4 / 1) :
   (XIdx.power sec1 node3 node2 .= 5 / 1) :
   (XIdx.power sec2 node3 node2 .= 6 / 1) :

   (XIdx.eta sec0 node3 node2 .= 1 / 4) :
   (XIdx.eta sec0 node2 node1 .= 1 / 2) :
   (XIdx.eta sec0 node0 node2 .= 3 / 4) :

   (XIdx.eta sec1 node0 node2 .= 2 / 5) :
   (XIdx.eta sec1 node2 node3 .= 3 / 5) :

   (XIdx.eta sec2 node0 node2 .= 7 / 10) :
   (XIdx.eta sec2 node3 node2 .= 9 / 10) :
   (XIdx.eta sec2 node2 node1 .= 1 / 1) :

   (XIdx.x sec1 node2 node3 .= 2 / 5) :

   (XIdx.x sec2 node2 node0 .= 3 / 10) :

   (XIdx.inSum sec1 node1 .= 20) :

   []


fullGiven :: EquationSystem s
fullGiven = foldMap getEquation $
   (XIdx.power sec0 node0 node2 .= 34 / 3) :
   (XIdx.power sec0 node1 node2 .= 25 / 4) :
   (XIdx.power sec0 node2 node0 .= 17 / 2) :
   (XIdx.power sec0 node2 node1 .= 25 / 2) :
   (XIdx.power sec0 node2 node3 .= 4 / 1) :
   (XIdx.power sec0 node3 node2 .= 16 / 1) :
   (XIdx.power sec1 node0 node2 .= 625 / 12) :
   (XIdx.power sec1 node1 node2 .= 10) :
   (XIdx.power sec1 node2 node0 .= 125 / 6) :
   (XIdx.power sec1 node2 node1 .= 25 / 2) :
   (XIdx.power sec1 node2 node3 .= 25 / 3) :
   (XIdx.power sec1 node3 node2 .= 5 / 1) :
   (XIdx.power sec2 node0 node2 .= 162 / 49) :
   (XIdx.power sec2 node1 node2 .= 54 / 7) :
   (XIdx.power sec2 node2 node0 .= 81 / 35) :
   (XIdx.power sec2 node2 node1 .= 54 / 7) :
   (XIdx.power sec2 node2 node3 .= 27 / 5) :
   (XIdx.power sec2 node3 node2 .= 6 / 1) :

   (XIdx.energy sec0 node0 node2 .= 34 / 3) :
   (XIdx.energy sec0 node1 node2 .= 25 / 4) :
   (XIdx.energy sec0 node2 node0 .= 17 / 2) :
   (XIdx.energy sec0 node2 node1 .= 25 / 2) :
   (XIdx.energy sec0 node2 node3 .= 4 / 1) :
   (XIdx.energy sec0 node3 node2 .= 16 / 1) :
   (XIdx.energy sec1 node0 node2 .= 625 / 6) :
   (XIdx.energy sec1 node1 node2 .= 20) :
   (XIdx.energy sec1 node2 node0 .= 125 / 3) :
   (XIdx.energy sec1 node2 node1 .= 25 / 1) :
   (XIdx.energy sec1 node2 node3 .= 50 / 3) :
   (XIdx.energy sec1 node3 node2 .= 10 / 1) :
   (XIdx.energy sec2 node0 node2 .= 162 / 49) :
   (XIdx.energy sec2 node1 node2 .= 54 / 7) :
   (XIdx.energy sec2 node2 node0 .= 81 / 35) :
   (XIdx.energy sec2 node2 node1 .= 54 / 7) :
   (XIdx.energy sec2 node2 node3 .= 27 / 5) :
   (XIdx.energy sec2 node3 node2 .= 6 / 1) :

   (XIdx.eta sec0 node0 node2 .= 3 / 4) :
   (XIdx.eta sec0 node2 node1 .= 1 / 2) :
   (XIdx.eta sec0 node3 node2 .= 1 / 4) :
   (XIdx.eta sec1 node0 node2 .= 2 / 5) :
   (XIdx.eta sec1 node2 node1 .= 4/5) :
   (XIdx.eta sec1 node2 node3 .= 3 / 5) :
   (XIdx.eta sec2 node0 node2 .= 7 / 10) :
   (XIdx.eta sec2 node2 node1 .= 1 / 1) :
   (XIdx.eta sec2 node3 node2 .= 9 / 10) :

   (XIdx.dTime sec0 .= 1 / 1) :
   (XIdx.dTime sec1 .= 2 / 1) :
   (XIdx.dTime sec2 .= 1 / 1) :

   (XIdx.x sec0 node0 node2 .= 1 / 1) :
   (XIdx.x sec0 node1 node2 .= 1 / 1) :
   (XIdx.x sec0 node2 node0 .= 17 / 25) :
   (XIdx.x sec0 node2 node1 .= 1 / 1) :
   (XIdx.x sec0 node2 node3 .= 8 / 25) :
   (XIdx.x sec0 node3 node2 .= 1 / 1) :
   (XIdx.x sec1 node0 node2 .= 1 / 1) :
   (XIdx.x sec1 node1 node2 .= 1 / 1) :
   (XIdx.x sec1 node2 node0 .= 1 / 1) :
   (XIdx.x sec1 node2 node1 .= 3 / 5) :
   (XIdx.x sec1 node2 node3 .= 2 / 5) :
   (XIdx.x sec1 node3 node2 .= 1 / 1) :
   (XIdx.x sec2 node0 node2 .= 1 / 1) :
   (XIdx.x sec2 node1 node2 .= 1 / 1) :
   (XIdx.x sec2 node2 node0 .= 3 / 10) :
   (XIdx.x sec2 node2 node1 .= 1 / 1) :
   (XIdx.x sec2 node2 node3 .= 7 / 10) :
   (XIdx.x sec2 node3 node2 .= 1 / 1) :

   (XIdx.inSum sec0 node1 .= 25 / 4) :
   (XIdx.inSum sec0 node2 .= 25 / 2) :
   (XIdx.outSum sec0 node0 .= 34 / 3) :
   (XIdx.outSum sec0 node2 .= 25 / 2) :
   (XIdx.outSum sec0 node3 .= 16 / 1) :
   (XIdx.inSum sec1 node1 .= 20) :
   (XIdx.inSum sec1 node2 .= 125 / 3) :
   (XIdx.inSum sec1 node3 .= 10 / 1) :
   (XIdx.outSum sec1 node0 .= 625 / 6) :
   (XIdx.outSum sec1 node2 .= 125 / 3) :
   (XIdx.inSum sec2 node1 .= 54 / 7) :
   (XIdx.inSum sec2 node2 .= 54 / 7) :
   (XIdx.outSum sec2 node0 .= 162 / 49) :
   (XIdx.outSum sec2 node2 .= 54 / 7) :
   (XIdx.outSum sec2 node3 .= 6 / 1) :

   (XIdx.maxEnergy seci sec0 node3 .= 22 / 1) :
   (XIdx.maxEnergy seci sec2 node3 .= 6 / 1) :
   (XIdx.maxEnergy sec1 sec2 node3 .= 10 / 1) :
   (XIdx.maxEnergy seci sece node3 .= 15 / 4) :
   (XIdx.maxEnergy sec1 sece node3 .= 25 / 4) :
   (XIdx.storage bndi node3 .= 22 / 1) :
   (XIdx.storage bnd0 node3 .= 6 / 1) :
   (XIdx.storage bnd1 node3 .= 16 / 1) :
   (XIdx.storage bnd2 node3 .= 10 / 1) :
   (XIdx.stEnergy seci sec0 node3 .= 16 / 1) :
   (XIdx.stEnergy seci sec2 node3 .= 9 / 4) :
   (XIdx.stEnergy seci sece node3 .= 15 / 4) :
   (XIdx.stEnergy sec1 sec2 node3 .= 15 / 4) :
   (XIdx.stEnergy sec1 sece node3 .= 25 / 4) :
   (XIdx.stX seci sec0 node3 .= 8 / 11) :
   (XIdx.stX seci sec2 node3 .= 9 / 88) :
   (XIdx.stX seci sece node3 .= 15 / 88) :
   (XIdx.stX sec0 seci node3 .= 1 / 1) :
   (XIdx.stX sec1 sec2 node3 .= 3 / 8) :
   (XIdx.stX sec1 sece node3 .= 5 / 8) :
   (XIdx.stX sec2 seci node3 .= 3 / 8) :
   (XIdx.stX sec2 sec1 node3 .= 5 / 8) :
   (XIdx.stX sece seci node3 .= 3 / 8) :
   (XIdx.stX sece sec1 node3 .= 5 / 8) :
   (XIdx.stInSum sec0 node3 .= 16 / 1) :
   (XIdx.stInSum sec2 node3 .= 6 / 1) :
   (XIdx.stInSum sece node3 .= 10) :
   (XIdx.stOutSum seci node3 .= 22 / 1) :
   (XIdx.stOutSum sec1 node3 .= 10 / 1) :

   []
