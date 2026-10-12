from django.urls import path
from .views import IngestTelemetryView, LatestPositionsView, HealthCheckView

urlpatterns = [
    path('health/', HealthCheckView.as_view(), name='health'),
    path('telemetry/', IngestTelemetryView.as_view(), name='ingest-telemetry'),
    path('trackers/latest/', LatestPositionsView.as_view(), name='latest-positions'),
]
