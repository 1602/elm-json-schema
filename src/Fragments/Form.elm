module Fragments.Form exposing (render, Context)

import Types exposing (..)
import Models exposing (ValidationErrors)
import Json.Encode as Encode exposing (Value)
import Html exposing (div, span, text, input)
import Html.Events exposing (onClick, onInput)
import Html.Attributes as Attrs exposing (style)
import Dict
import Set
import String
import JsonSchema as JS
import Layout exposing (boxStyle)
import Markdown
import Regex exposing (replace, regex)


type alias Path =
    List String


type alias Context msg =
    { validationErrors : ValidationErrors
    , schema : Schema
    , data : Value
    , onInput : Value -> msg
    }


updateValue : Context msg -> Path -> Value -> Value
updateValue ctx path val =
    JS.setValue ctx.schema path val ctx.data


render : Context msg -> Html.Html msg
render context =
    renderSchema context [] context.schema

renderPath : Path -> Html.Html msg
renderPath path =
    Html.pre [ style
        [ ( "font-weight", "bold" )
        , ( "font-size", (toString (21 - (List.length path) * 3)) ++ "px" )
        , ( "margin-bottom", "20px" )
        , ( "margin-top", "30px" )
        ]
    ] [ text <| String.join "." path ]

renderSchema : Context msg -> Path -> Schema -> Html.Html msg
renderSchema context path node =
    let
        renderRow ( name, property ) =
            let
                type_ =
                    property.type_

                required =
                    Set.member name node.required

                newPath =
                    path ++ [ name ]

                validationError =
                    Dict.get newPath context.validationErrors
                        |> Maybe.withDefault ""

                hasError =
                    Dict.member newPath context.validationErrors

                rowStyle =
                    if hasError then
                        boxStyle ++ [ ( "border-color", "red" ) ]
                    else
                        boxStyle
            in
                if property.type_ == "object" || property.type_ == "array" then
                    div []
                    [ renderPath newPath
                    , Markdown.toHtml [ Attrs.class "markdown-doc" ] property.description
                    , renderProperty context property required newPath
                    ]
                else
                div [ style [ ( "display", "flex" ), ("margin-bottom","20px") ] ]
                    [ div
                        [ style
                            [ ( "flex-shrink", "0" )
                            , ( "text-align", "right" )
                            , ( "padding", "10px" )
                            , ( "box-sizing", "border-box" )
                            , ( "width", "38.2%" )
                            , ( "background", "rgba(10, 150, 140, 0.04)" )
                            ]
                        ]
                        [ text
                            (if required then
                                "* "
                             else
                                ""
                            )
                        , Html.code [ style [ ("font-weight", "bold") ] ] [ text name ]
                        , Html.br [] []
                        , Html.span [ style [ ( "color", "dimgrey" ) ] ] [ text type_ ]
                        ]
                    , div [ style
                            [ ("padding", "10px")
                            , ( "box-sizing", "border-box" )
                            , ( "width", "61.8%" )
                            ]
                        ]
                        [ if String.isEmpty property.description then
                            text ""
                        else
                            Markdown.toHtml [ Attrs.class "markdown-doc" ] property.description

                        ,  renderProperty context property required newPath
                        , if hasError then
                            span
                                [ style
                                    [ ( "display", "inline-block" )
                                    , ( "font-style", "italic" )
                                    , ( "background", "lightyellow" )
                                    , ( "color", "red" )
                                      -- , ( "font-weight", "bold" )
                                    , ( "margin-top", "5px" )
                                    ]
                                ]
                                [ text validationError ]
                          else
                            text ""
                        ]
                    ]
    in
        div [] <| JS.mapProperties node.properties renderRow


renderSelect : Context msg -> List String -> Schema -> Bool -> Path -> Html.Html msg
renderSelect context options prop required path =
    options
        |> List.map (\opt -> Html.option [] [ text opt ])
        |> Html.select
            [ Html.Events.onInput (\s -> context.onInput <| updateValue context path <| Encode.string s)
            , Attrs.value <| JS.getString context.schema path context.data
            ]


