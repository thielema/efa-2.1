{-# LANGUAGE TypeOperators #-}

module Main (main) where

import qualified EFA.Application.Plot as PlotIO
import EFA.Application.Utility ( topologyFromEdges, quantityTopology )

import qualified EFA.Signal.Signal as Sig
import qualified EFA.Signal.Record as Rec
import qualified EFA.Signal.Data as Data
import qualified EFA.Signal.Chop as Chop
import qualified EFA.Signal.Sequence as Sequ
import EFA.Signal.Data (Data, (:>), Nil)

import qualified EFA.Flow.Topology.Absolute as EqSys
import qualified EFA.Flow.Topology.Quantity as FlowTopo
import qualified EFA.Flow.Topology.Index as XIdx
import qualified EFA.Flow.Topology.Record as TopoRecord
import qualified EFA.Flow.Draw as Draw
import qualified EFA.Flow.Sequence.Record as SeqRec
import EFA.Flow.Topology.Absolute ((.=), (=.=))

import qualified EFA.Flow.Sequence.Quantity as SeqQty

import qualified EFA.Equation.Result as Result

import qualified EFA.Graph.Topology.Node as Node
import qualified EFA.Graph.Topology as Topo
import qualified EFA.Graph as Graph

import qualified Graphics.Gnuplot.Terminal.Default as DefaultTerm
import EFA.Utility.Async (concurrentlyMany_)

import qualified Data.Map as Map

import Data.Foldable (foldMap, fold)
import Data.Monoid (mconcat, (<>))




node0, node1, node2, node3 :: Node.Int
node0 = Node.intNoRestriction 0
node1 = Node.intCrossing 0
node2 = Node.intNoRestriction 1
node3 = Node.intNoRestriction 2


topoTripod :: Topo.Topology Node.Int
topoTripod =
   topologyFromEdges [(node0, node1), (node1, node2), (node1, node3)]



time :: Sig.TSignal []  Double
time = Sig.fromList $ take (length node0Sig') [0..]


node0Sig :: Sig.PSignal [] Double
node0Sig = Sig.fromList node0Sig'


node2Sig :: Sig.PSignal [] Double
node2Sig = Sig.fromList node2Sig'


node0Sig' :: [Double]
node0Sig' = [1, 2, 3,  2,  0, -4, -5, -3, 0, -1, -2, 0, 3, 1,  0, -1, -2, -1]


node2Sig' :: [Double]
node2Sig' = [1, 2, 0, -2, -3, -4, -5, -3, 0,  1,  2, 3, 1, 0, -1, -2, -1,  0]



eta01 :: Double -> Double
eta01 x = if x < 0 then 1/n else n
   where n = 0.5

eta12 :: Double -> Double
eta12 x = if x < 0 then 1/n else n
   where n = 0.4

eta13 :: Double -> Double
eta13 x = if x < 0 then 1/n else n
   where n = 0.7


given ::
   EqSys.EquationSystemIgnore Node.Int s
      (Data ([] :> Nil) Double)
given =
   mconcat $
   (XIdx.dTime .= Data.map (const 1) sig0) :
   (XIdx.power node0 node1 .= sig0) :
   (XIdx.power node2 node1 .= sig2) :

   ((EqSys.variable $ XIdx.eta node0 node1) =.=
     EqSys.liftF (Data.map eta01) (EqSys.variable $ XIdx.power node0 node1)) :

   ((EqSys.variable $ XIdx.eta node1 node2) =.=
     EqSys.liftF (Data.map eta12) (EqSys.variable $ XIdx.power node2 node1)) :

   ((EqSys.variable $ XIdx.eta node1 node3) =.=
     EqSys.liftF (Data.map eta13) (EqSys.variable $ XIdx.power node1 node3)) :

   []
   where sig0 = Sig.unpack node0Sig
         sig2 = Sig.unpack node2Sig


main :: IO ()

main =
   case EqSys.solve (quantityTopology topoTripod) given of
      flowTopo -> do

         {-
         @PG:
         Theoretisch kann man hier

             rec = TopoRecord.sectionResultToPowerRecord flowTopo

         schreiben, jedoch muss man danach die Zeitachse integrieren
         und dabei stellt man fest,
         dass die Typargumente fuer die Ableitungen nicht konsistent gesetzt sind.
         -}
         let rec :: Rec.PowerRecord Node.Int [] Double
             rec =
                Rec.Record time $
                Map.mapMaybe (fmap Sig.TC . Result.toMaybe) $
                foldMap fold $
                Map.mapWithKey
                   (FlowTopo.liftEdgeFlow $
                    \e flow ->
                        Map.singleton (Topo.outPosFromDirEdge e)
                           (FlowTopo.flowEnergyOut flow)
                        <>
                        Map.singleton (Topo.inPosFromDirEdge e)
                           (FlowTopo.flowEnergyIn flow)) $
                Graph.edgeLabels $ FlowTopo.topology flowTopo

             sequencePowers :: Sequ.List (Rec.PowerRecord Node.Int [] Double)
             sequencePowers = Chop.genSequ $ Chop.addZeroCrossings rec

             sequenceFlowsFilt :: Sequ.List (Rec.FlowRecord Node.Int [] Double)
             sequenceFlowsFilt =
               fmap Rec.partIntegrate sequencePowers


             sequenceFlowGraph ::
               SeqQty.Graph Node.Int
                 (Result.Result (Data Nil Double)) (Result.Result (Data ([] :> Nil) Double))
             sequenceFlowGraph =
               SeqRec.flowGraphFromSequence $
               fmap (TopoRecord.flowTopologyFromRecord topoTripod) $
               sequenceFlowsFilt


         concurrentlyMany_ [
            PlotIO.record "Power Signals" DefaultTerm.cons show id rec,
            PlotIO.recordList_extract "Power Signals" DefaultTerm.cons show id
               [(Rec.Name "bla", rec)]
               [ XIdx.ppos node1 node0,
                 XIdx.ppos node1 node2,
                 XIdx.ppos node1 node3 ],

            Draw.xterm $ Draw.title "sequenceFlowGraph"
                     $ Draw.seqFlowGraph Draw.optionsDefault sequenceFlowGraph,

            Draw.xterm $ Draw.flowSection Draw.optionsDefault flowTopo ]
