{-# LANGUAGE FlexibleContexts #-}
  
module EFA.Data.OD.Signal.Chop where

import qualified EFA.Equation.Arithmetic as Arith
import qualified EFA.Data.Vector as DV
import qualified EFA.Data.Sequence as DataSequ
import qualified EFA.Data.Interpolation as Interp

import qualified EFA.Signal.Sequence as Sequ
import qualified EFA.Signal.Signal as S
import qualified EFA.Signal.Record as Record
import qualified EFA.Signal.Data as Data

import qualified EFA.Data.Axis.Strict as Strict
import qualified EFA.Data.OD.Signal.Flow as SignalFlow
--import qualified EFA.Data.Interpolation as Interp

import qualified Data.NonEmpty as NonEmpty
import qualified Data.NonEmpty.Set as NonEmptySet

import qualified EFA.Flow.Topology.Index as TopoIdx

--import qualified EFA.Flow.SequenceState.Index as Idx


import qualified Data.Map as Map

import EFA.Utility(Caller,
                  --merror,
                  (|>),
                   ModuleName(..),FunctionName, genCaller)


-- newtype Sectioning = Sectioning (NonEmpty.T [] Strict.Section)

modul :: ModuleName
modul = ModuleName "Data.OD.Signal.Chop"

nc :: FunctionName -> Caller
nc = genCaller modul

type Sectioning = [Strict.Range]

chopHRecord ::  
  (Ord b,
   Arith.Constant b,
   DV.Walker vec,
   DV.Storage vec b,
   DV.Storage vec a,
   DV.Slice vec,
   DV.Length vec,
   DV.Len (vec b)) =>
  Caller ->
  SignalFlow.HRecord key inst label vec a b ->
  DataSequ.List (SignalFlow.HRecord key inst label vec a b)
chopHRecord caller powerRecord = sequRecord
  where
    sectioning = findHSections caller powerRecord
    sequRecord = sliceHRecord powerRecord sectioning



findHSections :: 
  (DV.Storage vec a, DV.Length vec, 
   Ord b,
   Arith.Constant b,
   DV.Walker vec,
   DV.Storage vec b,
   DV.Len (vec b)) => 
  Caller ->
  SignalFlow.HRecord key inst label vec a b -> Sectioning
findHSections caller (SignalFlow.HRecord time m) = 
  NonEmpty.toList $ NonEmpty.zipWith (Strict.Range) startIndexList stopIndexList
  where startIndexList = NonEmptySet.toAscList $ foldl1 NonEmptySet.union $ map (SignalFlow.locateSignChanges (caller |> nc "findVSections")) $ Map.elems m
        stopIndexList = NonEmpty.snoc (DV.map (\(Strict.Idx idx)->Strict.Idx $ idx-1) $ 
                                       NonEmpty.tail startIndexList) (Strict.Idx $ Strict.len time)


getSignalSlice :: (DV.Storage vec a, DV.Slice vec) =>
  Strict.Range ->  
  SignalFlow.Data inst vec a -> 
  SignalFlow.Data inst vec a
getSignalSlice  (Strict.Range (Strict.Idx startIdx) (Strict.Idx endIdx)) (SignalFlow.Data vec) = 
    SignalFlow.Data $ DV.slice startIdx (endIdx-startIdx) vec

sliceHRecord :: (DV.Storage vec b, DV.Slice vec) =>
  SignalFlow.HRecord key inst label vec a b -> 
  Sectioning -> 
  DataSequ.List (SignalFlow.HRecord key inst label vec a b)
sliceHRecord (SignalFlow.HRecord t m) sectioning = DataSequ.fromRangeList $ map f sectioning
  where
    f range = (range,SignalFlow.HRecord t (Map.map (getSignalSlice range) m))


convertHRecord2Old :: 
  (DV.Walker sigVec,
   DV.Storage sigVec (Interp.Val a),
   DV.Storage sigVec a) =>
  SignalFlow.HRecord (TopoIdx.Position node) inst label sigVec a (Interp.Val a) ->   
  Record.FlowRecord node sigVec (Interp.Val a)
convertHRecord2Old (SignalFlow.HRecord (Strict.Axis _ _ time) m) = 
  Record.Record (S.TC (Data.Data $ DV.map Interp.Inter time)) (Map.map f m)
  where f (SignalFlow.Data vec) = S.TC (Data.Data vec)


convertToOld :: 
  (DV.Walker sigVec,
   DV.Storage sigVec a,
   DV.Storage sigVec (Interp.Val a)) =>
  DataSequ.List (SignalFlow.HRecord (TopoIdx.Position node) inst label sigVec a (Interp.Val a)) ->
  Sequ.List (Record.FlowRecord node sigVec (Interp.Val a))
convertToOld sequ = DataSequ.toOldSequence convertHRecord2Old sequ

