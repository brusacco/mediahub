# Mitmproxy Integration for Stream URL Capture

## Overview

MediaHub uses **mitmproxy** to capture `.m3u8` stream URLs from TV station websites. This approach is more reliable than Chrome DevTools Protocol (CDP) because it intercepts **all** HTTP/HTTPS traffic, regardless of:
- Iframes
- JavaScript-generated requests
- Media Source Extensions (MSE)
- HLS.js players
- Streann players
- Cross-domain requests

## Architecture

```
┌─────────────┐         ┌──────────────┐         ┌─────────────┐
│   Chrome    │────────▶│   mitmproxy  │────────▶│   Website   │
│  (Selenium)  │◀────────│  (127.0.0.1 │◀────────│  (Stream)   │
│             │         │   :8080)     │         │             │
└─────────────┘         └──────────────┘         └─────────────┘
                              │
                              ▼
                        ┌──────────────┐
                        │ capture_m3u8 │
                        │    .py       │
                        └──────────────┘
                              │
                              ▼
                        ┌──────────────┐
                        │ /tmp/        │
                        │ mitm_m3u8.log│
                        └──────────────┘
                              │
                              ▼
                        ┌──────────────┐
                        │ StreamUrl    │
                        │ UpdateService│
                        └──────────────┘
```

## Components

### 1. Mitmproxy Script (`capture_m3u8.py`)

**Location**: `/capture_m3u8.py`

**Purpose**: Intercepts all HTTP/HTTPS requests and logs any URL containing `.m3u8` to `/tmp/mitm_m3u8.log`.

**Code**:
```python
from mitmproxy import http

def response(flow: http.HTTPFlow):
    url = flow.request.pretty_url

    if ".m3u8" in url:
        with open("/tmp/mitm_m3u8.log", "a") as f:
            f.write(url + "\n")
```

**How it works**:
- `response()` is called for every HTTP/HTTPS request
- Checks if the URL contains `.m3u8`
- Appends the URL to `/tmp/mitm_m3u8.log` (one URL per line)

### 2. StreamUrlUpdateService

**Location**: `app/services/stream_url_update_service.rb`

**Key Methods**:

#### `create_driver`
- Configures Chrome to use mitmproxy as HTTP/HTTPS proxy
- Sets `--proxy-server=http://127.0.0.1:8080`
- Adds SSL certificate ignore flags (mitmproxy uses its own certificate)

#### `clear_mitmproxy_log`
- Clears `/tmp/mitm_m3u8.log` before each execution
- Ensures we only capture URLs from the current run

#### `read_mitmproxy_log`
- Reads all URLs from `/tmp/mitm_m3u8.log`
- Returns an array of unique URLs
- Logs found URLs for debugging

#### `select_best_url`
- Filters URLs by reference pattern (if available)
- Prioritizes URLs with authentication parameters (`k=`, `exp=`, `auth=`)
- Prefers `playlist.m3u8` over `chunklist.m3u8`
- Selects the longest/most complete URL as fallback

## Setup & Installation

### 1. Install mitmproxy

```bash
# macOS
brew install mitmproxy

# Linux (Ubuntu/Debian)
sudo apt-get install mitmproxy

# Python (alternative)
pip install mitmproxy
```

### 2. Start mitmproxy

```bash
# From project root
mitmproxy --listen-port 8080 --mode regular -s capture_m3u8.py
```

**Options**:
- `--listen-port 8080`: Port for proxy (must match `MITMPROXY_HOST` in service)
- `--mode regular`: Standard HTTP proxy mode
- `-s capture_m3u8.py`: Script to execute for each request

### 3. Verify mitmproxy is running

```bash
# Check if port 8080 is listening
lsof -i :8080

# Or check mitmproxy process
ps aux | grep mitmproxy
```

## Usage

### Manual Execution

```bash
# Update stream URL for a station
bundle exec rake 'stream:update_stream_url[STATION_ID]'

# Example: Update station ID=5
bundle exec rake 'stream:update_stream_url[5]'
```

### Service Flow

1. **Clear log**: `clear_mitmproxy_log` empties `/tmp/mitm_m3u8.log`
2. **Create driver**: Chrome configured with mitmproxy proxy
3. **Navigate**: Selenium navigates to `station.stream_source`
4. **Wait for page load**: Ensures page is fully loaded
5. **Click play button** (optional): If `play_button_selector` is configured, clicks the play button
6. **Auto-play fallback**: Attempts to mute and play videos automatically
7. **Wait**: Service waits 15 seconds for URLs to be captured
8. **Read log**: `read_mitmproxy_log` reads all captured URLs
9. **Select best**: `select_best_url` chooses the optimal URL
10. **Update**: Station's `stream_url` is updated in database

