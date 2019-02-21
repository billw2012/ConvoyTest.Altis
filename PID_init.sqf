// Inspired by https://gist.github.com/bradley219/5373998

params [
	'_obj',
	['_id', ''],
	['_dt', 0.1],
	['_min', -2],
	['_max', 2],
	['_Kp', 0.01],
	['_Kd', 0],
	['_Ki', 0]
];

// last two values are pre-error and integral.
_obj setVariable ["PID_init_" + _id, [_dt, _min, _max, _Kp, _Kd, _Ki]];
_obj setVariable ["PID_data_" + _id, [0, 0]];
