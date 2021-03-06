
module EFA.Symbolic.OperatorTree where

import qualified EFA.Symbolic.SumProduct as Term
import qualified EFA.Report.Format as Format
import EFA.Report.FormatValue (FormatValue, formatValue)

import qualified EFA.Equation.RecordIndex as RecIdx
import qualified EFA.Equation.Arithmetic as Arith
import EFA.Equation.Arithmetic
          (Sum, zero, (~+), (~-),
           Product, (~*), (~/),
           Constant)

import EFA.Utility (Pointed, point)

import qualified Data.NonEmpty.Class as NonEmptyC
import qualified Data.NonEmpty as NonEmpty
import qualified Data.Stream as Stream
import Data.Stream (Stream)

import qualified Data.Map as Map
import qualified Data.Set as Set
import qualified Data.Foldable as Fold
import Data.Map (Map)
import Data.Set (Set)
import Data.Foldable (Foldable, foldMap)
import Data.Monoid (mempty, mappend)
import Control.Monad (liftM2)


data Term a =
            Atom a
          | Const Rational
               {- we initialize it only with 0 or 1,
                  but constant folding may yield any rational number -}
          | Function Format.Function (Term a)
          | Minus (Term a)
          | Recip (Term a)
          | (Term a) :+ (Term a)
          | (Term a) :* (Term a) deriving (Show, Eq, Ord)



instance Num (Term idx) where
   fromInteger = Const . fromInteger
   negate = Minus
   (+) = (:+)
   (*) = (:*)
   abs = Function Format.Absolute
   signum = Function Format.Signum

instance Fractional (Term idx) where
   fromRational = Const
   recip = Recip
   (/) = (&/)

instance Sum (Term idx) where
   (~+) = (:+)
   (~-) = (&-)
   negate = Minus

instance Product (Term idx) where
   (~*) = (:*)
   (~/) = (&/)
   recip = Recip
   constOne = Function Format.ConstOne

instance Constant (Term idx) where
   zero = Const 0
   fromInteger = Const . fromInteger
   fromRational = Const


instance Pointed Term where
   point = Atom

instance Functor Term where
   fmap f =
      let go t =
             case t of
                Atom a -> Atom $ f a
                Const x -> Const x
                Function fn x -> Function fn $ fmap f x

                Minus x -> Minus $ go x
                Recip x -> Recip $ go x
                x :+ y -> go x :+ go y
                x :* y -> go x :* go y
      in go

instance Foldable Term where
   foldMap f =
      let go t =
             case t of
                Atom a -> f a
                Const _ -> mempty
                Function _ x -> go x

                Minus x -> go x
                Recip x -> go x
                x :+ y -> mappend (go x) (go y)
                x :* y -> mappend (go x) (go y)
      in go


infixl 7  :*, &/
infixl 6  :+, &-


{- |
For consistency with '(:+)' it should be named '(:-)'
but this is reserved for constructors.
-}

(&-) :: Term a -> Term a -> Term a
x &- y  =  x :+ Minus y

(&/) :: Term a -> Term a -> Term a
x &/ y  =  x :* Recip y



instance (Eq a, FormatValue a) => FormatValue (Term a) where
   formatValue = formatTerm


formatTerm ::
   (FormatValue a, Format.Format output) => Term a -> output
formatTerm =
   let go t =
          case t of
             Const x -> Format.ratio x
             Atom x -> formatValue x
             Function fn x -> Format.function fn $ go x

             x :+ y -> Format.parenthesize $ Format.plus (go x) (go y)
             x :* y -> Format.multiply (go x) (go y)

             Recip x -> Format.recip $ go x
             Minus x -> Format.negate $ Format.parenthesize $ go x
   in  go


--------------------------------------------------------------------


expand :: Term a -> NonEmpty.T [] (Term a)
expand = go
  where go (Minus u) = fmap Minus (go u)
        go (u :+ v) = NonEmptyC.append (go u) (go v)
        go (u :* v) = liftM2 (:*) (go u) (go v)
        go s = NonEmpty.singleton s

group ::
   (Ord a, Foldable f) => f (Term a) -> Map (Set a) (Term a)
