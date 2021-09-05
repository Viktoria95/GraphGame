#pragma once
#include "App/App.h"
#include "Mesh/InputBinder.h"
#include "Mesh/Shaded.h"
#include "Mesh/VertexStream.h"
#include "Mesh/Nothing.h"
#include "Cam/FirstPerson.h"
#include "Particle.h"

#include <array>

class DualQuaternion;

GG_SUBCLASS(Game, Egg::App)
public:	
	//static const unsigned int windowHeight = 720;
	//static const unsigned int windowWidth = 1280;

	static const unsigned int windowHeight = 1024;
	static const unsigned int windowWidth = 1024;

	static const unsigned int fillWindowHeight = 200;
	static const unsigned int fillWindowWidth = 200;

	static const unsigned int counterSize = 3;

private:
	enum BillboardsAlgorithm { Normal, ABuffer, SBuffer, SBufferV2, HashSimple };
	enum RenderMode { Realistic, Gradient, ControlParticles, Particles };
	enum FlowControl { RealisticFlow, ControlledFlow };
	enum ControlParticlePlacement { Vertex, Render, Animated, PBD, CPU };	
	enum Metal { Aluminium, Copper, Gold };
	enum Shading { MetalShading, PhongShading };
	enum MetaballFunction {Simple, Wyvill, Nishimura, Murakami};
	enum WaterShading { SimpleWater, DeepWater };

	// Common
	Egg::Cam::FirstPerson::P firstPersonCam;
	Microsoft::WRL::ComPtr<ID3D11Buffer> modelViewProjCB;
	Microsoft::WRL::ComPtr<ID3D11Buffer> eyePosCB;
	Microsoft::WRL::ComPtr<ID3D11Buffer> shadingCB;
	Microsoft::WRL::ComPtr<ID3D11Buffer> shadingTypeCB;
	Microsoft::WRL::ComPtr<ID3D11Buffer> metaballFunctionCB;
	std::vector<ControlParticle> controlParticles;

	Egg::Mesh::InputBinder::P inputBinder;

	BillboardsAlgorithm billboardsLoadAlgorithm;
	RenderMode renderMode;
	FlowControl flowControl;
	ControlParticlePlacement controlParticlePlacement;
	Metal metalShading;
	Shading shading;
	MetaballFunction metaballFunction;
	WaterShading waterShading;
	bool drawFlatControlMesh;
	bool animtedIsActive;
	bool adapticeControlPressureIsActive;
	bool controlParticleAnimtaionIsActive;

	// Particle
	Microsoft::WRL::ComPtr<ID3D11Buffer> particleDataBuffer;
	Microsoft::WRL::ComPtr<ID3D11ShaderResourceView> particleSRV;
	Microsoft::WRL::ComPtr<ID3D11UnorderedAccessView> particleUAV;

	// Control Particle
	Microsoft::WRL::ComPtr<ID3D11Buffer> controlParticleDataBuffer;
	Microsoft::WRL::ComPtr<ID3D11ShaderResourceView> controlParticleSRV;
	Microsoft::WRL::ComPtr<ID3D11UnorderedAccessView> controlParticleUAV;
	Microsoft::WRL::ComPtr<ID3D11Buffer> controlParticleCounterDataBuffer;
	Microsoft::WRL::ComPtr<ID3D11ShaderResourceView> controlParticleCounterSRV;
	Microsoft::WRL::ComPtr<ID3D11UnorderedAccessView> controlParticleCounterUAV;
	Microsoft::WRL::ComPtr<ID3D11Buffer> controlParticleIndirectDisptachDataBuffer;
	Microsoft::WRL::ComPtr<ID3D11UnorderedAccessView> controlParticleIndirectDisptachUAV;
	Egg::Mesh::Shaded::P controlMesh;
	Egg::Mesh::Shaded::P controlMeshFlat; //Debug
	Egg::Mesh::Shaded::P controlMeshFill;
	float controlMeshScale;
	Egg::Cam::FirstPerson::P fillCam;
	Egg::Mesh::Shaded::P animatedControlMesh;
	Egg::Mesh::Shaded::P animatedControlMeshFlat;
	float animatedControlMeshScale;

	// PBD
	Microsoft::WRL::ComPtr<ID3D11Buffer> controlParticleDefPosDataBuffer;
	Microsoft::WRL::ComPtr<ID3D11ShaderResourceView> controlParticleDefPosSRV;
	Microsoft::WRL::ComPtr<ID3D11UnorderedAccessView> controlParticleDefPosUAV;
	Microsoft::WRL::ComPtr<ID3D11Buffer> controlParticleNewPosDataBuffer;
	Microsoft::WRL::ComPtr<ID3D11ShaderResourceView> controlParticleNewPosSRV;
	Microsoft::WRL::ComPtr<ID3D11UnorderedAccessView> controlParticleNewPosUAV;
	Microsoft::WRL::ComPtr<ID3D11Buffer> controlParticleVelocityDataBuffer;
	Microsoft::WRL::ComPtr<ID3D11ShaderResourceView> controlParticleVelocitySRV;
	Microsoft::WRL::ComPtr<ID3D11UnorderedAccessView> controlParticleVelocityUAV;
	Microsoft::WRL::ComPtr<ID3D11Buffer> CmatCB;
	Egg::Mesh::Shader::P PBDShaderGravity;
	Egg::Mesh::Shader::P PBDShaderCollision;
	Egg::Mesh::Shader::P PBDShaderDistance;
	Egg::Mesh::Shader::P PBDShaderBending;
	Egg::Mesh::Shader::P PBDShaderFinalUpdate;
	std::array<Egg::Mesh::Shader::P, 26> PBDShaderTetrahedron;
	Egg::Mesh::Shader::P PBDShaderSetDefPos;
	Egg::Mesh::Shader::P PBDShaderSphereCollision;

	// Hashtables
	Microsoft::WRL::ComPtr<ID3D11Buffer> clistDataBuffer;
	Microsoft::WRL::ComPtr<ID3D11ShaderResourceView> clistSRV;
	Microsoft::WRL::ComPtr<ID3D11UnorderedAccessView> clistUAV;
	Microsoft::WRL::ComPtr<ID3D11Buffer> clistLengthDataBuffer;
	Microsoft::WRL::ComPtr<ID3D11ShaderResourceView> clistLengthSRV;
	Microsoft::WRL::ComPtr<ID3D11UnorderedAccessView> clistLengthUAV;
	Microsoft::WRL::ComPtr<ID3D11Buffer> clistBeginDataBuffer;
	Microsoft::WRL::ComPtr<ID3D11ShaderResourceView> clistBeginSRV;
	Microsoft::WRL::ComPtr<ID3D11UnorderedAccessView> clistBeginUAV;
	Microsoft::WRL::ComPtr<ID3D11Buffer> clistCellCountDataBuffer;
	Microsoft::WRL::ComPtr<ID3D11ShaderResourceView> clistCellCountSRV;
	Microsoft::WRL::ComPtr<ID3D11UnorderedAccessView> clistCellCountUAV;

	Microsoft::WRL::ComPtr<ID3D11Buffer> hlistDataBuffer;
	Microsoft::WRL::ComPtr<ID3D11ShaderResourceView> hlistSRV;
	Microsoft::WRL::ComPtr<ID3D11UnorderedAccessView> hlistUAV;
	Microsoft::WRL::ComPtr<ID3D11Buffer> hlistLengthDataBuffer;
	Microsoft::WRL::ComPtr<ID3D11ShaderResourceView> hlistLengthSRV;
	Microsoft::WRL::ComPtr<ID3D11UnorderedAccessView> hlistLengthUAV;
	Microsoft::WRL::ComPtr<ID3D11Buffer> hlistBeginDataBuffer;
	Microsoft::WRL::ComPtr<ID3D11ShaderResourceView> hlistBeginSRV;
	Microsoft::WRL::ComPtr<ID3D11UnorderedAccessView> hlistBeginUAV;

	Egg::Mesh::Shader::P clistShaderInit;
	Egg::Mesh::Shader::P clistShaderCompact;
	Egg::Mesh::Shader::P clistShaderLength;
	Egg::Mesh::Shader::P clistShaderSortEven;
	Egg::Mesh::Shader::P clistShaderSortOdd;
	Egg::Mesh::Shader::P hlistShaderInit;
	Egg::Mesh::Shader::P hlistShaderBegin;
	Egg::Mesh::Shader::P hlistShaderLength;

	// Billboard
	Egg::Mesh::Nothing::P billboardNothing;	
	Microsoft::WRL::ComPtr<ID3D11Buffer> billboardSizeCB;

	Egg::Mesh::Shaded::P billboards;
	Egg::Mesh::Shaded::P billboardsControl;
	Egg::Mesh::Shader::P billboardsPixelShaderA;
	Egg::Mesh::Shader::P billboardsPixelShaderS1;
	Egg::Mesh::Shader::P billboardsPixelShaderS2;
	Egg::Mesh::Shader::P billboardsPixelShaderSV21;
	Egg::Mesh::Shader::P billboardsPixelShaderSV22;

	Microsoft::WRL::ComPtr<ID3D11Buffer> offsetBuffer;
	Microsoft::WRL::ComPtr<ID3D11ShaderResourceView> offsetSRV;
	Microsoft::WRL::ComPtr<ID3D11UnorderedAccessView> offsetUAV;

	Microsoft::WRL::ComPtr<ID3D11Buffer> linkBuffer;
	Microsoft::WRL::ComPtr<ID3D11ShaderResourceView> linkSRV;
	Microsoft::WRL::ComPtr<ID3D11UnorderedAccessView> linkUAV;

	Microsoft::WRL::ComPtr<ID3D11Buffer> idBuffer;
	Microsoft::WRL::ComPtr<ID3D11ShaderResourceView> idSRV;
	Microsoft::WRL::ComPtr<ID3D11UnorderedAccessView> idUAV;

	Microsoft::WRL::ComPtr<ID3D11Buffer> countBuffer;
	Microsoft::WRL::ComPtr<ID3D11UnorderedAccessView> countUAV;

	Microsoft::WRL::ComPtr<ID3D11Buffer> counterBuffer;
	Microsoft::WRL::ComPtr<ID3D11ShaderResourceView> counterSRV;
	Microsoft::WRL::ComPtr<ID3D11UnorderedAccessView> counterUAV;

	// Sponge
	Microsoft::WRL::ComPtr<ID3D11ShaderResourceView> spongeDiffuseSRV;
	Microsoft::WRL::ComPtr<ID3D11ShaderResourceView> spongeNormalSRV;
	Microsoft::WRL::ComPtr<ID3D11ShaderResourceView> spongeHeightSRV;

	// Prefix sum
	Microsoft::WRL::ComPtr<ID3D11Buffer> scanBucketSizeCB;

	Microsoft::WRL::ComPtr<ID3D11Buffer> resultBuffer;
	Microsoft::WRL::ComPtr<ID3D11UnorderedAccessView> resultUAV;

	Egg::Mesh::Shader::P prefixSumComputeShader;
	Egg::Mesh::Shader::P prefixSumScanBucketResultShader;
	Egg::Mesh::Shader::P prefixSumScanAddBucketResultShader;

	Egg::Mesh::Shader::P prefixSumV2ComputeShader;


	// Environment
	Microsoft::WRL::ComPtr<ID3D11ShaderResourceView> envSrv;
	Microsoft::WRL::ComPtr<ID3D11SamplerState> samplerState;


	// Metaball
	int testCount;
	int testCount2;
	float radius;
	float metaBallMinToHit;
	int binaryStepCount;
	int maxRecursion;
	int marchCount;
	Egg::Mesh::Shaded::P metaballs;
	Egg::Mesh::Shader::P metaballRealisticPixelShader;
	Egg::Mesh::Shader::P metaballGradientPixelShader;
	Egg::Mesh::Shader::P metaballRealisticAPixelShader;
	Egg::Mesh::Shader::P metaballGradientAPixelShader;
	Egg::Mesh::Shader::P metaballRealisticSPixelShader;
	Egg::Mesh::Shader::P metaballGradientSPixelShader;
	Egg::Mesh::Shader::P metaballRealisticS2PixelShader;
	Egg::Mesh::Shader::P metaballGradientS2PixelShader;
	Egg::Mesh::Shader::P metaballRealisticHashSimpleShader;
	Egg::Mesh::Shader::P metaballGradientHashSimpleShader;

	// Animation
	Egg::Mesh::Shader::P fluidSimulationShader;
	Egg::Mesh::Shader::P controlledFluidSimulationShader;
	Egg::Mesh::Shader::P simpleSortEvenShader;
	Egg::Mesh::Shader::P simpleSortOddShader;
	Egg::Mesh::Shader::P mortonHashShader;
	Egg::Mesh::Shader::P setIndirectDispatchBufferShader;
	Egg::Mesh::Shader::P adaptiveControlPressureShader;
	Egg::Mesh::Shader::P rigControlParticlesShader;
	Egg::Mesh::Shader::P animateControlParticlesShader;
	Microsoft::WRL::ComPtr<ID3D11Buffer> controlParamsCB;
	std::array<float, 8> controlParams;


	// Debug
	Egg::Mesh::Nothing::P cpBillboardNothing;
	Microsoft::WRL::ComPtr<ID3D11Buffer> cpBillboardSizeCB;
	Egg::Mesh::Shaded::P cpBillboards;
	Egg::Mesh::Shader::P billboardsPixelShader;
	Egg::Mesh::Shader::P controlParticleBallPixelShader;
	Egg::Mesh::Shader::P particleBallPixelShader;
	Microsoft::WRL::ComPtr<ID3D11Buffer> debugTypeCB;
	uint debugType;
	const uint maxDebugType = 7;

	Microsoft::WRL::ComPtr<ID3D11Buffer> uavCounterReadback;

	// Skeletal
	int meshIdxInFile;
	float animatedMeshScale;
	int nBones;
	int nInstances;
	int nKeys;
	int nNodes;

	// Sponge
	Egg::Mesh::Shaded::P spongeMesh;

	std::vector<std::string> boneNames;
	//	std::vector<Egg::Math::float4x4> riggingPoseBoneTransforms;
	std::vector<std::vector<unsigned char> > boneTransformationChainNodeIndices;
	std::map<std::string, unsigned char> nodeNamesToNodeIndices;

	unsigned char* skeleton;
	DualQuaternion* keys;
	DualQuaternion* rigging;
	unsigned int currentKey;

	Microsoft::WRL::ComPtr<ID3D11Buffer> boneBuffer;

	Microsoft::WRL::ComPtr<ID3D11Buffer> bonePositionsBufferCB;

