
#include "particle.hlsli"

RWStructuredBuffer<ControlParticle> controlParticles;

cbuffer bonePositionsCB {
	float4 boneBuffer[53]; //TODO actual number
};

cbuffer modelViewProjCB {
	row_major float4x4 modelMatrix;
	row_major float4x4 modelViewProjMatrixInverse;
	row_major float4x4 modelViewProjMatrix;
	row_major float4x4 rayDirMatrix;
};

[numthreads(1, 1, 1)]
void csRigControlParticles(uint3 DTid : SV_GroupID)
{	
	
	unsigned int tid = DTid.x;

	//float3 pos = mul(float4(controlParticles[tid].position,1.0), modelViewProjMatrixInverse);
	float3 pos = controlParticles[tid].position;

	uint idxOfMinDist = 0;
	float minDist = length(pos - boneBuffer[0].xyz);
	for (int i = 1; i < 53; i++)
	{	
		float currentDist = length(pos - boneBuffer[i].xyz);
		if (currentDist < minDist)
		{
			minDist = currentDist;
			idxOfMinDist = i;
		}
	}

	controlParticles[tid].nonAnimatedPos = controlParticles[tid].position;
	controlParticles[tid].blendWeights = float4(1.0, 0.0, 0.0, 0.0);
	controlParticles[tid].blendIndices = uint4(idxOfMinDist, 1, 1, 1);
	controlParticles[tid].temp = minDist;
	//controlParticles[tid].blendIndices = uint4(tid%40, 1, 1, 1);
	
}


