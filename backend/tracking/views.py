import os
import math
import numpy as np
from sklearn.cluster import DBSCAN
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from .ml import detect_anomaly
from django.utils import timezone
from rest_framework.permissions import IsAuthenticated
from accounts.models import Profile
from .models import Telemetry, Alert, ShepherdLocation
from .serializers import (
    TelemetrySerializer,
    AlertSerializer,
    ShepherdLocationSerializer,
)
from accounts.models import Profile
from accounts.push_notifications import send_push_notification
from django.db import models
from datetime import timedelta
from django.utils import timezone

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

    distance = calculate_distance_meters(
        lat, lon, FARM_CENTER_LAT, FARM_CENTER_LON
    )

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

    # Suppress duplicate alerts for 15 minutes per tracker and alert type.
    cutoff = timezone.now() - timedelta(minutes=15)

    new_alerts = []

    for alert in alerts:
        already_exists = Alert.objects.filter(
            tracker_id=tid,
            alert_type=alert.alert_type,
            created_at__gte=cutoff,
        ).exists()

        if not already_exists:
            new_alerts.append(alert)

    if not new_alerts:
        return 0

    Alert.objects.bulk_create(new_alerts)

    recipients = Profile.objects.filter(
        models.Q(role=Profile.Role.OWNER) |
        models.Q(
            role=Profile.Role.SHEPHERD,
            owner__profile__role=Profile.Role.OWNER,
            user__is_active=True,
        )
    ).distinct().select_related("user")

    for profile in recipients:
        for alert in new_alerts:
            send_push_notification(
                user=profile.user,
                title=f"{alert.severity}: {alert.alert_type}",
                body=alert.message,
                data={
                    "type": "livestock_alert",
                    "alert_type": alert.alert_type,
                    "tracker_id": alert.tracker_id,
                },
            )

    return len(new_alerts)



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
        eps_meters = float(request.query_params.get('eps', 40))
        min_samples = int(request.query_params.get('min_samples', 20))
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

            dists = [
                calculate_distance_meters(
                    centroid_lat,
                    centroid_lon,
                    la,
                    lo
                )
                for la, lo in cluster_points
            ]

            radius_m = float(np.percentile(dists, 95)) + 20.0

            clusters.append({
                'cluster_id': int(k),
                'center_lat': round(centroid_lat, 6),
                'center_lon': round(centroid_lon, 6),
                'radius_m': round(radius_m, 1),
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
class IsolationForestAnomaliesView(APIView):
    """
    Analyses the latest telemetry reading of each tracker
    using the trained Isolation Forest model.
    """

    def get(self, request):
        tracker_id = request.query_params.get('tracker_id')

        tracker_ids = Telemetry.objects.order_by().values_list(
            'tracker_id', flat=True
        ).distinct()

        if tracker_id:
            tracker_ids = tracker_ids.filter(tracker_id=tracker_id)

        results = []

        try:
            for tid in tracker_ids:
                point = Telemetry.objects.filter(
                    tracker_id=tid
                ).order_by('-ts').first()

                if not point:
                    continue

                if point.speed is None or point.activity is None:
                    continue

                prediction = detect_anomaly(
                    speed=point.speed,
                    activity=point.activity,
                    lat=point.lat,
                    lon=point.lon
                )

                results.append({
                    'tracker_id': point.tracker_id,
                    'ts': point.ts,
                    'lat': point.lat,
                    'lon': point.lon,
                    'speed': point.speed,
                    'activity': point.activity,
                    'is_anomaly': prediction['is_anomaly'],
                    'anomaly_score': prediction['anomaly_score'],
                    'decision_score': prediction['decision_score'],
                    'prediction': (
                        'ANOMALY'
                        if prediction['is_anomaly']
                        else 'NORMAL'
                    )
                })

        except FileNotFoundError:
            return Response(
                {'error': 'Isolation Forest model has not been trained.'},
                status=status.HTTP_503_SERVICE_UNAVAILABLE
            )

        except ValueError as error:
            return Response(
                {'error': str(error)},
                status=status.HTTP_400_BAD_REQUEST
            )

        return Response({
            'algorithm': 'Isolation Forest',
            'trackers_analyzed': len(results),
            'results': results
        })

class HealthCheckView(APIView):
    def get(self, request):
        return Response({'status': 'healthy', 'service': 'livestock-backend'})


class ShepherdLocationUpdateView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        try:
            profile = request.user.profile
        except Profile.DoesNotExist:
            return Response(
                {'error': 'User profile not found.'},
                status=status.HTTP_403_FORBIDDEN
            )

        if profile.role != Profile.Role.SHEPHERD:
            return Response(
                {'error': 'Only shepherd accounts can submit locations.'},
                status=status.HTTP_403_FORBIDDEN
            )

        lat = request.data.get('lat')
        lon = request.data.get('lon')

        try:
            lat = float(lat)
            lon = float(lon)

            if not (-90 <= lat <= 90 and -180 <= lon <= 180):
                raise ValueError()
        except (TypeError, ValueError):
            return Response(
                {'error': 'Valid latitude and longitude are required.'},
                status=status.HTTP_400_BAD_REQUEST
            )

        def optional_float(value):
            if value is None:
                return None
            try:
                number = float(value)
                if not math.isfinite(number):
                    raise ValueError()
                return number
            except (TypeError, ValueError):
                raise ValueError()

        try:
            accuracy = optional_float(request.data.get('accuracy'))
            speed = optional_float(request.data.get('speed'))
        except ValueError:
            return Response(
                {'error': 'Accuracy and speed must be valid numbers.'},
                status=status.HTTP_400_BAD_REQUEST
            )

        location, _ = ShepherdLocation.objects.update_or_create(
            shepherd=request.user,
            defaults={
                'lat': lat,
                'lon': lon,
                'accuracy': accuracy,
                'speed': speed,
                'recorded_at': timezone.now(),
            }
        )

        return Response(
            ShepherdLocationSerializer(location).data,
            status=status.HTTP_200_OK
        )


class ShepherdLocationsListView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        try:
            profile = request.user.profile
        except Profile.DoesNotExist:
            return Response(
                {'error': 'User profile not found.'},
                status=status.HTTP_403_FORBIDDEN
            )

        if profile.role != Profile.Role.OWNER:
            return Response(
                {'error': 'Only owners can view shepherd locations.'},
                status=status.HTTP_403_FORBIDDEN
            )

        shepherd_ids = Profile.objects.filter(
            owner=request.user,
            role=Profile.Role.SHEPHERD
        ).values_list('user_id', flat=True)

        locations = ShepherdLocation.objects.filter(
            shepherd_id__in=shepherd_ids
        ).select_related('shepherd')

        return Response(
            ShepherdLocationSerializer(locations, many=True).data
        )

