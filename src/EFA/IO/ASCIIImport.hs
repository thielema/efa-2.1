

module EFA.IO.ASCIIImport (modelicaASCIIImport) where

-- | ASCII Import

import qualified Data.Map as M
import Text.ParserCombinators.Parsec (parse, ParseError)

import EFA.Signal.SequenceData (Record(Record), SigId(SigId))

import qualified EFA.Signal.Signal as S
import qualified EFA.Signal.Vector as SV

import EFA.IO.CSVParser (csvFile)




modelicaASCIIParse :: String -> Either ParseError [[String]] -> Record
modelicaASCIIParse _ (Right strs) = makeASCIIRecord strs
modelicaASCIIParse path (Left err) =
  error ("Parse error in file " ++ show path ++ ": " ++ show err)

makeASCIIRecord :: [[String]] -> Record
makeASCIIRecord [] = error "This is not possible!"
makeASCIIRecord hs =
  Record (S.fromList time) (M.fromList $ zip sigIdents (map S.fromList sigs))
  where sigIdents = map (SigId . ("sig_" ++) . show) [0..] 
        time:sigs = SV.transpose (map (map read . init) hs)

parseASCII :: String -> Either ParseError [[String]]
parseASCII input = parse (csvFile ' ') "(unknown)" input

-- | Main ASCIIII Import Function
modelicaASCIIImport :: FilePath -> IO Record
modelicaASCIIImport path = do 
  text <- readFile path
  return $ modelicaASCIIParse path (parseASCII text)