{-# LANGUAGE FlexibleContexts #-}

module EFA.Action.Flow.Topology.Check where

--import qualified EFA.Action.Flow as ActFlow
import qualified EFA.Action.Flow.Check as ActFlowCheck
-- import qualified EFA.Graph.Topology.Node as Node
import EFA.Equation.Result (Result(Determined,Undetermined))
import qualified EFA.Equation.Arithmetic as Arith
import qualified EFA.Graph as Graph
import qualified EFA.Flow.SequenceState.Index as Idx

import qualified EFA.Data.Interpolation as Interp
import qualified EFA.Data.ND.Cube.Map as CubeMap
import qualified EFA.Data.Vector as DV
import qualified EFA.Flow.Topology.Quantity as TopoQty
import qualified EFA.Flow.Topology as FlowTopo

-- import qualified Data.Foldable as Fold
import qualified Data.Map as Map
import qualified Data.Maybe as Maybe
--import Control.Applicative (liftA2)
--import Control.Monad(join)
--import Data.Foldable (Foldable, foldMap)

import EFA.Utility(Caller,
                 merror,
               --    (|>),
                   ModuleName(..),FunctionName, genCaller)

modul :: ModuleName
modul = ModuleName "Action.Flow.Topology"

nc :: FunctionName -> Caller
nc = genCaller modul

   
getFlowStatus :: 
  (Ord node, Ord (edge node), Ord a, Arith.Constant a,
   DV.Zipper vec, DV.Walker vec, DV.Storage vec ActFlowCheck.EdgeFlowStatus,
   DV.Storage vec (Maybe Idx.AbsoluteState), DV.Storage vec (Interp.Val a),
   DV.Storage vec ActFlowCheck.Validity) =>
  Caller ->
  FlowTopo.Section node edge sectionLabel nodeLabel (Maybe (TopoQty.Flow (Result (CubeMap.Data inst dim vec (Interp.Val a))))) -> 
  Result (CubeMap.Data inst dim vec ActFlowCheck.EdgeFlowStatus)
getFlowStatus caller flowGraph = 
  Maybe.fromJust $ snd $ Map.fold f (0,Nothing) $ Graph.edgeLabels $ TopoQty.topology flowGraph
  where           
    f (Just flow) (expo,Just status) = (expo+1,Just $ combineStatusResults expo status (getEdgeFlowStatus flow))
    f (Just flow) (expo,Nothing) = (expo+1,Just $ getEdgeFlowStatus flow)
    f Nothing (_,_) = merror caller modul "getFlowStatus" "Flow not defined"


combineStatusResults :: 
  (DV.Zipper vec, DV.Storage vec ActFlowCheck.EdgeFlowStatus) => 
  Int ->
  Result (CubeMap.Data inst dim vec ActFlowCheck.EdgeFlowStatus) -> 
  Result (CubeMap.Data inst dim vec ActFlowCheck.EdgeFlowStatus) ->   
  Result (CubeMap.Data inst dim vec ActFlowCheck.EdgeFlowStatus)
combineStatusResults expo (Determined s) (Determined s1) = 
  Determined $ CubeMap.zipWithData 
  (ActFlowCheck.combineEdgeFlowStatus expo) s s1   
combineStatusResults _ _ _ = Undetermined  

getEdgeFlowStatus :: 
  (Ord a, Arith.Constant a, DV.Zipper vec, DV.Walker vec,
   DV.Storage vec (Maybe Idx.AbsoluteState), DV.Storage vec (Interp.Val a),
   DV.Storage vec ActFlowCheck.Validity, DV.Storage vec ActFlowCheck.EdgeFlowStatus) =>
  TopoQty.Flow (Result (CubeMap.Data inst dim vec (Interp.Val a))) -> 
  Result (CubeMap.Data inst dim vec ActFlowCheck.EdgeFlowStatus)
getEdgeFlowStatus fl = f (TopoQty.flowPowerIn fl) (TopoQty.flowPowerOut fl)
  where 
     f (Determined p)  (Determined p1) = Determined (CubeMap.zipWithData (\x y -> ActFlowCheck.EdgeFlowStatus x y) validity state) 
                           where validity = CubeMap.zipWithData (ActFlowCheck.validityCheck edgeFlowCheck) p p1
                                 state = CubeMap.mapData getEdgeState p
     f _ _ = Undetermined

getEdgeState :: 
  (Ord a, Arith.Constant a) => 
  Interp.Val a -> Maybe Idx.AbsoluteState
getEdgeState p = 
  let g x = Just $ case (Arith.sign x) of 
          (Arith.Zero)  -> Idx.AbsoluteState 0
          (Arith.Positive) -> Idx.AbsoluteState 1 
          (Arith.Negative) -> Idx.AbsoluteState 2
  in case p of
          (Interp.Inter x) -> g x 
          (Interp.Invalid _) -> Nothing
          (Interp.Extra x) -> g x 

edgeFlowCheck ::  (Arith.Product a, Ord a, Arith.Constant a) => a -> a -> ActFlowCheck.EdgeFlowConsistency 
edgeFlowCheck x y = ActFlowCheck.EFC signCheck etaCheck
  where
    eta = if x >= Arith.zero then y Arith.~/ x else x Arith.~/ y
    etaCheck = ActFlowCheck.etaCheckFromBool $ eta > Arith.zero && eta < Arith.one 
    signCheck = ActFlowCheck.signCheckFromBool $ Arith.sign x == Arith.sign y



