module ImportAsync exposing (main)
import   async   Page.Home
import Html exposing (Html)
import async Page.Cart exposing (view)
import Page.Cart exposing (title)
import async {- loaded on first use -} Page.Account as Account
main = Html.text ""
