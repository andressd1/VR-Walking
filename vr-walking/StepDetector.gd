extends Node
class_name WIPEstimator

export(Vector3) var head := Vector3(0, 0, 0)
export(Vector3) var v := Vector3(0, 0, 0)
export(Vector3) var vv := Vector3(0, 0, 0)
export(Vector3) var direction := Vector3(0, 0, -1)
export(float) var rpm := 0.0

signal player_moved(delta, head, v, vv, mov, direction)

var RPM_PARAMS = {"t_vv_x":0.045, "w0":0.373254, "w1":0.39774, "w2":0.057184, "w_rpm":0.75} #0.826223 # "t_vv_x":0.025

var time_since_step := 0.0
var head_prev := Vector3(0, 0, 0)
var v_prev := Vector3(0, 0, 0)
var vv_prev := Vector3(0, 0, 0)
var mov := 0.0
var mov_prev := 0.0
var rpm_prev := 0.0
var direction_prev := Vector3(0, 0, -1)
var iterat := 0
var turn_count := 0
var turned_around = 0
var stopped := 0
var started := 0
var started_thresh := 250
var stopped_thresh := 3
var real_movpre := -0.1
var real_movprepre := -0.1
var is_jumping := false
var sidetoside := false
var rotation_pre:= Vector3(0.0,0.0,0.0)
var rotation:= Vector3(0.0,0.0,0.0)
var head_z_count := 0
var head_x_count := 0
var is_large_rpm_change := false
var backwards_counter = 0
var not_backwards_counter = 0

