params [
	'_obj',
	['_id', ""],
	'_setpoint',
	'_pv'
];

// Unpack data from the PID variable
private _init = _obj getVariable "PID_init_" + _id;
private _dt = _init select 0;
private _min = _init select 1;
private _max = _init select 2;
private _Kp = _init select 3;
private _Kd = _init select 4;
private _Ki = _init select 5;

private _data = _obj getVariable "PID_data_" + _id;
private _pre_error = _data select 0;
private _integral = _data select 1;

// Calculate error
private _error = _setpoint - _pv;

// Proportional term
private _Pout = _Kp * _error;

// Integral term
_integral = _integral + (_error * _dt);
private _Iout = _Ki * _integral;

// Derivative term
private _derivative = (_error - _pre_error) / _dt;
private _Dout = _Kd * _derivative;

// Calculate total output
private _output = _Pout + _Iout + _Dout;

// Restrict to max/min
_output = _min max (_max min _output);
// if( _output > _max ) then {_output = _max} else { 
// 	if( output < _min )
// 		_output = _min;
// };

// Save error to previous error
_pre_error = _error;

_obj setVariable ["PID_data_" + _id, [_pre_error, _integral]];

_output