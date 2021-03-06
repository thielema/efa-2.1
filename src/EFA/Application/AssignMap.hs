{-# LANGUAGE TypeFamilies #-}

module EFA.Application.AssignMap where

import EFA.Application.Utility (checkDetermined)

import qualified EFA.Equation.Arithmetic as Arith
import qualified EFA.Equation.Result as Result
import qualified EFA.Equation.Stack as Stack
import qualified EFA.Equation.RecordIndex as RecIdx
import EFA.Equation.Arithmetic ((~+))
import EFA.Equation.Result (Result)
import EFA.Equation.Stack (Stack)

import qualified EFA.Flow.Sequence.Quantity as SeqFlow
import qualified EFA.Flow.Sequence.Index as SeqIdx
import qualified EFA.Flow.SequenceState.Variable as Var
import qualified EFA.Flow.SequenceState.Index as Idx

import qualified EFA.Flow.Topology.Variable as TopoVar
import qualified EFA.Flow.Topology.Quantity as FlowTopo
import qualified EFA.Flow.Topology.Index as TopoIdx

import qualified EFA.Graph.Topology.Node as Node

import qualified EFA.Report.Format as Format
import EFA.Report.FormatValue (FormatValue, formatValue)
import EFA.Report.Format (Format)

import qualified EFA.Utility.Map as MapU
import qualified EFA.Utility.TotalMap as TMap

import qualified Data.Foldable as Fold
import qualified Data.Set as Set
import qualified Data.Map as Map
import Data.Traversable (traverse)
import Data.Map (Map)


print ::
   (FormatValue i, FormatValue a) =>
   Map i a -> IO ()
print =
   putStrLn . Format.unUnicode . format

format ::
   (FormatValue i, FormatValue a, Format output) =>
   Map i a -> output
format assigns =
   Format.lines $ Map.elems $ flip Map.mapWithKey assigns $ \term val ->
      Format.assign (formatValue term) (formatValue val)

ignoreUndetermined :: (Ord i) => Map i (Result a) -> Map i a
ignoreUndetermined =
   Map.mapMaybe Result.toMaybe


{- |
smart constructor
-}
indexSet :: Map i Stack.Branch -> IndexSet i
indexSet = IndexSet

deltaIndexSet :: (Ord i) => Map i Stack.Branch -> IndexSet i
deltaIndexSet =
   IndexSet . Map.filter (Stack.Delta==)

newtype IndexSet i = IndexSet (Map i Stack.Branch)
   deriving (Eq, Ord, Show)

instance FormatValue i => FormatValue (IndexSet i) where
   formatValue (IndexSet x) =
      Format.list $
      map
         (\(i,b) ->
            Format.recordDelta
               (case b of
                  Stack.Before -> RecIdx.Before
                  Stack.Delta -> RecIdx.Delta) $
            formatValue i) $
      Map.toList x

{- |
Convert a list of AssignMaps to an AssignMap of lists.
-}
transpose :: (Ord i, Arith.Constant a) => [Map i a] -> Map i [a]
transpose = TMap.core . traverse (TMap.cons Arith.zero)


{- |
Keep only values above a certain threshold.
-}
threshold ::
   (Ord i, Ord a, Arith.Sum a) => a -> Map i a -> Map i a
threshold x = Map.filter ((>=x) . Arith.abs)

{- |
Keep all those lists where at least one value is above a threshold.
This allows to filter consistently across stacks.
-}
simultaneousThreshold ::
   (Ord i, Ord a, Arith.Sum a) => a -> Map i [a] -> Map i [a]
simultaneousThreshold x = Map.filter (any ((>=x) . Arith.abs))


{-
This is compatible with a @Stack i a@,
but it may not be a perfect hyper-cube
since some corners may be missing.
-}
type AssignMap i a = Map (Map i Stack.Branch) a

{- |
@filterDeltaVars vars@ keeps only the terms
where every @var@ from @vars@ is a delta var.
-}
filterDeltaVars ::
   (Ord i) =>
   [i] ->
   AssignMap i a ->
   AssignMap i a
filterDeltaVars is =
   let set = Set.fromList is
   in  Map.filterWithKey
          (\k _ -> Fold.all (Stack.Delta ==) $ MapU.intersectionSet k set)


cumulate ::
   (Ord (idx node), Arith.Sum a) =>
   [AssignMap (Idx.InSection idx node) a] ->
   AssignMap (idx node) a
cumulate =
   Map.unionsWith (~+) .
   map
      (Map.mapKeysWith (~+)
         (Map.mapKeys (\(Idx.InPart _sec node) -> node)))


stripSection ::
   (Ord (idx node)) =>
   AssignMap (Idx.InSection idx node) a ->
   AssignMap (idx node) a
stripSection =
   Map.mapKeysWith
      (error "AssignMap.stripSection: multiple sections in one assignmap")
      (Map.mapKeys (\(Idx.InPart _sec node) -> node))


lookupStack ::
   (Ord i, Node.C node) =>
   SeqIdx.Energy node ->
   SeqFlow.Graph node t (Result (Stack i a)) ->
   Map.Map (IndexSet i) a
lookupStack energyIndex gr =
   case Var.checkedLookup "lookupStack" SeqFlow.lookup energyIndex gr of
      d ->
         Map.mapKeys deltaIndexSet $
         Stack.assignDeltaMap $
         checkDetermined ("lookupStack " ++ Format.unUnicode (formatValue energyIndex)) d

lookupEnergyStacks ::
   (Ord i, Node.C node, a ~ Arith.Scalar v, Arith.Integrate v) =>
   TopoIdx.Energy node ->
   SeqFlow.Graph node t (Result (Stack i v)) ->
   Map Idx.Section (Map (Map i Stack.Branch) a)
lookupEnergyStacks e =
   fmap (Stack.assignDeltaMap . Arith.integrate) .
   Map.mapMaybe Result.toMaybe .
   fmap (TopoVar.checkedLookup "lookupEnergyStacks" FlowTopo.lookupEnergy e .
         snd) .
   SeqFlow.sequence
