{-# LANGUAGE TypeSynonymInstances, FlexibleInstances #-}

module EFA2.Example.Loop (loop) where

import Data.Graph.Inductive
import qualified Data.Map as M

import Control.Monad.Error


import EFA2.Signal.Arith
import EFA2.Term.TermData
import EFA2.Graph.GraphData
import EFA2.Graph.Graph
import EFA2.Example.SymSig

numOf = 3

sigs :: LRPowerEnv [Val]

sigs (PowerIdx 0 1) = return (replicate numOf 3.0)
sigs (PowerIdx 1 0) = return (replicate numOf 2.2)
sigs (PowerIdx 1 2) = return (replicate numOf 1.8)
sigs (PowerIdx 2 1) = return (replicate numOf 1.0)
sigs (PowerIdx 2 3) = return (replicate numOf 1.1)
sigs (PowerIdx 3 2) = return (replicate numOf 0.5)

sigs (PowerIdx 1 4) = return (replicate numOf 0.4)
sigs (PowerIdx 4 1) = return (replicate numOf 0.3)
sigs (PowerIdx 4 5) = return (replicate numOf 0.1)
sigs (PowerIdx 5 4) = return (replicate numOf 0.05)

sigs (PowerIdx 4 2) = return (replicate numOf 0.2)
sigs (PowerIdx 2 4) = return (replicate numOf 0.1)
sigs idx = throwError (PowerIdxError idx)


loop :: (Signal a) => TheGraph [a]
loop = TheGraph g (signal sigs)
  where g = mkGraph (makeNodes no ++ makeNodes no2) (makeEdges no ++ makeEdges (1:no2) ++ makeEdges [4, 2])
        no = [0..3]
        no2 = [4, 5]