module Main where

import EFA2.StateAnalysis.StateAnalysis (bruteForce)
import EFA2.Topology.Draw

import EFA2.Example.ExampleHelper (makeNodes, makeSimpleEdges)

import EFA2.Topology.TopologyData as TD
import EFA2.Topology.EquationGenerator
import qualified EFA2.Topology.Flow as Flow
import EFA2.Signal.Index as Idx
import EFA2.Topology.EfaGraph as Gr
import EFA2.Signal.SequenceData
import EFA2.Interpreter.Env as Env
import EFA2.Solver.Equation (mkVar)


sec :: Idx.Section
sec = Idx.Section 0

topoDreibein :: Topology
topoDreibein = mkGraph (makeNodes ns) (makeSimpleEdges es)
  where ns = [(0, Source), (1, Sink), (2, Crossing), (3, TD.Storage)]
        es = [(0, 2), (1, 2), (2, 3)]


seqTopo :: SequFlowGraph
seqTopo = mkSeqTopo (select sol states)
  where sol = bruteForce topoDreibein
        states = [1, 0, 1]
        select ts = map (ts!!)
        mkSeqTopo = Flow.mkSequenceTopology
                    . Flow.genSectionTopology
                    . SequData

given :: [(Env.Index, Double)]
given = [ (mkVar (Idx.DTime (Idx.Record Absolute) initSection), 1),
          (mkVar (Idx.DTime (Idx.Record Absolute) (Section 0)), 1),
          (mkVar (Idx.DTime (Idx.Record Absolute) (Section 1)), 1),
          (mkVar (Idx.DTime (Idx.Record Absolute) (Section 2)), 1),


          (mkVar (Idx.Storage (Idx.Record Absolute) 
                              (Idx.SecNode (Section 2) (Idx.Node 3))), 10.0),

--          (makeVar Idx.Power (Idx.SecNode initSection (Idx.Node 3))
--                             (Idx.SecNode initSection (Idx.Node (-1))), 3.0),


          (makeVar Idx.Power (Idx.SecNode (Section 0) (Idx.Node 2))
                             (Idx.SecNode (Section 0) (Idx.Node 3)), 4.0),


          (makeVar Idx.X (Idx.SecNode (Section 0) (Idx.Node 2))
                         (Idx.SecNode (Section 0) (Idx.Node 3)), 0.32),

--         (makeVar Idx.X (Idx.SecNode (Section 1) (Idx.Node 3))
--                         (Idx.SecNode (Section 2) (Idx.Node 3)), 1),


          (makeVar Idx.Power (Idx.SecNode (Section 1) (Idx.Node 3))
                             (Idx.SecNode (Section 1) (Idx.Node 2)), 5),

          (makeVar Idx.Power (Idx.SecNode (Section 2) (Idx.Node 3))
                             (Idx.SecNode (Section 2) (Idx.Node 2)), 6),

          (makeVar Idx.Power (Idx.SecNode (Section 3) (Idx.Node 3))
                             (Idx.SecNode (Section 3) (Idx.Node 2)), 7),

          (makeVar Idx.Power (Idx.SecNode (Section 4) (Idx.Node 3))
                             (Idx.SecNode (Section 4) (Idx.Node 2)), 8),



          (makeVar Idx.FEta (Idx.SecNode (Section 0) (Idx.Node 3))
                            (Idx.SecNode (Section 0) (Idx.Node 2)), 0.25),
          (makeVar Idx.FEta (Idx.SecNode (Section 0) (Idx.Node 2))
                            (Idx.SecNode (Section 0) (Idx.Node 3)), 0.25),


          (makeVar Idx.FEta (Idx.SecNode (Section 0) (Idx.Node 2))
                            (Idx.SecNode (Section 0) (Idx.Node 1)), 0.5),

          (makeVar Idx.FEta (Idx.SecNode (Section 0) (Idx.Node 0))
                            (Idx.SecNode (Section 0) (Idx.Node 2)), 0.75) ]


main :: IO ()
main = do 

  let env = solveSystem given seqTopo

  drawTopology seqTopo env