## Configuration

### Constants in `StreamUrlUpdateService`

```ruby
MITMPROXY_LOG_PATH = '/tmp/mitm_m3u8.log'.freeze
MITMPROXY_HOST = '127.0.0.1:8080'.freeze
```

### Station Configuration

**Play Button Selector** (`play_button_selector`):
- Optional CSS selector for play button element
- Some players require explicit click to start streaming
- Examples:
  - `"button.play"` - Button with class "play"
  - `"#play-button"` - Element with ID "play-button"
  - `".media-play-button"` - Element with class "media-play-button"
- If not configured, service attempts auto-play via JavaScript

### Chrome Options

The service configures Chrome with:
- `--proxy-server=http://127.0.0.1:8080`: Routes traffic through mitmproxy
- `--ignore-certificate-errors`: Accepts mitmproxy's SSL certificate
- `--ignore-ssl-errors=yes`: Allows SSL errors (mitmproxy certificate)
- `--disable-web-security`: Disables CORS (may be needed for some sites)

## Troubleshooting

### No URLs captured

**Symptoms**: `read_mitmproxy_log` returns empty array

**Solutions**:
1. Verify mitmproxy is running: `lsof -i :8080`
2. Check log file exists: `ls -la /tmp/mitm_m3u8.log`
3. Check log permissions: `chmod 666 /tmp/mitm_m3u8.log`
4. Verify script is loaded: Check mitmproxy console for errors
5. Increase wait time: Modify `15.times` loop in `call` method

### SSL Certificate Errors

**Symptoms**: Chrome blocks requests, "NET::ERR_CERT_AUTHORITY_INVALID"

**Solutions**:
1. Ensure `--ignore-certificate-errors` is set
2. Ensure `--ignore-ssl-errors=yes` is set
3. Install mitmproxy certificate (optional):
   ```bash
   # macOS
   open ~/.mitmproxy/mitmproxy-ca-cert.pem
   # Then install in Keychain
   ```

### Multiple URLs captured

**Symptoms**: Multiple `.m3u8` URLs found, unsure which to use

**Solution**: `select_best_url` automatically prioritizes:
1. URLs matching reference pattern (if `stream_url` exists)
2. URLs with authentication (`k=`, `exp=`, `auth=`)
3. `playlist.m3u8` over `chunklist.m3u8`
4. Longest/most complete URL

## Advantages Over CDP

| Feature | CDP (Chrome DevTools) | Mitmproxy |
|---------|----------------------|-----------|
| **Compatibility** | Requires specific Selenium version | Works with any version |
| **Iframe Support** | Complex, requires session management | Automatic |
| **JavaScript Requests** | May miss fetch/XHR | Captures all |
| **Cross-domain** | Limited | Full support |
| **Setup Complexity** | High (CDP setup, listeners) | Low (just proxy) |
| **Reliability** | Version-dependent | Stable |

## Production Considerations

### Running mitmproxy as a Service

**systemd service** (`/etc/systemd/system/mitmproxy.service`):

```ini
[Unit]
Description=Mitmproxy for MediaHub stream capture
After=network.target

[Service]
Type=simple
User=mediahub
WorkingDirectory=/path/to/mediahub
ExecStart=/usr/local/bin/mitmproxy --listen-port 8080 --mode regular -s /path/to/mediahub/capture_m3u8.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

**Enable and start**:
```bash
sudo systemctl enable mitmproxy
sudo systemctl start mitmproxy
sudo systemctl status mitmproxy
```

### Log Rotation

The log file `/tmp/mitm_m3u8.log` is cleared before each execution, but for production you may want to:

1. Use a dedicated log directory: `/var/log/mediahub/mitm_m3u8.log`
2. Implement log rotation: Use `logrotate` or similar
3. Monitor log size: Alert if log grows unexpectedly

### Security

- **Localhost only**: mitmproxy listens on `127.0.0.1:8080` (localhost only)
- **No external access**: Firewall should block port 8080 from external access
- **Certificate handling**: Chrome ignores certificate errors (acceptable for local proxy)

## Related Files

- **Service**: `app/services/stream_url_update_service.rb`
- **Script**: `capture_m3u8.py`
- **Rake Task**: `lib/tasks/stream/update_stream_url.rake`
- **Documentation**: This file (`Documents/MITMPROXY_INTEGRATION.md`)

## References

- [Mitmproxy Documentation](https://docs.mitmproxy.org/)
- [Mitmproxy Scripts](https://docs.mitmproxy.org/stable/addons-scripting/)
- [Selenium Proxy Configuration](https://www.selenium.dev/documentation/webdriver/drivers/options/#proxy)

