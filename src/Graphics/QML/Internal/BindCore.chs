{-# LANGUAGE
    ForeignFunctionInterface
  #-}
{-# OPTIONS_HADDOCK hide #-}

module Graphics.QML.Internal.BindCore where

{#import Graphics.QML.Internal.BindPrim #}
{#import Graphics.QML.Internal.BindObj #}

import Foreign.ForeignPtr
import Foreign.Marshal.Utils (fromBool, toBool)
import Foreign.Ptr

#include <HsFFI.h>

#include "hsqml.h"

type HsFreeFunPtr = FunPtr (FunPtr (IO ()) -> IO ())
foreign import ccall "HsFFI.h &hs_free_fun_ptr"
  hsFreeFunPtr :: HsFreeFunPtr

type HsFreeStablePtr = FunPtr (Ptr () -> IO ())
foreign import ccall "HsFFI.h &hs_free_stable_ptr"
  hsFreeStablePtr :: HsFreeStablePtr

{#fun unsafe hsqml_init as hsqmlInit_
  {id `HsFreeFunPtr',
   id `HsFreeStablePtr'} ->
  `()' #}

hsqmlInit :: IO ()
hsqmlInit = hsqmlInit_ hsFreeFunPtr hsFreeStablePtr

{#fun unsafe hsqml_set_args as ^
  {id `Ptr HsQMLStringHandle'} ->
  `Bool' toBool #}

{#fun unsafe hsqml_get_args_count as ^
  {} ->
  `Int' fromIntegral #}

{#fun unsafe hsqml_get_args as ^
  {id `Ptr HsQMLStringHandle'} ->
  `()' #}

{#enum HsQMLGlobalFlag as ^ {underscoreToCase} #}

{#fun unsafe hsqml_set_flag as ^
  {enumToCInt `HsQMLGlobalFlag',
   fromBool `Bool'} ->
  `Bool' toBool #}

{#fun unsafe hsqml_get_flag as ^
  {enumToCInt `HsQMLGlobalFlag'} ->
  `Bool' toBool #}

type TrivialCb = IO ()

foreign import ccall "wrapper"
  marshalTrivialCb :: TrivialCb -> IO (FunPtr TrivialCb)

withTrivialCb :: TrivialCb -> (FunPtr TrivialCb -> IO a) -> IO a
withTrivialCb f with = marshalTrivialCb f >>= with

withMaybeTrivialCb :: Maybe TrivialCb -> (FunPtr TrivialCb -> IO b) -> IO b
withMaybeTrivialCb (Just f) = withTrivialCb f
withMaybeTrivialCb Nothing = \cont -> cont nullFunPtr

{#enum HsQMLEventLoopStatus as ^ {underscoreToCase} #}

{#fun hsqml_evloop_run as ^
  {withTrivialCb* `TrivialCb',
   withTrivialCb* `TrivialCb',
   withMaybeTrivialCb* `Maybe TrivialCb'} ->
  `HsQMLEventLoopStatus' cIntToEnum #}

{#fun hsqml_evloop_require as ^
  {} ->
  `HsQMLEventLoopStatus' cIntToEnum #}

{#fun hsqml_evloop_release as ^
  {} ->
  `()' #}

{#fun unsafe hsqml_evloop_notify_jobs as ^
  {} ->
  `()' #}

{#fun unsafe hsqml_evloop_shutdown as ^
  {} ->
  `HsQMLEventLoopStatus' cIntToEnum #}

{#pointer *HsQMLEngineHandle as ^ foreign newtype #}

foreign import ccall "hsqml.h &hsqml_finalise_engine_handle"
  hsqmlFinaliseEngineHandlePtr :: FunPtr (Ptr (HsQMLEngineHandle) -> IO ())

newEngineHandle :: Ptr HsQMLEngineHandle -> IO HsQMLEngineHandle
newEngineHandle p = do
  fp <- newForeignPtr hsqmlFinaliseEngineHandlePtr p
  return $ HsQMLEngineHandle fp

{#fun hsqml_create_engine as ^
  {withMaybeHsQMLObjectHandle* `Maybe HsQMLObjectHandle',
   id `HsQMLStringHandle',
   id `Ptr HsQMLStringHandle',
   id `Ptr HsQMLStringHandle',
   withTrivialCb* `TrivialCb'} ->
  `HsQMLEngineHandle' newEngineHandle* #}

{#fun hsqml_kill_engine as ^
  {withHsQMLEngineHandle* `HsQMLEngineHandle'} ->
  `()' #}

{#fun unsafe hsqml_set_debug_loglevel as ^
  {fromIntegral `Int'} -> `()'
  #}
