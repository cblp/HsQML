module Graphics.QML.Test.Harness where

import Graphics.QML.Test.Framework

import Test.QuickCheck
import Test.QuickCheck.Monadic
import Test.QuickCheck.Test

import Graphics.QML
import Data.IORef
import Data.Proxy
import Data.Typeable
import Data.Maybe
import System.IO
import System.Directory

qmlPrelude :: String
qmlPrelude = unlines [
    "import QtQuick 2.0",
    "import QtQuick.Window 2.0",
    "import HsQML.Model 1.0",
    "Window {",
    "    id: page; visible: false;",
    "    Component.onCompleted: {",
    "        function deepEq(a, b) {",
    "            if (a === b) {return true;}",
    "            if (typeof a == 'object' && typeof b == 'object') {",
    "                var ak = Object.keys(a); var bk = Object.keys(b);",
    "                if (ak.length != bk.length) {return false;}",
    "                for (var i=0; i<ak.length; i++) {",
    "                    if (!deepEq(a[ak[i]], b[ak[i]])) {return false;}}",
    "                return true;}",
    "            return false;}"]

qmlPostscript :: String
qmlPostscript = unlines [
    "    }",
    "}"]

finishTest :: MockObj a -> IO ()
finishTest mock = do
    let statusRef = mockStatus mock
    status <- readIORef statusRef
    let status' = case status of
            TestStatus (_:_) Nothing _ _ -> status {
                testFault = Just TUnderAction}
            _                            -> status
    writeIORef statusRef status'

runTest :: (TestAction a) => TestBoxSrc a -> IO TestStatus
runTest src = do
    let js = showTestCode (srcTestBoxes src) ""
    tmpDir <- getTemporaryDirectory
    (qmlPath, hndl) <- openTempFile tmpDir "test1-.qml"
    hPutStr hndl (qmlPrelude ++ js ++ qmlPostscript)
    hClose hndl
    mock <- mockFromSrc src
    go <- newObjectDC mock
    runEngineLoop defaultEngineConfig {
        initialDocument = fileDocument qmlPath,
        contextObject = Just $ anyObjRef go}
    removeFile qmlPath
    finishTest mock
    status <- readIORef (mockStatus mock)
    if isJust $ testFault status
        then putStrLn $ show status
        else return ()
    return status

testProperty :: (TestAction a) => TestBoxSrc a -> Property
testProperty src = monadicIO $ do
    status <- run $ runTest src
    assert $ isNothing $ testFault status
    return ()

checkProperty :: Int -> TestType -> IO Bool
checkProperty n (TestType pxy) = do
    putStrLn $ "Checking " ++ show (typeOf $ asProxyTypeOf undefined pxy)
    let args = stdArgs {maxSuccess = n}
    r <- quickCheckWithResult args $ testProperty . constrainSrc pxy
    return $ isSuccess r

constrainSrc :: Proxy a -> TestBoxSrc a -> TestBoxSrc a
constrainSrc = flip const
