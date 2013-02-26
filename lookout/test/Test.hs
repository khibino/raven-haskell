import Test.Hspec
import Control.Exception (evaluate)

import qualified Data.ByteString.Lazy.Char8 as LBS
import qualified Data.HashMap.Strict as HM
import Control.Concurrent.MVar (newEmptyMVar, putMVar, takeMVar)

import System.Log.Lookout
import System.Log.Lookout.Types as LT
import System.Log.Lookout.Transport.Debug (dumpRecord, briefRecord, catchRecord)
import System.Log.Lookout.Transport.HttpConduit (sendRecord)

main :: IO ()
main = hspec $ do
  describe "Types" $ do
    it "parses empty DSN into SentryDisabled" $ do
        fromDSN "" `shouldBe` SentryDisabled

    it "carps on invalid DSN" $ do
        evaluate (fromDSN "lol://haha") `shouldThrow` anyException
        evaluate (fromDSN "http://haha") `shouldThrow` anyException

    it "parses example DSN" $ do
        fromDSN dsn `shouldBe` ss

    it "generates correct endpoint" $ do
        endpointURL SentryDisabled `shouldBe` Nothing
        endpointURL ss `shouldBe` Just "http://example.com/sentry/api/project-id/store/"

    it "generates empty record" $ do
        newRecord "" "" "" Debug "" `shouldBe` emptyRecord

    it "generates record template" $ do
        r <- strip `fmap` test
        r `shouldBe` testRecord

    it "serializes as JSON" $ do
        r <- strip `fmap` test
        recordLBS r `shouldBe` testRecordLBS

  describe "Service" $ do
    it "ignores record when service is disabled" $ do
        l <- disabledLookout
        ok <- register l "test.logger" Debug "Fly me to /dev/null" id
        ok `shouldBe` ()

    it "uses a fallback" $ do
        v <- newEmptyMVar
        l <- initLookout "http://bad:boo@localhost:1/lookout" id undefined (\_ -> putMVar v True)
        sent <- register l "test.logger" Debug "Ready or not, here i come!" id
        sent `shouldBe` ()
        fbUsed <- takeMVar v
        fbUsed `shouldBe` True

  describe "Transport: HttpConduit" $ do
    it "sends a record" $ do
        l <- initLookout "http://test:test@localhost:19876/lookout" id sendRecord errorFallback
        ok <- register l "test.logger" Debug "Like a record, baby, right round." id
        ok `shouldBe` ()

  describe "Transport: Debug" $ do
    it "shows brief message" $ do
        l <- initLookout "http://not:really@whatever.fake/project" id briefRecord errorFallback
        ok <- register l "test.logger" Debug "Hi there!" id
        ok `shouldBe` ()

    it "dumps event record" $ do
        l <- initLookout "http://not:really@whatever.fake/project" id dumpRecord errorFallback
        ok <- register l "test.logger" Debug "Hi there!" id
        ok `shouldBe` ()

    it "catches record into MVar" $ do
        v <- newEmptyMVar
        l <- initLookout "http://not:really@whatever.fake/project" id (catchRecord v) errorFallback
        ok <- register l "test.logger" Debug "Hi there!" id
        ok `shouldBe` ()
        rec <- takeMVar v
        srMessage rec `shouldBe` "Hi there!"

dsn = "http://public_key:secret_key@example.com/sentry/project-id"

ss = SentrySettings {
         sentryURI = "http://example.com/sentry/",
         sentryPublicKey = "public_key",
         sentryPrivateKey = "secret_key",
         sentryProjectId = "project-id"
     }

strip rec = rec { srEventId = ""
                , srTimestamp = ""
                }

test = record "test.logger" Debug "test record please ignore" id

emptyRecord = SentryRecord { srEventId    = ""
                              , srMessage    = ""
                              , srTimestamp  = ""
                              , srLevel      = Debug
                              , srLogger     = ""
                              , srPlatform   = Nothing
                              , srCulprit    = Nothing
                              , srTags       = HM.empty
                              , srServerName = Nothing
                              , srModules    = HM.empty
                              , srExtra      = HM.empty
                              , srInterfaces = HM.empty
                              }

testRecord = emptyRecord { srMessage = "test record please ignore"
                         , srLevel = Debug
                         , srLogger = "test.logger"
                         }

testRecordLBS = LBS.pack "{\"timestamp\":\"\",\"message\":\"test record please ignore\",\"event_id\":\"\",\"level\":\"debug\",\"logger\":\"test.logger\"}"
