#include "metaball.hlsli"

StructuredBuffer<uint> idBuffer;

bool MetaBallTest_SBuffer(float3 p, float4 pos, IMetaballTester metaballTester)
{
	float acc = 0.0;

	uint uIndex = (uint)pos.y * (uint)windowWidth + (uint)pos.x;

	uint startIdx;
	if (uIndex > 0) {
		startIdx = offsetBuffer[uIndex - 1];
	}
	else
	{
		startIdx = 0;
	}

	uint endIdx = offsetBuffer[uIndex];

	for (uint i = startIdx; i < endIdx; i++) {
		uint j = idBuffer[i];

		if (metaballTester.testFunction(p, particles[j].position, acc, acc) == true)
		{
			return true;
		}
	}

	return false;
}


float3 Grad_SBuffer(float3 p, float4 pos) {
	uint uIndex = (uint)pos.y * (uint)windowWidth + (uint)pos.x;

	uint startIdx;
	if (uIndex > 0) {
		startIdx = offsetBuffer[uIndex - 1];
	}
	else
	{
		startIdx = 0;
	}

	uint endIdx = offsetBuffer[uIndex];

	float3 grad;
	const float r = metaBallRadius;// 0.005;

	for (int i = startIdx; i < endIdx; i++) {
		uint j = idBuffer[i];
		grad = calculateGrad(p, particles[j].position, grad);
	}

	return grad;
}

class SBufferMetaballVisualizer : IMetaballVisualizer
{
	bool callMetaballTestFunction(float3 p, float4 pos)
	{
		WyvillMetaballTester wyvillMetaballTester;

		return MetaBallTest_SBuffer(p, pos, wyvillMetaballTester);
	}

	float3 callGradientCalculator(float3 p, float4 pos)
	{
		return Grad_SBuffer(p, pos);
	}

	float3 getDiffuseColor(float3 p, float4 pos, float ambientIntensity, float3 lightDir, float3 surfaceColor, float3 lightColor)
	{
		float3 normal = normalize(Grad_SBuffer(p, pos));
		return surfaceColor * (ambientIntensity * lightColor + max(dot(normal, lightDir), 0.0) * lightColor);
	}

	float3 doBinarySearch(bool startInside, float3 startPos, bool endInside, float3 endPos, float4 pos)
	{
		SBufferMetaballVisualizer sBufferMetaballVisualizer;

		return BinarySearch(startInside, startPos, endInside, endPos, pos, sBufferMetaballVisualizer);
	}
};