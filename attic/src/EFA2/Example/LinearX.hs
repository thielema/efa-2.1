module EFA2.Example.LinearX (linearX) where

import Data.Graph.Inductive
import qualified Data.Map as M

import Control.Monad.Error

import EFA2.Signal.Arith
import EFA2.Term.TermData
import EFA2.Term.Env
import EFA2.Graph.GraphData
import EFA2.Graph.Graph
import EFA2.Example.SymSig

numOf :: Int
numOf = 3

sigs :: LRPowerEnv [Val]
sigs (PowerIdx 0 1) = return (replicate numOf 3.0)
sigs (PowerIdx 1 0) = return (replicate numOf 2.2)
sigs idx = throwError (PowerIdxError idx M.empty)


linearX :: (Signal a) => Int -> TheGraph [a]
linearX x = TheGraph g (signal sigs)
  where g = mkGraph (makeNodes no) (makeEdges no)
        no = [0..x]