func detect_step(camera : ARVRCamera, delta : float) -> Vector3:
	iterat += 1
	time_since_step += delta
	if delta == 0.0:
		delta = 0.001
	
	# features
	head_prev = head
	v_prev = v
	vv_prev = vv
	mov_prev = mov
	direction_prev = direction
	rpm_prev = rpm
	rotation_pre = rotation
	rotation = camera.rotation_degrees
	var change_in_rotat := Vector3(abs(rotation.x-rotation_pre.x), abs(rotation.y-rotation_pre.y), abs(rotation.z-rotation_pre.z))
	head = camera.translation
	
	# Head tilt adjustment
	var x_adjustment := 0.0020 * camera.rotation_degrees.z - 0.00006 # Based on experiment and linear regression
	var local_parallel_x := Vector3(camera.transform.basis.x.x, 0, camera.transform.basis.x.z).normalized()
	head = x_adjustment * local_parallel_x + head
	
	var params : Dictionary = RPM_PARAMS
	
	head = (1 - params["w0"]) * head_prev + params["w0"] * head
	v = (head - head_prev) / delta
	v = (1 - params["w1"]) * v_prev + params["w1"] * v
	vv = (v - v_prev) / delta
	vv = (1 - params["w2"]) * vv_prev + params["w2"] * vv
	
	# check user isn't just leaning forwards or backwards in the direction of their head
	# Not possible for walking or running
	if started < started_thresh:
		if Vector2(v_prev.x, v_prev.z).normalized().dot(-Vector2(camera.transform.basis.z.x, camera.transform.basis.z.z).normalized()) > 0.9 or Vector2(v_prev.x, v_prev.z).normalized().dot(-Vector2(camera.transform.basis.z.x, camera.transform.basis.z.z).normalized()) < -0.9:
			if Vector2(v.x, v.z).normalized().dot(-Vector2(camera.transform.basis.z.x, camera.transform.basis.z.z).normalized()) > 0.9 or Vector2(v.x, v.z).normalized().dot(-Vector2(camera.transform.basis.z.x, camera.transform.basis.z.z).normalized()) < -0.9:
				#$"../HUD/Viewport/Label".text =  "MOVING IN HEAD DIR"
				mov = 0
				return Vector3(0,0,0)
	
	# Calculates the length of the velocity and acceleration "floor"(no Y) vectors
	# Required for when user's head movement is not solely alogn X axis
	var real_v := Vector2(v.x, v.z).length()
	var real_a := Vector2(vv.x, vv.z).length()
	
	# Changes which axis to base the direction of velocity on
	# With the axis with the largest velocity for a past number of movements
	# eg.If user's head is mainly going side to side on X-axis use X-axis sign(+/-)
	var v_count := 12
	if abs(2*v.x) < abs(v.z):
		if head_z_count < v_count:
			head_z_count += 1
		else:
			head_x_count = 0
	elif abs(2*v.z) < abs(v.x):
		if head_x_count < v_count:
			head_x_count += 1
		else:
			head_z_count = 0	
	if head_x_count >= v_count:
		if v.x < 0:
				real_v = -real_v
	elif head_z_count >= v_count:
		if v.z < 0:
				real_v = -real_v
	else:
		if head_x_count > head_z_count: if v.x < 0: real_v = -real_v
		else: if v.z < 0: real_v = -real_v
	
	mov = real_v
	
	# Detects jumping based on vertical(y) acceleration and height of user
	if head.y > $"/root/Main/Player".HEIGHT_AVG * 0.99 and v.y > 1 and $"/root/Main/Player".HEIGHT_AVG_SET == true and is_jumping == false:
		is_jumping = true
		time_since_step = 0
		print("JUMP: %2.2f, %2.2f, %2.2f" % [head.y, v.y, vv.y])
	if is_jumping == true and ((head.y <= $"/root/Main/Player".HEIGHT_AVG * 1.005 and v.y <= 0) or time_since_step > 0.65):
		is_jumping = false
	if is_jumping == true:
		var camera_d := Vector3(camera.transform.basis.z.x, 0, camera.transform.basis.z.z).normalized()
		return (90 * camera_d * 8.7)
	
	# This detects when the player stops. 
	# You can make walking smoother (i.e. less likely to suddenly stop) by lowering params["t_vv_x"].
	# if abs(vv.x) < params["t_vv_x"] or abs(vv.x) > 0.68 or abs(v.x) > 0.35:
	if real_a < params["t_vv_x"] or real_a > 1.4 or real_v > 0.5:
		mov = 0
	if time_since_step > 2 and stopped >= stopped_thresh:
		rpm = 0
	if time_since_step > 0.85 and started < started_thresh:
		started = 0
	
	# Checks if player has stopped moving for a number of calls or
	# Could just be part of movement
	if mov == 0:	
		if stopped == stopped_thresh:
			is_large_rpm_change = false
			real_movpre = 0.0
			real_movprepre = 0.0
			started = 0
			sidetoside = false
		elif stopped < stopped_thresh and abs(v.y) < 0.4:
			stopped += 1
	elif sidetoside == true:
		if started <= started_thresh:
			started += 1
		stopped = 0

	if started > 1000:
		started = started_thresh+1
	
	# Increments started variable. Started increases as user moves
	# In ways that correspond to movements like stepping. 
	# Once started passses threshold, virtual walking begins. 
	# Started is increased by large amounts when velocity between
	# certain thresholds and the user has moved their head from
	# Side to side. Can cause slight delay of 1-2 steps but reduces drastically 
	# the detection of steps when just looking around.
	if abs(real_v) > 0.22 and abs(real_v) < 0.36 and change_in_rotat.y < 1.7 and change_in_rotat.x < 1.3 and sidetoside == true and started_thresh <= started_thresh:
		started += 85
	elif abs(real_v) > 0.165 and abs(real_v) < 0.36 and change_in_rotat.y < 1.7 and change_in_rotat.x < 1.3 and sidetoside == true and started_thresh <= started_thresh:
		 started += 25
	
	# Reduces wrongly detected walk starts from just moving head quickly
	if started < started_thresh and (change_in_rotat.y > 2 or change_in_rotat.z > 2.2):
		started = 0
	
	# Real_movpre and prepre are the previous values for
	# mov that were not 0. Useful for side to side detection and RPM
	if mov_prev != 0:
		real_movprepre = real_movpre
		real_movpre = mov_prev
	
	# zero crossing, count as step
	if ((real_movprepre > 0 and real_movpre < 0 and  mov < 0) or (real_movprepre < 0 and real_movpre > 0 and mov > 0)) and time_since_step > 0.15:
		
		var new_rpm = 30 / time_since_step
		
