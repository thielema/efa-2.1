module EFA.Action.Optimisation.Loop where

import qualified EFA.Action.Flow.Balance as Balance

import qualified EFA.Equation.Arithmetic as Arith
--import qualified Data.Map as Map
import qualified EFA.Utility.List as UtList

--import Text.Printf (printf, PrintfArg) --,IsChar)
import EFA.Utility(Caller,
                   --merror,
                   (|>),
                   ModuleName(..),FunctionName, genCaller)

modul :: ModuleName
modul = ModuleName "EFA.Action.Optimisation.Loop"

nc :: FunctionName -> Caller
nc = genCaller modul

newtype EtaCounter = EtaCounter Int
newtype MaxEtaIterations = MaxEtaIterations Int

incrementEtaCounter :: EtaCounter -> EtaCounter
incrementEtaCounter (EtaCounter cnt) = EtaCounter $ cnt+1

data EtaLoopParams = 
  EtaLoopParams
  {
    accessMaxEtaIterations :: MaxEtaIterations}
  
  
data BalanceLoopParams node a =  
  BalanceLoopParams 
  {accessMaxIterationsPerStorage :: Balance.MaxIterationsPerStorage , 
   accessMaxIterations :: Balance.MaxIterations,
   accessThreshold :: Balance.Threshold a, 
   accessInitialForcing :: Balance.Forcing node a,
   accessInitialStep :: Balance.ForcingStep node a,   
   accessInitialSto :: node}

data EtaLoopItem node a z = 
  EtaLoopItem EtaCounter [BalanceLoopItem node a z]

data BalanceLoopItem node a z = 
  BalanceLoopItem (Balance.BalanceCounter node) node
  (Balance.Forcing node a)  (Balance.ForcingStep node a) 
  (Balance.Balance node a) (Balance.BestForcingPair a) z

etaLoop :: (Ord node,Ord a, Show a, Show node, Arith.Constant a) =>
  Caller ->
  [node] ->
  EtaLoopParams ->
  BalanceLoopParams node a ->
  (Balance.Forcing node a -> z) ->
  (z -> Balance.Balance node a) ->
  [EtaLoopItem node a z]
etaLoop caller storages etaParams balParams systemFunction getBalance =  UtList.takeUntil check $ 
  go [EtaLoopItem (EtaCounter 0)  [BalanceLoopItem initialCount initialSto initialForcing 
                                   initialStep initialBlance initialBestPair initialResult] ]
  where
    check (EtaLoopItem (EtaCounter count) _) = count > maxEtaIterations 
    (MaxEtaIterations maxEtaIterations) = accessMaxEtaIterations etaParams
    initialStep = accessInitialStep balParams
    initialForcing = accessInitialForcing balParams
    initialSto = accessInitialSto balParams
    initialCount = Balance.initialiseBalanceCounter storages
    initialResult = systemFunction initialForcing
    initialBlance = getBalance initialResult
    initialBestPair = Balance.emptyBestForcingPair
    go xs = go $ xs ++ [EtaLoopItem count balLoop]
      where
        count = incrementEtaCounter lastCount
        (EtaLoopItem lastCount lastBalLoop) = last xs
        balLoop = balanceLoop (caller |> nc "etaLoop") balParams systemFunction getBalance (last lastBalLoop)

balanceLoop :: 
  (Ord a, Ord node, Show node, Arith.Constant a,Show a) =>
  Caller ->                               
  BalanceLoopParams node a ->
  (Balance.Forcing node a -> z) ->
  (z -> Balance.Balance node a) ->
  BalanceLoopItem node a z ->
  [BalanceLoopItem node a z]
balanceLoop caller balParams systemFunction getBalance lastBalItem = UtList.takeUntil check $ tail $ go [lastBalItem]
  where
    check (BalanceLoopItem cnt _ _ _ bal _ _) = 
      (Balance.checkBalance threshold bal) || 
      Balance.checkBalanceCounter cnt maxIterations
    threshold = accessThreshold balParams
    maxIterations = accessMaxIterations balParams   
    maxIterationsPerStorage = accessMaxIterationsPerStorage balParams
    go xs = go $ xs ++ [BalanceLoopItem count sto forcing nextStep balance bestPair result]
      where 
        (BalanceLoopItem lastCount lastSto lastForcing step lastBalance lastBestPair _) = last xs
        sto = Balance.selectStorageToForce (caller |> nc "balanceOneStorageLoop") 
              lastBalance threshold lastCount maxIterationsPerStorage lastSto 
        forcing = Balance.addForcingStep (caller |> nc "balanceOneStorageLoop") lastForcing step sto
        result = systemFunction forcing
        balance = getBalance result
        nextStep = Balance.calculateNextBalanceStep caller balance bestPair step sto
        count = Balance.incrementBalanceCounter lastCount sto
        bestPair = Balance.rememberBestBalanceForcing (caller |> nc "balanceOneStorageLoop") lastBestPair (forcing, balance) sto
        
        
