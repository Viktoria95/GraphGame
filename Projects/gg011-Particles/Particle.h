#pragma once

#include <cstdint>

#include "Math/math.h"
class Particle
{
	friend class Game;
	Egg::Math::float3 position;
	float massDensity;
	Egg::Math::float3 velocity;
	float pressure;
	Egg::Math::float3 temp;
	unsigned int zindex;

	//float lifespan;
	//float age;
public:
	void reborn() {
		using namespace Egg::Math;
		position = float3::random(0.1, 0.9);
//		position.y += 0.05;
//		position.y *= 5.0;
		//position.y += 5.0;

		//position = float3(0.0, 0.5, 0.0);
		massDensity = 0.0;
		velocity = float3 (0.0,0.0,0.0);
		pressure = 0.0;

		//age = 0;
		//lifespan = float1::random(2, 5);
	}
	Particle() { reborn(); }


};

class ControlParticle
{
	friend class Game;
	Egg::Math::float3 position;
	float controlPressureRatio;
	Egg::Math::float3	nonAnimatedPos;
	float	temp;
	Egg::Math::float4	blendWeights;
	Egg::Math::float4	blendIndices; // uint4
};