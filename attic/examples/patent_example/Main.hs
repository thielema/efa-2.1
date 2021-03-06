{-# LANGUAGE GADTs #-}

module Main where

import qualified Data.Map as M

import EFA.Topology.Topology
import EFA.Graph.Topology

import EFA.Solver.Equation
import EFA.Solver.EquationOrder

import EFA.Equation.Env
import EFA.Interpreter.Interpreter
import EFA.Interpreter.Arith

import qualified EFA.Graph.Draw as Draw

import qualified EFA.Signal.Signal as S
import EFA.Signal.Signal (Sc, PSigL, toScalar)

import qualified EFA.Signal.Sequence as Seq
import EFA.Signal.SequenceData


topo :: Topology
topo = mkGraph (makeNodes nodes) (makeEdges edges)
  where nodes = [(0, Source), (1, Crossing), (2, Crossing), (3, Sink), (4, Storage 0), (5, Storage 1)]
        edges = [ (0, 1, defaultELabel), 
                  (1, 2, defaultELabel),
                  (1, 4, defaultELabel),
                  (2, 3, defaultELabel),
                  (2, 5, defaultELabel) ]


mkSig :: Int -> ([Val] -> PSigL)
mkSig n = S.fromList . concat . replicate n

symbolic :: Topology -> Envs EqTerm
symbolic g = res { recordNumber = SingleRecord 0 }
  where (envs, ts) = makeAllEquations g [envs0sym]
        ts' = toAbsEquations $ order ts
        res = interpretEqTermFromScratch ts'

numeric :: Topology -> Envs Sc
numeric g = res { recordNumber = SingleRecord 0 }
  where (envs, ts) = makeAllEquations g [envs0num]
        ts' = toAbsEquations $ order ts
        res = interpretFromScratch (recordNumber envs) 1 (map (eqToInTerm envs) ts')


main :: IO ()
main = do
  let 
      s01 = [0, 2, 2, 0, 0, 0, 0, 0, 0, 0]
      s10 = [0, 0.8, 0.8, 0, 0, 0, 0, 0, 0, 0]
      s12 = [0.3, 0.3, 0.3, 0, 0, 0, 0, 0.3, 0.3, 0]
      s21 = [0.2, 0.2, 0.2, 0, 0, 0, 0, 0.2, 0.2, 0]
      s23 = [0, 0.5, 0.5, 0, 0.5, 0.5, 0, 0.5, 0.5, 0]
      s32 = [0, 0.25, 0.25, 0, 0.4, 0.4, 0, 0.25, 0.25, 0]
      s14 = [0, 0.5, 0.5, 0, 0, 0, 0, -0.5, -0.5, 0]
      s41 = [0, 0.3, 0.3, 0, 0, 0, 0, -0.3, -0.3, 0]
      s25 = [0, 0.5, 0.5, 0, -0.5, -0.5, 0, 0.5, 0.5, 0]
      s52 = [0, 0.3, 0.3, 0, -0.3, -0.3, 0, 0.3, 0.3, 0]

      n = 1
      --l = fromIntegral $ length $ replicate n (s01 ++ s01')
      --time = [0, 0] ++ (concatMap (replicate 3) [1.0 .. l])
      time = take (length s01) [0 ..]

      pMap =  M.fromList [ (PPosIdx 0 1, mkSig n s01),
                           (PPosIdx 1 0, mkSig n s10), 
                           (PPosIdx 1 2, mkSig n s12),
                           (PPosIdx 2 1, mkSig n s21),
                           (PPosIdx 2 3, mkSig n s23),
                           (PPosIdx 3 2, mkSig n s32),
                           (PPosIdx 1 4, mkSig n s14),
                           (PPosIdx 4 1, mkSig n s41),
                           (PPosIdx 2 5, mkSig n s25),
                           (PPosIdx 5 2, mkSig n s52) ]



      pRec = PowerRecord (S.fromList time) pMap
      sqTopo = Seq.makeSeqFlowGraph topo $ Seq.makeSequence pRec

      resSym = mapEqTermEnv ((:[]) . simplify) $ symbolic sqTopo

      resNum = numeric sqTopo 

  --drawTopologyX' sqTopo
  --print res 
  Draw.sequFlowGraphAbsWithEnv sqTopo resSym
  --print pRec

-- Symbolic =====================================================================

selfMap :: (MkVarC a, Ord a) => [a] -> M.Map a EqTerm
selfMap xs = M.fromList $ map (\x -> (x, mkVar x)) xs


selfEta :: (MkVarC a, Ord a) => [a] -> M.Map a (b -> EqTerm)
selfEta ns = M.fromList $ map (\x -> (x, const $ mkVar x)) ns

dtimes0sym :: DTimeMap EqTerm
dtimes0sym = selfMap [ DTimeIdx Idx.initSection 0, DTimeIdx 0 0, DTimeIdx 1 0, DTimeIdx 2 0 ]


power0sym :: PowerMap EqTerm
power0sym = selfMap [ PowerIdx Idx.initSection 0 4 Idx.initSection, PowerIdx Idx.initSection 0 5 Idx.initSection,
                      PowerIdx 0 0 0 1, PowerIdx 2 0 3 2, PowerIdx 1 0 3 2 ]

eta0sym :: FEtaMap EqTerm
eta0sym = selfEta [ FEtaIdx 0 0 0 1, FEtaIdx 0 0 1 0, 
                    FEtaIdx 0 0 1 2, FEtaIdx 0 0 2 1,
                    FEtaIdx 0 0 2 3, FEtaIdx 0 0 3 2,
                    FEtaIdx 0 0 1 4, FEtaIdx 0 0 4 1,
                    FEtaIdx 0 0 2 5, FEtaIdx 0 0 5 2,

                    FEtaIdx 1 0 0 1, FEtaIdx 1 0 1 0, 
                    FEtaIdx 1 0 1 2, FEtaIdx 1 0 2 1,
                    FEtaIdx 1 0 2 3, FEtaIdx 1 0 3 2,
                    FEtaIdx 1 0 1 4, FEtaIdx 1 0 4 1,
                    FEtaIdx 1 0 2 5, FEtaIdx 1 0 5 2,

                    FEtaIdx 2 0 0 1, FEtaIdx 2 0 1 0, 
                    FEtaIdx 2 0 1 2, FEtaIdx 2 0 2 1,
                    FEtaIdx 2 0 2 3, FEtaIdx 2 0 3 2,
                    FEtaIdx 2 0 1 4, FEtaIdx 2 0 4 1,
                    FEtaIdx 2 0 2 5, FEtaIdx 2 0 5 2 ]

x0sym :: XMap EqTerm
x0sym = selfMap [ XIdx 0 0 1 2, XIdx 0 0 1 4, XIdx 0 0 2 3, XIdx 0 0 2 5,
                  XIdx 2 0 2 3, XIdx 2 0 2 5 ]


envs0sym = emptyEnv { recordNumber = SingleRecord 0,
                      powerMap = power0sym,
                      dtimeMap = dtimes0sym,
                      xMap = x0sym,
                      fetaMap = eta0sym }


-- Numeric =====================================================================

dtimes0num :: DTimeMap Sc
dtimes0num = M.fromList [ (DTimeIdx Idx.initSection 0, toScalar 1.0),
                          (DTimeIdx 0 0, toScalar 1.0),
                          (DTimeIdx 1 0, toScalar 1.0),
                          (DTimeIdx 2 0, toScalar 1.0) ]


power0num :: PowerMap Sc
power0num = M.fromList [ (PowerIdx Idx.initSection 0 4 (-1), toScalar 8.0),
                         (PowerIdx Idx.initSection 0 5 (-1), toScalar 6.0),
                         (PowerIdx 0 0 0 1, toScalar 3.5),
                         (PowerIdx 2 0 3 2, toScalar 2.0),
                         (PowerIdx 1 0 3 2, toScalar 2.5) ]

eta0num :: FEtaMap Sc
eta0num = M.fromList [ (FEtaIdx 0 0 0 1, S.map $ const 0.8), (FEtaIdx 0 0 1 0, S.map $ const 0.8),
                       (FEtaIdx 0 0 1 2, S.map $ const 0.8), (FEtaIdx 0 0 2 1, S.map $ const 0.8),
                       (FEtaIdx 0 0 2 3, S.map $ const 0.8), (FEtaIdx 0 0 3 2, S.map $ const 0.8),
                       (FEtaIdx 0 0 1 4, S.map $ const 0.8), (FEtaIdx 0 0 4 1, S.map $ const 0.8),
                       (FEtaIdx 0 0 2 5, S.map $ const 0.8), (FEtaIdx 0 0 5 2, S.map $ const 0.8),

                       (FEtaIdx 1 0 0 1, S.map $ const 0.8), (FEtaIdx 1 0 1 0, S.map $ const 0.8),
                       (FEtaIdx 1 0 1 2, S.map $ const 0.8), (FEtaIdx 1 0 2 1, S.map $ const 0.8),
                       (FEtaIdx 1 0 2 3, S.map $ const 0.8), (FEtaIdx 1 0 3 2, S.map $ const 0.8),
                       (FEtaIdx 1 0 1 4, S.map $ const 0.8), (FEtaIdx 1 0 4 1, S.map $ const 0.8),
                       (FEtaIdx 1 0 2 5, S.map $ const 0.8), (FEtaIdx 1 0 5 2, S.map $ const 0.8),

                       (FEtaIdx 2 0 0 1, S.map $ const 0.8), (FEtaIdx 2 0 1 0, S.map $ const 0.8),
                       (FEtaIdx 2 0 1 2, S.map $ const 0.8), (FEtaIdx 2 0 2 1, S.map $ const 0.8),
                       (FEtaIdx 2 0 2 3, S.map $ const 0.8), (FEtaIdx 2 0 3 2, S.map $ const 0.8),
                       (FEtaIdx 2 0 1 4, S.map $ const 0.8), (FEtaIdx 2 0 4 1, S.map $ const 0.8),
                       (FEtaIdx 2 0 2 5, S.map $ const 0.8), (FEtaIdx 2 0 5 2, S.map $ const 0.8) ]

x0num :: XMap Sc
x0num = M.fromList [ (XIdx 0 0 1 2, toScalar 0.6),
                     (XIdx 0 0 1 4, toScalar 0.4),
                     (XIdx 0 0 2 3, toScalar 0.6),
                     (XIdx 0 0 2 5, toScalar 0.4),
                     (XIdx 2 0 2 3, toScalar 0.6),
                     (XIdx 2 0 2 5, toScalar 0.4) ]


envs0num = emptyEnv { recordNumber = SingleRecord 0,
                      powerMap = power0num,
                      dtimeMap = dtimes0num,
                      xMap = x0num,
                      fetaMap = eta0num }


