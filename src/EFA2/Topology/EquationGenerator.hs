
module EFA2.Topology.EquationGenerator where

import qualified Data.Map as M
import qualified Data.List as L
import qualified Data.List.HT as LH
import qualified Data.List.Key as Key
import qualified Data.Set as S

import EFA2.Signal.Index (SecNode(..), Section(..))
import qualified EFA2.Signal.Index as Idx

import EFA2.Topology.EfaGraph (Edge(..))
import qualified EFA2.Topology.EfaGraph as Gr

import qualified EFA2.Topology.TopologyData as TD
import EFA2.Solver.Equation (MkIdxC, mkVar)
import EFA2.Utils.Utils ((>>!))

import UniqueLogic.ST.Expression ((=:=))
import qualified UniqueLogic.ST.Expression as Expr
import qualified UniqueLogic.ST.System as Sys

import Control.Monad.ST (ST, runST)
import Control.Monad (liftM, liftM2)

import Control.Monad.Trans.Class (lift)
import Control.Monad.Trans.State (StateT, runStateT, gets, modify)


import Data.Monoid (Monoid, (<>), mempty, mappend, mconcat)

import Data.Maybe (maybeToList)
import Data.Ord (comparing)

import Data.Traversable (traverse)
import Data.Foldable (foldMap, fold)

import qualified EFA2.Interpreter.Env as Env
import Data.Tuple.HT (snd3)

import Debug.Trace


type ProvEnv s a = M.Map Env.Index (Sys.Variable s a)

newtype ExprWithVars s a = ExprWithVars (StateT (ProvEnv s a) (ST s) (Expr.T s a))
type SysWithVars s a = StateT (ProvEnv s a) (ST s) (Sys.M s ())


newtype EquationSystem s a = EquationSystem (SysWithVars s a)

instance Monoid (EquationSystem s a) where
         mempty = EquationSystem $ return (return ())
         mappend (EquationSystem x) (EquationSystem y) =
           EquationSystem $ liftM2 (>>!) x y


liftV2 :: 
  (Expr.T s a -> Expr.T s a -> Expr.T s a) -> 
  ExprWithVars s a -> ExprWithVars s a -> ExprWithVars s a
liftV2 f (ExprWithVars xs) (ExprWithVars ys) = ExprWithVars $ liftM2 f xs ys


instance (Fractional a) => Num (ExprWithVars s a) where
         (*) = liftV2 (*)
         (+) = liftV2 (+)
         (-) = liftV2 (-)

         fromInteger = ExprWithVars . return . fromInteger
         abs (ExprWithVars xs) = ExprWithVars $ liftM abs xs
         signum (ExprWithVars xs) = ExprWithVars $ liftM signum xs

infix 0 .=
(.=) :: (Eq a) => ExprWithVars s a -> ExprWithVars s a -> EquationSystem s a
(ExprWithVars xs) .= (ExprWithVars ys) = EquationSystem $ liftM2 (=:=) xs ys


constToExprSys :: a -> ExprWithVars s a
constToExprSys = ExprWithVars . return . Expr.constant

varToExprSys :: Sys.Variable s a -> ExprWithVars s a
varToExprSys = ExprWithVars . return . Expr.fromVariable


withLocalVar :: (ExprWithVars s a -> EquationSystem s b) -> EquationSystem s b
withLocalVar f = EquationSystem $ do
   v <- lift Sys.globalVariable
   case f $ ExprWithVars $ return $ Expr.fromVariable v of
        EquationSystem act -> act


recAbs :: Idx.Record
recAbs = Idx.Record Idx.Absolute

makeVar ::
  (MkIdxC a) =>
  (Idx.Record -> SecNode -> SecNode -> a) ->
  SecNode -> SecNode -> Env.Index
makeVar idxf nid nid' =
  mkVar $ idxf recAbs nid nid'

getVar :: Env.Index -> ExprWithVars s a
getVar idx =
  let newVar =
         lift Sys.globalVariable
          >>= \var -> modify (M.insert idx var)
          >>! return var
  in ExprWithVars $ fmap Expr.fromVariable $
        maybe newVar return =<< gets (M.lookup idx)

power :: SecNode -> SecNode -> ExprWithVars s a
power = (getVar .) . makeVar Idx.Power

energy :: SecNode -> SecNode -> ExprWithVars s a
energy = (getVar .) . makeVar Idx.Energy

maxenergy :: SecNode -> SecNode -> ExprWithVars s a
maxenergy = (getVar .) . makeVar Idx.MaxEnergy

eta :: SecNode -> SecNode -> ExprWithVars s a
eta = (getVar .) . makeVar Idx.FEta

