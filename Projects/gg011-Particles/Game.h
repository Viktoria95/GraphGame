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
	enum BillboardsAlgorithm { Normal, ABuffer, SBuffer, SBufferV2 };
	enum RenderMode { Realistic, Gradient, ControlParticles, Particles };
	enum FlowControl { RealisticFlow, ControlledFlow };
	enum ControlParticlePlacement { Vertex, Render, Animated };	
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

	// Billboard
	Egg::Mesh::Nothing::P billboardNothing;	
	Microsoft::WRL::ComPtr<ID3D11Buffer> billboardSizeCB;

	Egg::Mesh::Shaded::P billboards;
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
	void CreateControlParticles();
	void CreateBillboard();
	void CreatePrefixSum();
	void CreateEnviroment();
	void CreateMetaball();
	void CreateAnimation();	
	void CreateEnvironment();
	void CreateDebug();

	void clearRenderTarget(Microsoft::WRL::ComPtr<ID3D11DeviceContext> context);
	void clearContext(Microsoft::WRL::ComPtr<ID3D11DeviceContext> context);

	void renderBillboardA(Microsoft::WRL::ComPtr<ID3D11DeviceContext> context);
	void renderBillboardS1(Microsoft::WRL::ComPtr<ID3D11DeviceContext> context);
	void renderBillboardS2(Microsoft::WRL::ComPtr<ID3D11DeviceContext> context);
	void renderBillboardSV21(Microsoft::WRL::ComPtr<ID3D11DeviceContext> context);
	void renderBillboardSV22(Microsoft::WRL::ComPtr<ID3D11DeviceContext> context);

	void renderMetaball(Microsoft::WRL::ComPtr<ID3D11DeviceContext> context);
	void renderControlBalls(Microsoft::WRL::ComPtr<ID3D11DeviceContext> context);
	void renderBalls(Microsoft::WRL::ComPtr<ID3D11DeviceContext> context);
	void renderAnimation(Microsoft::WRL::ComPtr<ID3D11DeviceContext> context);
	void renderSort(Microsoft::WRL::ComPtr<ID3D11DeviceContext> context);
	void renderPrefixSum(Microsoft::WRL::ComPtr<ID3D11DeviceContext> context);
	void renderPrefixSumV2(Microsoft::WRL::ComPtr<ID3D11DeviceContext> context);
	void renderEnvironment(Microsoft::WRL::ComPtr<ID3D11DeviceContext> context);
	void renderControlMesh(Microsoft::WRL::ComPtr<ID3D11DeviceContext> context);
	void renderAnimatedControlMesh(Microsoft::WRL::ComPtr<ID3D11DeviceContext> context);
	void renderAnimatedControlMeshInTPose(Microsoft::WRL::ComPtr<ID3D11DeviceContext> context);
	void renderFlatControlMesh(Microsoft::WRL::ComPtr<ID3D11DeviceContext> context);
	void renderFlatAnimatedControlMesh(Microsoft::WRL::ComPtr<ID3D11DeviceContext> context);
	void fillControlParticles(Microsoft::WRL::ComPtr<ID3D11DeviceContext> context);
	void setBufferForIndirectDispatch(Microsoft::WRL::ComPtr<ID3D11DeviceContext> context);
	void setAdaptiveControlPressure(Microsoft::WRL::ComPtr<ID3D11DeviceContext> context);
	void rigControlParticles(Microsoft::WRL::ComPtr<ID3D11DeviceContext> context);
	void animateControlParticles(Microsoft::WRL::ComPtr<ID3D11DeviceContext> context);
	void stepAnimationKey(Microsoft::WRL::ComPtr<ID3D11DeviceContext> context);

GG_ENDCLASS
