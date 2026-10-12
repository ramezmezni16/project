from rest_framework import serializers
from .models import Telemetry

class TelemetrySerializer(serializers.ModelSerializer):
    class Meta:
        model = Telemetry
        fields = ['id', 'tracker_id', 'ts', 'lat', 'lon', 'speed', 'activity', 'battery', 'created_at']
        read_only_fields = ['id', 'created_at']
