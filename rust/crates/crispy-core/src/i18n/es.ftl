# CrispyTivi — Mensajes en español

## App
app-name = CrispyTivi
app-tagline = Tu experiencia cinematográfica de IPTV

## Navigation
nav-home = Para ti
nav-live = En vivo
nav-movies = Películas
nav-shows = Series
nav-library = Biblioteca
nav-search = Buscar

## Player controls
player-play = Reproducir
player-pause = Pausar
player-stop = Detener
player-seek-forward = Adelantar
player-seek-backward = Retroceder
player-volume-up = Subir volumen
player-volume-down = Bajar volumen
player-fullscreen = Pantalla completa
player-exit-fullscreen = Salir de pantalla completa
player-now-playing = Reproduciendo ahora

## Settings labels
settings-title = Ajustes
settings-language = Idioma
settings-video-quality = Calidad de video
settings-audio-track = Pista de audio
settings-subtitles = Subtítulos
settings-parental-controls = Control parental
settings-server-mode = Modo servidor
settings-about = Acerca de

## Error messages
error-network = Error de red. Por favor verifica tu conexión.
error-stream-unavailable = Este canal no está disponible en este momento.
error-source-load-failed = No se pudo cargar la fuente. Por favor intenta de nuevo.
error-auth-failed = Error de autenticación. Verifica tus credenciales.
error-timeout = La solicitud expiró. Por favor intenta de nuevo.
error-unknown = Ocurrió un error inesperado.

## Empty states
empty-channels = No se encontraron canales.
empty-vod = No hay contenido disponible.
empty-search = Sin resultados para "{ $query }".
empty-history = Tu historial de reproducción está vacío.
empty-favorites = Aún no tienes favoritos.

## Channels with count (plural)
channel-count = { $count ->
    [one] { $count } canal
   *[other] { $count } canales
}

## EPG / time
epg-now = Ahora
epg-next = Siguiente
epg-no-info = Sin información de programa

## Ratings
rating-label = Clasificación: { $rating }

## Duration
duration-hours-minutes = { $hours } h { $minutes } min
duration-minutes = { $minutes } min

## Sync
sync-in-progress = Sincronizando { $source }…
sync-done = { $source } sincronizado correctamente.
sync-failed = Error de sincronización: { $reason }

## Profile
profile-guest = Invitado
profile-switch = Cambiar perfil
