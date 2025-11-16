# MediaHub System Documentation

## Table of Contents

1. [System Overview](#system-overview)
2. [Architecture](#architecture)
3. [Core Models](#core-models)
4. [Key Features](#key-features)
5. [Data Flow](#data-flow)
6. [Background Processing](#background-processing)
7. [API Endpoints](#api-endpoints)
8. [Configuration](#configuration)
9. [Deployment](#deployment)

---

## System Overview

**MediaHub** is a Rails 7.1 application designed to record, transcribe, and analyze video content from live TV station streams. The system automatically processes video segments, extracts transcriptions, tags content, and provides analytics dashboards for users to track topics of interest.

### Key Capabilities

- **Stream Recording**: Continuously records 60-second video segments from multiple TV stations
- **Transcription**: Processes videos through Whisper to generate Spanish transcriptions
- **Automated Tagging**: Extracts relevant tags from transcriptions using pattern matching
- **Topic Tracking**: Allows users to subscribe to topics and track video statistics
- **Analytics**: Provides daily statistics and word frequency analysis

---

## Architecture

### Technology Stack

| Component       | Technology                 |
| --------------- | -------------------------- |
| Framework       | Rails 7.1.3+               |
| Ruby Version    | 3.3.0                      |
| Database (Dev)  | SQLite3                    |
| Database (Prod) | MySQL2                     |
| Frontend CSS    | Tailwind CSS 2.3.0         |
| JavaScript      | Stimulus + Turbo (Hotwire) |
| Admin Panel     | ActiveAdmin 3.2            |
| Authentication  | Devise 4.9                 |
| Tagging         | acts-as-taggable-on 10.0   |
| Versioning      | PaperTrail 15.1            |
| Cron Scheduler  | Whenever 1.0               |
| Charts          | Chartkick + Groupdate      |

### Directory Structure

```
mediahub/
├── app/
│   ├── admin/          # ActiveAdmin configurations
│   ├── controllers/    # MVC controllers
│   ├── models/         # ActiveRecord models
│   ├── services/       # Service objects (TaggerServices)
│   ├── views/          # ERB templates
│   └── assets/         # CSS/JS assets
├── lib/tasks/          # Rake tasks for background processing
│   └── stream/         # Stream recording tasks
├── config/
│   ├── routes.rb       # Application routes
│   ├── schedule.rb     # Cron job definitions
│   └── initializers/   # Configuration initializers
└── public/videos/      # Video storage (organized by station/date)
```

---

## Core Models

### Station

Represents a TV station with streaming capabilities.

**Attributes:**

- `name` (string): Station name
- `directory` (string): Directory name for file organization
- `stream_url` (text): HLS/M3U8 stream URL
- `stream_status` (enum): `disconnected` (0) or `connected` (1)
- `stream_source` (text): Source URL for stream URL updates
- `active` (boolean): Whether station is active

**Relationships:**

- `has_many :videos`
- `has_one_attached :logo`

**Key Methods:**

- `active` scope: Returns only active stations

### Video

Represents a recorded 60-second video segment.

**Attributes:**

- `location` (string): Filename (format: `YYYY-MM-DDTHH_MM_SS.mp4`)
- `posted_at` (datetime): Recording timestamp
- `path` (string): Full file system path
- `public_path` (string): Relative path from public directory
- `thumbnail_path` (string): Path to thumbnail image
- `transcription` (text): Spanish transcription text
- `station_id` (integer): Foreign key to Station

**Relationships:**

- `belongs_to :station`
- `acts_as_taggable_on :tags`

**Key Scopes:**

- `no_transcription`: Videos without transcriptions
- `has_transcription`: Videos with transcriptions
- `no_thumbnail`: Videos without thumbnails
- `normal_range`: Videos from last 7 days (uses `DAYS_RANGE`)

**Key Methods:**

- `generate_thumbnail`: Creates thumbnail using FFmpeg
- `all_tags`: Returns tag names including variations
- `all_tags_boundarys`: Returns regex patterns for tag matching
- `word_occurrences`: Analyzes word frequency in transcriptions
- `bigram_occurrences`: Analyzes bigram frequency

**File Organization:**
Videos are stored in: `public/videos/{station.directory}/{year}/{month}/{day}/{filename}`

### Tag

Represents a keyword extracted from video transcriptions.

**Attributes:**

- `name` (string): Tag name (unique)
- `variations` (string): Comma-separated alternative forms
- `taggings_count` (integer): Counter cache

**Relationships:**

- `has_and_belongs_to_many :topics`
- `has_many :taggings`

**Key Methods:**

- `list_videos`: Returns videos tagged with this tag (last 7 days)

### Topic

Represents a subject of interest that users can track.

**Attributes:**

- `name` (string): Topic name
- `status` (boolean): Active/inactive status

**Relationships:**

- `has_many :topic_stat_dailies`
- `has_many :user_topics`
- `has_many :users, through: :user_topics`
- `has_and_belongs_to_many :tags`

**Key Methods:**

- `list_videos`: Returns videos matching topic's tags (last 7 days)

**Versioning:**
Uses PaperTrail to track create, update, and destroy events.

### User

Represents an end user who subscribes to topics.

**Attributes:**

- `name` (string): User name
- `email` (string): Email (unique, required)
- `encrypted_password` (string): Devise password
- `status` (boolean): Active/inactive status

**Relationships:**

- `has_many :user_topics`
- `has_many :topics, through: :user_topics`

**Authentication:**
Uses Devise with modules: `database_authenticatable`, `recoverable`, `rememberable`, `validatable`

### TopicStatDaily

Daily statistics for topics.

**Attributes:**

- `topic_id` (integer): Foreign key to Topic
- `topic_date` (date): Date of statistics
- `video_quantity` (integer): Number of videos for this topic/date

**Relationships:**

- `belongs_to :topic`

**Key Scopes:**

- `normal_range`: Statistics from last 7 days

---

## Key Features

### 1. Stream Recording

- Continuously records 60-second segments from multiple TV stations
- Uses FFmpeg to segment HLS/M3U8 streams
- Saves files to temp directories with timestamped filenames
- Tracks connection status for each station
- Automatically retries on disconnection with exponential backoff
- **New Architecture**: Process-per-station with systemd management

**Architecture:**

The system uses a **process-per-station** architecture managed by systemd:

1. **Individual Workers** (`stream:listen_station[ID]`): One rake task per station
   - Handles a single stream connection
   - Real-time stderr monitoring for disconnection detection
   - File-based heartbeat tracking
   - Exponential backoff retry logic (5s, 10s, 20s, max 60s)
   - Graceful signal handling

2. **Orchestrator** (`stream:orchestrator`): Monitors and manages all stations
   - Checks station health every 60 seconds (configurable)
   - Detects disconnected or stale stations
   - Manages systemd services (start/stop/restart)
   - Multi-level disconnection detection:
     - Real-time FFmpeg stderr parsing
     - Heartbeat monitoring (last file generation)
     - Process status verification

3. **systemd Services**: One service per station
   - Automatic restart on failure (`Restart=always`, `RestartSec=5`)
   - Resource limits (512MB memory, 50% CPU)
   - Centralized logging via journald
   - Service management via rake tasks

**Disconnection Detection Methods:**

1. **Real-time stderr monitoring** (Primary - fastest)
   - Uses `Open3.popen3` to read FFmpeg stderr in real-time
   - Parses error messages: "Connection refused", "HTTP error", "Network is unreachable"
   - Detects disconnections within seconds

2. **File-based heartbeat** (Secondary - redundancy)
   - Updates `last_heartbeat_at` when new segments are generated
   - If no new file in 3 minutes, considered disconnected
   - Orchestrator verifies this periodically

3. **Process monitoring** (Tertiary - verification)
   - Verifies systemd service status
   - Checks process health

**Implementation:**

- Rake tasks:
  - `stream:listen_station[ID]`: Individual station listener
  - `stream:orchestrator`: Monitoring and management
  - `stream:systemd:*`: Service management commands
- Updates `stream_status` enum and `last_heartbeat_at` timestamp
- FFmpeg flags: `-timeout`, `-reconnect`, `-reconnect_at_eof` for better connection handling

### 2. Video Import

- Scans temp directories for new video files
- Validates filename format and video integrity
- Moves videos to organized date-based folders
- Generates thumbnails automatically
- Creates Video records in database

**Implementation:**

- Rake task: `import_videos`
- Validates files with `ffprobe`
- Checks if files are in use before processing
- Uses `find_or_create_by` to avoid duplicates

### 3. Transcription Processing

- Automated process using Whisper-ctranslate2
- Processes videos in parallel (4 processes)
- Uses CUDA acceleration for GPU processing
- Model: `medium` (configurable)
- Language: Spanish
- Format: Plain text (TXT)
- Stores transcriptions in `Video.transcription` field
- Automatically cleans up temporary files

**Implementation:**

- Rake task: `generate_transcription`
- Called by `process_videos` wrapper task
- Uses `parallel` gem for concurrent processing
- Command: `whisper-ctranslate2 --model medium --language Spanish --output_format txt --device cuda --compute_type float16`

### 4. Automated Tagging

- Extracts tags from transcriptions using pattern matching
- Matches tag names and variations against transcription text
- Uses word boundaries (`\b`) for accurate matching
- Tags videos with multiple tags

**Implementation:**

- Service: `TaggerServices::ExtractTags`
- Rake task: `tagger` (runs every 5 minutes)
- Processes videos from last 3 months
- Updates `tag_list` using acts-as-taggable-on

### 5. Topic Statistics

- Calculates daily video counts per topic
- Aggregates statistics for last 7 days
- Updates `TopicStatDaily` records

**Implementation:**

- Rake task: `topic_stat_daily` (runs hourly)
- Uses `Video.tagged_on_video_quantity` method
- Creates/updates daily records

### 6. User Dashboard

- Displays recent videos with transcriptions
- Shows topic statistics with charts (Chartkick)
- Word frequency analysis (word cloud)
- Topic-based video filtering

**Implementation:**

- Controller: `HomeController#index`
- View: `app/views/home/index.html.erb`
- Uses `current_user.topics` to filter content

---

## Data Flow

### Video Processing Pipeline

```
1. Stream Recording
   └─> FFmpeg records segments (60-second chunks)
       └─> Saves to: public/videos/{station}/temp/{timestamp}.mp4

2. Video Import (process_videos → import_videos)
   └─> Scans temp directories for new files
       └─> Validates filename format and video integrity
           └─> Moves to: public/videos/{station}/{year}/{month}/{day}/
               └─> Creates Video records
                   └─> Generates thumbnails

3. Transcription (process_videos → generate_transcription)
   └─> Processes videos without transcriptions (parallel, 4 processes)
       └─> Whisper-ctranslate2 generates Spanish transcriptions
           └─> Updates Video.transcription
               └─> Cleans up temporary files

4. Cleanup (process_videos → remove_fail_videos)
   └─> Removes videos older than 12 hours without transcriptions
       └─> Removes videos with invalid paths/locations

5. Tagging (separate cron: every 5 minutes)
   └─> TaggerServices extracts tags from transcriptions
       └─> Matches against Tag records (with variations)
           └─> Updates Video.tag_list

6. Statistics (separate cron: hourly)
   └─> Calculates daily video counts per topic
       └─> Updates TopicStatDaily records
```

### Tag Extraction Flow

```
1. Load all Tags (or specific tag)
2. For each Video transcription:
   a. Match tag.name with word boundaries
   b. Match tag.variations (comma-separated) with word boundaries
   c. Collect matching tags
3. Update Video.tag_list with found tags
```

---

## Background Processing

### Cron Schedule (`config/schedule.rb`)

| Frequency       | Task               | Description                       |
| --------------- | ------------------ | --------------------------------- |
| Every 1 minute  | `process_videos`   | Processes new videos              |
| Every 5 minutes | `tagger`           | Extracts tags from transcriptions |
| Every hour      | `topic_stat_daily` | Updates daily topic statistics    |

### Rake Tasks

#### `process_videos` (Wrapper Task)

- Orchestrates the video processing pipeline
- Uses lock file to prevent concurrent execution
- Runs sequentially:
  1. `import_videos`
  2. `generate_transcription`
  3. `remove_fail_videos`
- Executes every 1 minute via cron
- Handles errors gracefully, continues with next task

#### `import_videos`

- Scans temp directories for new video files
- Validates filename format: `YYYY-MM-DDTHH_MM_SS.mp4`
- Validates video integrity with `ffprobe`
- Checks if files are in use before processing
- Moves files to organized date folders
- Generates thumbnails automatically

#### `generate_transcription`

- Processes videos without transcriptions
- Uses `whisper-ctranslate2` with CUDA acceleration
- Processes in parallel (4 processes) using `parallel` gem
- Model: `medium` (configurable)
- Language: Spanish
- Output format: TXT
- Saves transcription to `Video.transcription`
- Cleans up temporary transcription files

#### `remove_fail_videos`

- Cleans up failed video records
- Removes videos older than 12 hours without transcriptions
- Removes videos with invalid/missing paths or locations
- Removes videos with non-.mp4 extensions
- Uses `find_each` for batch processing

#### `tagger`

- Processes videos from last 3 months
- Uses `TaggerServices::ExtractTags` to find tags
- Updates `Video.tag_list`
- Logs results

#### `topic_stat_daily`

- Calculates video counts per topic for last 7 days
- Creates/updates `TopicStatDaily` records
- Processes all active topics

#### `stream:listen_station[ID]`

- **New**: Individual station listener (process-per-station architecture)
- Handles a single stream connection
- Real-time disconnection detection via stderr monitoring
- File-based heartbeat tracking
- Exponential backoff retry logic
- Updates `stream_status` and `last_heartbeat_at`

#### `stream:orchestrator`

- **New**: Monitors and manages all station services
- Checks station health every 60 seconds (configurable via `ORCHESTRATOR_INTERVAL`)
- Detects disconnected or stale stations
- Manages systemd services automatically
- Should run as a systemd service or via cron

#### `stream:systemd:*`

- **New**: Service management commands
- `stream:systemd:generate[ID]`: Generate service file content
- `stream:systemd:install[ID]`: Install service (requires sudo)
- `stream:systemd:uninstall[ID]`: Uninstall service (requires sudo)
- `stream:systemd:start[ID]`: Start service
- `stream:systemd:stop[ID]`: Stop service
- `stream:systemd:restart[ID]`: Restart service
- `stream:systemd:install_all`: Install services for all active stations
- `stream:systemd:start_all`: Start all services
- `stream:systemd:stop_all`: Stop all services
- `stream:systemd:status_all`: Show status of all services

#### `stream:listen` (Legacy)

- **Deprecated**: Old multi-threaded approach
- Continuously records streams for all active stations
- Uses FFmpeg to segment streams (60-second chunks)
- Runs in separate threads per station
- Consider migrating to new architecture

#### `stream:update_stream_url`

- Updates stream URLs for stations with `stream_source`
- Used when streams expire or change

---

## API Endpoints

### Public Routes

| Method | Path                 | Controller#Action   | Description                    |
| ------ | -------------------- | ------------------- | ------------------------------ |
| GET    | `/`                  | `home#index`        | User dashboard (requires auth) |
| GET    | `/topics/:id`        | `topics#show`       | Topic detail page              |
| GET    | `/tags/:id`          | `tags#show`         | Tag detail page                |
| GET    | `/videos/:id`        | `videos#show`       | Video detail page              |
| GET    | `/stations/:id`      | `stations#show`     | Station detail page            |
| POST   | `/home/merge_videos` | `home#merge_videos` | Merge selected videos          |
| POST   | `/deploy`            | `home#deploy`       | Deployment webhook (no CSRF)   |

### Authentication Routes

- Devise routes for `/users` (sign in, sign out, password reset)
- ActiveAdmin routes at `/admin` (admin authentication)

---

## Configuration

### Constants (`config/initializers/custom_vars.rb`)

```ruby
DAYS_RANGE = 7  # Default time range for queries (days)
STOP_WORDS = [...]  # Loaded from stop-words.txt
```

### Environment Variables

- Database configuration: `config/database.yml`
- Credentials: `config/credentials.yml.enc` (encrypted)

### ActiveAdmin

- Configuration: `config/initializers/active_admin.rb`
- Resources: `app/admin/*.rb`
- Customizes admin interface for all models

### PaperTrail

- Tracks changes to Topic model
- Stores version history in `versions` table
- Sets `whodunnit` from current admin user

---

## Deployment

### Production Environment

- **Database**: MySQL2
- **Web Server**: Puma (daemon mode)
- **Reverse Proxy**: Apache2
- **SSL**: Let's Encrypt (Certbot)
- **Cron**: Whenever gem

### Deployment Process

1. **Webhook Deployment** (`/deploy` endpoint):

   ```ruby
   - git pull
   - bundle install
   - rails db:migrate
   - rake assets:precompile
   - touch tmp/restart.txt
   ```

2. **Manual Deployment**:
   ```bash
   git pull
   bundle install
   RAILS_ENV=production rails db:migrate
   RAILS_ENV=production rake assets:precompile
   touch tmp/restart.txt
   ```

### Apache Configuration

- Reverse proxy to Puma
- SSL enabled
- Rewrite rules for Rails
- Headers and expires modules enabled

### Background Services

- Stream recording: `nohup rake stream:listen > log/listen.log 2>&1 &`
- Puma server: `nohup puma &> output.log &`
- Cron jobs: Managed by Whenever gem

### File Storage

- Videos: `public/videos/{station}/{year}/{month}/{day}/`
- Temp files: `public/videos/{station}/temp/`
- Thumbnails: Same directory as videos (`.png` extension)

---

## Development Setup

### Prerequisites

- Ruby 3.3.0 (RVM recommended)
- SQLite3 (development)
- FFmpeg (for video processing)
- Whisper/Whisper-ctranslate2 (for transcription)

### Initial Setup

```bash
bundle install
rails db:create db:migrate
rails db:seed  # If seeds exist
```

### Running Locally

```bash
bin/dev  # Starts Rails server and Tailwind CSS watcher
```

### Common Development Tasks

```bash
# Import videos
rails import_videos

# Tag videos
rails tagger

# Start stream recording
rails stream:listen

# Generate topic stats
rails topic_stat_daily
```

---

## Stream Architecture Deployment

### Development Mode (macOS/Local)

En desarrollo local (macOS no tiene systemd), el sistema detecta automáticamente el entorno y usa gestión de procesos en lugar de systemd.

**Comandos disponibles:**

```bash
# Iniciar listener para una estación
rake stream:dev:start[STATION_ID]

# Detener listener para una estación
rake stream:dev:stop[STATION_ID]

# Reiniciar listener para una estación
rake stream:dev:restart[STATION_ID]

# Iniciar todos los listeners activos
rake stream:dev:start_all

# Detener todos los listeners
rake stream:dev:stop_all

# Ver estado de todos los listeners
rake stream:dev:status

# Iniciar orquestador en modo desarrollo
rake stream:dev:orchestrator
```

**Archivos generados:**
- PIDs: `tmp/pids/stream/stream-station-*.pid`
- Logs: `log/stream-station-*.log`

**El orquestador principal también funciona en desarrollo:**
```bash
# Detecta automáticamente que está en desarrollo y usa procesos en lugar de systemd
rake stream:orchestrator
```

### Production Mode (Linux with systemd)

### Initial Setup

1. **Run database migration**:
   ```bash
   rails db:migrate
   ```

2. **Install systemd services for all active stations**:
   ```bash
   sudo rake stream:systemd:install_all
   ```

3. **Start all services**:
   ```bash
   rake stream:systemd:start_all
   ```

4. **Set up orchestrator** (choose one):

   **Option A: systemd service** (recommended):
   ```bash
   # Create orchestrator service file
   sudo tee /etc/systemd/system/mediahub-orchestrator.service > /dev/null <<EOF
   [Unit]
   Description=MediaHub Stream Orchestrator
   After=network.target

   [Service]
   Type=simple
   User=www-data
   WorkingDirectory=/path/to/mediahub
   Environment="RAILS_ENV=production"
   Environment="ORCHESTRATOR_INTERVAL=60"
   ExecStart=/usr/bin/env bundle exec rake stream:orchestrator
   Restart=always
   RestartSec=10
   StandardOutput=journal
   StandardError=journal

   [Install]
   WantedBy=multi-user.target
   EOF

   sudo systemctl daemon-reload
   sudo systemctl enable mediahub-orchestrator
   sudo systemctl start mediahub-orchestrator
   ```

   **Option B: Cron job**:
   ```ruby
   # Add to config/schedule.rb
   every 1.minute do
     rake 'stream:orchestrator'
   end
   ```

### Managing Individual Stations

**Install service for a station**:
```bash
sudo rake stream:systemd:install[STATION_ID]
```

**Start/Stop/Restart a station**:
```bash
rake stream:systemd:start[STATION_ID]
rake stream:systemd:stop[STATION_ID]
rake stream:systemd:restart[STATION_ID]
```

**Check status of all stations**:
```bash
rake stream:systemd:status_all
```

**View logs for a station**:
```bash
sudo journalctl -u mediahub-stream-STATION_ID -f
```

**View orchestrator logs**:
```bash
sudo journalctl -u mediahub-orchestrator -f
```

### Troubleshooting

**Station not connecting**:
1. Check service status: `systemctl status mediahub-stream-STATION_ID`
2. Check logs: `journalctl -u mediahub-stream-STATION_ID -n 50`
3. Verify station is active: `Station.find(ID).active?`
4. Check stream URL: `Station.find(ID).stream_url`
5. Test FFmpeg manually: `ffmpeg -i "STREAM_URL" -t 10 test.mp4`

**Stale heartbeat**:
- Station shows as connected but `last_heartbeat_at` is old
- Check if FFmpeg is generating files: `ls -lt public/videos/STATION/temp/ | head`
- Restart service: `rake stream:systemd:restart[STATION_ID]`

**Orchestrator not managing stations**:
1. Check orchestrator is running: `systemctl status mediahub-orchestrator`
2. Check orchestrator logs: `journalctl -u mediahub-orchestrator -n 50`
3. Verify it has permissions to manage systemd services
4. Check `ORCHESTRATOR_INTERVAL` environment variable

**Service keeps restarting**:
- Check resource limits (memory/CPU)
- Review FFmpeg command and stream URL
- Check for network issues
- Review logs for specific error messages

**Migration from old architecture**:
1. Stop old `stream:listen` process
2. Install new services: `sudo rake stream:systemd:install_all`
3. Start services: `rake stream:systemd:start_all`
4. Start orchestrator
5. Monitor for issues and adjust as needed

### Environment Variables

- `ORCHESTRATOR_INTERVAL`: Check interval in seconds (default: 60)
- `SERVICE_PREFIX`: Prefix for systemd service names (default: `mediahub-stream`)
- `SERVICE_USER`: User to run services as (default: `www-data` or current user)

---

## Known Issues & Considerations

1. **File Processing**: Videos must be validated before import to avoid corrupted files
2. **Stream Stability**: Stream URLs may expire; system handles reconnection
3. **Memory Usage**: Large batch operations use `find_each` to prevent memory issues
4. **Transcription**: External process; not integrated into Rails app
5. **Tag Matching**: Uses word boundaries; may miss tags in compound words
6. **Stop Words**: Loaded from `stop-words.txt`; used for text analysis filtering
7. **Process Isolation**: New architecture uses separate processes per station for better isolation and fault tolerance
8. **systemd Dependency**: New architecture requires systemd; not suitable for non-systemd systems

---

## Future Enhancements

Potential improvements:

- Migrate to ActiveJob for background processing
- Add video search functionality
- Implement real-time notifications for topics
- Add API endpoints for external integrations
- Improve tag extraction with ML/NLP
- Add video playback controls
- Implement user preferences and filters

---

## Maintenance Notes

### Regular Tasks

- Monitor stream connections
- Check disk space for video storage
- Review and update tags/variations
- Clean up old videos (if retention policy exists)
- Monitor transcription processing queue

### Troubleshooting

- Check `log/listen.log` for stream recording issues
- Check `log/whenever.log` for cron job execution
- Verify FFmpeg installation for video processing
- Check database indexes for performance issues

---

_Last Updated: Initial Documentation_
_Rails Version: 7.1.3+_
_Ruby Version: 3.3.0_
