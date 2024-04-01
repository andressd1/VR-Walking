extends Node

export(bool) var LOGGING_ENABLED := false
export(float) var logging_duration := 30.0
export(String) var email
export(String) var password

var started_logging := false

var t := 0.0
var t_array : PoolRealArray = []
var head_array : PoolVector3Array = []
var v_array : PoolVector3Array = []
var vv_array : PoolVector3Array = []
var mov_array : PoolRealArray = []
var direction_array : PoolVector3Array = []


func _ready():
	if not LOGGING_ENABLED:
		return
	
	get_node("../HUD/Viewport/Label").text = "logging in..."
	Firebase.Auth.connect("login_succeeded", self, "_on_login_succeeded")
	Firebase.Auth.connect("login_failed", self, "_on_login_failed")
	
	Firebase.Auth.login_with_email_and_password(email, password)


func _on_login_succeeded(auth):
	print("login succeeded")
	var user = Firebase.Auth.get_user_data()
	print(user)
	get_node("../HUD/Viewport/Label").text = "login succeeded"


func _on_login_failed(error_code, message):
	print("error code: " + str(error_code))
	print("message: " + str(message))
	get_node("../HUD/Viewport/Label").text = "login error: %s %s" % [str(error_code), str(message)]


func _on_StepDetector_player_moved(delta, head, v, vv, mov, direction):
	if not LOGGING_ENABLED:
		return
	
	t += delta
	t_array.append(t)
	head_array.append(head)
	v_array.append(v)
	vv_array.append(vv)
	mov_array.append(mov)
	direction_array.append(direction)
	
	if t >= logging_duration:
		LOGGING_ENABLED = false
		save_log()


func save_log():
	if t_array.size() == 0:
		return
	
	get_node("../HUD/Viewport/Label").text = "writing data..."
	var dateTime = OS.get_datetime()
	# TODO add leading 0s for month, day, hour, minute
	var fileName := "walking-trackingdata-%s-%s-%s-%s%s.csv" % [str(dateTime.year), str(dateTime.month), str(dateTime.day), str(dateTime.hour), str(dateTime.minute)]
	var ref = Firebase.Storage.ref(fileName)
	var data := "t, head_x, head_y, head_z, v_x, v_y, v_z, vv_x, vv_y, vv_z, mov, d_x, d_z\n"
	for i in t_array.size():
		data += "%f, %f, %f, %f, %f, %f, %f, %f, %f, %f, %f, %f, %f\n" \
			% [t_array[i], 
				head_array[i].x, head_array[i].y, head_array[i].z,
				v_array[i].x, v_array[i].y, v_array[i].z,
				vv_array[i].x, vv_array[i].y, vv_array[i].z, 
				mov_array[i],
				direction_array[i].x, direction_array[i].z]
	ref.put_data(data.to_utf8())
	get_node("../HUD/Viewport/Label").text = "written data"
