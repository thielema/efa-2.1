{-# LANGUAGE ScopedTypeVariables #-}


module EFA2.Solver.DependencyGraph where

import Data.Graph.Inductive
import Data.Maybe

import qualified Data.Set as S
import qualified Data.Map as M
import qualified Data.List as L
import qualified Data.List.HT as HTL

import Debug.Trace

import EFA2.Utils.Utils
import EFA2.Solver.Equation


dependencyGraph :: (S.Set EqTerm -> S.Set EqTerm -> Bool) -> [S.Set EqTerm] -> Gr (S.Set EqTerm) ()
dependencyGraph p ss = g
  where xs = HTL.removeEach ss
        ys = concatMap (uncurry (mkArcs p)) xs
        m = M.fromList (zip ss [0..])
        es = unique $ map (\(x, y) -> (m M.! x, m M.! y, ())) ys
        g = mkGraph (map flipPair $ M.toList m) es

mkArcs :: (Ord a, Show a) => (S.Set a -> S.Set a -> Bool) -> S.Set a -> [S.Set a] -> [(S.Set a, S.Set a)]
mkArcs p s ss = catMaybes $ map g ss
  where g t | p s t = Just (s, t)
        g _ = Nothing

makeDependencyGraph :: (S.Set EqTerm -> S.Set EqTerm -> Bool) -> [EqTerm] -> Gr EqTerm ()
makeDependencyGraph p ts = deq
  where vsets = map (mkVarSet isVar) ts
        mt = M.fromList (zip vsets ts)
        dg = dependencyGraph p vsets
        deq = nmap (mt M.!) dg

-- | The produced graph has an edge, iff the solution of one node allows for computing the solution 
--   of the other node and the other node has exactly one unknown variable.
dpgDiffByAtMostOne :: [EqTerm] -> Gr EqTerm ()
dpgDiffByAtMostOne = makeDependencyGraph diffByAtMostOne

-- | The resulting graph has an edge iff two nodes have one or more variables in common.
dpgHasSameVariable :: [EqTerm] -> Gr EqTerm ()
dpgHasSameVariable = makeDependencyGraph hasSameVariable

-- | Produces a graph that has an edge iff there is a variable intersection between two nodes
--   and there is no path in the 'dpgDiffByAtMostOne'-graph beween these two nodes.
dpg :: [EqTerm] -> Gr EqTerm ()
dpg ts = L.foldl' (flip delEdge) dpg2 (edges dpg1)
  where dpg1 = dpgDiffByAtMostOne ts
        dpg2 = dpgHasSameVariable ts