xfactor :: SecNode -> SecNode -> ExprWithVars s a
xfactor = (getVar .) . makeVar Idx.X

yfactor :: SecNode -> SecNode -> ExprWithVars s a
yfactor = (getVar .) . makeVar Idx.Y

insumvar :: SecNode -> ExprWithVars s a
insumvar = getVar . mkVar . Idx.InSumVar recAbs

outsumvar :: SecNode -> ExprWithVars s a
outsumvar = getVar . mkVar . Idx.OutSumVar recAbs

storage :: SecNode -> ExprWithVars s a
storage = getVar . mkVar . Idx.Storage recAbs


dtime :: Section -> ExprWithVars s a
dtime = getVar . mkVar . Idx.DTime recAbs

mwhen :: Monoid a => Bool -> a -> a
mwhen True t = t
mwhen False _ = mempty 

edges :: Gr.EfaGraph node nodeLabel edgeLabel -> [Gr.Edge node]
edges = M.keys . Gr.edgeLabels

makeAllEquations ::
  (Eq a, Fractional a) =>
  TD.SequFlowGraph -> EquationSystem s a
makeAllEquations g = mconcat $
  makeInnerSectionEquations g :
  makeInterSectionEquations g :
  []

-----------------------------------------------------------------

makeInnerSectionEquations ::
  (Eq a, Fractional a) =>
  TD.SequFlowGraph -> EquationSystem s a
makeInnerSectionEquations g = mconcat $
  makeEnergyEquations es :
  makeEdgeEquations es :
  makeNodeEquations g :
  makeStorageEquations g' :
  []
  where g' = Gr.elfilter TD.isOriginalEdge g
        es = Gr.labEdges g


makeEdgeEquations ::
  (Eq a, Fractional a) =>
  [Gr.LEdge SecNode TD.ELabel] -> EquationSystem s a
makeEdgeEquations es = foldMap mkEq es
  where mkEq (Edge f t, lab) =
          case TD.edgeType lab of
               TD.OriginalEdge -> power t f .= eta f t * power f t
               TD.IntersectionEdge ->
                 (energy t f .= eta f t * energy f t)
                 <> (eta f t .= 1)


makeEnergyEquations ::
  (Eq a, Fractional a) =>
  [Gr.LEdge SecNode TD.ELabel] -> EquationSystem s a
makeEnergyEquations es = foldMap (mkEq . fst) es
  where mkEq (Edge f@(SecNode sf _) t@(SecNode st _)) =
          mwhen (sf == st)
            (energy f t .= dt * power f t) <> (energy t f .= dt * power t f)
          where dt = dtime sf

makeNodeEquations ::
  (Eq a, Fractional a) =>
  TD.SequFlowGraph -> EquationSystem s a
makeNodeEquations = fold . M.mapWithKey ((f .) . g) . Gr.nodes
  where  g n (ins, _, outs) = (S.toList ins, n, S.toList outs)
         f (ins, n, outs) =
           --(1 .= sum xin)
           -- <> (1 .= sum xout)
           (varsumin .= sum ein)
           <> (varsumout .= sum eout)
           <> mwhen (not (null ins) && not (null outs)) (varsumin .= varsumout)
           <> (mconcat $ zipWith (h varsumin) ein xin)
           <> (mconcat $ zipWith (h varsumout) eout xout)
          where xin = map (xfactor n) ins
                xout = map (xfactor n) outs
                ein = map (energy n) ins
                eout = map (energy n) outs
                varsumin = insumvar n       -- this variable is used again in makeStorageEquations
                varsumout = outsumvar n     -- and this, too.
                h s en x = en .= x * s


makeStorageEquations ::
  (Eq a, Fractional a) =>
  TD.SequFlowGraph -> EquationSystem s a
makeStorageEquations =
   mconcat . concatMap (LH.mapAdjacent f) . getInnersectionStorages
  where f (before, _) (now, dir) =
           storage now
           .=
           storage before
           +
           case dir of
                NoDir  -> 0
                InDir  -> insumvar now
                OutDir -> - outsumvar now


data StDir = InDir
           | OutDir
           | NoDir deriving (Eq, Ord, Show)

-- Only graphs without intersection edges are allowed.
-- Storages must not have more than one in or out edge.
getInnersectionStorages :: TD.SequFlowGraph -> [[(SecNode, StDir)]] -- Map SecNode StDir
getInnersectionStorages = getStorages format
  where format ([n], (s, _), []) = if TD.isDirEdge n then (s, InDir) else (s, NoDir)
        format ([], (s, _), [n]) = if TD.isDirEdge n then (s, OutDir) else (s, NoDir)
        format ([], (s, _), []) = (s, NoDir)
        format n@(_, _, _) = error ("getInnersectionStorages: " ++ show n)

