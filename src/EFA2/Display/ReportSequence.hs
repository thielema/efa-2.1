{-# LANGUAGE FlexibleInstances, GADTs #-}

module EFA2.Display.ReportSequence (module EFA2.Display.ReportSequence) where

import qualified Data.List as L
import qualified Data.Map as M
import qualified Data.Vector.Unboxed as UV
import Data.Monoid
import qualified Text.PrettyPrint.HughesPJ as PP
import qualified Text.Show.Pretty as SP

import EFA2.Signal.Signal
import EFA2.Signal.Data
import EFA2.Display.DispSignal

import System.IO

-- import EFA.Graph.GraphData
-- import EFA.Signal.SignalData
-- import EFA2.Utils.Utils
import EFA2.Signal.SequenceData
import EFA2.Display.DispSignal

type Title = String
type ColumnTitle = String

data Table = Table Title [ColumnTitle] [Row]
           | TableDoc [Table] deriving (Show)

instance Monoid Table  where
         mempty = TableDoc []
         mappend (TableDoc as) (TableDoc bs) = TableDoc (as ++ bs)
         mappend (TableDoc as) t@(Table _ _ _) = TableDoc (as ++ [t])
         mappend t@(Table _ _ _) (TableDoc bs) = TableDoc (t:bs)
         mappend t1@(Table _ _ _) t2@(Table _ _ _) = TableDoc [t1, t2]

data Row = VectorRow Title (UV.Vector Double)
         | ListRow Title [Double] 
         | SigRange Title String deriving (Show)
                                           
class ToTable a where
      toTable :: (SigId -> String) -> a -> Table

instance ToTable PowerRecord where
         toTable _ (PowerRecord time sigs) = TableDoc [Table "Signals" [] rows]
           where rows = map (\(x, y) ->  SigRange (show x) (sdisp y)) $ M.toList sigs

-- TODO: correct formating
formatDocHor :: Table -> String
formatDocHor (TableDoc ts) = PP.render $ PP.vcat rows'
  where rows = L.transpose $ map formatTable ts
        rows' = map f (zip tabBegins rows)
        f (x, t) = PP.nest x (foldl (PP.$$) PP.empty t)
        tabBegins = 0:(map (+60) tabBegins)

formatDocVer :: Table -> String
formatDocVer (TableDoc ts) = PP.render $ PP.vcat (L.intersperse PP.space (map PP.vcat rows))
  where rows = map formatTable ts

formatTable :: Table -> [PP.Doc]
formatTable (Table ti _ rs) = map formatRow rs

formatRow :: Row -> PP.Doc
formatRow (VectorRow ti vec) = (PP.nest 0 (PP.text ti)) PP.$$ (foldl (PP.$$) PP.empty (map f (zip colBegins lst)))
  where lst = map PP.double (UV.toList vec)
        f (x, t) = PP.nest x t
        colBegins = 10:(map (+22) colBegins)

formatRow (SigRange ti vec) = (PP.nest 0 (PP.text ti)) PP.$$ (foldl (PP.$$) PP.empty (map f (zip colBegins lst)))
  where lst = map PP.text [vec]
        f (x, t) = PP.nest x t
        colBegins = 10:(map (+22) colBegins)


formatRow (ListRow ti xs) = (PP.nest 0 (PP.text ti)) PP.$$ (foldl (PP.$$) PP.empty (map f (zip colBegins lst)))
  where lst = map PP.double xs
        f (x, t) = PP.nest x t
        colBegins = 10:(map (+22) colBegins)

-- TODO: write formatDocHor versions of this functions.
printTable :: (ToTable a) => Handle -> (SigId -> String) -> a -> IO ()
printTable h f = hPutStrLn h . formatDocVer . toTable f

printTableToScreen :: (ToTable a) => (SigId -> String) -> a -> IO ()
printTableToScreen = printTable stdout

printTableToFile :: (ToTable a) => FilePath -> (SigId -> String) ->  a -> IO ()
printTableToFile fileName f t = do
  h <- openFile fileName WriteMode
  printTable h f t
  hClose h


  
  