
#define particleCount 1024

#define controlParticleCount 1024

#define boundarySide 0.15
#define boundaryBottom 0.0
#define boundaryTop 1.0

#define mortonBinPerAxis 

struct Particle
{
	float3	position;
	float	massDensity;
	float3	velocity;
	float	pressure;
	float3 temp;
	uint zindex;
};

struct ControlParticle
{
	float3	position;
	float	pressure;
};

