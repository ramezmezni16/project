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
