#include "stdafx.h"
#include "Game.h"
#include "ThrowOnFail.h"
#include "Mesh/Importer.h"
#include "Mesh/Importer.h"
#include "DirectXTex.h"
#include "UtfConverter.h"
#include "DDSTextureLoader.h"
#include <assimp/importer.hpp>      // C++ importer interface
#include <assimp/scene.h>       // Output data structure
#include <assimp/postProcess.h> // Post processing flags
using namespace Egg::Math;

const unsigned int defaultParticleCount = 1024;

Game::Game(Microsoft::WRL::ComPtr<ID3D11Device> device) : Egg::App(device)
{
}

Game::~Game(void)
{
}

HRESULT Game::createResources() {

	using namespace Microsoft::WRL;


		//////////////////
	//////// Common ////////
		//////////////////

	{

		inputBinder = Egg::Mesh::InputBinder::create(device);

		firstPersonCam = Egg::Cam::FirstPerson::create();

	}


		//////////////////
	//////// Particle ////////
		//////////////////

	{
		// Create Particles
		for (int i = 0; i < defaultParticleCount; i++)
			particles.push_back(Particle());

		// particleDataBuffer
		D3D11_BUFFER_DESC particleBufferDesc;
		particleBufferDesc.BindFlags = D3D11_BIND_SHADER_RESOURCE | D3D11_BIND_UNORDERED_ACCESS;
		particleBufferDesc.CPUAccessFlags = 0;
		particleBufferDesc.Usage = D3D11_USAGE_DEFAULT;
		particleBufferDesc.MiscFlags = D3D11_RESOURCE_MISC_BUFFER_STRUCTURED;
		particleBufferDesc.StructureByteStride = sizeof(Particle);
		particleBufferDesc.ByteWidth = particles.size() * sizeof(Particle);

		D3D11_SUBRESOURCE_DATA initialParticleData;
		initialParticleData.pSysMem = &particles.at(0);

		Egg::ThrowOnFail("Could not create particleDataBuffer.", __FILE__, __LINE__) ^
			device->CreateBuffer(&particleBufferDesc, &initialParticleData, particleDataBuffer.GetAddressOf());

	}


		//////////////////
	//////// Billboard ////////
		//////////////////

	{	

		// Vertex Input
		billboardVSNothing = Egg::Mesh::Nothing::create(particles.size(), D3D11_PRIMITIVE_TOPOLOGY_POINTLIST);

		// billboardVSParticleSRV
		D3D11_SHADER_RESOURCE_VIEW_DESC billboardVSParticleSRVDesc;
		billboardVSParticleSRVDesc.ViewDimension = D3D11_SRV_DIMENSION_BUFFER;
		billboardVSParticleSRVDesc.Format = DXGI_FORMAT_UNKNOWN;
		billboardVSParticleSRVDesc.Buffer.FirstElement = 0;
		billboardVSParticleSRVDesc.Buffer.NumElements = particles.size();

		Egg::ThrowOnFail("Could not create billboardVSParticleSRV.", __FILE__, __LINE__) ^
			device->CreateShaderResourceView(particleDataBuffer.Get(), &billboardVSParticleSRVDesc, &billboardVSParticleSRV);

		// billboardGSTransCB
		D3D11_BUFFER_DESC billboardGSTransCBDesc;
		billboardGSTransCBDesc.BindFlags = D3D11_BIND_CONSTANT_BUFFER;
		billboardGSTransCBDesc.ByteWidth = sizeof(Egg::Math::float4x4) * 4;
		billboardGSTransCBDesc.CPUAccessFlags = 0;
		billboardGSTransCBDesc.MiscFlags = 0;
		billboardGSTransCBDesc.StructureByteStride = 0;
		billboardGSTransCBDesc.Usage = D3D11_USAGE_DEFAULT;
		Egg::ThrowOnFail("Failed to create billboardGSTransCB.", __FILE__, __LINE__) ^
			device->CreateBuffer(&billboardGSTransCBDesc, nullptr, billboardGSTransCB.GetAddressOf());

		// billboardGSSizeCB
		D3D11_BUFFER_DESC billboardGSSizeCBDesc;
		billboardGSSizeCBDesc.BindFlags = D3D11_BIND_CONSTANT_BUFFER;
		billboardGSSizeCBDesc.CPUAccessFlags = 0;
		billboardGSSizeCBDesc.MiscFlags = 0;
		billboardGSSizeCBDesc.StructureByteStride = 0;
		billboardGSSizeCBDesc.Usage = D3D11_USAGE_DEFAULT;
		billboardGSSizeCBDesc.ByteWidth = sizeof(Egg::Math::float4) * 1;

		Egg::Math::float4 billboardSize(.1, .1, 0, 0);
		D3D11_SUBRESOURCE_DATA initialBbSize;
		initialBbSize.pSysMem = &billboardSize;

		Egg::ThrowOnFail("Failed to create billboardGSSizeCB.", __FILE__, __LINE__) ^
			device->CreateBuffer(&billboardGSSizeCBDesc, &initialBbSize, billboardGSSizeCB.GetAddressOf());

		// Shaders
		ComPtr<ID3DBlob> billboardVertexShaderByteCode = loadShaderCode("vsBillboard.cso");
		Egg::Mesh::Shader::P billboardVertexShader = Egg::Mesh::Shader::create("vsBillboard.cso", device, billboardVertexShaderByteCode);

		ComPtr<ID3DBlob> billboardGeometryShaderByteCode = loadShaderCode("gsBillboard.cso");
		Egg::Mesh::Shader::P billboardGeometryShader = Egg::Mesh::Shader::create("gsBillboard.cso", device, billboardGeometryShaderByteCode);

		ComPtr<ID3DBlob> firePixelShaderByteCode = loadShaderCode("psBillboard.cso");
		Egg::Mesh::Shader::P billboardPixelShader = Egg::Mesh::Shader::create("psBillboard.cso", device, firePixelShaderByteCode);

		// Binding
		Egg::Mesh::Material::P billboardMaterial = Egg::Mesh::Material::create();
		billboardMaterial->setShader(Egg::Mesh::ShaderStageFlag::Vertex, billboardVertexShader);
		billboardMaterial->setShader(Egg::Mesh::ShaderStageFlag::Geometry, billboardGeometryShader);
		billboardMaterial->setShader(Egg::Mesh::ShaderStageFlag::Pixel, billboardPixelShader);
		billboardMaterial->setCb("billboardGSTransCB", billboardGSTransCB, Egg::Mesh::ShaderStageFlag::Geometry);
		billboardMaterial->setCb("billboardGSSizeCB", billboardGSSizeCB, Egg::Mesh::ShaderStageFlag::Geometry);

		ComPtr<ID3D11InputLayout> billboardInputLayout = inputBinder->getCompatibleInputLayout(billboardVertexShaderByteCode, billboardVSNothing);
		billboards = Egg::Mesh::Shaded::create(billboardVSNothing, billboardMaterial, billboardInputLayout);
	}


		//////////////////
	//////// METABALLS ////////
		//////////////////

	{

		// metaballVSParticleSRV
		D3D11_SHADER_RESOURCE_VIEW_DESC metaballVSParticleSRVDesc;
		metaballVSParticleSRVDesc.ViewDimension = D3D11_SRV_DIMENSION_BUFFER;
		metaballVSParticleSRVDesc.Format = DXGI_FORMAT_UNKNOWN;
		metaballVSParticleSRVDesc.Buffer.FirstElement = 0;
		metaballVSParticleSRVDesc.Buffer.NumElements = particles.size();

		Egg::ThrowOnFail("Could not create metaballVSParticleSRV.", __FILE__, __LINE__) ^
			device->CreateShaderResourceView(particleDataBuffer.Get(), &metaballVSParticleSRVDesc, &metaballVSParticleSRV);

		// metaballVSTransCB
		D3D11_BUFFER_DESC metaballVSTransCBDesc;
		metaballVSTransCBDesc.BindFlags = D3D11_BIND_CONSTANT_BUFFER;
		metaballVSTransCBDesc.ByteWidth = sizeof(Egg::Math::float4x4) * 4;
		metaballVSTransCBDesc.CPUAccessFlags = 0;
		metaballVSTransCBDesc.MiscFlags = 0;
		metaballVSTransCBDesc.StructureByteStride = 0;
		metaballVSTransCBDesc.Usage = D3D11_USAGE_DEFAULT;
		Egg::ThrowOnFail("Failed to create metaballPerObjectConstantBuffer.", __FILE__, __LINE__) ^
			device->CreateBuffer(&metaballVSTransCBDesc, nullptr, metaballVSTransCB.GetAddressOf());

		// metaballPSEyePosCB
		D3D11_BUFFER_DESC metaballPSEyePosCBDesc;
		metaballPSEyePosCBDesc.BindFlags = D3D11_BIND_CONSTANT_BUFFER;
		metaballPSEyePosCBDesc.ByteWidth = sizeof(Egg::Math::float4x4) * 4;
		metaballPSEyePosCBDesc.CPUAccessFlags = 0;
		metaballPSEyePosCBDesc.MiscFlags = 0;
		metaballPSEyePosCBDesc.StructureByteStride = 0;
		metaballPSEyePosCBDesc.Usage = D3D11_USAGE_DEFAULT;
		Egg::ThrowOnFail("Failed to create metaballPerFrameConstantBuffer.", __FILE__, __LINE__) ^
			device->CreateBuffer(&metaballPSEyePosCBDesc, nullptr, metaballPSEyePosCB.GetAddressOf());

		// Shaders
		Egg::Mesh::Geometry::P fullQuadGeometry = Egg::Mesh::Indexed::createQuad(device);

		ComPtr<ID3DBlob> metaballVertexShaderByteCode = loadShaderCode("vsMetaball.cso");
		Egg::Mesh::Shader::P backgroundVertexShader = Egg::Mesh::Shader::create("vsMetaball.cso", device, metaballVertexShaderByteCode);

		ComPtr<ID3DBlob> metaballPixelShaderByteCode = loadShaderCode("psMetaball.cso");
		Egg::Mesh::Shader::P backgroundPixelShader = Egg::Mesh::Shader::create("psMetaball.cso", device, metaballPixelShaderByteCode);

		// Binding
		Egg::Mesh::Material::P metaballMaterial = Egg::Mesh::Material::create();
		metaballMaterial->setShader(Egg::Mesh::ShaderStageFlag::Vertex, backgroundVertexShader);
		metaballMaterial->setShader(Egg::Mesh::ShaderStageFlag::Pixel, backgroundPixelShader);
		metaballMaterial->setCb("metaballVSTransCB", metaballVSTransCB, Egg::Mesh::ShaderStageFlag::Vertex);
		metaballMaterial->setCb("metaballPSEyePosCB", metaballPSEyePosCB, Egg::Mesh::ShaderStageFlag::Pixel);

		ComPtr<ID3D11InputLayout>metaballInputLayout = inputBinder->getCompatibleInputLayout(metaballVertexShaderByteCode, fullQuadGeometry);
		metaballMesh = Egg::Mesh::Shaded::create(fullQuadGeometry, metaballMaterial, metaballInputLayout);
	}
	
		//////////////////
	//////// Animation ////////
		//////////////////

	{
		// Unordered Access View
		D3D11_UNORDERED_ACCESS_VIEW_DESC animationCSParticleUAVDesc;
		animationCSParticleUAVDesc.ViewDimension = D3D11_UAV_DIMENSION_BUFFER;
		animationCSParticleUAVDesc.Format = DXGI_FORMAT_UNKNOWN;
		animationCSParticleUAVDesc.Buffer.FirstElement = 0;
		animationCSParticleUAVDesc.Buffer.NumElements = particles.size();
		animationCSParticleUAVDesc.Buffer.Flags = D3D11_BUFFER_UAV_FLAG_COUNTER; // WHY????

		Egg::ThrowOnFail("Could not create animationUAV.", __FILE__, __LINE__) ^
			device->CreateUnorderedAccessView(particleDataBuffer.Get(), &animationCSParticleUAVDesc, &animationCSParticleUAV);


		// ComputeShader
		ComPtr<ID3DBlob>fluidSimulationShaderByteCode = loadShaderCode("csFluidSimulation.cso");
		fluidSimulationShader = Egg::Mesh::Shader::create("csFluidSimulation.cso", device, fluidSimulationShaderByteCode);

		ComPtr<ID3DBlob>simpleSortEvenShaderByteCode = loadShaderCode("csSimpleSortEven.cso");
		simpleSortEvenShader = Egg::Mesh::Shader::create("csSimpleSortEven.cso", device, simpleSortEvenShaderByteCode);

		ComPtr<ID3DBlob>simpleSortOddShaderByteCode = loadShaderCode("csSimpleSortOdd.cso");
		simpleSortOddShader = Egg::Mesh::Shader::create("csSimpleSortOdd.cso", device, simpleSortOddShaderByteCode);
	}

	return S_OK;
}

