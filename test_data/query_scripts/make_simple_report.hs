{-# LANGUAGE DeriveDataTypeable #-}

module Main where

import ResultsDB(getConnection)
import Database.HDBC(toSql,withTransaction,prepare,execute,sFetchAllRows)
import Database.HDBC.Sqlite3(Connection)
import Text.Hastache
import Text.Hastache.Context(mkStrContext)
import qualified Data.ByteString.Lazy.Char8 as L
import System.FilePath((</>),(<.>),takeDirectory,takeFileName)
import System.Directory
import System.Console.CmdArgs
import System.Environment
import Data.Time.Clock(getCurrentTime,UTCTime)
import System.Locale(defaultTimeLocale)
import Data.Time.Format(formatTime)
import Data.Maybe
import Control.Monad.IO.Class

data Options = Options
               { reportName :: String
               , reportComment :: String
               , queryType :: String
               , query :: String
               } deriving (Data,Typeable,Show)

progOpts :: Options
progOpts = Options
           { reportName  = "query" &= help "The name of this report"
           , reportComment = "" &= help "additional comments"
           , queryType = "stdErrLike" &= help "Which sort of query should we do? Default=stdErrLike"
           , query = "%Not implemented code%" &= help "The query to perform over stderr"}

data Batch = Batch
             { bId :: Int
             , bTime :: Int
             , bImplementation :: String
             , bImplPath :: String
             , bImplVersion :: String
             , bTitle :: String
             , bNotes :: String
             , bTimestamp :: Int
             , bSystem :: String
             , bOsnodename :: String
             , bOsrelease :: String
             , bOsversion :: String
             , bHardware :: String
             } deriving Show

data SingleTestRun = SingleTestRun
                     { strId :: Int
                     , strTestId :: String
                     , strBatchId :: Int
                     , strStatus :: String
                     , strStdout :: String
                     , strStderr :: String
                     } deriving Show

strPASS :: String
strPASS = "PASS"
strFAIL :: String
strFAIL = "FAIL"
strABORT :: String
strABORT = "ABORT"

stmts :: [(String,String)]
stmts = [
  ("stmtGetTestRunByID", "SELECT * from test_batch_runs where id=?"),

  ("stmtGetBatchIDs" , "SELECT id from test_batch_runs ORDER BY id DESC"),

  ("getLatestBatch" , "select id,"++
                      "time,"++
                      "implementation,"++
                      "impl_path,"++
                      "impl_version,"++
                      "title,"++
                      "notes,"++
                      "timestamp,"++
                      "system,"++
                      "osnodename,"++
                      "osrelease,"++
                      "osversion,"++
                      "hardware from test_batch_runs where id=("++
                      "select max(id) from ("++
                      "(select * from test_batch_runs where "++
                      "implementation='JSRef')))"),

  ("stmtGetSTRsByBatch" , "SELECT * from single_test_runs where batch_id=?"),

  ("stmtGetSTRsByBatchStdOut" , "SELECT * from single_test_runs where stdout LIKE ? AND batch_id=?;"),

  ("stdErrLike" , "SELECT id,test_id,batch_id,status,stdout,stderr from single_test_runs where stdout LIKE ? AND batch_id=?;"),

  ("stdErrNotLike" , "SELECT id,test_id,batch_id,status,stdout,stderr from single_test_runs where id NOT IN (select id from single_test_runs where stdout LIKE ? AND batch_id=?)")
  ]

dbToBatch :: [Maybe String] -> Batch
dbToBatch res = Batch
                     { bId = read.fromJust $ head res
                     , bTime = read.fromJust $ res!!1
                     , bImplementation = fromJust $ res!!2
                     , bImplPath = fromJust $ res!!3
                     , bImplVersion = fromJust $ res!!4
                     , bTitle = fromJust $ res!!5
                     , bNotes = fromJust $ res!!6
                     , bTimestamp = read.fromJust $ res!!7
                     , bSystem = fromJust $ res!!8
                     , bOsnodename = fromJust $ res!!9
                     , bOsrelease = fromJust $ res!!10
                     , bOsversion = fromJust $ res!!11
                     , bHardware = fromJust $ res!!12}


dbToSTR :: [Maybe String] -> SingleTestRun
dbToSTR res = SingleTestRun
                     { strId = read.fromJust $ head res
                     , strTestId = fromJust $ res!!1
                     , strBatchId = read.fromJust $ res!!2
                     , strStatus = fromJust $ res!!3
                     , strStdout = fromJust $ res!!4
                     , strStderr = fromJust $ res!!5
                     }

reportDir :: IO FilePath
reportDir = do
  dir <- getCurrentDirectory
  return $ runNTimes 5 takeDirectory dir </> "web" </> "test_results"
  where runNTimes n f x = iterate f x !! n

outerTemplate :: IO FilePath
outerTemplate = do
  dir <- reportDir
  return $ dir</>"template"<.>"tmpl"

reportTemplate :: IO FilePath
reportTemplate = do
  dir <- reportDir
  return $ dir</>"test_results"<.>"tmpl"

outputFileName :: String -> UTCTime -> String -> IO FilePath
outputFileName username time tname = do
  dir <- reportDir
  return $
    dir </> ("query_"++username++"_"++tname++"_"++
             formatTime defaultTimeLocale "%_y-%m-%dT%H:%M:%S" time) <.> "html"

reportContext :: Monad m => String -> String -> String -> UTCTime -> Batch -> [SingleTestRun] -> MuContext m
reportContext qname comment user time batch results = mkStrContext context
  where
    passes = filter ((strPASS==). strStatus ) results
    fails = filter ((strFAIL==). strStatus ) results
    aborts = filter ((strABORT==). strStatus ) results
    context "implementation" = MuVariable $ bImplementation batch
    context "testtitle" = MuVariable qname
    context "testnote" = MuVariable $ comment ++ " -- " ++ bTitle batch ++ ": " ++ bNotes batch
    context "time" = MuVariable $ formatTime defaultTimeLocale "%_y-%m-%dT%H:%M:%S" time
    context "user" = MuVariable user
    context "system" = MuVariable $ bSystem batch
    context "osnodename" = MuVariable $ bOsnodename batch
    context "osrelease" = MuVariable $ bOsrelease batch
    context "osversion" = MuVariable $ bOsversion batch
    context "hardware" = MuVariable $ bHardware batch
    context "numpasses" = MuVariable $ length passes
    context "numfails" = MuVariable $ length fails
    context "numaborts" = MuVariable $ length aborts
    context "aborts" = MuList $ map (mkStrContext . resContext) aborts
    context "failures" = MuList $ map (mkStrContext . resContext) fails
    context "passes" = MuList $ map (mkStrContext . resContext) passes
    context _ = error "I forgot a case from my template"
    resContext res "testname" = MuVariable . takeFileName $ strTestId res
    resContext res "filename" = MuVariable $ strTestId res
    resContext res "stdout" = MuVariable $ strStdout res
    resContext res "stderr" = MuVariable $ strStderr res
    resContext _ _ = error "I forgot an inner case from my template"

getLatestBatch :: Connection -> IO Batch
getLatestBatch con = do
  stmt <- prepare con (fromJust (lookup "getLatestBatch" stmts))
  execute stmt []
  dat <- fmap head $ sFetchAllRows stmt
  return $ dbToBatch dat

getTestsByErrQuery :: Int -> String -> String -> Connection -> IO [SingleTestRun]
getTestsByErrQuery batch querytype querystr con = do
  stmt <- prepare con (fromJust (lookup querytype stmts))
  execute stmt [toSql querystr, toSql batch]
  dat <- sFetchAllRows stmt
  return $ map dbToSTR dat

escapelessConfig :: MonadIO m => MuConfig m
escapelessConfig = defaultConfig {muEscapeFunc = emptyEscape}


main :: IO ()
main = do
  opts <- cmdArgs progOpts
  con <- getConnection
  latestBatch <- withTransaction con getLatestBatch
  strs <- withTransaction con $
          getTestsByErrQuery (bId latestBatch) (queryType opts) (query opts)
  outertemp <- outerTemplate
  template <- reportTemplate
  username <- getEnv "USER"
  time <- getCurrentTime
  report <- hastacheFile defaultConfig template (reportContext (reportName opts) (reportComment opts) username time latestBatch strs)
  outfile <- outputFileName username time (reportName opts)
  L.writeFile outfile =<< hastacheFile escapelessConfig outertemp (mkStrContext (\_ -> MuVariable report))
