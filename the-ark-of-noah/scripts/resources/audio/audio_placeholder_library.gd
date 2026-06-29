class_name AudioPlaceholderLibrary
extends Resource

## Central list of placeholder audio cues expected by systems.
## Why: lets future audio pass replace placeholders without hunting constants.

@export var cues: Dictionary[String, String] = {}