renderProperty : Context msg -> Schema -> Bool -> Path -> Html.Html msg
renderProperty context prop required path =
    case prop.type_ of
        "string" ->
            case prop.enum of
                Nothing ->
                    renderInput context prop required path

                Just enum ->
                    renderSelect context enum prop required path

        "integer" ->
            renderInput context prop required path

        "boolean" ->
            renderInput context prop required path

        "object" ->
            renderSchema context path prop

        "array" ->
            case prop.items of
                Just (JS.ArrayItemDefinition itemDefinition) ->
                    renderArray context itemDefinition required path

                Nothing ->
                    text "missing item definition for array"

        "any" ->
            renderInput context prop required path

        _ ->
            text ("Unknown property type: " ++ prop.type_)


renderArray : Context msg -> Schema -> Bool -> List String -> Html.Html msg
renderArray context property required path =
    let
        length =
            JS.getLength context.schema path context.data

        buttonStyle =
            [ ( "background", "white" )
            , ( "cursor", "pointer" )
            , ( "border", "1px solid ActiveBorder" )
            , ( "color", "ActiveBorder" )
            , ( "margin", "10px" )
            , ( "padding", "5px" )
            , ( "display", "inline-block" )
            ]

        renderItem index =
            div [ ]
                [ renderPath <| path ++ [index]
                , renderProperty
                    context
                    property
                    required
                    (path ++ [ index ])
                ]
    in
        div []
            [ div [] <|
                List.map renderItem <|
                    List.map toString (List.range 0 (length - 1))
            , span
                [ onClick (context.onInput <| updateValue context (path ++ [ toString length ]) (JS.defaultFor property))
                , style buttonStyle
                ]
                [ text "Add item" ]
            ]


renderInput : Context msg -> Schema -> Bool -> Path -> Html.Html msg
renderInput context property required path =
    let
        inputType =
            case property.format of
                Just "uri" ->
                    "url"

                Just "email" ->
                    "email"

                Just "date" ->
                    "date"

                Just "phone" ->
                    "tel"

                Just "color" ->
                    "color"

                _ ->
                    case property.type_ of
                        "integer" ->
                            "text"

                        "boolean" ->
                            "checkbox"

                        _ ->
                            "text"

        pattern =
            case property.format of
                Just "uuid" ->
                    "[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}"

                Just "date" ->
                    "\\d{4}-[01]\\d-[0-3]\\d"

                _ ->
                    ".*"

        title =
            case property.format of
                Just "uuid" ->
                    "Enter UUID like: xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx where x is any hexadecimal digit and y is one of 8, 9, A, or B"

                Just "date" ->
                    "Date format is YYYY-MM-DD"

                Just "uri" ->
                    "Enter URL"

                _ ->
                    ""

        update s =
            context.onInput <|
                updateValue context
                    path
                    (case property.type_ of
                        "integer" ->
                            s
                                |> replace Regex.All (regex "[^0-9]") (\_ -> "")
                                |> String.toInt
                                |> (\r -> case r of
                                    Ok r ->
                                        Encode.int r
                                    Err x ->
                                        let
                                            a = Debug.log "error" x
                                        in
                                            Encode.null
                                )

                        "boolean" ->
                            JS.getBool context.schema path context.data
                                |> not
                                |> Encode.bool

                        _ ->
                            Encode.string s
                    )

        attributes =
            [ Attrs.required required
              -- , Attrs.name name
            , Attrs.title title
            , Attrs.pattern pattern
            , Attrs.type_ inputType
            , onInput update
            , style
                [ ( "font-family", "iosevka, menlo, monospace" )
                , ( "min-width", "90%" )
                , ( "font-size", "12px" )
                , ( "padding", "3px" )
                ]
            , Attrs.value <|
                if property.type_ == "integer" then
                    JS.getInt context.schema path context.data |> toString
                else if property.type_ == "boolean" then
                    String.join "_" path
                else
                    JS.getString context.schema path context.data
            ]
            ++ (
                if property.type_ == "boolean" then
                    [ Attrs.checked <|
                        JS.getBool context.schema path context.data
                    , onClick <|
                        update ""
                    ]
                else
                    []
            )
    in
        input
            attributes
            []
