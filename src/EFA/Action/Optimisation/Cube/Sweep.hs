{-# LANGUAGE Rank2Types #-}
{-# LANGUAGE TypeOperators #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE  TypeFamilies #-}

module EFA.Action.Optimisation.Cube.Sweep where
import EFA.Utility(Caller,
                   merror,(|>),
                   ModuleName(..),FunctionName, genCaller)
  
import qualified EFA.Action.EtaFunctions as EtaFunctions

import qualified EFA.Data.Vector as DV
import qualified EFA.Data.ND as ND
import qualified EFA.Data.Axis.Strict as Strict
import qualified EFA.Flow.Topology.Record as TopoRecord
--import qualified EFA.Flow.Topology as FlowTopoPlain

import qualified EFA.Data.Interpolation as Interp
--import qualified EFA.Application.Utility as AppUt

--import EFA.Application.Utility (quantityTopology)
--import qualified EFA.Application.Optimisation.Sweep as Sweep
--import EFA.Application.Optimisation.Params (Name)
--import qualified EFA.Application.Optimisation.Params as Params

--import qualified EFA.Flow.Topology.Absolute as EqSys
import qualified EFA.Flow.Topology.Quantity as FlowTopo
--import qualified EFA.Flow.Topology.Index as XIdx
--import qualified EFA.Flow.Topology.Variable as Variable
--import EFA.Flow.Topology.Absolute ( (.=), 
--                                    (=.=) )

--import qualified EFA.Flow.Absolute as EqAbs
--import qualified EFA.Flow.Absolute as EqAbs

import qualified EFA.Equation.Arithmetic as Arith
--import qualified EFA.Equation.RecordIndex as RecIdx
--import qualified EFA.Equation.Verify as Verify
import qualified EFA.Equation.Result as Result
--import qualified EFA.Flow.Topology.Record as TopoRecord

import qualified EFA.Graph.Topology.Node as Node
import qualified EFA.Graph.Topology as Topo
--import qualified EFA.Flow.Topology.Quantity as TopoQty

--import qualified EFA.Signal.Vector as SV
--import qualified EFA.Signal.Signal as Sig
--import qualified EFA.Signal.Record as Record
--import qualified EFA.Signal.Data as Data
--import EFA.Signal.Data (Data(Data), Nil,(:>))

--import qualified  UniqueLogic.ST.TF.System as ULSystem

import qualified Data.Map as Map
--import qualified Data.Foldable as Fold
-- import Data.Map as (Map)
--import Data.Monoid((<>))

import qualified EFA.Flow.Topology.Index as TopoIdx
--import qualified EFA.Equation.Result as Result
import qualified EFA.Data.Collection as Collection
import qualified EFA.Data.ND.Cube.Map as CubeMap
import qualified EFA.Data.ND.Cube.Grid as CubeGrid


import qualified EFA.Action.Optimisation.Sweep as Sweep
import qualified EFA.Action.Optimisation.Cube.Solve as CubeSolve

import qualified Data.Maybe as Maybe

--import qualified EFA.Flow.Topology as FlowTopo

-- TODO: Modul so verallgemeinern, dass mit verschiedenen Datentypen gesweept werden kann
modul :: ModuleName
modul = ModuleName "DoubleSweep"

nc :: FunctionName -> Caller
nc = genCaller modul


type Given inst dim dim1 label vec vec1 a b =  
  CubeMap.Cube (Sweep.Demand inst) dim label vec a (Collection.Collection label (CubeMap.Cube (Sweep.Search inst) dim1 label vec1 a b)) 

type SweepResult node inst dim dim1 label vec vec1 a b = 
  CubeMap.Cube (Sweep.Demand inst) dim label vec a (FlowTopo.Section node (Result.Result (CubeMap.Data (Sweep.Search inst) dim1 vec1 b)))

type DemandSweepResult node inst dim label vec a b = 
  CubeMap.Cube (Sweep.Demand inst) dim label vec a (FlowTopo.Section node b)

generateGiven :: 
  (Eq label, 
   DV.Walker vec,
   DV.Storage vec (ND.Data dim a),
   DV.Storage vec [a],
   DV.Storage vec a,
   DV.Storage vec (vec [a]),
   DV.Storage vec (Collection.Collection label (CubeMap.Cube (Sweep.Search inst) dim1 label vec1 a (Interp.Val a))),
   DV.Singleton vec,
   Eq (vec1 a), 
   Ord label,
   DV.Walker vec1,
   DV.Storage vec1 a,
   DV.Storage vec1 (ND.Data dim1 a),
   DV.Storage vec1 [a],
   DV.Storage vec1 (vec1 [a]),
   DV.Singleton vec1,
   DV.FromList vec1,
   DV.Storage vec1 (Interp.Val a),
   DV.FromList vec) =>
  Caller ->
  (CubeGrid.Grid (Sweep.Demand inst) dim label vec a) -> 
  (CubeGrid.Grid (Sweep.Search inst) dim1 label vec1 a) -> 
  Given inst dim dim1 label vec vec1 a (Interp.Val a)
  
generateGiven caller demandGrid searchGrid = 
  if CubeGrid.haveNoCommonAxes demandGrid searchGrid then result else err
  where 
    err = merror (caller |> nc "generateWithGrid")  modul "generateWithGrid"
          "Demand and search grid must not have the same Variables"
    result = CubeMap.generateWithGrid (makeCollection) demandGrid
    makeCollection demandCoord = Collection.fromList  (nc "generateWithGrid") $ 
                                 ND.toList demandCubes ++ ND.toList searchCubes
       where
        demandCubes = ND.imap (\dimIdx axis -> (Strict.getLabel axis, CubeMap.map Interp.Inter $
                            CubeMap.generateWithGrid (const $ ND.unsafeLookup demandCoord dimIdx) searchGrid)) demandGrid 
        
        searchCubes = ND.imap (\dimIdx axis -> (Strict.getLabel axis, CubeMap.map Interp.Inter $
                            CubeMap.generateWithGrid (flip ND.unsafeLookup dimIdx) searchGrid)) searchGrid

solve:: 
  (DV.Walker vec,
   DV.Storage vec (Collection.Collection (TopoIdx.Position node) (CubeMap.Cube (Sweep.Search inst) dim1 (TopoIdx.Position node) vec1 a (Interp.Val a))),
   Eq a,
   Arith.Constant a,
   Node.C node,
   DV.Zipper vec1,
   DV.Walker vec1,
   DV.Storage vec1 Bool,
   DV.Storage vec1 (Interp.Val a),
   DV.Storage vec1 a,
   DV.Singleton vec1,
   DV.Length vec1,
   DV.Storage vec (FlowTopo.Section node (Result.Result (CubeMap.Data (Sweep.Search inst) dim1 vec1 (Interp.Val a))))) =>
  Topo.Topology node -> 
  EtaFunctions.FunctionMap node a ->  
  Given inst dim dim1 (TopoIdx.Position node) vec vec1 a (Interp.Val a) ->
  SweepResult node inst dim dim1 (TopoIdx.Position node) vec vec1 a (Interp.Val a)
solve topology etaFunctions given = CubeMap.map (CubeSolve.solve topology etaFunctions) given


-- | Delivers the energy flow sweep at one location in the demand room 
getSearchSweepFlow::
  (DV.Storage vec a,
   DV.Length vec, 
   DV.LookupMaybe vec (FlowTopo.Section node (Result.Result (CubeMap.Data (Sweep.Search inst) dim1 vec1 (Interp.Val a)))))=>
  SweepResult node inst dim dim1 (TopoIdx.Position node) vec vec1 a (Interp.Val a) ->
  CubeGrid.DimIdx dim ->
  Maybe (FlowTopo.Section node (Result.Result (CubeMap.Data (Sweep.Search inst) dim1 vec1 (Interp.Val a))))  
getSearchSweepFlow result ndIdx = CubeMap.lookupMaybe ndIdx result

-- | Delivers the energy flow at one location in the demand room and one location in the search room
getSearchSweepPowers :: 
  (Ord node, 
   DV.Storage vec a,
   DV.LookupMaybe vec (FlowTopo.Section node (Result.Result (CubeMap.Data (Sweep.Search inst) dim1 vec1 (Interp.Val a)))),
   DV.Length vec) =>
  CubeGrid.Grid (Sweep.Search inst) dim1 (TopoIdx.Position node) vec1 a ->
  SweepResult node inst dim dim1 (TopoIdx.Position node) vec vec1 a (Interp.Val a) -> 
  CubeGrid.DimIdx dim -> 
  Maybe (Collection.Collection (TopoIdx.Position node) 
         (Result.Result (CubeMap.Cube (Sweep.Search inst) dim1 (TopoIdx.Position node) vec1 a (Interp.Val a))))
getSearchSweepPowers sweepGrid result ndIdx = f $ getSearchSweepFlow result ndIdx 
  where f (Just flow) = Just $ Collection.Collection (Result.Determined sweepGrid) (TopoRecord.sectionResultToPowerMap flow)
        f Nothing = Nothing


-- | Delivers the energy flow at one location in the demand room and one location in the search room
getFlowAtSingleSweepPoint::
  (DV.Storage vec a,
   DV.LookupMaybe vec (FlowTopo.Section node (Result.Result (CubeMap.Data (Sweep.Search inst) dim1 vec1 (Interp.Val a)))),
   DV.Length vec, 
   DV.Storage vec1 a,
   DV.LookupMaybe vec1 (Interp.Val a),
   DV.Length vec1) =>
  SweepResult node inst dim dim1 (TopoIdx.Position node) vec vec1 a (Interp.Val a) ->
  CubeGrid.Grid (Sweep.Search inst) dim1 label vec1 a ->
  CubeGrid.DimIdx dim ->
  CubeGrid.DimIdx dim1 ->
  Maybe (FlowTopo.Section node (Result.Result  (Maybe (Interp.Val a))))  
getFlowAtSingleSweepPoint result sweepGrid demandIdx searchIdx = f $ CubeMap.lookupMaybe demandIdx result
  where f (Just sweepFlow) = Just $ FlowTopo.mapSection g sweepFlow
        f Nothing = Nothing  
        g (Result.Determined cubeData) = Result.Determined $ CubeMap.lookupMaybe searchIdx (CubeMap.Cube sweepGrid cubeData)
        g Result.Undetermined = Result.Undetermined


{-    
getDemandSweepFlow:: 
  (Result.Result (CubeMap.Data (Sweep.Search inst) dim1 vec1 (Interp.Val a) -> Result.Result (Interp.Val a))) ->   
  SweepResult node inst dim dim1 (TopoIdx.Position node) vec vec1 a (Interp.Val a) ->
  DemandSweepResult node inst dim (TopoIdx.Position node) vec a (Interp.Val a) -}
getDemandSweepFlow f result = CubeMap.map (FlowTopo.mapSection f) result  

  
getDemandSweepPower:: 
  (Eq a,Ord node,
   DV.Storage vec (FlowTopo.Section node (Result.Result (CubeMap.Data (Sweep.Search inst) dim1 vec1 (Interp.Val a)))),
   DV.Storage vec (Maybe (Result.Result (Interp.Val a))),
   Arith.Constant a,
   DV.Storage vec (Interp.Val a), 
   DV.Walker vec,
   DV.Storage vec (FlowTopo.Section node (Result.Result (Interp.Val a))),
   DV.Storage vec (Map.Map (TopoIdx.Position node) (Result.Result (Interp.Val a))),
   DV.Singleton vec)=>
  (Result.Result (CubeMap.Data (Sweep.Search inst) dim1 vec1 (Interp.Val a)) -> Result.Result (Interp.Val a)) -> 
  SweepResult node inst dim dim1 (TopoIdx.Position node) vec vec1 a (Interp.Val a) ->
  TopoIdx.Position node  -> 
  Maybe (Result.Result (CubeMap.Cube (Sweep.Demand inst) dim (TopoIdx.Position node) vec a (Interp.Val a)))
  
getDemandSweepPower f result key = g cube
  where
    g cu = case (CubeMap.any (== Nothing) cu, CubeMap.any (== Just (Result.Undetermined)) cu) of
      (True,_) -> Nothing
      (False,True) -> Just (Result.Undetermined)
      (False,False) -> Just $ Result.Determined $ CubeMap.map (\(Just (Result.Determined x)) -> x) cu          
    cube = CubeMap.map (Map.lookup key) powerMap      
    powerMap = CubeMap.map TopoRecord.sectionResultToPowerMap $ getDemandSweepFlow f result                       

getDemandSweepPowers::
  (Eq a,Ord node,
   DV.Storage vec (FlowTopo.Section node (Result.Result (CubeMap.Data (Sweep.Search inst) dim1 vec1 (Interp.Val a)))), 
        Arith.Constant a,
   DV.Walker vec, 
   DV.LookupUnsafe vec (FlowTopo.Section node (Result.Result (CubeMap.Data (Sweep.Search inst) dim1 vec1 (Interp.Val a)))),
   DV.Storage
   vec
   (Map.Map (TopoIdx.Position node) (Result.Result (Interp.Val a))),
   DV.Storage
   vec (FlowTopo.Section node (Result.Result (Interp.Val a))),
   DV.Storage vec (Interp.Val a),
   DV.Storage vec (Maybe (Result.Result (Interp.Val a))),
   DV.Singleton vec)=>
  (Result.Result (CubeMap.Data (Sweep.Search inst) dim1 vec1 (Interp.Val a)) -> Result.Result (Interp.Val a)) -> 
  SweepResult node inst dim dim1 (TopoIdx.Position node) vec vec1 a (Interp.Val a) ->
  Collection.Collection (TopoIdx.Position node) 
  (Result.Result (CubeMap.Cube (Sweep.Demand inst) dim (TopoIdx.Position node) vec a (Interp.Val a)))
getDemandSweepPowers f result = Collection.Collection (Result.Determined (CubeMap.getGrid result)) $ 
                                Map.mapWithKey (\ key _ -> fmap CubeMap.getData $ Maybe.fromJust $ getDemandSweepPower f result key) powerMap
  where
    powerMap = TopoRecord.sectionResultToPowerMap $ CubeMap.lookupLinUnsafe result (CubeGrid.LinIdx 0)