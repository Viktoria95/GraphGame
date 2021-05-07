#include "metaball.hlsli"

float distanceFromSphere(float3 p, float3 center, float r) {
	return length(p - center) - r;
}

bool mapTheWorld(float3 p, float TotalDistanceTraveled, out float TotalDistanceTraveledOut) {
	const float MinimumHitDistance = 0.001;
	TotalDistanceTraveledOut = TotalDistanceTraveled;

	float sphere0 = distanceFromSphere(p, float3(0.0, 0.0, 0.0), 1.0);
	TotalDistanceTraveledOut = TotalDistanceTraveledOut + sphere0;
	if (sphere0 < MinimumHitDistance)
		return true;
	return false;

}

float mapTheWorld2(float3 p) {
	float sphere0 = distanceFromSphere(p, float3(0.0, 0.0, 0.0), 1.0);
	return sphere0;
}

float3 calculateGradient(float3 p) {
	const float3 smallStep = float3(0.001, 0.0, 0.0);
	float gradientX = mapTheWorld2(p + smallStep.xyy) - mapTheWorld2(p - smallStep.xyy);
	float gradientY = mapTheWorld2(p + smallStep.yxy) - mapTheWorld2(p - smallStep.yxy);
	float gradientZ = mapTheWorld2(p + smallStep.yyx) - mapTheWorld2(p - smallStep.yyx);

	float3 normal = float3(gradientX, gradientY, gradientZ);

	return normalize(normal);
}

bool testFunction(float3 p, float3 position, float acc, out float accOut)
{
    /*const float MinimumHitDistance = 0.001;
	float r = abs(distance(p, position));
	float res = (1.0 / (r*r)) * (1.0 / (r*r));
	accOut = acc + res;
	if (accOut > MinimumHitDistance)
	{
		return true;
	}
	return false; */

	
	//ez a jo 

	const float MinimumHitDistance = 0.1;
	float res = 1.0 / ((p.x - position.x)*(p.x - position.x) + (p.y - position.y)*(p.y - position.y) + (p.z - position.z)*(p.z - position.z));
	if (abs(distance(p, position)) < 1.0)
		accOut = acc + res;
	if (accOut > MinimumHitDistance)
	{
		return true;
	}
	return false; 

	/*
	float r = 0.0;
	float b = 4.0;
	float a = 1.1;

	r = abs(distance(p, position));

	float res = (-4.0 / 9.0) * pow(r / b, 6) + (17.0 / 9.0)*pow(r / b, 4) - (22.0 / 9.0)*pow(r / b, 2) + 1;

	if (r < b) {
		accOut = acc + a*res;
	}

	if (accOut > metaBallMinToHit.x)
	{
		return true;
	}

	return false;*/
}

bool testAllMetaballs(float3 p, float TotalDistanceTraveled, out float TotalsDistanceTraveledOut) {
	float acc = 0.0;

	for (int i = 0; i < metaballCount; i++) {
		if (testFunction(p, particles[i].position, acc, acc) == true)
		{
			//TotalsDistanceTraveledOut = TotalDistanceTraveled + (length(p - particles[i].position));
			return true;
		}
		TotalsDistanceTraveledOut = TotalDistanceTraveled + 0.24;// length(p - float3(particles[i].position));
	}

	return false;
}

float3 calculateGradForMetaball(float3 p, float3 position, float3 grad)
{
	float3 gradOut = grad;
	float weight = (pow((-2.0*1.0), 2.0) / pow(length(p - float3(position)), 3.0)) * ((-1.0) / (2.0*length(p - float3(position))));
	gradOut.x += (weight * (p.x - position.x));
	gradOut.y += (weight * (p.y - position.y));
	gradOut.z += (weight * (p.z - position.z));

	return gradOut;
}

float3 GradForMetaball(float3 p) {
	float3 grad = float3(0.0,0.0,0.0);

	for (int i = 0; i < metaballCount; i++) {
		grad = calculateGrad(p, particles[i].position, grad);
	}

	return grad;
}

float4 calculateSimpleColor(float3 currentPos, float3 rayDir) {
	float3 normal = normalize(GradForMetaball(currentPos));
	float3 ref = reflect(normalize(rayDir), normal);
	return float4(normal * (1.0/(length(eyePos-currentPos) / 10.0)), 1.0);// envTexture.SampleLevel(ss, ref, 0);
}

