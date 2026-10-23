module ImportAsync exposing (main)

import Html exposing (Html)
import {- loaded on first use -} async Page.Account as Account
import async Page.Cart exposing (title, view)
import async Page.Home


main =
    Html.text ""
