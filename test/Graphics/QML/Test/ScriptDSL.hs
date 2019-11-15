{-# LANGUAGE CPP, FlexibleInstances #-}

module Graphics.QML.Test.ScriptDSL where

import Data.Bits
import Data.Char
import Data.Int
import Data.List
#if MIN_VERSION_base(4,10,0)
import Data.Semigroup
#endif
import Data.Text (Text)
import qualified Data.Text as T
import Numeric

data Expr = Global | Expr {unExpr :: ShowS}

data Prog = Prog ShowS ShowS

instance Semigroup Prog where
    (Prog a1 b1) <> (Prog a2 b2) = Prog (a1 . a2) (b2 . b1)

instance Monoid Prog where
    mempty = Prog id id

#   if MIN_VERSION_base(4,11,0)
#   elif MIN_VERSION_base(4,10,0)
    mappend = (<>)
#   else
    mappend (Prog a1 b1) (Prog a2 b2) = Prog (a1 . a2) (b2 . b1)
#   endif

showProg :: Prog -> ShowS
showProg (Prog a b) = a . b

class Literal a where
    literal :: a -> Expr

instance Literal Bool where
    literal True = Expr $ showString "true"
    literal False = Expr $ showString "false"

instance Literal Int where
    literal x = Expr $ shows x

instance Literal Int32 where
    literal x = Expr $ shows x

instance Literal Double where
    literal x | isNaN x                 = Expr $ showString "(0/0)"
              | isInfinite x && (x < 0) = Expr $ showString "(-1/0)"
              | isInfinite x            = Expr $ showString "(1/0)"
              | isNegativeZero x        = Expr $ showString "-0"
              | otherwise               = Expr $ shows x

instance Literal Text where
    literal txt =
        Expr (showChar '"' . (
            foldr (.) id . map f $ T.unpack txt) . showChar '"')
        where f '\"' = showString "\\\""
              f '\\' = showString "\\\\"
              f c | ord c < 32     = hexEsc c
                  | ord c > 0xffff = surEsc c
                  | ord c > 127    = hexEsc c
                  | otherwise      = showChar c
              hexEsc c = let h = showHex (ord c)
                         in showString "\\u" .  showString (
                                replicate (4 - (length $ h "")) '0') . h
              surEsc c = let v = ord c - 0x10000
                             hi = chr $ (v `shiftR` 10) + 0xD800
                             lo = chr $ (v .&. 0x3ff) + 0xDC00
                         in hexEsc hi . hexEsc lo

instance Literal a => Literal (Maybe a) where
    literal Nothing = Expr $ showString "null"
    literal (Just v) = literal v

instance Literal a => Literal [a] where
    literal xs = Expr (showChar '[' . (
        foldr (.) id . intersperse (showChar ',') $ map (unExpr . literal) xs) .
        showChar ']')

var :: Int -> Expr
var 0 = Global
var n = Expr (showChar 'x' . shows n)

sym :: String -> Expr
sym name = Expr $ showString name

dot :: Expr -> String -> Expr
dot Global     m = Expr $ showString m
dot (Expr lhs) m = Expr (lhs . showChar '.' . showString m)

call :: Expr -> [Expr] -> Expr
call (Expr f) ps = Expr (
    f . showChar '(' . (
        foldr (.) id $ intersperse (showChar ',') $ map unExpr ps) .
    showChar ')')
call _ _ = error "cannot call the context object"

binOp :: String -> Expr -> Expr -> Expr
binOp op (Expr lhs) (Expr rhs) = Expr (
    showChar '(' . lhs . showString op . rhs . showChar ')')
binOp _ _ _ = error "cannot operate on the context object"

eq :: Expr -> Expr -> Expr
eq = binOp " == "

neq :: Expr -> Expr -> Expr
neq = binOp " != "

deepEq :: Expr -> Expr -> Expr
deepEq a b = call (sym "deepEq") [a, b]

eval :: Expr -> Prog
eval (Expr ex) = Prog (ex . showString ";\n") id
eval _ = error "cannot eval the context object"

set :: Expr -> Expr -> Prog
set (Expr lhs) (Expr rhs) =
    Prog (lhs . showString " = " . rhs . showString ";\n") id
set _ _ = error "cannot set the context object"

saveVar :: Int -> Expr -> Prog
saveVar v (Expr rhs) =
    Prog (showString "var x" . shows v . showString " = " .
        rhs . showString ";\n") id
saveVar _ _ = error "cannot save the context object"

assert :: Expr -> Prog
assert (Expr ex) =
    Prog (showString "if (!" . ex .
        showString ") {Qt.quit(); throw -1;}\n") id
assert _ = error "cannot assert the context object"

connect :: Expr -> Expr -> Prog
connect sig fn = eval $ sig `dot` "connect" `call` [fn]

disconnect :: Expr -> Expr -> Prog
disconnect sig fn = eval $ sig `dot` "disconnect" `call` [fn]

makeCont :: [String] -> Prog -> Prog
makeCont args (Prog a b) =
    Prog (showString "var cont = function(" . farg . showString ") {\n")
        (showString "};\n" . a . b)
    where farg = foldr1 (.) $ (id:) $ intersperse (showChar ',') $
                     map showString args

contVar :: Expr
contVar = sym "cont"

callee :: Expr
callee = sym "arguments.callee"

end :: Prog
end = Prog (showString "Qt.quit();\n") id
