module Main where

import Prelude

import Effect (Effect)
import Effect.Console (logShow)
import Data.String.Pattern (Pattern(..))
import Data.String.Common (split)

main :: Effect Unit
main = do
  logShow $ split (Pattern " ") "Hello World." 