type InOutFormat = Gr.InOut SecNode TD.NodeType TD.ELabel

getStorages :: (InOutFormat -> b) -> TD.SequFlowGraph -> [[b]]
getStorages format =
  map (map format)
  . Key.group (getNode . fst . snd3)
  . filter TD.isStorageNode
  . Gr.mkInOutGraphFormat    -- ersetzen durch nodes


-----------------------------------------------------------------

makeInterSectionEquations ::
  (Eq a, Fractional a) =>
  TD.SequFlowGraph -> EquationSystem s a
makeInterSectionEquations g = mconcat $
  makeInterNodeEquations g :
  []

makeInterNodeEquations ::
  (Eq a, Fractional a) =>
  TD.SequFlowGraph -> EquationSystem s a
makeInterNodeEquations topo = foldMap f st
  where st = getIntersectionStorages topo
        f (dir, x) =
          case dir of
               NoDir -> mempty
               InDir -> mkInStorageEquations x
               OutDir -> mkOutStorageEquations x

getSection :: Idx.SecNode -> Idx.Section
getSection (Idx.SecNode s _) = s

getNode :: Idx.SecNode -> Idx.Node
getNode (Idx.SecNode _ n) = n

mkInStorageEquations ::
  (Eq a, Fractional a) =>
  ([SecNode], SecNode, [SecNode]) -> EquationSystem s a
mkInStorageEquations (_, _, []) = mempty
mkInStorageEquations (_, n, outs) =
  withLocalVar $ \s ->
    -- The next equation is special for the initial Section.
    (maxenergy n so .= if initialSec n then initStorage else varsumin)
    <> (s .= sum es)
    <> (mconcat $ zipWith (\x e -> e .= x * s) ys es)
    <> (mconcat $ zipWith f sos souts)
  where souts@(so:sos) = L.sortBy (comparing getSection) outs
        initStorage = storage n
        varsumin = insumvar n
        initialSec s = getSection s == Idx.initSection
        ys = map (yfactor n) souts
        es = map (maxenergy n) souts
        f next beforeNext = maxenergy n next .= maxenergy n beforeNext - energy beforeNext n

mkOutStorageEquations ::
  (Eq a, Fractional a) =>
  ([SecNode], SecNode, [SecNode]) -> EquationSystem s a
mkOutStorageEquations ([], _, _) = mempty
mkOutStorageEquations (ins, n, _) =
  withLocalVar $ \s ->
    (s .= sum esOpposite)
    <> (varsumout .= sum esHere)
    <> (mconcat $ zipWith (\e x -> e .= x * s) esOpposite xsHere)
    <> (mconcat $ zipWith (\e x -> e .= x * varsumout) esHere xsHere)
  where sins = L.sortBy (comparing getSection) ins
        esOpposite = map (flip maxenergy n) sins
        esHere = map (energy n) sins
        xsHere = map (xfactor n) sins
        varsumout = outsumvar n


getIntersectionStorages ::
  TD.SequFlowGraph -> [(StDir, ([SecNode], SecNode, [SecNode]))]
getIntersectionStorages = concat . getStorages (format . toSecNode)
  where toSecNode (ins, n, outs) = (map fst ins, fst n, map fst outs)
        format x@(ins, SecNode sec _, outs) =
          case (filter h ins, filter h outs) of
               ([], [])  ->  -- We treat initial storages as in-storages
                 if sec == Idx.initSection then (InDir, x) else (NoDir, x)
               ([_], []) -> (InDir, x)
               ([], [_]) -> (OutDir, x)
               _ -> error ("getIntersectionStorages: " ++ show x)
          where h s = getSection s == sec


