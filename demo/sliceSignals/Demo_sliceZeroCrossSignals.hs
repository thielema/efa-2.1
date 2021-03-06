{-# LANGUAGE TypeOperators #-}

-- | Demonstriert das Schneiden von zero-crossing-Signalen

module Main where

import qualified EFA.Flow.Topology.Index as XIdx

import qualified EFA.Signal.Sequence as Sequ
import qualified EFA.Signal.Signal as Signal
import EFA.Signal.Chop (genSequ, addZeroCrossings)
import EFA.Signal.Record (Record(Record), PowerRecord)
import EFA.Signal.Data ((:>), Nil, Data)

import EFA.Utility (idxList)

import qualified Data.Map as Map
import Data.Map (Map)



data Node = Node0 | Node1 deriving (Eq, Ord, Show)

node0, node1 :: Node
node0 = Node0
node1 = Node1

time :: Signal.TC s t (Data ([] :> Nil) Double)
time = Signal.fromList [0, 10..50]

t :: String
t = "zero crossing"

p :: Signal.TC s t (Data ([] :> Nil) Double)
p = Signal.fromList [2, 2, 2, -2, -2]

pmap :: Map (XIdx.Position Node) (Signal.TC s t (Data ([] :> Nil) Double))
pmap = Map.fromListWith
         (error "duplicate keys")
         [(XIdx.ppos node0 node1,  p)]


titleList :: [String]
titleList = [t]

pmapList :: [Map (XIdx.Position Node) (Signal.TC s t (Data ([] :> Nil) Double))]
pmapList = [pmap]

recList :: [PowerRecord Node [] Double]
recList = map (Record time) pmapList

list ::
  [(Int, (String, (PowerRecord Node [] Double, Sequ.List (PowerRecord Node [] Double))))]
list = idxList $
  zip titleList
      (zip recList (map (genSequ . addZeroCrossings) recList))

f ::
   (Ord node, Show node, Show seq) =>
   (Int, (String, (PowerRecord node [] Double, seq))) -> IO ()

f (idx, (title, (pRec, sqRec))) = do
  putStrLn ""
  putStrLn $ "Test " ++ show (idx + 1) ++ ": " ++ title
  putStrLn $ "XList: \n" ++ show pRec
  putStrLn $ "XList: \n" ++ show (addZeroCrossings pRec)
  putStrLn $ "Sequence: " ++  show sqRec

main :: IO ()
main = mapM_ f list


