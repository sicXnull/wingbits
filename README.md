# Wingbits Docker Container

This is a self-contained Docker container for running a Wingbits ADS-B feeder station. It includes all necessary components:

- **readsb**: ADS-B decoder for RTL-SDR devices
- **wingbits client**: Feeds data to the Wingbits network
- **tar1090**: Web-based aircraft map interface
- **graphs1090**: Performance graphs and statistics

## Prerequisites

- Docker and Docker Compose installed
- RTL-SDR USB dongle for ADS-B reception
- USB geosigner device at `/dev/ttyACM0`
- Wingbits account and station ID

## Quick Start

### 1. Create Configuration File

Copy the example environment file and edit it with your station details:

```bash
cp .env.example .env
```

Edit `.env` and update the following:

```bash
LAT=-31.966645           # Your station latitude
LONG=115.862013          # Your station longitude
DEVICE_ID=cool-animal-name  # Your station ID from Wingbits
```

### 2. Build the Container

```bash
docker-compose build
```

### 3. Run the Container

```bash
docker-compose up -d
```

### 4. View Logs

```bash
docker-compose logs -f
```

## Configuration

### Required Environment Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `LAT` | Station latitude | `-31.966645` |
| `LONG` | Station longitude | `115.862013` |
| `DEVICE_ID` | Station identifier from Wingbits | `cool-animal-name` |

### Optional Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `GAIN` | RTL-SDR gain setting (dB). Leave unset for autogain, or specify 0-49.6 | `autogain` |
| `ENABLE_HEATMAP` | Enable aircraft heatmap | `false` |

**Note:** Autogain is recommended for most setups. Only set a manual gain value if you need to optimize for your specific location and antenna setup.

### Device Mapping

The container requires access to two USB devices:

1. **RTL-SDR dongle** - Automatically detected
2. **Geosigner** - Mapped via `/dev/ttyACM0:/dev/ttyACM0`

If your geosigner is on a different device, update the `devices` section in `docker-compose.yml`:

```yaml
devices:
  - /dev/ttyACM1:/dev/ttyACM0  # Map ttyACM1 on host to ttyACM0 in container
```

## Accessing Web Interfaces

Once running, you can access:

- **tar1090 Map**: http://localhost:8080
- **graphs1090**: http://localhost:8081
- **Wingbits Dashboard**: https://wingbits.com/dashboard/stations/YOUR_DEVICE_ID?active=map

## Manual Docker Run

If you prefer to run without docker-compose:

```bash
docker build -t wingbits-feeder .

docker run -d \
  --name wingbits \
  --restart unless-stopped \
  --device /dev/ttyACM0:/dev/ttyACM0 \
  --privileged \
  -e LAT="-31.966645" \
  -e LONG="115.862013" \
  -e DEVICE_ID="cool-animal-name" \
  -e ENABLE_HEATMAP="false" \
  -p 8080:8080 \
  -p 8081:80 \
  -p 30001:30001 \
  -p 30002:30002 \
  -p 30003:30003 \
  -p 30004:30004 \
  -p 30005:30005 \
  -v wingbits-data:/etc/wingbits \
  -v wingbits-logs:/var/log/wingbits \
  -v wingbits-history:/var/globe_history \
  wingbits-feeder
```

## Container Management

### Start the container
```bash
docker-compose up -d
```

### Stop the container
```bash
docker-compose down
```

### Restart the container
```bash
docker-compose restart
```

### View logs
```bash
docker-compose logs -f
```

### Check service status
```bash
docker-compose exec wingbits supervisorctl status
```

## Troubleshooting

### Check if RTL-SDR is detected

```bash
docker-compose exec wingbits lsusb | grep -i RTL28
```

### Check if geosigner is accessible

```bash
docker-compose exec wingbits ls -la /dev/ttyACM0
```

### View individual service logs

```bash
# Wingbits client logs
docker-compose exec wingbits tail -f /var/log/wingbits/wingbits.out.log

# Readsb logs
docker-compose exec wingbits tail -f /var/log/wingbits/readsb.out.log

# Supervisor logs
docker-compose exec wingbits tail -f /var/log/supervisor/supervisord.log
```

### Restart individual services

```bash
docker-compose exec wingbits supervisorctl restart wingbits
docker-compose exec wingbits supervisorctl restart readsb
```

### Container won't start

1. Check that required environment variables are set:
   ```bash
   docker-compose config
   ```

2. Verify USB devices are accessible:
   ```bash
   ls -la /dev/ttyACM0
   lsusb
   ```

3. Check Docker logs:
   ```bash
   docker-compose logs
   ```

## Data Persistence

The following data is persisted using Docker volumes:

- `/etc/wingbits` - Configuration and device ID
- `/var/log/wingbits` - Application logs
- `/var/globe_history` - Heatmap data (if enabled)
- `/var/log/supervisor` - Service manager logs

To backup your configuration:

```bash
docker run --rm -v wingbits-data:/data -v $(pwd):/backup alpine tar czf /backup/wingbits-backup.tar.gz -C /data .
```

To restore:

```bash
docker run --rm -v wingbits-data:/data -v $(pwd):/backup alpine tar xzf /backup/wingbits-backup.tar.gz -C /data
```

## Updates

To update to the latest version:

```bash
docker-compose down
docker-compose build --no-cache
docker-compose up -d
```

## Support

- Wingbits Documentation: https://docs.wingbits.com
- Wingbits Dashboard: https://wingbits.com/dashboard

## License

This container packages open-source software from various projects. Please refer to individual component licenses.

