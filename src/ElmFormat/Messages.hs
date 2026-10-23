module ElmFormat.Messages (PromptMessage(..), InfoMessage(..), ErrorMessage(..)) where

-- inspired by:
-- https://wiki.haskell.org/Internationalization_of_Haskell_programs_using_Haskell_data_types

import Prelude ()
import Relude

import CommandLine.InfoFormatter (ToConsole(..), Loggable(..))
import CommandLine.ResolveFiles as ResolveFiles
import qualified Data.Text as Text
import qualified ElmFormat.Verbatim as Verbatim
import qualified ElmFormat.Version
import ElmVersion
import qualified Reporting.Annotation as A
import qualified Reporting.Error.Syntax as Syntax
import qualified Data.Aeson as Aeson
import Data.Aeson ((.=))


data InfoMessage
  = ProcessingFile FilePath
  | FileWouldChange ElmVersion FilePath
  | ParseError FilePath [A.Located Syntax.Error]
  | JsonParseError FilePath Text
  | VerbatimError FilePath Verbatim.Error


data PromptMessage
    = FilesWillBeOverwritten [FilePath]


data ErrorMessage
  = BadInputFiles [ResolveFiles.Error]
  | NoInputs
  | SingleOutputWithMultipleInputs
  | TooManyInputs
  | OutputAndValidate
  | MustSpecifyVersionWithUpgrade ElmVersion


showFiles :: [FilePath] -> Text
showFiles = unlines . fmap (\filename -> "    " <> Text.pack filename)


instance ToConsole PromptMessage where
    toConsole = \case
        FilesWillBeOverwritten filePaths ->
            unlines
                [ "This will overwrite the following files to use Elm's preferred style:"
                , ""
                , showFiles filePaths
                , "This cannot be undone! Make sure to back up these files before proceeding."
                , ""
                , "Are you sure you want to overwrite these files with formatted versions? (y/n)"
                ]


instance ToConsole InfoMessage where
    toConsole = \case
        ProcessingFile file ->
            "Processing file " <> Text.pack file

        FileWouldChange _ file ->
            "File would be changed " <> Text.pack file

        ParseError inputFile errs ->
            let
                location =
                    Text.pack $
                    case errs of
                        [] -> inputFile
                        (A.At (A.Region (A.Position line col) _) _) : _ -> inputFile ++ ":" ++ show line ++ ":" ++ show col
            in
            "Unable to parse file " <> location <> " To see a detailed explanation, run elm make on the file."

        JsonParseError inputFile err ->
            "Unable to parse JSON file " <> Text.pack inputFile <> "\n\n" <> err

        VerbatimError inputFile err ->
            Text.pack inputFile <> maybe "" (\line -> ":" <> show line) (verbatimLine err)
                <> ": " <> verbatimError err


instance Loggable InfoMessage where
    jsonInfoMessage =
        let
            fileMessage filename message =
                Aeson.pairs $ mconcat
                    [ "path" .= (filename :: FilePath)
                    , "message" .= (message :: String)
                    ]
        in
        \case
        ProcessingFile _ -> Nothing
        FileWouldChange elmVersion file ->
            Just $ fileMessage file $
                "File is not formatted with elm-format-" <> ElmFormat.Version.asString
                <> " --elm-version=" <> show elmVersion
        ParseError inputFile _ ->
            Just $ fileMessage inputFile "Error parsing the file"
        JsonParseError inputFile _ ->
            Just $ fileMessage inputFile "Error parsing the JSON file"
        VerbatimError inputFile err ->
            Just $ fileMessage inputFile $ toString $
                maybe "" (\line -> "Line " <> show line <> ": ") (verbatimLine err)
                <> verbatimError err


instance ToConsole ErrorMessage where
    toConsole = \case
        BadInputFiles filePaths ->
            unlines
                [ "There was a problem reading one or more of the specified INPUT paths:"
                , ""
                , unlines $ map ((<>) "    " . toConsole) filePaths
                , "Please check the given paths."
                ]

        SingleOutputWithMultipleInputs ->
            unlines
                [ "Can't write to the OUTPUT path, because multiple .elm files have been specified."
                , ""
                , "Please remove the --output argument. The .elm files in INPUT will be formatted in place."
                ]

        TooManyInputs ->
            "Too many input sources! Please only provide one of either INPUT or --stdin"

        OutputAndValidate ->
            "Cannot use --output and --validate together"

        MustSpecifyVersionWithUpgrade elmVersion ->
            "I can only upgrade code to specific Elm versions.  To make sure I'm doing what you expect, you must also specify --elm-version=" <> Text.pack (show elmVersion) <> " when you use --upgrade."

        NoInputs ->
            error "Error case NoInputs should be handled elsewhere.  Please report this issue at https://github.com/avh4/elm-format/issues"


verbatimLine :: Verbatim.Error -> Maybe Int
verbatimLine = \case
    Verbatim.IndentedMarker line -> Just line
    Verbatim.RegionAmongImports line -> Just line
    Verbatim.RegionMoved -> Nothing


verbatimError :: Verbatim.Error -> Text
verbatimError = \case
    Verbatim.IndentedMarker _ ->
        "`-- elm-format: off` and `-- elm-format: on` only count at the start of a line, between top-level declarations."

    Verbatim.RegionAmongImports _ ->
        "an `-- elm-format: off` region must come after the imports; elm-format sorts them, and the region would move."

    Verbatim.RegionMoved ->
        "an `-- elm-format: off` region could not be kept in place. Regions must wrap whole top-level declarations after the imports."
