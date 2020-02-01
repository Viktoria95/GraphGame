#pragma once
#include "App/App.h"
#include "Mesh/InputBinder.h"
#include "Mesh/Shaded.h"
#include "Mesh/VertexStream.h"
#include "Mesh/Nothing.h"
#include "Cam/FirstPerson.h"
#include "Particle.h"

#include <array>

GG_SUBCLASS(Game, Egg::App)
public:	
	static const unsigned int windowHeight = 720;
	static const unsigned int windowWidth = 1280;

private:
	enum BillboardsAlgorithm { Normal, ABuffer, SBuffer };
	enum RenderMode { Realistic, Gradient, ControlParticles, Particles };
	enum FlowControl { RealisticFlow, ControlledFlow };
	enum ControlParticlePlacement { Vertex, Render };

	// Common
	Egg::Cam::FirstPerson::P firstPersonCam;
	Microsoft::WRL::ComPtr<ID3D11Buffer> modelViewProjCB;
	Microsoft::WRL::ComPtr<ID3D11Buffer> eyePosCB;

	Egg::Mesh::InputBinder::P inputBinder;
	BillboardsAlgorithm billboardsLoadAlgorithm;
	RenderMode renderMode;
	FlowControl flowControl;
	ControlParticlePlacement controlParticlePlacement;

	// Particle
	Microsoft::WRL::ComPtr<ID3D11Buffer> particleDataBuffer;
	Microsoft::WRL::ComPtr<ID3D11ShaderResourceView> particleSRV;
	Microsoft::WRL::ComPtr<ID3D11UnorderedAccessView> particleUAV;

	// Control Particle
	Microsoft::WRL::ComPtr<ID3D11Buffer> controlParticleDataBuffer;
	Microsoft::WRL::ComPtr<ID3D11ShaderResourceView> controlParticleSRV;
	Microsoft::WRL::ComPtr<ID3D11UnorderedAccessView> controlParticleUAV;
	Egg::Mesh::Shaded::P controlMesh;

	// Billboard
	Egg::Mesh::Nothing::P billboardNothing;	
	Microsoft::WRL::ComPtr<ID3D11Buffer> billboardSizeCB;

	Egg::Mesh::Shaded::P billboards;
	Egg::Mesh::Shader::P billboardsPixelShaderA;
	Egg::Mesh::Shader::P billboardsPixelShaderS1;
	Egg::Mesh::Shader::P billboardsPixelShaderS2;

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


	// Prefix sum
	Microsoft::WRL::ComPtr<ID3D11Buffer> scanBucketSizeCB;

	Microsoft::WRL::ComPtr<ID3D11Buffer> resultBuffer;
	Microsoft::WRL::ComPtr<ID3D11UnorderedAccessView> resultUAV;

	Egg::Mesh::Shader::P prefixSumComputeShader;
	Egg::Mesh::Shader::P prefixSumScanBucketResultShader;
	Egg::Mesh::Shader::P prefixSumScanAddBucketResultShader;


	// Environment
	Microsoft::WRL::ComPtr<ID3D11ShaderResourceView> envSrv;
	Microsoft::WRL::ComPtr<ID3D11SamplerState> samplerState;


	// Metaball
	Egg::Mesh::Shaded::P metaballs;
	Egg::Mesh::Shader::P metaballRealisticPixelShader;
	Egg::Mesh::Shader::P metaballRealisticAPixelShader;
	Egg::Mesh::Shader::P metaballRealisticSPixelShader;


	// Animation
	Egg::Mesh::Shader::P fluidSimulationShader;
	Egg::Mesh::Shader::P controlledFluidSimulationShader;
	Egg::Mesh::Shader::P simpleSortEvenShader;
	Egg::Mesh::Shader::P simpleSortOddShader;
	Egg::Mesh::Shader::P mortonHashShader;
	Microsoft::WRL::ComPtr<ID3D11Buffer> controlParamsCB;
	std::array<float, 8> controlParams;


	// Debug
	Egg::Mesh::Shader::P controlParticleBallPixelShader;
	Egg::Mesh::Shader::P particleBallPixelShader;
	Microsoft::WRL::ComPtr<ID3D11Buffer> debugTypeCB;
	uint debugType;
	const uint maxDebugType = 7;

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

	void renderMetaball(Microsoft::WRL::ComPtr<ID3D11DeviceContext> context);
	void renderControlBalls(Microsoft::WRL::ComPtr<ID3D11DeviceContext> context);
	void renderBalls(Microsoft::WRL::ComPtr<ID3D11DeviceContext> context);
	void renderAnimation(Microsoft::WRL::ComPtr<ID3D11DeviceContext> context);
	void renderSort(Microsoft::WRL::ComPtr<ID3D11DeviceContext> context);
	void renderPrefixSum(Microsoft::WRL::ComPtr<ID3D11DeviceContext> context);
	void renderEnvironment(Microsoft::WRL::ComPtr<ID3D11DeviceContext> context);

GG_ENDCLASS
