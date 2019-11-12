#pragma once
#include "App/App.h"
#include "Mesh/InputBinder.h"
#include "Mesh/Shaded.h"
#include "Mesh/VertexStream.h"
#include "Mesh/Nothing.h"
#include "Cam/FirstPerson.h"
#include "Particle.h"

GG_SUBCLASS(Game, Egg::App)

	enum BillboardsAlgorithm { Normal, ABuffer, SBuffer, SBufferFaster };

	// Common
	Egg::Cam::FirstPerson::P firstPersonCam;
	Egg::Mesh::InputBinder::P inputBinder;
	BillboardsAlgorithm billboardsLoadAlgorithm;
	int windowHeight, windowWidth;

	// Environment
	Egg::Mesh::Shaded::P backgroundMesh;
	Microsoft::WRL::ComPtr<ID3D11Buffer> perObjectConstantBuffer;
	Microsoft::WRL::ComPtr<ID3D11ShaderResourceView> envSrv; 

	// Particle
	std::vector<Particle> particles;	
	Microsoft::WRL::ComPtr<ID3D11Buffer> particleDataBuffer;

	// Billboard
	Egg::Mesh::Nothing::P billboardVSNothing;
	Microsoft::WRL::ComPtr<ID3D11ShaderResourceView> billboardVSParticleSRV;
	Microsoft::WRL::ComPtr<ID3D11Buffer> billboardGSTransCB;
	Microsoft::WRL::ComPtr<ID3D11Buffer> billboardGSSizeCB;
	Egg::Mesh::Shaded::P billboards, billboardsSBuffer;

	Microsoft::WRL::ComPtr<ID3D11Buffer> offsetBuffer;
	Microsoft::WRL::ComPtr<ID3D11UnorderedAccessView> offsetUAV;

	Microsoft::WRL::ComPtr<ID3D11Buffer> resultBuffer;
	Microsoft::WRL::ComPtr<ID3D11UnorderedAccessView> resultUAV;

	Microsoft::WRL::ComPtr<ID3D11Buffer> startBuffer;
	Microsoft::WRL::ComPtr<ID3D11UnorderedAccessView> startUAV;

	Microsoft::WRL::ComPtr<ID3D11Buffer> linkBuffer;
	Microsoft::WRL::ComPtr<ID3D11UnorderedAccessView> linkUAV;

	Microsoft::WRL::ComPtr<ID3D11Buffer> offsetBufferResult;
	Microsoft::WRL::ComPtr<ID3D11UnorderedAccessView> offsetUAVResult;

	Microsoft::WRL::ComPtr<ID3D11Buffer> idBuffer;
	Microsoft::WRL::ComPtr<ID3D11UnorderedAccessView> idUAV;

	Microsoft::WRL::ComPtr<ID3D11Buffer> countBuffer;
	Microsoft::WRL::ComPtr<ID3D11UnorderedAccessView> countUAV;

	// Metaball
	Egg::Mesh::Shaded::P metaballMesh;
	Microsoft::WRL::ComPtr<ID3D11ShaderResourceView> metaballVSParticleSRV;
	Microsoft::WRL::ComPtr<ID3D11Buffer> metaballVSTransCB;
	Microsoft::WRL::ComPtr<ID3D11Buffer >metaballPSEyePosCB;
	Microsoft::WRL::ComPtr<ID3D11ShaderResourceView> offsetSRV;
	Microsoft::WRL::ComPtr<ID3D11ShaderResourceView> linkSRV;
	Microsoft::WRL::ComPtr<ID3D11ShaderResourceView> idSRV;

	// Prefix sum
	Egg::Mesh::Shader::P prefixSumComputeShader;
	Egg::Mesh::Shader::P prefixSumScanBucketResultShader;
	Egg::Mesh::Shader::P prefixSumScanBucketResult2Shader;
	Egg::Mesh::Shader::P prefixSumScanAddBucketResultShader;
	Egg::Mesh::Shader::P prefixSumScanAddBucketResult2Shader;

	//PrefixSumFast
	Egg::Mesh::Shader::P prefixSumFComputeShader;
	Egg::Mesh::Shader::P prefixSumFComputeShader2;
	Egg::Mesh::Shaded::P prefixSumMesh;

	// Animation
	Microsoft::WRL::ComPtr<ID3D11UnorderedAccessView> animationCSParticleUAV;
	Egg::Mesh::Shader::P fluidSimulationShader;
	Egg::Mesh::Shader::P simpleSortEvenShader;
	Egg::Mesh::Shader::P simpleSortOddShader;

public:
	Game(Microsoft::WRL::ComPtr<ID3D11Device> device);
	~Game(void);

	HRESULT createResources();
	HRESULT releaseResources();

	void render(Microsoft::WRL::ComPtr<ID3D11DeviceContext> context);
	void animate(double dt, double t);
	bool processMessage(HWND hWnd,
		UINT uMsg, WPARAM wParam, LPARAM lParam);

	void createParticles();
	void createBillboard();
	void createMetaball();
	void createAnimation();
	void createPrefixSum();
	void createEnvironment();

	void clearRenderTarget(Microsoft::WRL::ComPtr<ID3D11DeviceContext> context);
	void clearContext(Microsoft::WRL::ComPtr<ID3D11DeviceContext> context);
	void renderBillboard(Microsoft::WRL::ComPtr<ID3D11DeviceContext> context);
	void renderBillboardWithSBuffer(Microsoft::WRL::ComPtr<ID3D11DeviceContext> context);
	void renderMetaball(Microsoft::WRL::ComPtr<ID3D11DeviceContext> context);
	void renderAnimation(Microsoft::WRL::ComPtr<ID3D11DeviceContext> context);
	void renderSort(Microsoft::WRL::ComPtr<ID3D11DeviceContext> context);
	void renderPrefixSum(Microsoft::WRL::ComPtr<ID3D11DeviceContext> context);
	void renderEnvironment(Microsoft::WRL::ComPtr<ID3D11DeviceContext> context);

GG_ENDCLASS
