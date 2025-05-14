extends Node3D

@export var targetWeight : float
@export var alignWeight : float
@export var cohesionWeight : float
@export var seperateWeight : float
@export var avoidCollisionWeight : float
@export var minSpeed : float
@export var maxSpeed : float
@export var maxSteerForce : float

var target = null
var velocity : Vector3
var numPerceivedFlockmates : float # whole number
var centreOfFlockmates : Vector3
var avgFlockHeading : Vector3
var avgAvoidanceHeading : Vector3

func SteerTowards(vector : Vector3) -> Vector3:
	var v : Vector3 = vector.normalized() * maxSpeed - velocity;
	var speed : float = v.length()
	v = v.normalized() * minf(speed, maxSteerForce)
	return v


#for (int indexB = 0; indexB < numBoids; indexB ++) {
	#if (id.x != indexB) {
		#Boid boidB = boids[indexB];
		#float3 offset = boidB.position - boids[id.x].position;
		#float sqrDst = offset.x * offset.x + offset.y * offset.y + offset.z * offset.z;
#
		#if (sqrDst < viewRadius * viewRadius) {
			#boids[id.x].numFlockmates += 1;
			#boids[id.x].flockHeading += boidB.direction;
			#boids[id.x].flockCentre += boidB.position;
#
			#if (sqrDst < avoidRadius * avoidRadius) {
				#boids[id.x].separationHeading -= offset / sqrDst;
			#}
		#}
	#}


func UpdateBoid (delta):
	var acceleration : Vector3 = Vector3.ZERO

	if (numPerceivedFlockmates != 0):
		centreOfFlockmates /= numPerceivedFlockmates
		var offsetToFlockmatesCentre : Vector3 = (centreOfFlockmates - position);
		
		var alignmentForce = SteerTowards(avgFlockHeading) * alignWeight;
		var cohesionForce = SteerTowards(offsetToFlockmatesCentre) * cohesionWeight;
		var seperationForce = SteerTowards(avgAvoidanceHeading) * seperateWeight;
		
		acceleration += alignmentForce;
		acceleration += cohesionForce;
		acceleration += seperationForce;
	
	velocity += acceleration * delta;
	var speed : float = velocity.length();
	var dir : Vector3 = velocity / speed;
	speed = clampf(speed, minSpeed, maxSpeed);
	velocity = dir * speed;
	
	position += velocity * delta;