{-

makeInterSectionEquations ::
  (Eq a, Fractional a) =>
  TD.SequFlowGraph -> EquationSystem s a
makeInterSectionEquations g = mconcat $
  makeInterNodeEquations g :
  []

makeInterNodeEquations ::
  (Eq a, Fractional a) =>
  TD.SequFlowGraph -> EquationSystem s a
makeInterNodeEquations topo = foldMap f st
  where st = getIntersectionStorages topo
        f (dir, x) =
          case dir of
               NoDir -> mempty
               InDir -> mkInStorageEquations x
               OutDir -> mkOutStorageEquations x

getSection :: Idx.SecNode -> Idx.Section
getSection (Idx.SecNode s _) = s

getNode :: Idx.SecNode -> Idx.Node
getNode (Idx.SecNode _ n) = n

mkInStorageEquations ::
  (Eq a, Fractional a) =>
  ([SecNode], SecNode, [SecNode]) -> EquationSystem s a
mkInStorageEquations (_, _, []) = mempty
mkInStorageEquations (_, n, outs) =
  withLocalVar $ \s ->
    -- The next equation is special for the initial Section.
    (energy n so .= if initialSec n then initStorage else varsumin)
    <> (s .= sum es)
    <> (mconcat $ zipWith (\x e -> e .= x * s) xs es)
    <> (mconcat $ zipWith f sos souts)
  where souts@(so:sos) = L.sortBy (comparing getSection) outs
        initStorage = storage n
        varsumin = insumvar n
        initialSec s = getSection s == Idx.initSection
        xs = map (xfactor n) souts
        es = map (energy n) souts
        f next beforeNext = energy n next .= energy n beforeNext - energy beforeNext n

mkOutStorageEquations ::
  (Eq a, Fractional a) =>
  ([SecNode], SecNode, [SecNode]) -> EquationSystem s a
mkOutStorageEquations ([], _, _) = mempty
mkOutStorageEquations (ins, n, _) =
  withLocalVar $ \s ->
    (s .= sum esOpposite)
    <> (varsumout .= sum esHere)
    <> (mconcat $ zipWith (\e x -> e .= x * s) esOpposite xsHere)
    <> (mconcat $ zipWith (\e x -> e .= x * varsumout) esHere xsHere)
  where sins = L.sortBy (comparing getSection) ins
        esOpposite = map (flip energy n) sins
        esHere = map (energy n) sins
        xsHere = map (xfactor n) sins
        varsumout = outsumvar n


getIntersectionStorages ::
  TD.SequFlowGraph -> [(StDir, ([SecNode], SecNode, [SecNode]))]
getIntersectionStorages = concat . getStorages (format . toSecNode)
  where toSecNode (ins, n, outs) = (map fst ins, fst n, map fst outs)
        format x@(ins, SecNode sec _, outs) =
          case (filter h ins, filter h outs) of
               ([], [])  ->  -- We treat initial storages as in-storages
                 if sec == Idx.initSection then (InDir, x) else (NoDir, x)
               ([_], []) -> (InDir, x)
               ([], [_]) -> (OutDir, x)
               _ -> error ("getIntersectionStorages: " ++ show x)
          where h s = getSection s == sec

-}

-----------------------------------------------------------------


mapToEnvs :: (a -> b) -> M.Map Env.Index a -> Env.Envs Env.SingleRecord b
mapToEnvs func m = M.foldWithKey f envs m
  where envs =
          Env.emptyEnv { Env.recordNumber = Env.SingleRecord (Idx.Record Idx.Absolute) }
        f (Env.Energy idx) v e =
          e { Env.energyMap = M.insert idx (func v) (Env.energyMap e) }
        f (Env.MaxEnergy idx) v e =
          e { Env.maxenergyMap = M.insert idx (func v) (Env.maxenergyMap e) }
        f (Env.Power idx) v e =
          e { Env.powerMap = M.insert idx (func v) (Env.powerMap e) }
        f (Env.X idx) v e =
          e { Env.xMap = M.insert idx (func v) (Env.xMap e) }
        f (Env.Y idx) v e =
          e { Env.yMap = M.insert idx (func v) (Env.yMap e) }
        f (Env.Store idx) v e =
          e { Env.storageMap = M.insert idx (func v) (Env.storageMap e) }
        f (Env.DTime idx) v e =
          e { Env.dtimeMap = M.insert idx (func v) (Env.dtimeMap e) }
        f _ _ e = e


-- powerConvMap :: M.Map Idx.PowerConversion (BijectionWeak a a)

solveSystemDoIt ::
  (Eq a, Fractional a) =>
  [(Env.Index, a)] -> TD.SequFlowGraph -> M.Map Env.Index (Maybe a)
solveSystemDoIt given g = runST $ do
  let f (var, val) = getVar var .= constToExprSys val
      EquationSystem eqsys = foldMap f given <> makeAllEquations g
      -- EquationSystem eqsys = foldMap f given <> makeAllEquations powerConvMap g
  (eqs, varmap) <- runStateT eqsys M.empty
  Sys.solve eqs
  traverse Sys.query varmap

solveSystem ::
  (Eq a, Fractional a) =>
  [(Env.Index, a)] -> TD.SequFlowGraph -> Env.Envs Env.SingleRecord [a]
solveSystem given = mapToEnvs maybeToList . solveSystemDoIt given