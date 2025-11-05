#!/bin/bash
set -e

# Function to validate lat/long coordinates
check_coordinates() {   
    latitude="none"
    longitude="none"
    local lat_regex='^[-+]?([0-9]|[1-8][0-9])(\.[0-9]+)?$'
    local lon_regex='^[-+]?([0-9]|[1-9][0-9]|1[0-7][0-9]|180)(\.[0-9]+)?$'
    
    latitude=$(echo "$1" | cut -d ',' -f1)
    longitude=$(echo "$1" | cut -d ',' -f2 | tr -d ' ')

    # Validate latitude from -90 to +90
    if [[ $latitude =~ $lat_regex && $(awk -v lat="$latitude" 'BEGIN {if (lat >= -90 && lat <= 90) print 1; else print 0}') -eq 1 ]]; then
        echo "✓ Valid coordinate for latitude: $latitude"
    else
        echo "✗ Invalid coordinate for latitude: $latitude"
        return 1
    fi

    # Validate longitude from -180 to +180
    if [[ $longitude =~ $lon_regex && $(awk -v lon="$longitude" 'BEGIN {if (lon >= -180 && lon <= 180) print 1; else print 0}') -eq 1 ]]; then
        echo "✓ Valid coordinate for longitude: $longitude"
    else
        echo "✗ Invalid coordinate for longitude: $longitude"
        return 1
    fi
}

# Function to validate the Device ID input format
validate_deviceid() {
    # handle animal names or device serials
    if [[ "$1" =~ ^[a-z]+-[a-z]+-[a-z]+$ || "$1" =~ ^[0-9A-F]{18}$ || "$1" =~ ^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$ ]]; then
        return 0
    else
        echo "Invalid device ID format."
        return 1
    fi
}

echo "================================================"
echo "   Wingbits Docker Container Starting"
echo "================================================"
echo ""

# Validate LAT and LONG
if [ -z "$LAT" ]; then
    echo "ERROR: LAT environment variable is required"
    echo "Example: LAT=\"-31.966645\""
    exit 1
fi

if [ -z "$LONG" ]; then
    echo "ERROR: LONG environment variable is required"
    echo "Example: LONG=\"115.862013\""
    exit 1
fi

# Combine for validation
LOCATION="$LAT, $LONG"

if ! check_coordinates "$LOCATION"; then
    echo "ERROR: Invalid coordinates"
    exit 1
fi

echo "Location: $LAT, $LONG"

# Validate and set DEVICE_ID
if [ -z "$DEVICE_ID" ]; then
    echo "ERROR: DEVICE_ID environment variable is required"
    echo "Example: DEVICE_ID=\"cool-animal-name\""
    exit 1
fi

if ! validate_deviceid "$DEVICE_ID"; then
    echo "ERROR: Invalid device ID format"
    exit 1
fi

echo "Device ID: $DEVICE_ID"
echo "$DEVICE_ID" > /etc/wingbits/device

# Use LAT and LONG directly
latitude="$LAT"
longitude="$LONG"

# Configure readsb location
echo "Configuring readsb location..."
if [ -f /usr/local/bin/readsb-set-location ]; then
    /usr/local/bin/readsb-set-location "$LOCATION"
else
    # Manual configuration if script doesn't exist
    if [ -f /etc/default/readsb ]; then
        sed -i "s/--lat [0-9.-]*/--lat $latitude/" /etc/default/readsb
        sed -i "s/--lon [0-9.-]*/--lon $longitude/" /etc/default/readsb
        if ! grep -q -- "--lat" /etc/default/readsb; then
            echo "DECODER_OPTIONS=\"--lat $latitude --lon $longitude\"" >> /etc/default/readsb
        fi
    fi
fi

# Set readsb gain if specified, otherwise use autogain
if [ -n "$GAIN" ]; then
    echo "Setting readsb gain to: $GAIN"
    if [ -f /usr/local/bin/readsb-gain ]; then
        /usr/local/bin/readsb-gain "$GAIN"
    fi
else
    echo "Using autogain (no manual gain specified)"
    if [ -f /usr/local/bin/readsb-gain ]; then
        /usr/local/bin/readsb-gain autogain
    fi
fi

# Configure tar1090 if config exists
if [ -f /usr/local/share/tar1090/html/config.js ]; then
    echo "Configuring tar1090..."
    sed -i 's|// useRouteAPI = false;|useRouteAPI = true;|' /usr/local/share/tar1090/html/config.js
    sed -i 's|// routeApiUrl = "https://api.adsb.lol/api/0/routeset";|routeApiUrl = "https://api.adsb.lol/api/0/routeset";|' /usr/local/share/tar1090/html/config.js
    sed -i "s|//shareBaseUrl = 'https://adsb.lol/';|shareBaseUrl = 'https://wingbits.com/map';|" /usr/local/share/tar1090/html/config.js
fi

# Configure tar1090 script if it exists
if [ -f /usr/local/share/tar1090/html/script.js ]; then
    sed -i "s|shareLink = shareBaseUrl + string;|shareLink = shareBaseUrl + '?flight=' + SelPlanes.map((s) => encodeURIComponent(s.icao)).join(',');|" /usr/local/share/tar1090/html/script.js
    sed -i 's|"\\" onclick=\\"copyShareLink(); return false;\\">"|"\\">"|' /usr/local/share/tar1090/html/script.js
    sed -i 's|"Copy" + NBSP + "Link"|"WB" + NBSP + "Link"|' /usr/local/share/tar1090/html/script.js
fi

# Configure graphs1090 if config exists
if [ -f /etc/default/graphs1090 ]; then
    echo "Configuring graphs1090..."
    if grep -q "^colorscheme=" /etc/default/graphs1090; then
        sed -i "s/^colorscheme=.*/colorscheme=dark/" /etc/default/graphs1090
    fi
fi

# Enable heatmap if requested
if [ "$ENABLE_HEATMAP" = "true" ]; then
    echo "Enabling heatmap..."
    if [ -f /etc/default/readsb ]; then
        mkdir -p /var/globe_history
        if id "readsb" &>/dev/null; then
            chown readsb /var/globe_history
        fi
        
        options="--heatmap-dir /var/globe_history --heatmap 30"
        if grep -q '^JSON_OPTIONS=' /etc/default/readsb; then
            if ! grep -q -- "--heatmap" /etc/default/readsb; then
                sed -i "s|JSON_OPTIONS=\"\(.*\)\"|JSON_OPTIONS=\"\1 $options\"|" /etc/default/readsb
            fi
        fi
    fi
fi

# Create necessary runtime directories
mkdir -p /run/readsb /run/collectd

echo ""
echo "Configuration complete!"
echo "================================================"
echo ""
echo "Dashboard: https://wingbits.com/dashboard/stations/$DEVICE_ID?active=map"
echo "Local map: http://localhost:8080 (tar1090)"
echo "Graphs: http://localhost:80 (graphs1090)"
echo ""
echo "================================================"
echo "Starting services..."
echo ""

# Execute the command passed to the container
exec "$@"

