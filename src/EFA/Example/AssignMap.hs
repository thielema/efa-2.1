module EFA.Example.AssignMap where

import qualified EFA.Equation.Result as Result
import qualified EFA.Equation.Stack as Stack
import qualified EFA.Report.Format as Format
import qualified EFA.Graph.Topology.Index as Idx
import EFA.Equation.Result (Result)
import EFA.Report.FormatValue (FormatValue, formatValue)
import EFA.Report.Format (Format)
import EFA.Utility (intersectionMapSet)

import qualified Data.Foldable as Fold
import qualified Data.Set as Set
import qualified Data.Map as Map
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

newtype IndexSet i = IndexSet (Map i Stack.Branch)
   deriving (Eq, Ord, Show)

instance FormatValue i => FormatValue (IndexSet i) where
   formatValue (IndexSet x) =
      Format.list $
      map
         (\(i,b) ->
            Format.recordDelta
               (case b of
                  Stack.Before -> Idx.Before
                  Stack.Delta -> Idx.Delta) $
            formatValue i) $
      filter p $ Map.toList x
      where p (_, b) =  b == Stack.Delta

{- |
Keep only values above a certain threshold.
-}
threshold :: (Ord i, Ord a, Num a) => a -> Map i a -> Map i a
threshold x = Map.filter ((>=x) . abs)

{- |
@filterDeltaVars vars@ keeps only the terms
where every @var@ from @vars@ is a delta var.
-}
filterDeltaVars ::
   (Ord i) =>
   [i] ->
   Map (Map i Stack.Branch) a ->
   Map (Map i Stack.Branch) a
filterDeltaVars is =
   let set = Set.fromList is
   in  Map.filterWithKey
          (\k _ -> Fold.all (Stack.Delta ==) $ intersectionMapSet k set)