float4 calculateComplexColor(float3 rayDir) {
	const int NumberOfSteps = 400;

	RayMarchHit firstElem;
	firstElem.position = eyePos;
	firstElem.direction = normalize(rayDir);
	firstElem.recursionDepth = 0;
	firstElem.alfa = 1.0;

	RayMarchHit stack[16];
	uint stackSize = 1;
	stack[0] = firstElem;

	float3 color = float3(0.0, 0.0, 0.0);

	float TotalDistanceTraveled = 0.0;

	float3 marchPos = stack[stackSize].position;
	float3 marchDir = stack[stackSize].direction;

	uint killer = 10;
	[loop]
	while (stackSize > 0 && killer > 0)
	{
		killer--;
		stackSize--;

		marchPos = stack[stackSize].position;
		marchDir = stack[stackSize].direction;
		uint marchRecursionDepth = stack[stackSize].recursionDepth;
		float marchAlfa = stack[stackSize].alfa;

		if (marchRecursionDepth < 2) 
		{
			bool startedInside = testAllMetaballs(marchPos, TotalDistanceTraveled, TotalDistanceTraveled);
			//float3 start = marchPos;
			//float3 marchStep = marchDir * 10.0 / float(marchCount);
			marchPos += TotalDistanceTraveled * marchDir;// +TotalDistanceTraveled * marchDir;
			//marchPos += marchDir * tStart;

			bool marchHit = false;
			for (int i = 0; i < NumberOfSteps && !marchHit; i++)
			{
				bool inside = testAllMetaballs(marchPos, TotalDistanceTraveled, TotalDistanceTraveled);
				if (inside && !startedInside || !inside && startedInside)
				{
					marchHit = true;

					//marchPos = metaballVisualizer.doBinarySearch(startedInside, start, inside, marchPos, pos);

					float distance = length(marchPos - stack[stackSize].position);
					float i0 = 1.0f;

					float3 normal = normalize(GradForMetaball(marchPos));
					float refractiveIndex = 1.3325;
					if (dot(normal, marchDir) > 0) {
						normal = -normal;
						refractiveIndex = 1.0 / refractiveIndex;
					}

					float fresnelAlfa = Fresnel(normalize(marchDir), normalize(normal), refractiveIndex);
					float reflectAlfa = fresnelAlfa * marchAlfa * (i0);
					float refractAlfa = (1.0 - fresnelAlfa) * marchAlfa * (i0);

					float3 refractDir = refract(marchDir, normal, 1.0 / refractiveIndex);

					if (reflectAlfa > 0.01)
					{
						RayMarchHit reflectElem;
						reflectElem.direction = reflect(marchDir, normal);
						reflectElem.position = marchPos + normal * 0.1;
						reflectElem.recursionDepth = marchRecursionDepth + 1;
						reflectElem.alfa = reflectAlfa;

						stack[stackSize] = reflectElem;
						stackSize++;
					}

					if (refractAlfa > 0.01)
					{
						RayMarchHit refractElem;
						refractElem.direction = refractDir;
						refractElem.position = marchPos;
						refractElem.recursionDepth = marchRecursionDepth + 1;
						refractElem.alfa = refractAlfa;

						stack[stackSize] = refractElem;
						stackSize++;
					}
				}
				marchPos = eyePos + TotalDistanceTraveled * marchDir;
			}

			if (!marchHit)
			{
				color += envTexture.SampleLevel(ss, marchDir, 0) * marchAlfa;
			}

		}
		else
		{
			color += envTexture.SampleLevel(ss, marchDir, 0) * marchAlfa;
		}

	}

	if (killer == 0)
	{
		//return float4 (1.0, 0.0, 0.0, 1.0);
	}

	return float4(marchDir * (1.0 / (length(eyePos - marchPos) / 10.0)), 1.0);

}

float4 psSimpleMetaball(VsosQuad input) : SV_Target
{	
	float3 p = eyePos;
	float3 d = normalize(input.rayDir);

	if (functionType == 0)
		return envTexture.Sample(ss, d);

	const int NumberOfSteps = 500;
	const float MinimumHitDistance = 0.001;
	const float MaximumHitDistance = 1000.0;
	float TotalDistanceTraveled = 0.0;

	for (int i = 0; i < NumberOfSteps; i++)
	{
		float3 currentPos = eyePos + TotalDistanceTraveled * d;
		/*
		if (mapTheWorld(currentPos, TotalDistanceTraveled, TotalDistanceTraveled)) {
			float3 normal = calculateGradient(currentPos);
			float3 ref = reflect(normalize(input.rayDir), normal);
			return envTexture.SampleLevel(ss, ref, 0);
		}
*/
		bool test = testAllMetaballs(currentPos, TotalDistanceTraveled, TotalDistanceTraveled);

		if (test) {
			if ((int)type == 0)
				return calculateSimpleColor(currentPos, input.rayDir);
			else 
				return calculateComplexColor(input.rayDir);
		}

		if (TotalDistanceTraveled > MaximumHitDistance) {
			break;
		}
	}

	return float4(0.0, 0.0, 0.0, 1.0);//envTexture.Sample(ss, d);
}



