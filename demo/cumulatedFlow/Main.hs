module Main where

import qualified EFA.Example.Topology.TripodA as Tripod
import EFA.Example.Topology.TripodA (Node, node0, node1, node2, node3)
import EFA.Application.Utility ( seqFlowGraphFromStates )

import qualified EFA.Flow.Cumulated.Absolute as CumEqSys
import qualified EFA.Flow.Cumulated.Quantity as Cumulated

import qualified EFA.Flow.Sequence.Absolute as EqSys
import qualified EFA.Flow.Sequence.Quantity as SeqFlow
import qualified EFA.Flow.Sequence.Index as XIdx
import qualified EFA.Flow.Draw as Draw
import EFA.Flow.Sequence.Absolute ( (.=) )

import qualified EFA.Graph.Topology.Index as Idx
import qualified EFA.Graph as Graph

import qualified EFA.Utility.Stream as Stream
import EFA.Utility.Async (concurrentlyMany_)
import EFA.Utility.Stream (Stream((:~)))

import Data.Monoid (Monoid, mconcat, mempty)


sec0, sec1, sec2 :: Idx.Section
sec0 :~ sec1 :~ sec2 :~ _ = Stream.enumFrom $ Idx.Section 0


given :: EqSys.EquationSystemIgnore Node s Double Double
given =
   mconcat $

   (XIdx.dTime sec0 .= 0.5) :
   (XIdx.dTime sec1 .= 2) :
   (XIdx.dTime sec2 .= 1) :

   (XIdx.storage (Idx.afterSection sec2) node3 .= 10.0) :


   (XIdx.power sec0 node2 node3 .= 4.0) :

   (XIdx.x sec0 node2 node3 .= 0.32) :

   (XIdx.power sec1 node3 node2 .= 5) :
   (XIdx.power sec2 node3 node2 .= 6) :

   (XIdx.eta sec0 node3 node2 .= 0.25) :
   (XIdx.eta sec0 node2 node1 .= 0.5) :
   (XIdx.eta sec0 node0 node2 .= 0.75) :

   (XIdx.eta sec1 node2 node1 .= 0.5) :
   (XIdx.eta sec1 node0 node2 .= 0.75) :
   (XIdx.power sec1 node1 node2 .= 4.0) :


   (XIdx.eta sec2 node3 node2 .= 0.75) :
   (XIdx.eta sec2 node2 node1 .= 0.5) :
   (XIdx.eta sec2 node0 node2 .= 0.75) :
   (XIdx.power sec2 node1 node2 .= 4.0) :

   (XIdx.eta sec1 node2 node3 .= 0.25) :

   []


main :: IO ()
main = do

   let solved =
          EqSys.solve
             (seqFlowGraphFromStates Tripod.topology [1, 0, 1])
             given
       cum =
          Graph.mapEdge Cumulated.flowResultFromCumResult $
          Cumulated.fromSequenceFlowResult $ SeqFlow.sequence solved
       cumSolved = CumEqSys.solve cum mempty

   concurrentlyMany_ $ map Draw.xterm $
      Draw.sequFlowGraph Draw.optionsDefault solved :
      Draw.cumulatedFlow cum :
      Draw.cumulatedFlow cumSolved :
      []