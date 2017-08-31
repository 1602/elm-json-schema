module DataManipulation exposing (all)

import Test exposing (Test, test, describe)
import Expect
import Json.Encode as Encode
import Json.Schema.Helpers as Helpers exposing (setValue)
import Json.Schema.Builder exposing (toSchema, buildSchema, withType, withProperties)


all : Test
all =
    describe "data manipulation"
        [ describe "setValue"
            [ test "simple string value" <|
                \() ->
                    buildSchema
                        |> withType "string"
                        |> toSchema
                        |> Result.andThen (setValue Encode.null "#/" (Encode.string "test"))
                        |> Expect.equal (Ok <| Encode.string "test")
            , test "string property in object" <|
                \() ->
                    buildSchema
                        |> withProperties
                            [ ( "foo", buildSchema |> withType "string" )
                            ]
                        |> toSchema
                        |> Result.andThen (setValue Encode.null "#/foo" (Encode.string "bar"))
                        |> Result.map (Encode.encode 0)
                        |> Expect.equal (Ok """{"foo":"bar"}""")
            , test "string property in nested object" <|
                \() ->
                    buildSchema
                        |> withProperties
                            [ ( "foo"
                              , buildSchema
                                    |> withProperties [ ( "bar", buildSchema |> withType "string" ) ]
                              )
                            ]
                        |> toSchema
                        |> Result.andThen (setValue Encode.null "#/foo/bar" (Encode.string "baz"))
                        |> Result.map (Encode.encode 0)
                        |> Expect.equal (Ok """{"foo":{"bar":"baz"}}""")
            , test "string property in deeply nested object" <|
                \() ->
                    buildSchema
                        |> withProperties
                            [ ( "foo"
                              , buildSchema
                                    |> withProperties
                                        [ ( "bar"
                                          , buildSchema
                                                |> withProperties [ ( "baz", buildSchema |> withType "string" ) ]
                                          )
                                        , ( "tar"
                                          , buildSchema |> withType "string"
                                          )
                                        ]
                              )
                            , ( "goo"
                              , buildSchema |> withType "string"
                              )
                            ]
                        |> toSchema
                        |> Result.andThen
                            (setValue
                                (Encode.object
                                    [ ( "goo", Encode.string "doo" )
                                    , ( "foo"
                                      , Encode.object
                                            [ ( "tar"
                                              , Encode.string "har"
                                              )
                                            , ( "bar"
                                              , Encode.object [ ( "zim", Encode.string "zam" ) ]
                                              )
                                            ]
                                      )
                                    ]
                                )
                                "#/foo/bar/baz"
                                (Encode.string "fiz")
                            )
                        |> Result.map (Encode.encode 0)
                        |> Expect.equal (Ok """{"foo":{"bar":{"baz":"fiz","zim":"zam"},"tar":"har"},"goo":"doo"}""")
            ]
        ]
