{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE Rank2Types #-}
{-# LANGUAGE FlexibleContexts #-}
module EFA.Flow.Topology.Absolute (
   module EFA.Flow.Topology.Absolute,
   (=.=),
   ) where

import qualified EFA.Flow.Topology.EquationSystem as EqSys
import qualified EFA.Flow.Topology.Quantity as FlowTopo
import qualified EFA.Flow.Topology.Variable as Var
import EFA.Flow.Topology.EquationSystem ((=.=))

import qualified EFA.Equation.Record as Record
import qualified EFA.Equation.Verify as Verify
import qualified EFA.Equation.Arithmetic as Arith
import EFA.Equation.Result(Result)

import qualified EFA.Graph.Topology.Index as Idx
import qualified EFA.Graph.Topology.Node as Node

import qualified UniqueLogic.ST.TF.Expression as Expr
import qualified UniqueLogic.ST.TF.System as Sys

import qualified Control.Monad.Exception.Synchronous as ME

import Control.Applicative (liftA, liftA2)
import Data.Tuple.HT (mapFst)


type
   EquationSystem mode node s a =
      EqSys.EquationSystem mode Record.Absolute node s a

type
   Expression mode node s a x =
      EqSys.Expression mode Record.Absolute node s a x


type
   EquationSystemIgnore node s a =
      EqSys.EquationSystem Verify.Ignore Record.Absolute node s a

type
   ExpressionIgnore node s a x =
      EqSys.Expression Verify.Ignore Record.Absolute node s a x


solve ::
   (Arith.Product a, Node.C node) =>
   FlowTopo.Section node (Result a) ->
   (forall s. EquationSystem Verify.Ignore node s a) ->
   FlowTopo.Section node (Result a)
solve graph sys =
   FlowTopo.mapSection Record.unAbsolute $
   EqSys.solve (FlowTopo.mapSection Record.Absolute graph) sys

solveTracked ::
   (Verify.GlobalVar (Verify.Track output) a Idx.Absolute Var.Signal node,
    Arith.Product a, Node.C node) =>
   FlowTopo.Section node (Result a) ->
   (forall s. EquationSystem (Verify.Track output) node s a) ->
   (ME.Exceptional
      (Verify.Exception output)
      (FlowTopo.Section node (Result a)),
    Verify.Assigns output)
solveTracked graph sys =
   mapFst (fmap (FlowTopo.mapSection Record.unAbsolute)) $
   EqSys.solveTracked (FlowTopo.mapSection Record.Absolute graph) sys


constant ::
   (Sys.Value mode a) =>
   a -> Expression mode node s a a
constant = EqSys.constant

variable ::
   (Sys.Value mode a, FlowTopo.Lookup idx, Node.C node) =>
   idx node -> Expression mode node s a a
variable = EqSys.variable . Idx.absolute


liftF ::
   (Arith.Sum y, Sys.Value mode y) =>
   (x -> y) ->
   Expression mode node s a x ->
   Expression mode node s a y
liftF = liftA . Expr.fromRule2 . Sys.assignment2

liftF2 ::
   (Arith.Sum z, Sys.Value mode z) =>
   (x -> y -> z) ->
   Expression mode node s a x ->
   Expression mode node s a y ->
   Expression mode node s a z
liftF2 = liftA2 . Expr.fromRule3 . Sys.assignment3


infix 0 .=, =%%=

(.=) ::
   (Sys.Value mode a, FlowTopo.Lookup idx, Node.C node) =>
   idx node -> a -> EquationSystem mode node s a
evar .= val  =  variable evar =.= constant val


(=%%=) ::
   (Sys.Value mode a, FlowTopo.Lookup idx, Node.C node) =>
   idx node -> idx node -> EquationSystem mode node s a
(=%%=) = (EqSys.=%%=)