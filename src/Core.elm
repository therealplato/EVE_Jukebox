module Core exposing (Model(..), Msg(..), Playlist, Song, chooseSong, currentSong, next, playlistDecoder, previous)

import Array exposing (Array)
import Draggable
import Http
import Json.Decode exposing (Decoder, array, field, map2, map3, string)


type alias Song =
    { name : String
    , duration : String
    , link : String
    }


type alias Playlist =
    { index : Int
    , progress : Float
    , shuffledSongs : Maybe (Array Song)
    , name : String
    , songs : Array Song
    }


type alias DragState =
    { position : ( Int, Int )
    , drag : Draggable.State String
    }


type Model
    = Success
        { playlist : Playlist
        , volume : Float
        , dragState : DragState
        }
    | Error String


type Msg
    = Next
    | Previous
    | Shuffle
    | Shuffled (Array Song)
    | Load String
    | Loaded (Result Http.Error Playlist)
    | ChooseSong Int
    | ChangeVolume Float
    | Play
    | TogglePause
    | OnDragBy Draggable.Delta
    | DragMsg (Draggable.Msg String)
    | Progress Float


next : Playlist -> Playlist
next playlist =
    if playlist.index == Array.length playlist.songs - 1 then
        { playlist | index = 0 }

    else
        { playlist | index = playlist.index + 1 }


previous : Playlist -> Playlist
previous playlist =
    if playlist.index == 0 then
        { playlist | index = Array.length playlist.songs - 1 }

    else
        { playlist | index = playlist.index - 1 }


currentSong : Playlist -> Song
currentSong playlist =
    let
        songs =
            if playlist.shuffledSongs == Nothing then
                playlist.songs

            else
                Maybe.withDefault Array.empty playlist.shuffledSongs
    in
    Maybe.withDefault { name = "", link = "", duration = "" } <| Array.get playlist.index songs


chooseSong : Playlist -> Int -> Playlist
chooseSong pl songIndex =
    { pl | index = songIndex }


playlistDecoder : Decoder Playlist
playlistDecoder =
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
