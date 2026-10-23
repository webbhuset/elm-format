module ElmFormat.Verbatim (Error(..), protect) where

-- Source marked to be left exactly as written:
--
--     -- elm-format: off       as the first line, above `module`: the whole file
--
--     -- elm-format: off       at the start of a line between top-level
--     ...                      declarations: everything up to the matching
--     -- elm-format: on        `on`, or to the end of the file without one
--
-- Each region is swapped for a placeholder comment before formatting, which
-- formatting keeps, and swapped back afterwards. A region therefore has to be
-- whole top-level declarations: nothing inside a declaration starts a line at
-- column 0, which is the only place a marker counts.

import Prelude ()
import Relude

import qualified Data.Text as Text


data Error
    = IndentedMarker Int
    | RegionAmongImports Int
    | RegionMoved
    deriving (Eq, Show)


protect :: (Text -> Either e Text) -> (Error -> e) -> Text -> Either e Text
protect format toError input =
    case Text.splitOn "\n" input of
        firstLine : _ | isMarker offMarker firstLine ->
            Right input

        inputLines ->
            case cut 1 inputLines [] [] of
                Left err ->
                    Left (toError err)

                Right (_, []) ->
                    format input

                Right (outLines, regions) ->
                    do  formatted <- format (Text.intercalate "\n" outLines)
                        first toError $ restore regions formatted


offMarker :: Text
offMarker =
    "-- elm-format: off"


onMarker :: Text
onMarker =
    "-- elm-format: on"


isMarker :: Text -> Text -> Bool
isMarker marker line =
    Text.stripEnd line == marker


placeholder :: Int -> Text
placeholder index =
    "-- elm-format: verbatim " <> show index


-- A region keeps the lines between its markers, and whether it ended in an `on`.
data Region =
    Region [Text] Bool


cut :: Int -> [Text] -> [Text] -> [Region] -> Either Error ([Text], [Region])
cut lineNumber remaining out regions =
    case remaining of
        [] ->
            Right (reverse out, reverse regions)

        line : rest
            | isMarker offMarker line && any (Text.isPrefixOf "import ") rest ->
                -- Imports are sorted, and a region among them would move.
                Left (RegionAmongImports lineNumber)

            | isMarker offMarker line ->
                let
                    (inside, after) = break (isMarker onMarker) rest
                    marked = placeholder (length regions) : line : out
                in
                case after of
                    onLine : rest' ->
                        cut (lineNumber + length inside + 2) rest'
                            (onLine : marked)
                            (Region inside True : regions)

                    [] ->
                        -- To the end of the file, whose ending is elm-format's
                        -- to normalise.
                        Right
                            ( reverse marked
                            , reverse (Region (dropTrailing Text.null inside) False : regions)
                            )

            | isMarker offMarker (Text.stripStart line) || isMarker onMarker (Text.stripStart line) ->
                Left (IndentedMarker lineNumber)

            | otherwise ->
                cut (lineNumber + 1) rest (line : out) regions


-- Every placeholder must still sit right after its `off` and, when it had one,
-- right before its `on`; anything else means formatting moved the comments
-- apart, as it can among imports, and putting the region back would be a guess.
restore :: [Region] -> Text -> Either Error Text
restore regions formatted =
    let
        go previous remaining =
            case remaining of
                [] ->
                    Right []

                line : rest ->
                    case lookupPlaceholder line of
                        Nothing ->
                            (line :) <$> go (Just line) rest

                        Just (Region inside closed) ->
                            let
                                follows = maybe False (isMarker offMarker) previous
                                precedes =
                                    case rest of
                                        next : _ -> not closed || isMarker onMarker next
                                        [] -> not closed
                            in
                            if follows && precedes then
                                (inside ++) <$> go (Just line) rest
                            else
                                Left RegionMoved

        lookupPlaceholder line =
            fmap snd $ find ((==) (Text.stripEnd line) . fst) $
                zip (map placeholder [0..]) regions

        formattedLines = Text.splitOn "\n" formatted

        found = length (filter (isJust . lookupPlaceholder) formattedLines)
    in
    if found /= length regions then
        Left RegionMoved
    else
        Text.intercalate "\n" <$> go Nothing formattedLines


dropTrailing :: (a -> Bool) -> [a] -> [a]
dropTrailing predicate =
    reverse . dropWhile predicate . reverse
