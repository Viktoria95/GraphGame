#pragma once
#include "App/App.h"
#include "Mesh/InputBinder.h"
#include "Mesh/Shaded.h"
#include "Mesh/VertexStream.h"
#include "Mesh/Nothing.h"
#include "Cam/FirstPerson.h"
#include "Particle.h"

GG_SUBCLASS(Game, Egg::App)
public:
	
	static const unsigned int windowHeight = 720;
	static const unsigned int windowWidth = 1280;

	//static const unsigned int windowHeight = 593;
	//static const unsigned int windowWidth = 1152;

	//static const unsigned int windowHeight = 750;
	//static const unsigned int windowWidth = 1000;

private:
	enum BillboardsAlgorithm { Normal, ABuffer, SBuffer, SBufferFaster };

	// Common
	Egg::Cam::FirstPerson::P firstPersonCam;
	Microsoft::WRL::ComPtr<ID3D11Buffer> modelViewProjCB;

	Egg::Mesh::InputBinder::P inputBinder;
	BillboardsAlgorithm billboardsLoadAlgorithm;	

	// Environment
	Microsoft::WRL::ComPtr<ID3D11ShaderResourceView> envSrv; 

	// Particle
	Microsoft::WRL::ComPtr<ID3D11Buffer> particleDataBuffer;
	Microsoft::WRL::ComPtr<ID3D11ShaderResourceView> particleSRV;
	Microsoft::WRL::ComPtr<ID3D11UnorderedAccessView> particleUAV;

	// Billboard
	Egg::Mesh::Nothing::P billboardNothing;	
	Microsoft::WRL::ComPtr<ID3D11Buffer> billboardSizeCB;
	Egg::Mesh::Shaded::P billboards;
	Egg::Mesh::Shaded::P billboardsSBuffer;

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
	Microsoft::WRL::ComPtr<ID3D11Buffer> metaballVSTransCB;
	Microsoft::WRL::ComPtr<ID3D11Buffer >metaballPSEyePosCB;
	Microsoft::WRL::ComPtr<ID3D11ShaderResourceView> offsetSRV;
	Microsoft::WRL::ComPtr<ID3D11ShaderResourceView> linkSRV;
	Microsoft::WRL::ComPtr<ID3D11ShaderResourceView> idSRV;

	// Prefix sum
	Egg::Mesh::Shader::P prefixSumComputeShader;
	Egg::Mesh::Shader::P prefixSumScanBucketResultShader;
	Egg::Mesh::Shader::P prefixSumScanBucketResult2Shader;
	Egg::Mesh::Shader::P prefixSumScanBucketResult3Shader;
	Egg::Mesh::Shader::P prefixSumScanAddBucketResultShader;
	Egg::Mesh::Shader::P prefixSumScanAddBucketResult2Shader;
	Microsoft::WRL::ComPtr<ID3D11Buffer> scanBucketSizeCB;

	//PrefixSumFast
	Egg::Mesh::Shader::P prefixSumFComputeShader;
	Egg::Mesh::Shader::P prefixSumFComputeShader2;
	Egg::Mesh::Shaded::P prefixSumMesh;

	// Animation
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


	void CreateCommon();
	void CreateParticles();
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
