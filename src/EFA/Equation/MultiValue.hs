{-# LANGUAGE TypeFamilies #-}
module EFA.Equation.MultiValue where

import qualified EFA.Equation.Arithmetic as Arith
import EFA.Equation.Arithmetic
          (Sum, (~+), (~-),
           Product, (~*), (~/),
           Constant, zero,
           Integrate, Scalar, integrate)

import qualified Test.QuickCheck as QC

import qualified Data.Set as Set

import qualified Data.Foldable as Fold
import qualified Data.List.HT as ListHT
import Control.Applicative (Applicative, pure, (<*>), liftA2)
import Data.Traversable (Traversable, sequenceA)
import Data.Foldable (Foldable, foldMap)
import Data.Monoid ((<>))


{- |
The length of the list must match the depth of the tree.
The indices must be in strictly ascending order.
-}
data MultiValue i a = MultiValue [i] (Tree a)
   deriving (Show, Eq)

data Tree a =
     Leaf a
   | Branch (Tree a) (Tree a)
   deriving (Show, Eq)

instance Functor Tree where
   fmap f (Leaf a) = Leaf (f a)
   fmap f (Branch a0 a1) = Branch (fmap f a0) (fmap f a1)

-- | must only be applied if the index sets match
instance Applicative Tree where
   pure = Leaf
   Leaf f <*> Leaf a = Leaf $ f a
   Branch f g <*> Branch a b = Branch (f <*> a) (g <*> b)
   _ <*> _ = error "MultiValue.<*>: non-matching data structures"

instance Foldable Tree where
   foldMap f (Leaf a) = f a
   foldMap f (Branch a0 a1) = foldMap f a0 <> foldMap f a1

instance Traversable Tree where
   sequenceA (Leaf a) = fmap Leaf a
   sequenceA (Branch a0 a1) = liftA2 Branch (sequenceA a0) (sequenceA a1)


mergeTrees :: Ord i => [i] -> Tree a -> [i] -> Tree b -> Tree (a,b)
mergeTrees [] (Leaf a) _ bs = fmap ((,) a) bs
mergeTrees _ as [] (Leaf b) = fmap (flip (,) b) as
mergeTrees it@(i:is) a@(Branch a0 a1) jt@(j:js) b@(Branch b0 b1) =
   case compare i j of
      EQ -> Branch (mergeTrees is a0 js b0) (mergeTrees is a1 js b1)
      LT -> Branch (mergeTrees is a0 jt b ) (mergeTrees is a1 jt b )
      GT -> Branch (mergeTrees it a  js b0) (mergeTrees it a  js b1)
mergeTrees _ _ _ _ = error "MultiValue.mergeTrees: inconsistent data structure"

mergeIndices :: Ord i => [i] -> [i] -> [i]
mergeIndices [] js = js
mergeIndices is [] = is
mergeIndices it@(i:is) jt@(j:js) =
   case compare i j of
      EQ -> i : mergeIndices is js
      LT -> i : mergeIndices is jt
      GT -> j : mergeIndices it js


eqRelaxed :: (Ord i, Eq a) => MultiValue i a -> MultiValue i a -> Bool
eqRelaxed a b = case liftA2 (==) a b of MultiValue _is tree -> Fold.and tree


instance (Ord i) => Functor (MultiValue i) where
   fmap f (MultiValue is a) = MultiValue is (fmap f a)

instance (Ord i) => Applicative (MultiValue i) where
   pure = singleton
   MultiValue is a <*> MultiValue js b =
      MultiValue
         (mergeIndices is js)
         (fmap (uncurry ($)) $ mergeTrees is a js b)

instance (Ord i) => Foldable (MultiValue i) where
   foldMap f (MultiValue _is a) = foldMap f a

instance (Ord i) => Traversable (MultiValue i) where
   sequenceA (MultiValue is a) = fmap (MultiValue is) $ sequenceA a


instance (Ord i, Num a) => Num (MultiValue i a) where
   fromInteger = pure . fromInteger
   negate = fmap negate
   (+) = liftA2 (+)
   (-) = liftA2 (-)
   (*) = liftA2 (*)
   abs = fmap abs
   signum = fmap signum

instance (Ord i, Fractional a) => Fractional (MultiValue i a) where
   fromRational = pure . fromRational
   recip = fmap recip
   (/) = liftA2 (/)


instance (Ord i, Sum a) => Sum (MultiValue i a) where
   (~+) = liftA2 (~+)
   (~-) = liftA2 (~-)
   negate = fmap Arith.negate

instance (Ord i, Product a) => Product (MultiValue i a) where
   (~*) = liftA2 (~*)
   (~/) = liftA2 (~/)
   recip = fmap Arith.recip

instance (Ord i, Constant a) => Constant (MultiValue i a) where
   zero = pure zero
   fromInteger = pure . Arith.fromInteger
   fromRational = pure . Arith.fromRational

instance (Ord i, Integrate v) => Integrate (MultiValue i v) where
   type Scalar (MultiValue i v) = MultiValue i (Scalar v)
   integrate = fmap integrate


singleton :: a -> MultiValue i a
singleton = MultiValue [] . Leaf

pair :: i -> a -> a -> MultiValue i a
pair i a0 a1 = MultiValue [i] (Branch (Leaf a0) (Leaf a1))

deltaPair :: Sum a => i -> a -> a -> MultiValue i a
deltaPair i a0 a1 = MultiValue [i] (Branch (Leaf a0) (Leaf (a0~+a1)))

constant :: [i] -> a -> MultiValue i a
constant is a = MultiValue is $ foldr (\_ b -> Branch b b) (Leaf a) is


instance
   (QC.Arbitrary i, Ord i, QC.Arbitrary a) =>
      QC.Arbitrary (MultiValue i a) where
   arbitrary =
      sequenceA . flip constant QC.arbitrary .
         take 4 . Set.toList . Set.fromList =<< QC.arbitrary

   shrink (MultiValue it tree) =
      (case tree of
         Leaf _ -> []
         Branch a0 a1 ->
            concatMap (\(_,is) -> [MultiValue is a0, MultiValue is a1]) $
            ListHT.removeEach it)
      ++
      (let go (Leaf x) = map Leaf $ QC.shrink x
           go (Branch a0 a1) =
              map (flip Branch a1) (go a0) ++ map (Branch a0) (go a1)
       in  map (MultiValue it) $ go tree)