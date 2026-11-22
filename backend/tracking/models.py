
from django.conf import settings
from django.db import models


class Telemetry(models.Model):
    tracker_id = models.CharField(max_length=32, db_index=True)
    ts = models.DateTimeField(db_index=True)
    lat = models.FloatField()
    lon = models.FloatField()
    speed = models.FloatField(null=True, blank=True)
    activity = models.FloatField(null=True, blank=True)
    battery = models.FloatField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'telemetry'
        managed = False
        ordering = ['-ts']


class Alert(models.Model):
    tracker_id = models.CharField(max_length=32, db_index=True)
    alert_type = models.CharField(max_length=32)
    severity = models.CharField(max_length=16)
    message = models.TextField()
    lat = models.FloatField(null=True, blank=True)
    lon = models.FloatField(null=True, blank=True)
    ts = models.DateTimeField()
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'alerts'
        managed = False
        ordering = ['-created_at']


class ShepherdLocation(models.Model):
    shepherd = models.OneToOneField(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='latest_shepherd_location',
    )
    lat = models.FloatField()
    lon = models.FloatField()
    accuracy = models.FloatField(null=True, blank=True)
    speed = models.FloatField(null=True, blank=True)
    recorded_at = models.DateTimeField()
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-updated_at']

    def __str__(self):
        return f'{self.shepherd.username} - {self.recorded_at}'
