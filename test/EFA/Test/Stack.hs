{-# LANGUAGE TemplateHaskell #-}
module EFA.Test.Stack where

import EFA.Test.Arithmetic (Triple)

import qualified EFA.Equation.Stack as Stack
import qualified EFA.Equation.MultiValue as MV
import EFA.Equation.Stack (Stack)

import qualified EFA.Equation.Arithmetic as Arith
import EFA.Equation.Arithmetic ((~+), (~-), (~*), (~/))

import qualified Data.Map as Map
import Data.Map (Map)
import Control.Applicative (liftA2)

import qualified Test.QuickCheck.Property.Generic as Law
import qualified Test.QuickCheck as QC
import Test.QuickCheck.Modifiers (Positive, getPositive)
import Test.QuickCheck.All (quickCheckAll)


type IntStack = Stack Char Integer
type IntMultiValue = MV.MultiValue Char Integer

type RatioStack = Stack Char Rational
type PosRatioMultiValue = MV.MultiValue Char (Positive Rational)


newtype AMap k a = AMap (Map k a) deriving (Show)

instance
   (Ord k, QC.Arbitrary k, QC.Arbitrary a) =>
      QC.Arbitrary (AMap k a) where
   arbitrary = fmap (AMap . Map.fromList) QC.arbitrary
   shrink (AMap m) = fmap (AMap . Map.fromList) $ QC.shrink $ Map.toList m

prop_filterIdentity :: IntStack -> Bool
prop_filterIdentity x  =
   case Stack.startFilter x of
      fx -> Stack.filter Map.empty fx == Just fx

prop_filterProjectNaive :: AMap Char Stack.Branch -> IntStack -> Bool
prop_filterProjectNaive (AMap c) x  =
   Stack.filterNaive c x == Stack.filterNaive c (Stack.filterNaive c x)

prop_filterProject :: AMap Char Stack.Branch -> IntStack -> Bool
prop_filterProject (AMap c) x  =
   case Stack.startFilter x of
      fx ->
         Stack.filter c fx
         ==
         (Stack.filter c =<< Stack.filter c fx)

prop_filterCommutative ::
   AMap Char Stack.Branch -> AMap Char Stack.Branch -> IntStack -> Bool
prop_filterCommutative (AMap c0) (AMap c1) x =
   case Stack.startFilter x of
      fx ->
         (Stack.filter c0 =<< Stack.filter c1 fx)
         ==
         (Stack.filter c1 =<< Stack.filter c0 fx)

prop_filterMerge :: AMap Char Stack.Branch -> AMap Char Stack.Branch -> IntStack -> Bool
prop_filterMerge (AMap c0) (AMap c1) x =
   case Stack.startFilter x of
      fx ->
         (Stack.filter c1 =<< Stack.filter c0 fx)
         ==
         (flip Stack.filter fx =<< Stack.mergeConditions c0 c1)

prop_filterPlus :: AMap Char Stack.Branch -> IntStack -> IntStack -> Bool
prop_filterPlus (AMap c) x y =
   let filt = fmap Stack.filtered . Stack.filter c . Stack.startFilter
   in  filt (x + y)  ==  liftA2 (+) (filt x) (filt y)


prop_multiValueConvert :: IntMultiValue -> Bool
prop_multiValueConvert x =
   x == Stack.toMultiValue (Stack.fromMultiValue x)

prop_multiValuePlus :: IntMultiValue -> IntMultiValue -> Bool
prop_multiValuePlus x y =
   Stack.fromMultiValue (x+y)
   ==
   Stack.fromMultiValue x + Stack.fromMultiValue y

prop_multiValueTimes :: IntMultiValue -> IntMultiValue -> Bool
prop_multiValueTimes x y =
   Stack.fromMultiValue (x*y)
   ==
   Stack.fromMultiValue x * Stack.fromMultiValue y

prop_multiValueNegate :: IntMultiValue -> Bool
prop_multiValueNegate x =
   Stack.fromMultiValue (negate x) == negate (Stack.fromMultiValue x)

prop_multiValueRecip :: PosRatioMultiValue -> Bool
prop_multiValueRecip px =
   case fmap getPositive px of
      x -> Stack.fromMultiValue (recip x) == recip (Stack.fromMultiValue x)

prop_multiValueIntegrate :: MV.MultiValue Char (Triple Integer) -> Bool
prop_multiValueIntegrate x =
   Stack.fromMultiValue (Arith.integrate x)
   ==
   Arith.integrate (Stack.fromMultiValue x)


prop_arithmeticPlus :: IntStack -> IntStack -> Bool
prop_arithmeticPlus x y  =  x+y == x~+y

prop_arithmeticMinus :: IntStack -> IntStack -> Bool
prop_arithmeticMinus x y  =  x-y == x~-y

prop_arithmeticNegate :: IntStack -> Bool
prop_arithmeticNegate x  =  negate x == Arith.negate x

prop_arithmeticTimes :: RatioStack -> RatioStack -> Bool
prop_arithmeticTimes x y  =  x*y == x~*y

prop_arithmeticDivide :: RatioStack -> PosRatioMultiValue -> Bool
prop_arithmeticDivide x py =
   case Stack.fromMultiValue $ fmap getPositive py of
      y -> x/y == x~/y

prop_arithmeticRecip :: PosRatioMultiValue -> Bool
prop_arithmeticRecip px =
   case Stack.fromMultiValue $ fmap getPositive px of
      x -> recip x == Arith.recip x


prop_commutativePlus :: IntStack -> IntStack -> Bool
prop_commutativePlus = Law.eq $ Law.prop_Commutative (+) Law.T

prop_commutativeTimes :: IntStack -> IntStack -> Bool
prop_commutativeTimes = Law.eq $ Law.prop_Commutative (*) Law.T

prop_associativePlus :: IntStack -> IntStack -> IntStack -> Bool
prop_associativePlus = Law.eq $ Law.prop_Associative (+) Law.T

prop_associativeTimes :: IntStack -> IntStack -> IntStack -> Bool
prop_associativeTimes = Law.eq $ Law.prop_Associative (*) Law.T

prop_identityPlus :: IntStack -> Bool
prop_identityPlus = Law.eq $ Law.prop_Identity 0 (+) Law.T

prop_identityTimes :: IntStack -> Bool
prop_identityTimes = Law.eq $ Law.prop_Identity 1 (*) Law.T

prop_associativeMinus :: IntStack -> IntStack -> IntStack -> Bool
prop_associativeMinus x y z  =  (x+y)-z == x+(y-z)

prop_swapMinus :: IntStack -> IntStack -> Bool
prop_swapMinus x y  =  (x-y) == negate (y-x)

prop_inversePlus :: IntStack -> Bool
prop_inversePlus =
   Law.eqWith Stack.eqRelaxedNum $
   Law.prop_GroupInverse 0 (+) negate Law.T

prop_distributivePlus :: IntStack -> IntStack -> IntStack -> Bool
prop_distributivePlus x y z  =  (x+y)*z == x*z + y*z

prop_distributiveMinus :: IntStack -> IntStack -> IntStack -> Bool
prop_distributiveMinus x y z  =  (x-y)*z == x*z - y*z


runTests :: IO Bool
runTests = $quickCheckAll
