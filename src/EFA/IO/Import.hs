module EFA.IO.Import (module EFA.IO.Import) where

import qualified Data.Map as M 

import Data.Ratio (Ratio, approxRational)

import EFA.Signal.SequenceData (Record(Record), SigId(SigId))

--import Text.ParserCombinators.Parsec
import Data.List.HT (chop)

import qualified EFA.Signal.Signal as S
import qualified EFA.Signal.Vector as SV


-- Modelica CSV Import -----------------------------------------------------------------  


{- Modlica CSV - Example:

"time","Sig2","Sig3",
0,1,2,
0,2,4,

-}

-- | Main Modelica CSV Import Function
modelicaCSVImport:: FilePath -> IO Record
modelicaCSVImport path = do 
  text <- readFile path
  return $ modelicaCSVParse text

-- | Parse modelica-generated CSV - files with signal logs   
modelicaCSVParse :: String -> Record
modelicaCSVParse text = rec
  where csvlines = lines text -- read get all lines
        header =  csvParseHeaderLine $ head csvlines  -- header with labels in first line       
        sigIdents = map SigId (tail header) -- first column is "time" / use Rest
        columns = SV.transpose (map csvParseDataLine $ tail csvlines) -- rest of lines contains data / transpose from columns to lines
        time = if (head header) == "time" then head columns else error $ "Error in csvImport - first column not time : " ++ (head header)
        sigs = tail columns -- generate signals from rest of columns
        rec = Record (S.fromList time)  (M.fromList $ zip sigIdents (map S.fromList sigs)) -- generate Record with signal Map
        
-- | Parse CSV Header Line
csvParseHeaderLine :: String -> [String]  
csvParseHeaderLine line = init $ map read (chop (','==) line)   -- (init . tail) to get rid of Modelica " " quotes 

class ParseCVS a where
      csvParseDataLine :: String -> [a]


instance ParseCVS Double where
         -- | Parse CSV Data Line
         csvParseDataLine line = init $ map read (chop (','==) line)  -- another init to get rid of final , per line

instance Integral int => ParseCVS (Ratio int) where
         csvParseDataLine line = init $ map (realToFrac . flip approxRational (0.001::Rational) . read) (chop (','==) line)