--  in UtList.takeUntil check $ go [BalanceLoopItem initialCount initialSto initialForcing initialStep 
--                                   initialBalance Balance.emptyBestForcingPair intialResult] 
{-
balanceLoop :: 
  (Ord a, Ord node, Show node, Arith.Constant a,Show a) =>
  Caller ->                               
  BalanceLoopParams node a ->
  (Balance.Forcing node a -> z) ->
  (z -> Balance.Balance node a) ->
  Balance.BalanceCounter node ->
  (Balance.Forcing node a) ->
  (Balance.ForcingStep node a) -> 
  node ->
  [BalanceLoopItem node a z]
balanceLoop caller balParams systemFunction getBalance initialCount initialForcing initialStep initialSto = 
  let  
    intialResult = systemFunction initialForcing
    initialBalance = getBalance intialResult
    check (BalanceLoopItem cnt _ _ _ bal _ _) = 
      (Balance.checkBalance threshold bal) || 
      Balance.checkBalanceCounter cnt maxIterations
    threshold = accessThreshold balParams
    maxIterations = accessMaxIterations balParams   
    maxIterationsPerStorage = accessMaxIterationsPerStorage balParams
    go xs = go $ xs ++ [BalanceLoopItem count sto forcing nextStep balance bestPair result]
      where 
        (BalanceLoopItem lastCount lastSto lastForcing step lastBalance lastBestPair _) = last xs
        sto = Balance.selectStorageToForce (caller |> nc "balanceOneStorageLoop") 
              lastBalance threshold lastCount maxIterationsPerStorage sto 
        forcing = Balance.addForcingStep (caller |> nc "balanceOneStorageLoop") lastForcing step sto
        result = systemFunction forcing
        balance = getBalance result
        nextStep = Balance.calculateNextBalanceStep caller balance bestPair step sto
        count = Balance.incrementBalanceCounter lastCount sto
        bestPair = Balance.rememberBestBalanceForcing (caller |> nc "balanceOneStorageLoop") lastBestPair (forcing, balance) sto
        
        
  in UtList.takeUntil check $ go [BalanceLoopItem initialCount initialSto initialForcing initialStep 
                                   initialBalance Balance.emptyBestForcingPair intialResult] 

-}

{-
balanceOneStorageLoopM :: 
  (Ord a, Ord node, Show node, Arith.Constant a,Show a) =>
  Caller ->                               
  BalanceLoopParams node a ->
  (Balance.Forcing node a -> z) ->
  (z -> Balance.Balance node a) ->
  Balance.BalanceCounter node ->
  (Balance.Forcing node a) ->
  (Balance.ForcingStep node a) -> 
  node ->
  [BalanceLoopItem node a z]
balanceOneStorageLoopM caller params systemFunction getBalance initialCount initialForcing initialStep sto = do
  let  
    intialResult = systemFunction initialForcing
    initialBalance = getBalance intialResult
    check (BalanceLoopItem cnt _ _ bal _ _ ) = 
      (Balance.checkBalance caller threshold bal sto) || 
      Balance.checkBalanceCounter cnt maxIterations
    threshold = accessThreshold params
    maxIterations = accessMaxIterationsPerStorage params   
    go (BalanceLoopItem lastCount lastForcing step lastBalance lastBestPair _) = do 
      let 
--        (BalanceLoopItem lastCount lastForcing step lastBalance lastBestPair _) = last xs
        forcing = Balance.addForcingStep (caller |> nc "balanceOneStorageLoopIO") lastForcing step sto
        result = systemFunction forcing
        balance = getBalance result
        nextStep = Balance.calculateNextBalanceStep caller balance bestPair step sto
        count = incrementBalanceCounter lastCount sto
        bestPair = Balance.rememberBestBalanceForcing (caller |> nc "balanceOneStorageLoopIO") lastBestPair (forcing, balance) sto
      return $ BalanceLoopItem count forcing nextStep balance bestPair result
        
  return $ go (BalanceLoopItem initialCount initialForcing initialStep 
                                   initialBalance Balance.emptyBestForcingPair intialResult)
 
  
-}           
           

{-

showBalanceLoopItem::(Show a, Show node,PrintfArg a,Arith.Constant a )=>
  (Counter, BalanceLoopItem node a z) ->
  String
showBalanceLoopItem (bStp, BalanceLoopItem bForc _bFStep bal _) =
  printf " BL: %2d | " bStp ++ printfBalanceFMap bForc bal
-}

-- Ein Allgemeiner Loop wird unnötig kompliziert
{-
loopIO :: 
  (cnt -> cnt) ->
  (result -> quality) ->    
  (input -> result) ->
  (result -> input) ->
  (quality -> cnt -> Bool) ->
  (cnt,quality,z) ->
  [(cnt,quality,z)]
loopIO increment measureQuality deriveNewInput calculateNewResult exitCriteria  (initialCount,initialInput,initialResult) = 
  UtList.takeUntil g $ iterate (calculateNewResult . deriveNewInput) (initialCount,initialInput,initialResult) 
  where
  g (counter,quality,_) = not . exitCriteria counter quality 
  f (counter,_,_,resultIn) = (increment counter, measureQuality newResult, newInput , newResult)
    where newInput = deriveNewInput resultIn
          newResult = calculateNewResult newInput
          

-- ein loop mit IO hat klare Vorteile, besseres Debuggen !!
showEtaLoop ::
  (Show node, Show a, PrintfArg a, Arith.Constant a) =>
  Params.Optimisation node [] Sweep UV.Vector a ->
  [EtaLoopItem node Sweep UV.Vector a z] ->
  [String]
showEtaLoop optParams loop =
  iterateLoops optParams showEtaLoopItem showBalanceLoopItem (zip [0..] loop)

showEtaLoopItem::
  Params.Optimisation node [] Sweep UV.Vector a ->
  (Counter, EtaLoopItem node Sweep UV.Vector a z) ->
  String
showEtaLoopItem _optParams (step, EtaLoopItem _sfgIn _sweep _) =
  printf "EL: %8d" step

-}