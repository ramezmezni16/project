
from django.urls import path
from .views import (
    IngestTelemetryView,
    LatestPositionsView,
    HealthCheckView,
    AlertsListView,
    DBSCANClusteringView,
    IsolationForestAnomaliesView,
    ShepherdLocationUpdateView,
    ShepherdLocationsListView,
)

urlpatterns = [
    path('health/', HealthCheckView.as_view(), name='health'),
    path('telemetry/', IngestTelemetryView.as_view(), name='ingest-telemetry'),
    path('trackers/latest/', LatestPositionsView.as_view(), name='latest-positions'),
    path('alerts/', AlertsListView.as_view(), name='alerts-list'),
    path('analytics/clusters/', DBSCANClusteringView.as_view(), name='dbscan-clusters'),
    path('analytics/anomalies/', IsolationForestAnomaliesView.as_view(), name='isolation-forest-anomalies'),

    path(
        'shepherd/location/',
        ShepherdLocationUpdateView.as_view(),
        name='shepherd-location-update'
    ),
    path(
        'shepherds/locations/',
        ShepherdLocationsListView.as_view(),
        name='shepherd-locations-list'
    ),
]
