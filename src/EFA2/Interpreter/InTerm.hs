{-# LANGUAGE TypeSynonymInstances, FlexibleInstances #-}


module EFA2.Interpreter.InTerm where

import EFA2.Interpreter.Arith
import EFA2.Interpreter.Env

data InTerm a = PIdx PowerIdx
              | EIdx EtaIdx
              | DPIdx DPowerIdx
              | DEIdx DEtaIdx
              | ScaleIdx XIdx
              | VIdx VarIdx
              | InConst a
              | InGiven a
              | InMinus (InTerm a)
              | InRecip (InTerm a)
              | InAdd (InTerm a) (InTerm a)
              | InMult (InTerm a) (InTerm a)
              | InEqual (InTerm a) (InTerm a) deriving (Eq, Ord, Show)


instance Arith (InTerm Double) where
         zero = InConst 0.0
         cst = InConst
         neg = InMinus
         rec = InRecip
         (.+) = InAdd
         (.*) = InMult
         x ./ y = InMult x (InRecip y)
