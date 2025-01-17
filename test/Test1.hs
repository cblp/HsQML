{-# OPTIONS_GHC -Wno-orphans #-}

{-# LANGUAGE DeriveDataTypeable, TypeFamilies #-}

module Main where

import Graphics.QML.Test.Framework
import Graphics.QML.Test.Harness
import Graphics.QML.Test.DataTest
import Graphics.QML.Test.SimpleTest
import Graphics.QML.Test.SignalTest
import Graphics.QML.Test.MixedTest
import Graphics.QML.Test.AutoListTest
import Data.Proxy
import System.Exit

import Data.Int
import Data.Text (Text)
import qualified Data.Text as T
import Test.QuickCheck.Arbitrary

instance Arbitrary Text where
    arbitrary = fmap T.pack $ arbitrary
    shrink = map T.pack . shrink . T.unpack

main :: IO ()
main = do
    rs <- sequence [
        checkProperty 100 $ TestType (Proxy :: Proxy SimpleMethods),
        checkProperty 100 $ TestType (Proxy :: Proxy SimpleProperties),
        checkProperty 100 $ TestType (Proxy :: Proxy SignalTest1),
        checkProperty 100 $ TestType (Proxy :: Proxy ObjectA),
        checkProperty 20 $ TestType (Proxy :: Proxy (DataTest Bool)),
        checkProperty 20 $ TestType (Proxy :: Proxy (DataTest Int32)),
        checkProperty 20 $ TestType (Proxy :: Proxy (DataTest Double)),
        checkProperty 20 $ TestType (Proxy :: Proxy (DataTest Text)),
        checkProperty 20 $ TestType (Proxy :: Proxy (DataTest (Maybe Bool))),
        checkProperty 20 $ TestType (Proxy :: Proxy (DataTest (Maybe Int32))),
        checkProperty 20 $ TestType (Proxy :: Proxy (DataTest (Maybe Double))),
        checkProperty 20 $ TestType (Proxy :: Proxy (DataTest (Maybe Text))),
        checkProperty 20 $ TestType (Proxy :: Proxy (DataTest [Bool])),
        checkProperty 20 $ TestType (Proxy :: Proxy (DataTest [Int32])),
        checkProperty 20 $ TestType (Proxy :: Proxy (DataTest [Double])),
        checkProperty 20 $ TestType (Proxy :: Proxy (DataTest [Text])),
        checkProperty 100 $ TestType (Proxy :: Proxy AutoListTest)]
    if and rs
    then exitSuccess
    else exitFailure
