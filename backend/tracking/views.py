import os
import math
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from .models import Telemetry, Alert
from .serializers import TelemetrySerializer, AlertSerializer

# Pasture Center (approx midpoint of habitual zones) & Allowed Radius (meters)
FARM_CENTER_LAT = 36.9553
FARM_CENTER_LON = 8.7598
MAX_GEOFENCE_RADIUS_METERS = 500.0

def calculate_distance_meters(lat1, lon1, lat2, lon2):
    # Haversine distance in meters
    R = 6371000.0
    phi1, phi2 = math.radians(lat1), math.radians(lat2)
    delta_phi = math.radians(lat2 - lat1)
    delta_lambda = math.radians(lon2 - lon1)
    a = math.sin(delta_phi / 2.0)**2 + math.cos(phi1) * math.cos(phi2) * math.sin(delta_lambda / 2.0)**2
    c = 2.0 * math.atan2(math.sqrt(a), math.sqrt(1.0 - a))
    return R * c

def check_anomalies(data):
    alerts = []
    tid = data['tracker_id']
    ts = data['ts']
    lat, lon = data['lat'], data['lon']
    speed = data.get('speed') or 0.0
    activity = data.get('activity') or 0.0
    battery = data.get('battery') or 100.0

    # 1. Geofence breach check
    distance = calculate_distance_meters(lat, lon, FARM_CENTER_LAT, FARM_CENTER_LON)
    if distance > MAX_GEOFENCE_RADIUS_METERS:
        alerts.append(Alert(
            tracker_id=tid,
            alert_type='ESCAPE',
            severity='CRITICAL',
            message=f'Cow {tid} has escaped the pasture! Distance: {int(distance)}m from center.',
            lat=lat, lon=lon, ts=ts
        ))

    # 2. Rush / Panic / Stampede check
    if speed >= 10.0 or activity >= 0.85:
        alerts.append(Alert(
            tracker_id=tid,
            alert_type='RUSH',
            severity='CRITICAL',
            message=f'Cow {tid} is rushing frantically! Speed: {speed} km/h, Activity: {activity}.',
            lat=lat, lon=lon, ts=ts
        ))

    # 3. Immobility / Sick check
    if speed == 0.0 and activity < 0.05:
        alerts.append(Alert(
            tracker_id=tid,
            alert_type='STILL',
            severity='WARNING',
            message=f'Cow {tid} has stopped moving completely (possible injury/illness).',
            lat=lat, lon=lon, ts=ts
        ))

    # 4. Low Battery check
    if battery < 20.0:
        alerts.append(Alert(
            tracker_id=tid,
            alert_type='LOW_BATTERY',
            severity='WARNING',
            message=f'Tracker {tid} battery is low ({battery}%).',
            lat=lat, lon=lon, ts=ts
        ))

    if alerts:
        Alert.objects.bulk_create(alerts)
    return len(alerts)

class IngestTelemetryView(APIView):
    def post(self, request):
        api_key = request.headers.get('X-API-Key')
        expected_key = os.getenv('INGEST_API_KEY', 'dev-ingest-key-123')
        if not api_key or api_key != expected_key:
            return Response({'error': 'Unauthorized: invalid or missing API key'}, status=status.HTTP_401_UNAUTHORIZED)
        
        serializer = TelemetrySerializer(data=request.data)
        if serializer.is_valid():
            serializer.save()
            # Run real-time anomaly check
            alert_count = check_anomalies(serializer.data)
            return Response({'telemetry': serializer.data, 'alerts_triggered': alert_count}, status=status.HTTP_201_CREATED)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

class AlertsListView(APIView):
    def get(self, request):
        tracker_id = request.query_params.get('tracker_id')
        queryset = Alert.objects.all()
        if tracker_id:
            queryset = queryset.filter(tracker_id=tracker_id)
        # Return latest 50 alerts
        return Response(AlertSerializer(queryset[:50], many=True).data)

class LatestPositionsView(APIView):
    def get(self, request):
        tracker_ids = sorted(list(set(Telemetry.objects.order_by().values_list('tracker_id', flat=True))))
        latest = []
        for tid in tracker_ids:
            point = Telemetry.objects.filter(tracker_id=tid).order_by('-ts').first()
            if point:
                latest.append(TelemetrySerializer(point).data)
        return Response(latest)

class HealthCheckView(APIView):
    def get(self, request):
        return Response({'status': 'healthy', 'service': 'livestock-backend'})