HRESULT Game::releaseResources()
{
	billboards.reset();
	return Egg::App::releaseResources();
}

void Game::render(Microsoft::WRL::ComPtr<ID3D11DeviceContext> context)
{
	using namespace Egg::Math;

	// Clear Rendertarget
	{
		context->OMSetRenderTargets(1, defaultRenderTargetView.GetAddressOf(), defaultDepthStencilView.Get());

		float clearColor[4] = { 0.9f, 0.7f, 0.1f, 0.0f };
		context->ClearRenderTargetView(defaultRenderTargetView.Get(), clearColor);
		context->ClearDepthStencilView(defaultDepthStencilView.Get(), D3D11_CLEAR_DEPTH, 1.0, 0);
	}

	// Billboard	
	{
		float4x4 matrices[4];
		matrices[0] = float4x4::identity;
		matrices[1] = float4x4::identity;
		matrices[2] =	(firstPersonCam->getViewMatrix() * firstPersonCam->getProjMatrix());
		matrices[3] = firstPersonCam->getViewDirMatrix();
		context->UpdateSubresource(billboardGSTransCB.Get(), 0, nullptr, matrices, 0, 0);

		context->VSSetShaderResources(0, 1, billboardVSParticleSRV.GetAddressOf());

		//billboards->draw(context);
	}	

	// Clear Context
	{
		UINT pNumViewports = 1;
		D3D11_VIEWPORT pViewports[1];
		context->RSGetViewports(&pNumViewports, pViewports);
		context->ClearState();
		context->RSSetViewports(pNumViewports, pViewports);
		context->OMSetRenderTargets(1, defaultRenderTargetView.GetAddressOf(), defaultDepthStencilView.Get());
	}

	// Metaball
	{
		float4x4 matrices[4];
		matrices[0] = float4x4::identity;
		matrices[1] = float4x4::identity;
		matrices[2] = (firstPersonCam->getViewMatrix() * firstPersonCam->getProjMatrix());
		matrices[3] = firstPersonCam->getViewDirMatrix();
		context->UpdateSubresource(metaballVSTransCB.Get(), 0, nullptr, matrices, 0, 0);

		float4 perFrameVectors[1];
		perFrameVectors[0] = firstPersonCam->getEyePosition().xyz1;
		context->UpdateSubresource(metaballPSEyePosCB.Get(), 0, nullptr, perFrameVectors, 0, 0);

		context->PSSetShaderResources(0, 1, metaballVSParticleSRV.GetAddressOf());

		metaballMesh->draw(context);
	}	

	// Clear Context
	{
		UINT pNumViewports = 1;
		D3D11_VIEWPORT pViewports[1];
		context->RSGetViewports(&pNumViewports, pViewports);
		context->ClearState();
		context->RSSetViewports(pNumViewports, pViewports);
		context->OMSetRenderTargets(1, defaultRenderTargetView.GetAddressOf(), defaultDepthStencilView.Get());
	}


	// Animation
	{
		uint zeros[2] = { 0, 0 };
		context->CSSetShader(static_cast<ID3D11ComputeShader*>(fluidSimulationShader->getShader().Get()), nullptr, 0);
		context->CSSetUnorderedAccessViews(0, 1, animationCSParticleUAV.GetAddressOf(), zeros);
		context->Dispatch(defaultParticleCount, 1, 1);
	}

	// Clear Context
	{
		UINT pNumViewports = 1;
		D3D11_VIEWPORT pViewports[1];
		context->RSGetViewports(&pNumViewports, pViewports);
		context->ClearState();
		context->RSSetViewports(pNumViewports, pViewports);
		context->OMSetRenderTargets(1, defaultRenderTargetView.GetAddressOf(), defaultDepthStencilView.Get());
	}

	// Sort
	{
		uint zeros[2] = { 0, 0 };
		context->CSSetShader(static_cast<ID3D11ComputeShader*>(simpleSortEvenShader->getShader().Get()), nullptr, 0);
		context->CSSetUnorderedAccessViews(0, 1, animationCSParticleUAV.GetAddressOf(), zeros);
		context->Dispatch(defaultParticleCount / 2 - 1, 1, 1);

		context->CSSetShader(static_cast<ID3D11ComputeShader*>(simpleSortOddShader->getShader().Get()), nullptr, 0);
		context->CSSetUnorderedAccessViews(0, 1, animationCSParticleUAV.GetAddressOf(), zeros);
		context->Dispatch(defaultParticleCount / 2 - 2, 1, 1);
	}

	// Clear Context
	{
		UINT pNumViewports = 1;
		D3D11_VIEWPORT pViewports[1];
		context->RSGetViewports(&pNumViewports, pViewports);
		context->ClearState();
		context->RSSetViewports(pNumViewports, pViewports);
		context->OMSetRenderTargets(1, defaultRenderTargetView.GetAddressOf(), defaultDepthStencilView.Get());
	}
}

void Game::animate(double dt, double t)
{
	if (!firstPersonCam) return;
	firstPersonCam->animate(dt);
	
}

bool Game::processMessage(HWND hWnd, UINT uMsg, WPARAM wParam, LPARAM lParam)
{
	if (!firstPersonCam) return false;
	firstPersonCam->processMessage(hWnd, uMsg, wParam, lParam);
	return false;
}
