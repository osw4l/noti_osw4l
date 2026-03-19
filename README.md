# noti_osw4l

Espacio de trabajo colaborativo en tiempo real, inspirado en Notion. Construido con Elixir, Phoenix LiveView, Ecto y Oban.

## Features

- **Autenticacion** - Registro y login sin verificacion de email
- **Workspaces** - CRUD de espacios de trabajo con roles (owner/admin/member)
- **Notas y Tareas** - Notas con listas de tareas, toggle slide para completar, descripciones inline
- **Chat en tiempo real** - Mensajes de texto dentro de cada workspace via PubSub
- **Voz en tiempo real (WebRTC)** - Llamadas de audio P2P entre miembros del workspace con signaling via LiveView
- **Notificaciones** - Sistema de notificaciones con sonido, badge en campana, dropdown y browser notifications
- **Cursores en tiempo real** - Cursores compartidos estilo Figma con colores por usuario
- **Usuarios online** - Vista de todos los usuarios conectados y en que workspace estan
- **Control de acceso** - Invitar usuarios, solicitar acceso, aceptar/rechazar con notificaciones automaticas
- **Explorar workspaces** - Navegar todos los workspaces y solicitar acceso
- **Activity log** - Registro asincrono de acciones via Oban (quien creo/completo que tarea en que workspace)
- **Dark mode** - Tema oscuro/claro con daisyUI

## Stack

| Tecnologia | Version | Uso |
|---|---|---|
| Elixir | 1.19+ | Lenguaje |
| Phoenix | 1.8 | Framework web |
| Phoenix LiveView | 1.1 | UI en tiempo real |
| Ecto | 3.13 | ORM / migraciones |
| Oban | 2.20 | Jobs en background |
| PostgreSQL | 17 | Base de datos |
| Tailwind CSS | 4.1 | Estilos |
| DBGate | latest | Visualizador de BD |

## Requisitos

- Elixir 1.19+
- Erlang/OTP 28+
- Docker y Docker Compose

## Setup con Docker (recomendado)

```bash
# Levantar todo: app + PostgreSQL + DBGate
docker compose up --build

# O en background
docker compose up --build -d
```

- App: [localhost:4000](http://localhost:4000)
- DBGate: [localhost:9090](http://localhost:9090)

Las migraciones se ejecutan automaticamente al iniciar el contenedor.

## Setup local (desarrollo)

```bash
# Levantar solo BD y DBGate
docker compose up db dbgate -d

# Instalar dependencias y configurar BD
mix setup

# Iniciar servidor
mix phx.server
```

- App: [localhost:4000](http://localhost:4000)
- DBGate: [localhost:9090](http://localhost:9090)
- LiveDashboard: [localhost:4000/dev/dashboard](http://localhost:4000/dev/dashboard)

## Arquitectura

```
lib/
  noti_osw4l/
    accounts/          # Usuarios y autenticacion
      user.ex
    workspaces/        # Espacios de trabajo y memberships
      workspace.ex
      membership.ex
    notes/             # Notas y tareas
      note.ex
      task.ex
    chat/              # Mensajes de chat
      message.ex
    activity/          # Logs de actividad
      log.ex
    notifications/     # Sistema de notificaciones
      notification.ex
    workers/           # Oban workers
      activity_log_worker.ex
  noti_osw4l_web/
    live/              # LiveViews
      register_live.ex
      login_live.ex
      workspace_list_live.ex
      workspace_show_live.ex
      online_users_live.ex
      browse_workspaces_live.ex
      activity_log_live.ex
      notification_bell_component.ex
    presence.ex        # Phoenix Presence
    user_auth.ex       # Plugs de autenticacion
```

### Contextos Ecto

| Contexto | Responsabilidad |
|---|---|
| `Accounts` | Registro, login, busqueda de usuarios |
| `Workspaces` | CRUD workspaces, memberships, acceso |
| `Notes` | CRUD notas y tareas, toggle completion |
| `Chat` | Mensajes de texto por workspace |
| `Activity` | Logs de actividad |
| `Notifications` | Notificaciones con PubSub broadcast |

### Tiempo real

- **PubSub** - Sync de notas/tareas, mensajes de chat y notificaciones entre usuarios
- **Presence** - Tracking de usuarios online, cursores compartidos, participantes de llamada
- **WebRTC** - Audio P2P entre miembros del workspace (signaling via LiveView + PubSub, STUN de Google)
- **Oban** - Logging asincrono de actividad en cola `:activity`
- **Web Audio API** - Sonidos de notificacion (oscillator tones)
- **Browser Notifications** - Notificaciones push del navegador

## Rutas

| Ruta | Descripcion |
|---|---|
| `/register` | Registro de usuario |
| `/login` | Inicio de sesion |
| `/workspaces` | Lista de workspaces propios y compartidos |
| `/workspaces/:id` | Detalle de workspace con notas, tareas, chat |
| `/workspaces/:id/activity` | Log de actividad del workspace |
| `/online` | Usuarios conectados en la plataforma |
| `/browse` | Explorar workspaces y solicitar acceso |

## Variables de entorno (desarrollo)

| Variable | Default | Descripcion |
|---|---|---|
| `DB_USER` | `postgres` | Usuario de PostgreSQL |
| `DB_PASSWORD` | `postgres` | Password de PostgreSQL |
| `DB_HOST` | `localhost` | Host de PostgreSQL |
| `DB_NAME` | `noti_osw4l_dev` | Nombre de la BD |
| `DB_PORT` | `5432` | Puerto de PostgreSQL |
| `PORT` | `4000` | Puerto del servidor Phoenix |
