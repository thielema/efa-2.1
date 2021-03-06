
module EFA.Application.Flow.Sequence.SystemEta where

import EFA.Application.Utility (checkDetermined)

import qualified EFA.Flow.Sequence.Quantity as SeqFlow
import qualified EFA.Application.Flow.SystemEta as SystemEta
import qualified EFA.Flow.Topology.Quantity as FlowTopo

import qualified EFA.Graph.Topology.Node as Node

import qualified EFA.Equation.Arithmetic as Arith
import EFA.Equation.Arithmetic ((~+))
import EFA.Equation.Result (Result)

import EFA.Utility.Map (Caller)

import Data.Maybe.HT (toMaybe)


etaSys ::
   (Node.C node, Arith.Product v) =>
   SeqFlow.Graph node a (Result v) -> Result v
etaSys =
   SystemEta.etaSys . fmap (FlowTopo.topology . snd) . SeqFlow.sequence


detEtaSys ::
   (Node.C node, Arith.Product v) =>
   Caller ->
   SeqFlow.Graph node a (Result v) -> v
detEtaSys caller =
   checkDetermined (caller ++ ".detEtaSys") . etaSys


type Condition node a v = SeqFlow.Graph node a (Result v) -> Bool

type Forcing node a v = SeqFlow.Graph node a (Result v) -> v


objectiveFunction ::
   (Node.C node, Arith.Product v) =>
   Condition node a v ->
   Forcing node a v ->
   SeqFlow.Graph node a (Result v) ->
   Maybe (v, v)
objectiveFunction cond forcing env =
   let eta = detEtaSys "objectiveFunction" env
   in  toMaybe (cond env) $ (eta ~+ forcing env, eta)
