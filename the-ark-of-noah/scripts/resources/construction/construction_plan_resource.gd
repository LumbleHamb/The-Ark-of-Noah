class_name ConstructionPlanResource
extends Resource

## Groups all stages for one construction project.
## Why: designers can change stage count and requirements in one resource.

@export var plan_name: String = "Plan"
@export var stages: Array[ConstructionStageResource] = []
