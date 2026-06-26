import sys
import re

filename = sys.argv[1]
with open(filename, 'r') as f:
    content = f.read()

# Replace scripts with packed scenes
content = content.replace('path="res://components/fade/fade_component.gd" id="3_fadecomp"', 'path="res://components/fade/fade_component.tscn" id="3_fade_scene"')
content = content.replace('path="res://components/detection/detection_component.gd" id="4_detcomp"', 'path="res://components/detection/detection_component.tscn" id="4_det_scene"')
content = content.replace('path="res://components/wander/wander_component.gd" id="5_wandercomp"', 'path="res://components/wander/wander_component.tscn" id="5_wander_scene"')
content = content.replace('path="res://components/flee/flee_component.gd" id="6_fleecomp"', 'path="res://components/flee/flee_component.tscn" id="6_flee_scene"')

content = content.replace('type="Script" path="res://components', 'type="PackedScene" path="res://components')

# Replace nodes
# FadeComponent
content = re.sub(r'\[node name="FadeComponent" type="Node" parent="\." unique_id=4004000\]\nscript = ExtResource\("3_fadecomp"\)\n', '[node name="FadeComponent" parent="." unique_id=4004000 instance=ExtResource("3_fade_scene")]\n', content)
# DetectionComponent
content = re.sub(r'\[node name="DetectionComponent" type="Node" parent="\." unique_id=4004001\]\nscript = ExtResource\("4_detcomp"\)\n', '[node name="DetectionComponent" parent="." unique_id=4004001 instance=ExtResource("4_det_scene")]\n', content)
# WanderComponent
content = re.sub(r'\[node name="WanderComponent" type="Node" parent="\." unique_id=4004002\]\nscript = ExtResource\("5_wandercomp"\)\n', '[node name="WanderComponent" parent="." unique_id=4004002 instance=ExtResource("5_wander_scene")]\n', content)
# FleeComponent
content = re.sub(r'\[node name="FleeComponent" type="Node" parent="\." unique_id=4004003\]\nscript = ExtResource\("6_fleecomp"\)\n', '[node name="FleeComponent" parent="." unique_id=4004003 instance=ExtResource("6_flee_scene")]\n', content)

with open(filename, 'w') as f:
    f.write(content)
