# CrispyTivi — English messages

## App
app-name = CrispyTivi
app-tagline = Your cinematic IPTV experience

## Navigation
nav-home = For You
nav-live = Live
nav-movies = Movies
nav-shows = Shows
nav-library = Library
nav-search = Search

## Player controls
player-play = Play
player-pause = Pause
player-stop = Stop
player-seek-forward = Skip forward
player-seek-backward = Skip backward
player-volume-up = Volume up
player-volume-down = Volume down
player-fullscreen = Fullscreen
player-exit-fullscreen = Exit fullscreen
player-now-playing = Now Playing

## Settings labels
settings-title = Settings
settings-language = Language
settings-video-quality = Video Quality
settings-audio-track = Audio Track
settings-subtitles = Subtitles
settings-parental-controls = Parental Controls
settings-server-mode = Server Mode
settings-about = About

## Error messages
error-network = Network error. Please check your connection.
error-stream-unavailable = This stream is currently unavailable.
error-source-load-failed = Failed to load source. Please try again.
error-auth-failed = Authentication failed. Check your credentials.
error-timeout = Request timed out. Please try again.
error-unknown = An unexpected error occurred.

## Empty states
empty-channels = No channels found.
empty-vod = No content available.
empty-search = No results for "{ $query }".
empty-history = Your watch history is empty.
empty-favorites = No favorites added yet.

## Channels with count (plural)
channel-count = { $count ->
    [one] { $count } channel
   *[other] { $count } channels
}

## EPG / time
epg-now = Now
epg-next = Next
epg-no-info = No programme info

## Ratings
rating-label = Rating: { $rating }

## Duration
duration-hours-minutes = { $hours }h { $minutes }m
duration-minutes = { $minutes }m

## Sync
sync-in-progress = Syncing { $source }…
sync-done = { $source } synced successfully.
sync-failed = Sync failed: { $reason }

## Profile
profile-guest = Guest
profile-switch = Switch Profile
