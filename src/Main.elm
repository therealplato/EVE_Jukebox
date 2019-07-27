port module Main exposing (control, main, progress, update)

import Array exposing (Array)
import Browser
import Core exposing (..)
import Draggable
import Http
import Json.Decode exposing (Decoder, array, field, map2, map3, string)
import Platform.Sub as Sub
import Random exposing (generate)
import Random.Array exposing (shuffle)
import View exposing (..)


port control : String -> Cmd msg


port progress : (Float -> msg) -> Sub msg


subscriptions : Model -> Sub Msg
subscriptions model =
    case model of
        Success { dragState } ->
            Sub.batch
                [ Draggable.subscriptions DragMsg dragState.drag
                , progress Progress
                ]

        Error _ ->
            Sub.none


dragConfig : Draggable.Config String Msg
dragConfig =
    Draggable.basicConfig OnDragBy


init : () -> ( Model, Cmd Msg )
init _ =
    ( Success
        { playlist =
            { index = 0
            , progress = 0
            , shuffledSongs = Nothing
            , name = "Empty"
            , songs = Array.empty
            }
        , volume = 100
        , dragState =
            { position = ( 0, 0 )
            , drag = Draggable.init
            }
        }
    , loadJson "./playlists/EVE_Soundtrack.json"
    )


main =
    Browser.document
        { init = init
        , update = update
        , view = view
        , subscriptions = subscriptions
        }


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model_ =
    case model_ of
        Success ({ playlist, volume, dragState } as model) ->
            case msg of
                Next ->
                    update Play (Success { model | playlist = next model.playlist })

                Previous ->
                    update Play (Success { model | playlist = previous model.playlist })

                Shuffle ->
                    if playlist.shuffledSongs == Nothing then
                        ( Success model, generate Shuffled (shuffle playlist.songs) )

                    else
                        ( Success { model | playlist = { playlist | shuffledSongs = Nothing } }, Cmd.none )

                Shuffled shuffledList ->
                    ( Success
                        { playlist = { playlist | index = 0, shuffledSongs = Just shuffledList }
                        , volume = volume
                        , dragState = dragState
                        }
                    , Cmd.none
                    )

                Load link ->
                    ( Success model, loadJson link )

                Loaded result ->
                    case result of
                        Ok pl ->
                            ( Success { model | playlist = pl }, Cmd.none )

                        Err err ->
                            ( Error <| errorToString err, Cmd.none )

                ChooseSong songIndex ->
                    update Play <| Success { model | playlist = chooseSong model.playlist songIndex }

                ChangeVolume vol ->
                    ( Success { model | volume = vol }
                    , control ("volume " ++ String.fromFloat vol)
                    )

                Play ->
                    ( Success model, control ("play " ++ (currentSong playlist).link) )

                TogglePause ->
                    ( Success model, control "togglePause" )

                OnDragBy ( dx, dy ) ->
                    ( Success
                        { model
                            | dragState =
                                { dragState
                                    | position =
                                        ( round (toFloat (Tuple.first dragState.position) + dx)
                                        , round (toFloat (Tuple.second dragState.position) + dy)
                                        )
                                }
                        }
                    , Cmd.none
                    )

                DragMsg dragMsg ->
                    let
                        ( newDragState, m ) =
                            Draggable.update dragConfig dragMsg model.dragState
                    in
                    ( Success
                        { model
                            | dragState = { position = model.dragState.position, drag = newDragState.drag }
                        }
                    , m
                    )

                Progress val ->
                    ( Success
                        { model | playlist = { playlist | progress = val } }
                    , Cmd.none
                    )

        Error _ ->
            ( model_, Cmd.none )


loadJson : String -> Cmd Msg
loadJson link =
    Http.get
        { url = link
        , expect = Http.expectJson Loaded songDecoder
        }


songDecoder : Decoder Playlist
songDecoder =
    map2 (Playlist 0 0 Nothing)
        (field "name" string)
        (field "songs"
            (array
                (map3 Song
                    (field "name" string)
                    (field "duration" string)
                    (field "link" string)
                )
            )
        )


errorToString : Http.Error -> String
errorToString e =
    case e of
        Http.BadUrl url ->
            "Bad URL: " ++ url

        Http.Timeout ->
            "Request timed out."

        Http.NetworkError ->
            "A Network Error occurred"

        Http.BadStatus status ->
            String.fromInt status ++ " returned"

        Http.BadBody body ->
            "Bad Body: " ++ body
