from rest_framework import serializers
from .models import Telemetry, Alert

class TelemetrySerializer(serializers.ModelSerializer):
    class Meta:
        model = Telemetry
        fields = ['id', 'tracker_id', 'ts', 'lat', 'lon', 'speed', 'activity', 'battery', 'created_at']
        read_only_fields = ['id', 'created_at']

class AlertSerializer(serializers.ModelSerializer):
    class Meta:
        model = Alert
        fields = ['id', 'tracker_id', 'alert_type', 'severity', 'message', 'lat', 'lon', 'ts', 'created_at']
        read_only_fields = ['id', 'created_at']
