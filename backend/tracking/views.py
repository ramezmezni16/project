import os
import math
import numpy as np
from sklearn.cluster import DBSCAN
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from .models import Telemetry, Alert
from .serializers import TelemetrySerializer, AlertSerializer

FARM_CENTER_LAT = 36.9553
FARM_CENTER_LON = 8.7598
MAX_GEOFENCE_RADIUS_METERS = 500.0

def calculate_distance_meters(lat1, lon1, lat2, lon2):
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

    distance = calculate_distance_meters(lat, lon, FARM_CENTER_LAT, FARM_CENTER_LON)
    if distance > MAX_GEOFENCE_RADIUS_METERS:
        alerts.append(Alert(
            tracker_id=tid,
            alert_type='ESCAPE',
            severity='CRITICAL',
            message=f'Cow {tid} has escaped the pasture! Distance: {int(distance)}m from center.',
            lat=lat, lon=lon, ts=ts
        ))

    if speed >= 10.0 or activity >= 0.85:
        alerts.append(Alert(
            tracker_id=tid,
            alert_type='RUSH',
            severity='CRITICAL',
            message=f'Cow {tid} is rushing frantically! Speed: {speed} km/h, Activity: {activity}.',
            lat=lat, lon=lon, ts=ts
        ))

    if speed == 0.0 and activity < 0.05:
        alerts.append(Alert(
            tracker_id=tid,
            alert_type='STILL',
            severity='WARNING',
            message=f'Cow {tid} has stopped moving completely (possible injury/illness).',
            lat=lat, lon=lon, ts=ts
        ))

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
            alert_count = check_anomalies(serializer.data)
            return Response({'telemetry': serializer.data, 'alerts_triggered': alert_count}, status=status.HTTP_201_CREATED)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

class AlertsListView(APIView):
    def get(self, request):
        tracker_id = request.query_params.get('tracker_id')
        queryset = Alert.objects.all()
        if tracker_id:
            queryset = queryset.filter(tracker_id=tracker_id)
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

class DBSCANClusteringView(APIView):
    """
    Runs DBSCAN on the recent GPS telemetry points.
    - eps_meters: neighborhood radius (default 150m)
    - min_samples: min points to form a core grazing cluster (default 5)
    """
    def get(self, request):
        # Fetch the latest 1000 GPS coordinates
        points = Telemetry.objects.order_by('-ts')[:1000]
        if len(points) < 5:
            return Response({'error': 'Not enough telemetry data to run DBSCAN yet.'}, status=status.HTTP_400_BAD_REQUEST)

        coords = np.array([[p.lat, p.lon] for p in points])
        # Convert degrees to radians for Haversine
        coords_rad = np.radians(coords)

        # 6371000 meters Earth radius; 150 meters epsilon
        eps_meters = float(request.query_params.get('eps', 150))
        min_samples = int(request.query_params.get('min_samples', 5))
        eps_rad = eps_meters / 6371000.0

        db = DBSCAN(eps=eps_rad, min_samples=min_samples, metric='haversine')
        labels = db.fit_predict(coords_rad)

        unique_labels = set(labels)
        clusters = []
        noise_count = int(np.sum(labels == -1))

        for k in sorted(unique_labels):
            if k == -1:
                continue  # Noise / Outliers
            cluster_points = coords[labels == k]
            centroid_lat = float(np.mean(cluster_points[:, 0]))
            centroid_lon = float(np.mean(cluster_points[:, 1]))
            clusters.append({
                'cluster_id': int(k),
                'center_lat': round(centroid_lat, 6),
                'center_lon': round(centroid_lon, 6),
                'point_count': int(len(cluster_points)),
                'label': f'Habitual Grazing Zone {k + 1}'
            })

        return Response({
            'total_points_analyzed': len(points),
            'clusters_discovered': len(clusters),
            'habitual_zones': clusters,
            'noise_outliers_count': noise_count,
            'algorithm': 'DBSCAN (Haversine)'
        })

class HealthCheckView(APIView):
    def get(self, request):
        return Response({'status': 'healthy', 'service': 'livestock-backend'})