group =
   Map.filter (0/=) .
   fmap simplify .
   Map.fromListWith (+) .
   fmap (\t -> (foldMap Set.singleton t, t)) .
   Fold.toList


streamPairs :: Stream a -> Stream (a, a)
streamPairs xs = Stream.zip xs (Stream.tail xs)

iterateUntilFix :: (Eq a) => (a -> a) -> a -> a
iterateUntilFix f =
   fst . Stream.head . Stream.dropWhile (uncurry (/=)) .
   streamPairs . Stream.iterate f

simplifyOld :: Eq a => Term a -> Term a
simplifyOld = iterateUntilFix simplify' . NonEmpty.sum . expand
  where simplify' :: Eq a => Term a -> Term a
        simplify' (Const x :+ Const y) = Const $ x+y
        simplify' ((Const 0.0) :+ x) = simplify' x
        simplify' (x :+ (Const 0.0)) = simplify' x

        simplify' (Const x :* Const y) = Const $ x*y
        simplify' ((Const 1.0) :* x) = simplify' x
        simplify' (x :* (Const 1.0)) = simplify' x
        simplify' ((Const 0.0) :* _) = Const 0.0
        simplify' (_ :* (Const 0.0)) = Const 0.0

        simplify' (Recip (Const x)) = Const $ recip x
        simplify' (x :* (Recip y)) | x == y = Const 1.0
        simplify' ((Minus x) :* (Recip y)) | x == y = Const (-1.0)
        simplify' ((Recip x) :* y) | x == y = Const 1.0
        simplify' ((Recip x) :* (Minus y)) | x == y = Const (-1.0)

        simplify' (Recip (Recip x)) = simplify' x
        simplify' (Recip x) = Recip (simplify' x)

        simplify' (Minus (Const x)) = Const $ negate x
        simplify' (Minus (Minus x)) = simplify' x
        simplify' (Minus x) = Minus (simplify' x)
        simplify' ((Minus x) :* (Minus y)) = simplify' x :* simplify' y
        simplify' (x :+ y) = simplify' x :+ simplify' y
        simplify' (x :* y) = simplify' x :* simplify' y
        simplify' x = x


simplify :: Ord a => Term a -> Term a
simplify = fromNormalTerm . toNormalTerm

evaluate :: Fractional b => (a -> b) -> Term a -> b
evaluate f =
   let go t =
          case t of
             Atom a -> f a
             Const x -> fromRational x
             Function fn x ->
                case fn of
                   Format.Absolute -> abs $ go x
                   Format.Signum -> signum $ go x
                   Format.ConstOne -> 1

             Minus x -> negate $ go x
             Recip x -> recip $ go x
             x :+ y -> go x + go y
             x :* y -> go x * go y
   in  go

toNormalTerm :: Ord a => Term a -> Term.Term a
toNormalTerm = evaluate Term.Atom

fromNormalTerm :: Ord a => Term.Term a -> Term a
fromNormalTerm = Term.evaluate Atom


delta :: Term (RecIdx.Record RecIdx.Absolute a) -> Term (RecIdx.Record RecIdx.Delta a)
delta =
   let before = fmap (\(RecIdx.Record RecIdx.Absolute a) -> (RecIdx.Record RecIdx.Before a))
       function fn x =
          Function fn (before x + go x) - Function fn (before x)
       go (Const _) = Const 0
       go (Atom (RecIdx.Record RecIdx.Absolute a)) = (Atom (RecIdx.Record RecIdx.Delta a))
       go (Function fn a) =
          case fn of
             Format.Absolute -> function fn a
             Format.Signum -> function fn a
             Format.ConstOne -> Arith.clear $ before a
       go (Minus t) = Minus $ go t
       go (s :+ t) = go s + go t
       go (Recip s) =
          let bs = before s ; ds = go s
              --  recip (s+ds) - recip s
              --  (s-(s+ds)) / ((s+ds) * s)
          in  -ds / ((bs+ds) * bs)
       go (s :* t) =
          let bs = before s ; ds = go s
              bt = before t ; dt = go t
          in  ds * bt + bs * dt + ds * dt
   in  go
