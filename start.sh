#!/bin/bash

# Quick start script for Wingbits Docker container

echo "================================================"
echo "   Wingbits Docker Container Setup"
echo "================================================"
echo ""

# Check if .env exists
if [ ! -f .env ]; then
    echo "⚠️  .env file not found!"
    echo ""
    echo "Creating .env file from env.example..."
    cp env.example .env
    echo ""
    echo "✓ .env file created"
    echo ""
    echo "Please edit .env and update with your station details:"
    echo "  - LAT: Your station latitude"
    echo "  - LONG: Your station longitude"
    echo "  - DEVICE_ID: Your station ID from Wingbits"
    echo ""
    echo "Then run this script again."
    exit 1
fi

# Check if required variables are set
source .env

if [ -z "$LAT" ] || [ "$LAT" = "-31.966645" ]; then
    echo "⚠️  Please update LAT in .env file"
    exit 1
fi

if [ -z "$LONG" ] || [ "$LONG" = "115.862013" ]; then
    echo "⚠️  Please update LONG in .env file"
    exit 1
fi

if [ -z "$DEVICE_ID" ] || [ "$DEVICE_ID" = "cool-animal-name" ]; then
    echo "⚠️  Please update DEVICE_ID in .env file"
    exit 1
fi

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo "❌ Docker is not running. Please start Docker and try again."
    exit 1
fi

# Check if device exists
if [ ! -e /dev/ttyACM0 ]; then
    echo "⚠️  Warning: /dev/ttyACM0 not found"
    echo "   Make sure your geosigner device is connected"
    echo ""
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

echo "Configuration:"
echo "  Latitude: $LAT"
echo "  Longitude: $LONG"
echo "  Device ID: $DEVICE_ID"
echo "  Gain: ${GAIN:-autogain}"
echo "  Heatmap: ${ENABLE_HEATMAP:-false}"
echo ""

# Build and start
echo "Building Docker container..."
docker-compose build

if [ $? -eq 0 ]; then
    echo ""
    echo "✓ Build successful"
    echo ""
    echo "Starting Wingbits container..."
    docker-compose up -d
    
    if [ $? -eq 0 ]; then
        echo ""
        echo "✓ Container started successfully!"
        echo ""
        echo "================================================"
        echo "   Access your station:"
        echo "================================================"
        echo ""
        echo "  Local map (tar1090):  http://localhost:8080"
        echo "  Graphs (graphs1090):  http://localhost:8081"
        echo "  Wingbits Dashboard:   https://wingbits.com/dashboard/stations/$DEVICE_ID?active=map"
        echo ""
        echo "================================================"
        echo ""
        echo "View logs with: docker-compose logs -f"
        echo "Stop with:      docker-compose down"
        echo ""
    else
        echo "❌ Failed to start container"
        exit 1
    fi
else
    echo "❌ Build failed"
    exit 1
fi

