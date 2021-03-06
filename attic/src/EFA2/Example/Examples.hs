
module EFA2.Example.Examples where

import EFA2.Topology.Topology (makeNodes, makeSimpleEdges)
import EFA2.Topology.TopologyData (Topology, NodeType(..))
import EFA2.Topology.EfaGraph (mkGraph)


topoDreibein :: Topology
topoDreibein = mkGraph (makeNodes nodes) (makeSimpleEdges edges)
  where nodes = [(0, Source), (1, Sink), (2, Crossing), (3, Storage)]
        edges = [(0, 2), (1, 2), (2, 3)]


topoLoop :: Topology
topoLoop = mkGraph (makeNodes nodes) (makeSimpleEdges edges)
  where nodes = [(0, NoRestriction), (1, Crossing), (2, Crossing), (3, Crossing), (4, NoRestriction), (5, NoRestriction) ]
        edges = [(0, 1), (1, 2), (1, 3),
                 (2, 3), (2, 4), (3, 5) ]

-- Topologie mit zwei Komponenten
topoDoubleLoop :: Topology
topoDoubleLoop = mkGraph (makeNodes nodes) (makeSimpleEdges edges)
  where nodes = [(0, NoRestriction), (1, Crossing), (2, Crossing), (3, Crossing), (4, NoRestriction), (5, NoRestriction),
                 (6, NoRestriction), (7, Crossing), (8, Crossing), (9, Crossing), (10, NoRestriction), (11, NoRestriction) ]
        edges = [(0, 1), (1, 2), (1, 3),
                 (2, 3), (2, 4), (3, 5),
                 (6, 7), (7, 8), (7, 9),
                 (8, 9), (8, 10), (9, 11) ]