public:
	Game(Microsoft::WRL::ComPtr<ID3D11Device> device);
	~Game(void);

	HRESULT createResources();
	HRESULT releaseResources();

	void render(Microsoft::WRL::ComPtr<ID3D11DeviceContext> context);
	void animate(double dt, double t);
	bool processMessage(HWND hWnd,
		UINT uMsg, WPARAM wParam, LPARAM lParam);


	void CreateCommon();
	void CreateParticles();
	void CreateControlMesh();
	void CreateSpongeMesh();
	void CreateControlParticles();
	void CreateBillboard();
	void CreateBillboardForControlParticles();
	void CreatePrefixSum();
	void CreateEnviroment();
	void CreateMetaball();
	void CreateAnimation();	
	void CreateEnvironment();
	void CreateDebug();

	void clearRenderTarget(Microsoft::WRL::ComPtr<ID3D11DeviceContext> context);
	void clearContext(Microsoft::WRL::ComPtr<ID3D11DeviceContext> context);

	void renderParticleBillboard(Microsoft::WRL::ComPtr<ID3D11DeviceContext> context);
	void renderControlParticleBillboard(Microsoft::WRL::ComPtr<ID3D11DeviceContext> context);
	void renderBillboardA(Microsoft::WRL::ComPtr<ID3D11DeviceContext> context);
	void renderBillboardS1(Microsoft::WRL::ComPtr<ID3D11DeviceContext> context);
	void renderBillboardS2(Microsoft::WRL::ComPtr<ID3D11DeviceContext> context);
	void renderBillboardSV21(Microsoft::WRL::ComPtr<ID3D11DeviceContext> context);
	void renderBillboardSV22(Microsoft::WRL::ComPtr<ID3D11DeviceContext> context);

	void renderMetaball(Microsoft::WRL::ComPtr<ID3D11DeviceContext> context);
	void renderControlBalls(Microsoft::WRL::ComPtr<ID3D11DeviceContext> context);
	void renderBalls(Microsoft::WRL::ComPtr<ID3D11DeviceContext> context);
	void renderAnimation(Microsoft::WRL::ComPtr<ID3D11DeviceContext> context);

	void renderSpongeMesh(Microsoft::WRL::ComPtr<ID3D11DeviceContext> context);
	void renderSort(Microsoft::WRL::ComPtr<ID3D11DeviceContext> context);
	void renderInitCList(Microsoft::WRL::ComPtr<ID3D11DeviceContext> context);
	void renderNonZeroPrefix(Microsoft::WRL::ComPtr<ID3D11DeviceContext> context);
	void renderCompactCList(Microsoft::WRL::ComPtr<ID3D11DeviceContext> context);
	void renderLengthCList(Microsoft::WRL::ComPtr<ID3D11DeviceContext> context);
	void renderInitHList(Microsoft::WRL::ComPtr<ID3D11DeviceContext> context);
	void renderSortCList(Microsoft::WRL::ComPtr<ID3D11DeviceContext> context);
	void renderBeginHList(Microsoft::WRL::ComPtr<ID3D11DeviceContext> context);
	void renderLengthHList(Microsoft::WRL::ComPtr<ID3D11DeviceContext> context);

	void renderPrefixSum(Microsoft::WRL::ComPtr<ID3D11DeviceContext> context);
	void renderPrefixSumV2(Microsoft::WRL::ComPtr<ID3D11DeviceContext> context);
	void renderEnvironment(Microsoft::WRL::ComPtr<ID3D11DeviceContext> context);
	void renderControlMesh(Microsoft::WRL::ComPtr<ID3D11DeviceContext> context);
	void renderAnimatedControlMesh(Microsoft::WRL::ComPtr<ID3D11DeviceContext> context);
	void renderAnimatedControlMeshInTPose(Microsoft::WRL::ComPtr<ID3D11DeviceContext> context);
	void renderFlatControlMesh(Microsoft::WRL::ComPtr<ID3D11DeviceContext> context);
	void renderFlatAnimatedControlMesh(Microsoft::WRL::ComPtr<ID3D11DeviceContext> context);
	void renderPBD(Microsoft::WRL::ComPtr<ID3D11DeviceContext> context);
	void renderPBDOnCPU(Microsoft::WRL::ComPtr<ID3D11DeviceContext> context);
	void fillControlParticles(Microsoft::WRL::ComPtr<ID3D11DeviceContext> context);
	void setBufferForIndirectDispatch(Microsoft::WRL::ComPtr<ID3D11DeviceContext> context);
	void setAdaptiveControlPressure(Microsoft::WRL::ComPtr<ID3D11DeviceContext> context);
	void rigControlParticles(Microsoft::WRL::ComPtr<ID3D11DeviceContext> context);
	void animateControlParticles(Microsoft::WRL::ComPtr<ID3D11DeviceContext> context);
	void stepAnimationKey(Microsoft::WRL::ComPtr<ID3D11DeviceContext> context);

	Egg::Math::float3 calculateNormal(Egg::Math::float3 p0, Egg::Math::float3 p1, Egg::Math::float3 p2);
	Egg::Math::float3 calculateBinormal(Egg::Math::float3 p0, Egg::Math::float3 p1, Egg::Math::float3 p2, Egg::Math::float2 t0, Egg::Math::float2 t1, Egg::Math::float2 t2);
	Egg::Math::float3 calculateTangent(Egg::Math::float3 p0, Egg::Math::float3 p1, Egg::Math::float3 p2, Egg::Math::float2 t0, Egg::Math::float2 t1, Egg::Math::float2 t2);
	Microsoft::WRL::ComPtr<ID3D11ShaderResourceView> loadTexture(std::string name);

GG_ENDCLASS
