{-# LANGUAGE FlexibleContexts #-}

module EFA.Action.Optimisation.Signal.Plot where

import qualified EFA.Flow.Topology.Quantity as TopoQty
import qualified EFA.Action.DemandAndControl as DemandAndControl
import qualified EFA.Action.Flow.Topology.Optimality as FlowTopoOpt
import qualified EFA.Graph.Topology.Node as Node
import qualified EFA.Graph as Graph
import qualified EFA.Flow.Topology as FlowTopo
import qualified EFA.Action.Flow.Balance as Balance
import qualified EFA.Flow.Topology.Index as XIdx

--import qualified EFA.Action.Optimisation.Sweep as Sweep
import qualified EFA.Flow.SequenceState.Index as Idx
import qualified EFA.Data.Axis.Strict as Strict
import qualified EFA.Data.ND as ND
import qualified EFA.Equation.Arithmetic as Arith
import qualified EFA.Data.Vector as DV
import qualified EFA.Action.Flow.Check as ActFlowCheck
import qualified EFA.Data.ND.Cube.Grid as CubeGrid
import qualified EFA.Value.State as ValueState
import qualified EFA.Action.Flow.Optimality as FlowOpt

import qualified EFA.Action.Optimisation.Signal as OptSignal
import qualified EFA.Action.Optimisation.Cube.Sweep as CubeSweep
import qualified EFA.Data.OD.Signal.Flow as SignalFlow
import qualified EFA.Data.Interpolation as Interp
import qualified EFA.Data.ND.Cube.Map as CubeMap

import qualified Graphics.Gnuplot.Value.Tuple as Tuple
import qualified Graphics.Gnuplot.Value.Atom as Atom

import qualified EFA.Value.Type as Type

import qualified EFA.Data.Plot.D2.FlowSignal as SignalFlowPlot
import qualified EFA.Data.Plot.D2 as PlotD2

import qualified Data.Map as Map
import qualified Control.Monad as Monad
import qualified Data.Maybe as Maybe

import EFA.Utility(Caller,
                   merror,(|>),
                   ModuleName(..),FunctionName, genCaller)
modul :: ModuleName
modul = ModuleName "EFA.Action.Optimisation.Signal.Plot"

nc :: FunctionName -> Caller
nc = genCaller modul


{-

newtype DemandCycle node inst dim vec a b = 
  DemandCycle (SignalFlow.Signal inst String vec a (ND.Data dim b))

newtype DemandCycleRec node inst vec a b = 
  DemandCycleRec (SignalFlow.HRecord (DemandAndControl.DemandVar node) inst String vec a b) 

newtype DemandCycleMap node inst vec a b = 
  DemandCycleMap (Map.Map (DemandAndControl.DemandVar node) (SignalFlow.Signal inst String vec a b)) deriving Show

newtype SupportSignal node inst dim  vec a b = 
  SupportSignal (SignalFlow.Signal inst String vec a (ND.Data dim (Strict.SupportingPoints (Strict.Idx,b)))) 
  
newtype OptimalityPerStateSignal node inst vec a b = OptimalityPerStateSignal
        (SignalFlow.Signal inst String vec a (ValueState.Map (FlowOpt.OptimalityValues b)))

newtype OptimalControlSignalsPerState node inst vec a b = 
  OptimalControlSignalsPerState (Map.Map (DemandAndControl.ControlVar node) (SignalFlow.Signal inst String vec a (ValueState.Map b)))
--  OptimalControlSignalsPerState (SignalFlow.HRecord (DemandAndControl.ControlVar node) inst String vec a (ValueState.Map b))

newtype OptimalStoragePowersPerState node inst  vec a b = 
   OptimalStoragePowersPerState (Map.Map node (SignalFlow.Signal inst String vec a (ValueState.Map (Maybe b))))
--   OptimalStoragePowersPerState (SignalFlow.HRecord node inst String vec a (ValueState.Map (Maybe b)))

newtype OptimalStateChoice node inst vec a b = 
  OptimalStateChoice (SignalFlow.Signal inst String vec a ([Maybe Idx.AbsoluteState],Maybe b))

newtype OptimalControlSignals node inst  vec a b = 
  OptimalControlSignals (Map.Map (DemandAndControl.ControlVar node) (SignalFlow.Signal inst String vec a b))

newtype OptimalStoragePowers node inst vec a b = 
  OptimalStoragePowers (Map.Map (node) (SignalFlow.Signal inst String vec a (Maybe b)))

-}


-- class ToPlotData  
plotDemandCycle ::
  (Ord node,
   Ord a,
   Ord b,
   Arith.Constant a,
   Arith.Constant b,
   Tuple.C b,
   Tuple.C a,
   Atom.C b,
   Atom.C a,
   Type.ToDisplayUnit b,
   Type.GetDynamicType a,
   Type.GetDynamicType b,
   DV.Walker vec,
   DV.Storage vec (ND.Data dim b),
   DV.Storage vec a,
   DV.Storage vec b,
   DV.Singleton vec,
   DV.Length vec,
   DV.FromList vec) =>
  OptSignal.DemandCycle node inst dim vec a b ->
  [DemandAndControl.DemandVar node] ->
  [PlotD2.PlotData (DemandAndControl.DemandVar node) info String a b]
plotDemandCycle demandVars cycle = plotDemandCycleMap $ OptSignal.convertToDemandCycleMap demandVars cycle 

-- plotDemandCycleMap :: 
plotDemandCycleMap ::
  (Ord b,
   Ord a,
   Arith.Constant b,
   Arith.Constant a,
   Tuple.C a,
   Tuple.C b,
   Atom.C a,
   Atom.C b,
   Type.ToDisplayUnit b,
   Type.GetDynamicType b,
   Type.GetDynamicType a,
   DV.Walker vec,
   DV.Storage vec b,
   DV.Storage vec a,
   DV.Singleton vec,
   DV.Length vec,
   DV.FromList vec) =>
  OptSignal.DemandCycleMap node inst vec a b ->
  [PlotD2.PlotData (DemandAndControl.DemandVar node) info String a b]
plotDemandCycleMap (OptSignal.DemandCycleMap cycle) = 
  concat $ Map.elems $ Map.mapWithKey (\ident sig ->  PlotD2.toPlotData (Just ident) sig) cycle