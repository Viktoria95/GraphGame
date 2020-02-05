#pragma once
#include "Math/math.h"


class DualQuaternion
{
public:
	Egg::Math::float4 orientation;
	Egg::Math::float4 translation;

	DualQuaternion(){}
	DualQuaternion(const Egg::Math::float4& orientation, const Egg::Math::float4& translation);

	void set(const Egg::Math::float4& orientation, const Egg::Math::float4& translation);

	void operator*=(const DualQuaternion& other);
};
