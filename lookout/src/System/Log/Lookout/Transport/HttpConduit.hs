{-# LANGUAGE OverloadedStrings #-}
module System.Log.Lookout.Transport.HttpConduit
    ( sendRecord
    ) where

import Network (withSocketsDo)
import Network.HTTP.Conduit
import qualified Data.ByteString.Char8 as BS

import System.Log.Lookout
import System.Log.Lookout.Types

sendRecord :: SentrySettings -> SentryRecord -> IO ()
sendRecord conf rec = withSocketsDo $ do
    let ep = endpointURL conf
    let auth = concat [ "Sentry sentry_version=2.0"
                      , ", sentry_client=lookout-0.1.0.0"
                      , ", sentry_key=" ++ sentryPublicKey conf
                      , ", sentry_secret=" ++ sentryPrivateKey conf
                      ]
    case ep of
        Nothing -> return ()
        Just url -> do
            req' <- parseUrl url
            let req = req' { method = "POST"
                           , requestHeaders = [("X-Sentry-Auth", BS.pack auth)]
                           , requestBody = RequestBodyLBS (recordLBS rec)
                           }
            res <- withManager $ httpLbs req
            return ()