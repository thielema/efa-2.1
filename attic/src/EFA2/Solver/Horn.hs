module EFA2.Solver.Horn where

import qualified Data.Traversable as Trav
import qualified Data.Foldable as Fold
import qualified Data.List.Key as Key
import qualified Data.List as L
import qualified Data.Set as S
import qualified Data.Map as M
import qualified Data.NonEmpty.Mixed as NonEmptyM
import qualified Data.NonEmpty as NonEmpty
import Data.NonEmpty ((!:))
import Control.Monad (liftM2)
import Control.Functor.HT (void)
import Data.Maybe (mapMaybe, catMaybes)
import Data.Ord.HT (comparing)
import Data.Eq.HT (equating)
import Data.Bool.HT (if')

import Data.Graph.Inductive (Node, Gr, labNodes, delEdge, edges)
import EFA2.Utils.Graph (foldGraphNodes, mapGraphNodes)

import EFA2.Solver.DependencyGraph (dpgDiffByAtMostOne, dpgHasSameVariable)
import EFA2.Solver.Equation (EqTerm, mkVarSet)

import qualified Test.QuickCheck as QC

import Debug.Trace (trace)


data Formula = Zero
             | One
             | Atom Int
             | And Formula Formula
             | Formula :-> Formula deriving (Ord, Eq)

infix 8 :->

instance Show Formula where
         show Zero = "F"
         show One = "T"
         show (Atom x) = show x
         show (And f g) = "(" ++ show f ++ " ∧ " ++ show g ++ ")"
         show (f :-> g) = show f ++ " → " ++ show g

instance QC.Arbitrary Formula where
   arbitrary =
      QC.oneof $
      return Zero :
      return One :
      fmap Atom QC.arbitrary :
      QC.sized (\n -> let arb = QC.resize (div n 2) QC.arbitrary in liftM2 And arb arb) :
      QC.sized (\n -> let arb = QC.resize (div n 2) QC.arbitrary in liftM2 (:->) arb arb) :
      []

   shrink x =
      case x of
         Zero -> []
         One -> []
         Atom n -> map Atom $ QC.shrink n
         And f g -> f : g : (map (uncurry And) $ QC.shrink (f,g))
         f :-> g -> f : g : (map (uncurry (:->)) $ QC.shrink (f,g))

type Step = Int

hornsToStr :: [Formula] -> String
hornsToStr fs = L.intercalate " ∧ " $ map (("(" ++) . (++ ")") . show) fs


isAtom :: Formula -> Bool
isAtom (Atom _) = True
isAtom _ = False

fromAtom :: Formula -> Int
fromAtom (Atom x) = x
fromAtom t = error ("Wrong term " ++ show t ++ " supplied to fromAtom.")

getAtoms :: Formula -> S.Set Formula
getAtoms v@(Atom _) = S.singleton v
getAtoms (And f g) = S.union (getAtoms f) (getAtoms g)
getAtoms (f :-> g) = S.union (getAtoms f) (getAtoms g)
getAtoms _ = S.empty

leftMarked :: S.Set Formula -> Formula -> Bool
leftMarked _ (One :-> _) = True
leftMarked vs (lhs :-> _) = S.null $ S.difference (getAtoms lhs) vs
leftMarked _ _ = False

rightMarked :: S.Set Formula -> Formula -> Bool
rightMarked vs (_ :-> v) = S.member v vs
rightMarked _ _ = False

makeAnd :: NonEmpty.T [] Formula -> Formula
makeAnd = NonEmpty.foldl1 And

step :: Step -> S.Set (Step, Formula) -> [Formula] -> (S.Set (Step, Formula), [Formula])
step i vs fs = (unionVs, filter (not . rightMarked onlyVars') bs)
  where (as, bs) = L.partition (leftMarked onlyVars) fs
        vs' = S.fromList $ zip (repeat i) (map (\(_ :-> v) -> v) as)
        unionVs = S.union vs' vs
        onlyVars = S.map snd vs
        onlyVars' = S.map snd unionVs

horn' :: Step -> S.Set (Step, Formula) -> [Formula] -> Maybe (S.Set (Step, Formula))
horn' i vs fs =
   if' (Fold.any ((Zero ==) . snd) vs) Nothing $
   if' (vs == vs') (Just vs) $
   horn' (i+1) vs' fs'
  where (vs', fs') = step i vs fs

-- | Returns a set of 'Atom's that are have to be marked True in order to fulfill the 'Formula'e.
--   To each 'Atom' is associated the 'Step' in which it was marked.
horn :: [Formula] -> Maybe (S.Set (Step, Formula))
horn fs = fmap atomsOnly res
  where atomsOnly = S.filter (isAtom . snd)
        res = horn' 0 S.empty fs

-- | Takes a dependency graph and returns Horn clauses from it, that is, every directed edge
--   is taken for an implication.
graphToHorn :: Gr a () -> [Formula]
graphToHorn g = foldGraphNodes f [] g
  where f acc ([], _, []) = acc
        f acc (ins, x, _) = (map (:-> Atom x) (map Atom ins)) ++ acc

{-
-- | Takes a dependency graph and returns Horn clauses from it. /Given/ 'Formula'e will
--   produce additional clauses of the form One :-> Atom x. 
--   These are the starting clauses for the Horn marking algorithm.
makeHornFormulae :: (a -> Bool) -> Gr a () -> [Formula]
makeHornFormulae isVar g = given ++ graphToHorn g
  where given = L.foldl' f [] (labNodes g)
        f acc (n, t) | isGiven t = (One :-> Atom n):acc
        f acc _ = acc
-}

-- | Takes a dependency graph and a list of 'Formula'e. With help of the horn marking algorithm
--   it produces a list of 'EqTerm' equations that is ordered such, that it can be computed
--   one by one.
makeHornOrder :: M.Map Node a -> [Formula] -> [a]
makeHornOrder m formulae = map ((m M.!) . fromAtom) fs'
  where Just fs = horn formulae
        fs' = map snd (S.toAscList fs)

-- | Filter equations which contain the same variables.
-- Given terms are also filtered, as they contain no variables.
filterUnneeded ::
   (Ord a) =>
   (EqTerm -> Maybe a) -> [EqTerm] -> [EqTerm]
filterUnneeded isVar =
   map (fst . NonEmpty.head) .
   NonEmptyM.groupBy (equating snd) .
   map (\t -> (t, mkVarSet isVar t))


makeHornClauses ::
   (Ord a, Show a) =>
   (EqTerm -> Maybe a) -> [EqTerm] -> [EqTerm] ->
   (M.Map Node EqTerm, [Formula])
makeHornClauses isVar givenExt rest = (m, startfs ++ fsdpg ++ fsdpg2)
  where m = M.fromList (labNodes dpg)
        ts = givenExt ++ rest
        dpg = dpgDiffByAtMostOne isVar ts
        fsdpg = graphToHorn dpg
        ext = filter (flip elem givenExt . snd) (labNodes dpg)

        startfs = map (h . fst) ext
        h x = One :-> Atom x

        dpg2 = dpgHasSameVariable isVar ts
        dpg3 = L.foldl' (flip delEdge) dpg2 (edges dpg)
        fsdpg2 = concat $ mapGraphNodes g dpg3
        mset = M.map (mkVarSet isVar) m

        g ([], _, _) = []
        g (ins, n, _) =
           map (\xs -> makeAnd (fmap Atom xs) :-> Atom n) $
           mapMaybe NonEmpty.fetch sc
          where _sc = greedyCover mset n ins
                sc = setCoverBruteForce mset n ins


hornOrder ::
   (Ord a, Show a) =>
   (EqTerm -> Maybe a) -> [EqTerm] -> [EqTerm] -> [EqTerm]
hornOrder isVar givenExt ts =
   uncurry makeHornOrder $ makeHornClauses isVar givenExt ts


-- using a NonEmptyList, the 'tail' could be total
allNotEmptyCombinations :: (Ord a) => [a] -> [[a]]
allNotEmptyCombinations =
   NonEmpty.tail . fmap catMaybes . Trav.mapM (\x -> Nothing !: Just x : [])


setCoverBruteForce ::
   Ord a => M.Map Node (S.Set a) -> Node -> [Node] -> [[Node]]
setCoverBruteForce m n ns =
   let minL = 16
       l = length ns
   in  if l > minL
         then
            trace
               ("Instance size " ++ show l ++
                "; setCoverBruteForce doesn't like instances > " ++ show minL) []
         else
            let p t = sizeLessThanTwo ((m M.! n) S.\\ t)
            in  map fst $ filter (p . S.unions . snd) $
                map unzip $
                allNotEmptyCombinations $
                map (\k -> (k, m M.! k)) ns

greedyCover ::
   Ord a => M.Map Node (S.Set a) -> Node -> [Node] -> [[Node]]
greedyCover m n ns0 = [go (m M.! n) ns0]
  where go s _ | sizeLessThanTwo s = []
        go _ [] = error "no set cover"
        go s ns = x : go (s S.\\ s') (L.delete x ns)
          where (x, s') =
                   Key.minimum (lazySize . (s S.\\) . snd) $
                   map (\a -> (a, m M.! a)) ns

lazySize :: S.Set a -> [()]
lazySize = void . S.toList

sizeLessThanTwo :: S.Set a -> Bool
sizeLessThanTwo = null . drop 1 . S.toList


setCoverBruteForceOld ::
   Ord a => M.Map Node (S.Set a) -> Node -> [Node] -> [[Node]]
setCoverBruteForceOld _ _ ns | l > n = trace msg []
  where n = 16
        l = length ns
        msg = "Instance size " ++ show l ++ "; setCoverBruteForceOld doesn't like instances > " ++ show n
setCoverBruteForceOld m n ns = map fst $ filter p xs
  where s = m M.! n
        combs = allNotEmptyCombinations ns
        xs = zip combs (map f combs)
        f ys = S.unions $ map (m M.!) ys
        p (_c, t) = S.size (s S.\\ t) < 2

greedyCoverOld ::
   Ord a => M.Map Node (S.Set a) -> Node -> [Node] -> [[Node]]
greedyCoverOld m n ns0 = [go s0 ns0]
  where s0 = m M.! n
        go s _ | S.size s < 2 = []
        go _ [] = error "no set cover"
        go s ns = x:(go (s S.\\ s') ns')
          where sets = map (\a -> (a, m M.! a)) ns
                (x, s') = head $ L.sortBy (comparing (S.size . (s S.\\) . snd)) sets
                ns' = L.delete x ns


setCoverBruteForceProp :: [(Node, [Ordering])] -> Node -> [Node] -> Bool
setCoverBruteForceProp forms n ns0 =
   let m = fmap S.fromList $ M.insert n [] $ M.fromList forms
       ns = S.toList $ S.intersection (M.keysSet m) $ S.fromList ns0
   in  setCoverBruteForce m n ns
       ==
       setCoverBruteForceOld m n ns

greedyCoverProp :: [(Node, [Ordering])] -> Node -> [Node] -> Bool
greedyCoverProp forms n ns0 =
   let m = fmap S.fromList $ M.insert n [] $ M.fromList forms
       ns = S.toList $ S.intersection (M.keysSet m) $ S.fromList ns0
   in  greedyCover m n ns
       ==
       greedyCoverOld m n ns
