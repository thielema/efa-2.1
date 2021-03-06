{-# LANGUAGE TypeOperators #-}
module EFA.Flow.Topology.Record (
   Flow(..),
   Section,
   flowTopologyFromRecord,
   fromSection,
   fullFlow,
   sectionToPowerRecord,
   sectionResultToPowerRecord,
   ) where

import qualified EFA.Flow.Topology.Quantity as FlowTopo
import qualified EFA.Flow.Topology.Index as Idx
import qualified EFA.Flow.Topology as FlowTopoPlain

import qualified EFA.Graph.Topology.Node as Node
import qualified EFA.Graph.Topology as Topo
import qualified EFA.Graph as Graph
import EFA.Graph.Topology (Topology)
import EFA.Graph (DirEdge(DirEdge), unDirEdge)

import qualified EFA.Signal.Signal as Signal
import qualified EFA.Signal.Vector as SV
import qualified EFA.Signal.Record as Record
import EFA.Signal.Record (Record(Record), FlowRecord)
import EFA.Signal.Signal (fromScalar)
import EFA.Signal.Data (Data, Nil, (:>))

import qualified EFA.Equation.Result as Result
import EFA.Equation.Result (Result(Determined, Undetermined))
import EFA.Equation.Arithmetic
          (Sum, Constant, Sign(Positive, Negative, Zero))

import qualified EFA.Utility.Map as MapU

import Control.Applicative (pure)

import qualified Data.Map as Map


data Flow a = Flow {flowOut, flowIn :: a}

instance Functor Flow where
   fmap f (Flow o i) = Flow (f o) (f i)

type Section node v a =
        FlowTopoPlain.Section
           node Graph.EitherEdge
           (Signal.TSignal v a)
           () (Maybe (Flow (Signal.FFSignal v a)))

flowTopologyFromRecord ::
   (Ord node, Show node,
    Ord a, Constant a,
    SV.Walker v, SV.Storage v a) =>
   Topology node ->
   FlowRecord node v a ->
   Section node v a
flowTopologyFromRecord topo (Record time fs) =
   FlowTopoPlain.Section time $
   Graph.fromMap (Graph.nodeLabels topo) $
   Map.unionsWith (error "flowTopologyFromRecord: duplicate edges") $
   Map.elems $
   Map.mapWithKey
      (\e@(DirEdge idx1 idx2) () ->
         let look = MapU.checkedLookup "Flow.flowTopologyFromRecord" fs
             normal   = look $ Topo.outPosFromDirEdge e
             opposite = look $ Topo.inPosFromDirEdge e
         in  case fromScalar $ Signal.sign $ Signal.sum normal of
                Positive ->
                   Map.singleton
                      (Graph.EDirEdge $ DirEdge idx1 idx2)
                      (Just $ Flow {flowOut = normal, flowIn = opposite})
                Negative ->
                   Map.singleton
                      (Graph.EDirEdge $ DirEdge idx2 idx1)
                      (Just $ Flow {flowOut = Signal.neg opposite, flowIn = Signal.neg normal})
                Zero ->
                   Map.singleton
                      (Graph.EUnDirEdge $ unDirEdge idx1 idx2)
                      Nothing) $
   Graph.edgeLabels topo

fromSection ::
   (Sum a, SV.Zipper v, SV.Walker v, SV.Singleton v, SV.Storage v a,
    Node.C node) =>
   FlowTopoPlain.Section node Graph.EitherEdge
      (Signal.TSignal v a) (FlowTopo.Sums (Result (Data (v :> Nil) a)))
      (Maybe (Flow (Signal.FFSignal v a))) ->
   FlowTopo.Section node (Result (Data (v :> Nil) a))
fromSection (FlowTopoPlain.Section dtime topo) =
   FlowTopoPlain.Section
      (Determined . Signal.unpack . Signal.delta $ dtime)
      (Graph.mapEdge
         (fmap (fullFlow . fmap (Determined . Signal.unpack)))
         topo)


sectionToPowerRecord ::
   (Ord node) =>
   FlowTopo.Section node (Data (v :> Nil) a) ->
   Record.PowerRecord node v a
sectionToPowerRecord (FlowTopoPlain.Section time topo) =
   Record.Record (Signal.TC time) $
   fmap Signal.TC $ topologyToPowerMap topo

sectionResultToPowerRecord ::
   (Ord node) =>
   FlowTopo.Section node (Result (Data (v :> Nil) a)) ->
   Record.PowerRecord node v a
sectionResultToPowerRecord (FlowTopoPlain.Section rtime topo) =
   Record.Record
      (Signal.TC $
       case rtime of
          Undetermined -> error "sectionResultToPowerRecord"
          Determined time -> time) $
   fmap Signal.TC $ Map.mapMaybe Result.toMaybe $ topologyToPowerMap topo

topologyToPowerMap ::
   (Ord node) =>
   FlowTopo.Topology node a -> Map.Map (Idx.Position node) a
topologyToPowerMap topo =
   Map.unionsWith (error "envToPowerRecord: duplicate edges") $
   Map.elems $
   Map.mapWithKey
      (\e flow ->
         Map.fromList $
            (Topo.outPosFromDirEdge e, FlowTopo.flowPowerOut flow) :
            (Topo.inPosFromDirEdge e,  FlowTopo.flowPowerIn flow) :
            []) $
   Graph.edgeLabels $
   FlowTopoPlain.dirFromFlowGraph topo

fullFlow :: Flow (Result a) -> FlowTopo.Flow (Result a)
fullFlow flow =
   (pure Undetermined) {
      FlowTopo.flowEnergyOut = flowOut flow,
      FlowTopo.flowEnergyIn = flowIn flow
   }
