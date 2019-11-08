#pragma once
#include "App/App.h"
#include "Mesh/InputBinder.h"
#include "Mesh/Shaded.h"
#include "Mesh/VertexStream.h"
#include "Mesh/Nothing.h"
#include "Cam/FirstPerson.h"
#include "Particle.h"


GG_SUBCLASS(Game, Egg::App)

	// Common
	Egg::Cam::FirstPerson::P firstPersonCam;
	Egg::Mesh::InputBinder::P inputBinder;

	// Particle
	std::vector<Particle> particles;	
	Microsoft::WRL::ComPtr<ID3D11Buffer> particleDataBuffer;

	// Billboard
	Egg::Mesh::Nothing::P billboardVSNothing;
	Microsoft::WRL::ComPtr<ID3D11ShaderResourceView> billboardVSParticleSRV;
	Microsoft::WRL::ComPtr<ID3D11Buffer> billboardGSTransCB;
	Microsoft::WRL::ComPtr<ID3D11Buffer> billboardGSSizeCB;
	Egg::Mesh::Shaded::P billboards;

	// Metaball
	Egg::Mesh::Shaded::P metaballMesh;
	Microsoft::WRL::ComPtr<ID3D11ShaderResourceView> metaballVSParticleSRV;
	Microsoft::WRL::ComPtr<ID3D11Buffer> metaballVSTransCB;
	Microsoft::WRL::ComPtr<ID3D11Buffer >metaballPSEyePosCB;

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

GG_ENDCLASS
