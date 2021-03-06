module Main where

import qualified EFA.Example.Topology.Tripod.Given as TripodGiven

import qualified EFA.Flow.Sequence.Absolute as EqSys
import qualified EFA.Flow.Draw as Draw

import qualified Data.GraphViz.Attributes.Colors.X11 as Colors


main :: IO ()
main =
  Draw.xterm $
    Draw.bgcolour Colors.Burlywood1 $
    Draw.title "Dies ist der Titel!" $
    Draw.seqFlowGraph
       (Draw.showEtaNode $ Draw.showStorage $ Draw.showCarryEdge $
        Draw.hideVariableIndex $ Draw.optionsDefault) $
    EqSys.solve TripodGiven.seqFlowGraph TripodGiven.equationSystem
