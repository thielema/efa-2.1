module EFA.Flow.Topology.Variable (
   module EFA.Flow.Topology.Variable,
   Var.Signal(..),
   ) where

import qualified EFA.Equation.Variable as Var
import qualified EFA.Graph.Topology.Index as Idx
import qualified EFA.Graph.Topology.Node as Node

import qualified EFA.Report.Format as Format
import EFA.Report.Format (Format)
import EFA.Report.FormatValue
          (FormatValue, formatValue)


class FormatIndex idx where
   formatIndex :: (Node.C node, Format output) => idx node -> output

instance FormatIndex Idx.Energy where
   formatIndex = formatValue

instance FormatIndex Idx.Power where
   formatIndex = formatValue

instance FormatIndex Idx.Eta where
   formatIndex = formatValue

instance FormatIndex Idx.X where
   formatIndex = formatValue

instance FormatIndex Idx.DTime where
   formatIndex = formatValue

instance FormatIndex Idx.Sum where
   formatIndex = formatValue


index :: (Var.SignalIndex idx) => idx node -> Var.Signal node
index = Var.signalIndex


checkedLookup ::
   (Node.C node, FormatIndex idx) =>
   String -> (idx node -> t -> Maybe b) -> idx node -> t -> b
checkedLookup name lk idx =
   maybe (error $
             "Topology." ++ name ++
             " " ++ Format.unUnicode (formatIndex idx)) id .
   lk idx