#		if sidetoside == false and change_in_rotat < 1.7 and time_since_step > 0.25:
#			sidetoside = true
		if time_since_step < 0.9 and time_since_step > 0.25 and started < started_thresh and change_in_rotat.y < 1.7  and change_in_rotat.x < 1 and camera.rotation_degrees.x > -15:
			started += 100
			sidetoside = true
		elif started < started_thresh:
			sidetoside = false
		
		# "too fast" outlier detection -- keep old_rpm
		#TODO use probabilistic model instead, i.e. don't jsut cut off but modulate change by likelihood, e.g. unlikely fast change causes only small change due to modulation
		if new_rpm > 120 and new_rpm > 1.25 * rpm_prev:
			rpm = rpm_prev
		else:
			time_since_step = 0
			
			# "too slow" outlier detection -- keep rpm_prev after resetting time_since_step
			# TODO use probabilistic model instead, i.e. don't jsut cut off but modulate change by likelihood, e.g. unlikely fast change causes only small change due to modulation
			# If predicted RPM change is large, wait one more call before making large change to RPM
			# exponential smoothing of RPM to prevent jerky movements
			if new_rpm > rpm_prev + 7 or new_rpm < rpm_prev - 7:
				if is_large_rpm_change or rpm_prev < 35:
					rpm = params["w_rpm"] * rpm_prev + (1-params["w_rpm"]) * new_rpm
					is_large_rpm_change = false
				else:
					is_large_rpm_change = true
					if new_rpm < 0.55 * rpm_prev:
						rpm = rpm_prev
					else:
						rpm = 0.97 * rpm_prev + 0.03 * new_rpm
			else:
				is_large_rpm_change = false
				rpm = 0.93 * rpm_prev + 0.07 * new_rpm
				
	# walk direction estimation based on rotated sideway movement speed
	var d = Vector3(v.z, 0, -v.x) # rotate v 
	# flip direction around if it is pointing backwards according to camera direction
	if d.dot(camera.get_global_transform().basis.z) < 0:
		d = -d

	# compensate for relative-z movement correlated with relative-x
	# TODO check and tune this
	d = d + 0.2 * Vector3(v.x, 0, v.z)
	d = d.normalized()
	
	var mult_a := 0.9965
	# If new d is more than 100 degrees from direction, new direction should be current d. 
	# ie. user turning around. 
	var trans_z := camera.transform.basis.z
	trans_z.y = 0
	if direction_prev.dot(trans_z) < -0.1:
		if turned_around == 4:
			direction = trans_z.normalized()
			turn_count += 1
			turned_around = 0
		else:
			turned_around += 1
	else:
		# Increases the adjustment of direction with d based on 
		# how far the direction is from the current d
		# Only activates modifier if d is larger than 
		# a threshold for more than 5 calls
		# Not perfect, has slight jitter but quite a bit more responsive
		#var modif := - ((pow(37, direction_prev.dot(d.normalized())) - 1)/36) + 1 # Exponential increase 
		var modif := 1/(1+pow(2.71828,10*direction_prev.dot(d)-5))
		if turn_count == 10 and modif > 0.18 and rpm <= 65:
			mult_a = mult_a - 0.18 * modif
			turn_count = 5
		elif rpm > 65 and turn_count > 8:
			turn_count = 3
			mult_a = 0.9
		elif modif > 0.25:
			mult_a = 0.9982
			turn_count += 1
		else:
			turn_count = 0

		direction = mult_a * direction_prev + (1-mult_a) * d
		direction = direction.normalized()
	
	# $"../HUD/Viewport/Label".text =  "Dist: %2.1f, %2.1f, %d, %d, %2.1f" % [-$"/root/Main/Player".translation.z, mov, started, rpm, time_since_step]
	if stopped >= stopped_thresh or started < started_thresh:
			$"../HUD/Viewport/Label".text =  "STOPPED"
