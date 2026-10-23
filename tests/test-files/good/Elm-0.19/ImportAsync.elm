module ImportAsync exposing (main)

import Html exposing (Html)
import async Page.Account as Account
import async Page.Cart exposing (view)
import async Page.Home
import Platform


main : Html msg
main =
    Html.text ""
