import os
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from .models import Telemetry
from .serializers import TelemetrySerializer

class IngestTelemetryView(APIView):
    def post(self, request):
        api_key = request.headers.get('X-API-Key')
        expected_key = os.getenv('INGEST_API_KEY', 'dev-ingest-key-123')
        if not api_key or api_key != expected_key:
            return Response({'error': 'Unauthorized: invalid or missing API key'}, status=status.HTTP_401_UNAUTHORIZED)
        
        serializer = TelemetrySerializer(data=request.data)
        if serializer.is_valid():
            serializer.save()
            return Response(serializer.data, status=status.HTTP_201_CREATED)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

class LatestPositionsView(APIView):
    def get(self, request):
        # Fetch exactly one latest position per unique tracker
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