#		$"../HUD/Viewport/Label".text = "%2.0f, %2.4f, %2.4f, %d" % [camera.rotation_degrees.x, $"/root/Main/Player".HEIGHT_AVG, head.y, backwards_counter]
	else:
		$"../HUD/Viewport/Label".text =  "%2.0f, %2.1f, %d, %2.1f" % [rpm, mov, stopped, time_since_step]
		# $"../HUD/Viewport/Label".text = "%2.0f, %2.0f, %2.4f, %2.4f, %d" % [rpm, camera.rotation_degrees.x, $"/root/Main/Player".HEIGHT_AVG, head.y, backwards_counter]
	# Moves HUD around to direction of movement
	# For development purposes
	if started > started_thresh:
		$"../HUD".transform.basis.x = Vector3(direction.z, 0, -direction.x)
		$"../HUD".transform.basis.z = Vector3(direction.x, 0, direction.z)
		var hud_dir := 6.4 * -direction.normalized() # at -6.4 from player
		hud_dir.y = -1.5
		$"../HUD".translation = hud_dir
		
	
	# Detects strafing, user is stepping but tilting head
	# Tilt to left, strafe left
	var strafe_angle = 17
	if camera.rotation_degrees.z > strafe_angle and camera.rotation_degrees.z < 90:
		return (rpm * Vector3(direction.z, direction.y, -direction.x) * 2) if ( (mov != 0 or stopped < stopped_thresh) and started >= started_thresh and rpm > 15) else Vector3(0, 0, 0)
	# Tilt to right, strafe right
	elif camera.rotation_degrees.z > -90 and camera.rotation_degrees.z < -strafe_angle:
		return (rpm * Vector3(-direction.z, direction.y, direction.x) * 2) if ( (mov != 0 or stopped < stopped_thresh) and started >= started_thresh and rpm > 15) else Vector3(0, 0, 0)
	
	
	# Detects backwards walking. Not backwards running
	# User is leaning back slightly meaning height doesnt increase much from average
	# And user has upward head tilt, 7+ degrees
	# backwards stops when user drop head at or below -2 degrees on the x axis
	if backwards_counter >= 15 and camera.rotation_degrees.x > -2 and  head.y >= $"/root/Main/Player".HEIGHT_AVG - 0.05 and rpm < 70:
			not_backwards_counter = 0
			return (rpm * -direction * 2) if ( (mov != 0 or stopped < stopped_thresh) and started >= started_thresh and rpm > 15) else Vector3(0, 0, 0)
	elif direction.dot(camera.transform.basis.z) > 0.85 and camera.rotation_degrees.x > 7 and head.y <= $"/root/Main/Player".HEIGHT_AVG -0.0012 + 0.00115 * (camera.rotation_degrees.x - 7) and  head.y >= $"/root/Main/Player".HEIGHT_AVG - 0.05 and $"/root/Main/Player".BACKWARDS_SET == true:
		backwards_counter += 1
		not_backwards_counter = 0
	else:
		if not_backwards_counter == 5:
			backwards_counter = 0
		else:
			not_backwards_counter += 1
		
		
	emit_signal("player_moved", delta, head, v, vv, mov, direction)
	return (rpm * direction * 2) if ( (mov != 0 or stopped < stopped_thresh) and started >= started_thresh and rpm > 15) else Vector3(0, 0, 0)
		#return mov != 0
	
	#TODO copensate for rotation, i.e. don't trigger steps when just tilting head
	#TODO have separate feature for side vector based on left-right swing. 
	# No matter if left to right or right ot left, use info to build normalised vector. Smooth with separate weights. Perhaps even intergrate head z-movement?
	
	# alternative: could count zero crossing as step, and then give step a certain duration
	# (mov_prev >= 0 and mov < 0 ) or (mov_prev <= 0 and mov > 0)
 
