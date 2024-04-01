extends KinematicBody

export(float) var SPEED := 2.0
export(float) var TILT_SENSITIVITY := 9.5
export(bool) var DEBUG_OUTPUT := false
export(float) var HEIGHT_AVG := 0.0
var HEIGHT_AVG_SET := false
var BACKWARDS_SET := false
var call_count := 30
var back_count := call_count + 9
var i := 0

func _physics_process(delta):
	var head_tilt := 0.0 #$ARVROrigin/ARVRCamera.rotation.z
	var camera = $ARVROrigin/ARVRCamera
	var v = $StepDetector.detect_step(camera, delta)
	
	if OS.has_feature("editor"):
		v = Vector3(0, 0, Input.is_action_pressed("ui_select"))
		if Input.is_action_pressed("ui_left"):
			head_tilt += 10 / TILT_SENSITIVITY * delta
		if Input.is_action_pressed("ui_right"):
			head_tilt -= 10 / TILT_SENSITIVITY * delta
	
	# Calculates the average height of the headset on the user's head 
	# When they first put it on. Used for jumping and backwards detection
	if i < call_count and camera.translation.y != 0 and abs(camera.rotation_degrees.x) < 10:
		i+=1
		HEIGHT_AVG += camera.translation.y
	if i == call_count:
		HEIGHT_AVG = HEIGHT_AVG/call_count
		HEIGHT_AVG_SET = true
		i+=1
	
	# Helps fine tuning HEIGHT_AVG for use in backwards detection
	# Adjusts for a head tilt below the backwards tilt threshold as 
	# users have to also lean back and reduce their height,  
	# similar to a smaller head tilt
	var height_dif = camera.translation.y - HEIGHT_AVG
	if HEIGHT_AVG_SET == true and height_dif < 0.05 and height_dif > -0.02 and camera.rotation_degrees.x < 6.25 and camera.rotation_degrees.x > 5.5 and abs(camera.rotation_degrees.z) < 4 and $StepDetector.rpm < 72 and $StepDetector.backwards_counter == 0:
		if v != Vector3(0,0,0) and height_dif < -0.004:
			HEIGHT_AVG = HEIGHT_AVG * 0.95 + camera.translation.y * 0.05
		elif v != Vector3(0,0,0) and height_dif > 0.008:
			HEIGHT_AVG += 0.001
		elif i < back_count and v == Vector3(0,0,0):
			HEIGHT_AVG = HEIGHT_AVG * 0.85 + camera.translation.y * 0.15
		elif v == Vector3(0,0,0):
			HEIGHT_AVG = HEIGHT_AVG * 0.98 + camera.translation.y * 0.02
		i+=1
		
	if i == back_count:
		i+=1
		BACKWARDS_SET = true
		print("Height:", HEIGHT_AVG)
		
#	if DEBUG_OUTPUT:
#		#$HUD/Viewport/Label.text = "rpm=%d v.x=%2.3f vv.x=%2.3f %s" % [$StepDetector.rpm, $StepDetector.v.x, $StepDetector.vv.x, $ARVROrigin/ARVRCamera.rotation_degrees]
#		$HUD/Viewport/Label.text = "rpm=%d Zdist=%2.1f vx=%2.3f vz=%2.3f dx=%2.3f dz=%2.3f" % [$StepDetector.rpm, -translation.z, $StepDetector.v.x, $StepDetector.v.z, $StepDetector.direction.x, $StepDetector.direction.z]
	# $HUD/Viewport/Label.text = "Dist: %2.0f, SPM: %2.0f" % [dist, $StepDetector.actual_rpm*2]
	move_and_slide(-delta * SPEED * v)

