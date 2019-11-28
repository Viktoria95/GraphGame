#include "stdafx.h"
#include "Game.h"
#include "ThrowOnFail.h"
#include "Mesh/Importer.h"
#include "Mesh/Importer.h"
#include "DirectXTex.h"
#include "UtfConverter.h"
#include "DDSTextureLoader.h"
#include <assimp/importer.hpp>      
#include <assimp/scene.h>       
#include <assimp/postProcess.h> 
using namespace Egg::Math;

const unsigned int defaultParticleCount = 1024;
const unsigned int linkbufferSizePerPixel = 256;
const unsigned int sbufferSizePerPixel = 256;

Game::Game(Microsoft::WRL::ComPtr<ID3D11Device> device) : Egg::App(device)
{
}

Game::~Game(void)
{
}

HRESULT Game::createResources()
{
	CreateCommon();
	CreateParticles();
	createBillboard();
	createPrefixSum();
	createMetaball();
	createAnimation();

	return S_OK;
}

void Game::CreateCommon()
{
	inputBinder = Egg::Mesh::InputBinder::create(device);

	firstPersonCam = Egg::Cam::FirstPerson::create();

	billboardsLoadAlgorithm = SBuffer;

	// billboardGSTransCB
	D3D11_BUFFER_DESC modelViewProjCBDesc;
	modelViewProjCBDesc.BindFlags = D3D11_BIND_CONSTANT_BUFFER;
	modelViewProjCBDesc.ByteWidth = sizeof(Egg::Math::float4x4) * 4;
	modelViewProjCBDesc.CPUAccessFlags = 0;
	modelViewProjCBDesc.MiscFlags = 0;
	modelViewProjCBDesc.StructureByteStride = 0;
	modelViewProjCBDesc.Usage = D3D11_USAGE_DEFAULT;
	Egg::ThrowOnFail("Failed to create billboardGSTransCB.", __FILE__, __LINE__) ^
		device->CreateBuffer(&modelViewProjCBDesc, nullptr, modelViewProjCB.GetAddressOf());
}

void Game::CreateParticles()
{
	std::vector<Particle> particles;

	// Create Particles
	for (int i = 0; i < defaultParticleCount; i++)
		particles.push_back(Particle());


	// Data Buffer
	D3D11_BUFFER_DESC particleBufferDesc;
	particleBufferDesc.BindFlags = D3D11_BIND_SHADER_RESOURCE | D3D11_BIND_UNORDERED_ACCESS;
	particleBufferDesc.CPUAccessFlags = 0;
	particleBufferDesc.Usage = D3D11_USAGE_DEFAULT;
	particleBufferDesc.MiscFlags = D3D11_RESOURCE_MISC_BUFFER_STRUCTURED;
	particleBufferDesc.StructureByteStride = sizeof(Particle);
	particleBufferDesc.ByteWidth = defaultParticleCount * sizeof(Particle);

	D3D11_SUBRESOURCE_DATA initialParticleData;
	initialParticleData.pSysMem = &particles.at(0);

	Egg::ThrowOnFail("Could not create particleDataBuffer.", __FILE__, __LINE__) ^
		device->CreateBuffer(&particleBufferDesc, &initialParticleData, particleDataBuffer.GetAddressOf());


	// Shader Resource View
	D3D11_SHADER_RESOURCE_VIEW_DESC particleSRVDesc;
	particleSRVDesc.ViewDimension = D3D11_SRV_DIMENSION_BUFFER;
	particleSRVDesc.Format = DXGI_FORMAT_UNKNOWN;
	particleSRVDesc.Buffer.FirstElement = 0;
	particleSRVDesc.Buffer.NumElements = defaultParticleCount;

	Egg::ThrowOnFail("Could not create metaballVSParticleSRV.", __FILE__, __LINE__) ^
		device->CreateShaderResourceView(particleDataBuffer.Get(), &particleSRVDesc, &particleSRV);


	// Unordered Access View
	D3D11_UNORDERED_ACCESS_VIEW_DESC particleUAVDesc;
	particleUAVDesc.ViewDimension = D3D11_UAV_DIMENSION_BUFFER;
	particleUAVDesc.Format = DXGI_FORMAT_UNKNOWN;
	particleUAVDesc.Buffer.FirstElement = 0;
	particleUAVDesc.Buffer.NumElements = defaultParticleCount;
	particleUAVDesc.Buffer.Flags = D3D11_BUFFER_UAV_FLAG_COUNTER; // WHY????

	Egg::ThrowOnFail("Could not create animationUAV.", __FILE__, __LINE__) ^
		device->CreateUnorderedAccessView(particleDataBuffer.Get(), &particleUAVDesc, &particleUAV);
}

void Game::createBillboard() {
	using namespace Microsoft::WRL;

	// Vertex Input
	billboardNothing = Egg::Mesh::Nothing::create(defaultParticleCount, D3D11_PRIMITIVE_TOPOLOGY_POINTLIST);

	// billboardGSSizeCB
	D3D11_BUFFER_DESC billboardSizeCBDesc;
	billboardSizeCBDesc.BindFlags = D3D11_BIND_CONSTANT_BUFFER;
	billboardSizeCBDesc.CPUAccessFlags = 0;
	billboardSizeCBDesc.MiscFlags = 0;
	billboardSizeCBDesc.StructureByteStride = 0;
	billboardSizeCBDesc.Usage = D3D11_USAGE_DEFAULT;
	billboardSizeCBDesc.ByteWidth = sizeof(Egg::Math::float4) * 1;

	Egg::Math::float4 billboardSize(.1, .1, 0, 0);
	D3D11_SUBRESOURCE_DATA initialBbSize;
	initialBbSize.pSysMem = &billboardSize;

	Egg::ThrowOnFail("Failed to create billboardGSSizeCB.", __FILE__, __LINE__) ^
		device->CreateBuffer(&billboardSizeCBDesc, &initialBbSize, billboardSizeCB.GetAddressOf());

	// TODO
	// scanBucketSizeCB
	D3D11_BUFFER_DESC scanBucketSizeCBDesc;
	scanBucketSizeCBDesc.BindFlags = D3D11_BIND_CONSTANT_BUFFER;
	scanBucketSizeCBDesc.CPUAccessFlags = 0;
	scanBucketSizeCBDesc.MiscFlags = 0;
	scanBucketSizeCBDesc.StructureByteStride = 0;
	scanBucketSizeCBDesc.Usage = D3D11_USAGE_DEFAULT;
	scanBucketSizeCBDesc.ByteWidth = sizeof(Egg::Math::int1)*4;

	Egg::Math::int1 scanSize(0);
	D3D11_SUBRESOURCE_DATA initialScanSize;
	initialScanSize.pSysMem = &scanSize;

	Egg::ThrowOnFail("Failed to create scanBucketSizeCB.", __FILE__, __LINE__) ^
		device->CreateBuffer(&scanBucketSizeCBDesc, &initialScanSize, scanBucketSizeCB.GetAddressOf());

	// Shaders
	ComPtr<ID3DBlob> billboardVertexShaderByteCode = loadShaderCode("vsBillboard.cso");
	Egg::Mesh::Shader::P billboardVertexShader = Egg::Mesh::Shader::create("vsBillboard.cso", device, billboardVertexShaderByteCode);

	ComPtr<ID3DBlob> billboardGeometryShaderByteCode = loadShaderCode("gsBillboard.cso");
	Egg::Mesh::Shader::P billboardGeometryShader = Egg::Mesh::Shader::create("gsBillboard.cso", device, billboardGeometryShaderByteCode);

	/*
	ComPtr<ID3DBlob> billboardPixelShaderByteCode;
	Egg::Mesh::Shader::P billboardPixelShader;

	
	if (billboardsLoadAlgorithm == ABuffer || billboardsLoadAlgorithm == Normal) {
		billboardPixelShaderByteCode = loadShaderCode("psBillboardA.cso");
		billboardPixelShader = Egg::Mesh::Shader::create("psBillboardA.cso", device, billboardPixelShaderByteCode);
	}
	if (billboardsLoadAlgorithm == SBuffer) {
		billboardPixelShaderByteCode = loadShaderCode("psBillboardS.cso");
		billboardPixelShader = Egg::Mesh::Shader::create("psBillboardS.cso", device, billboardPixelShaderByteCode);
	}
	*/

	ComPtr<ID3DBlob> billboardPixelShaderAByteCode = loadShaderCode("psBillboardA.cso");
	billboardsPixelShaderA = Egg::Mesh::Shader::create("psBillboardA.cso", device, billboardPixelShaderAByteCode);

	ComPtr<ID3DBlob> billboardPixelShaderS1ByteCode = loadShaderCode("psBillboardS1.cso");
	billboardsPixelShaderS1 = Egg::Mesh::Shader::create("psBillboardS1.cso", device, billboardPixelShaderS1ByteCode);

	ComPtr<ID3DBlob> billboardsPixelShaderS2ByteCode = loadShaderCode("psBillboardS2.cso");
	billboardsPixelShaderS2 = Egg::Mesh::Shader::create("psBillboardS2.cso", device, billboardsPixelShaderS2ByteCode);

	ComPtr<ID3DBlob> billboardWithSBufferShaderByteCode = loadShaderCode("psBillboardWithSBuffer.cso");
	Egg::Mesh::Shader::P billboardPixelShaderWithSbuffer = Egg::Mesh::Shader::create("psBillboardWithSBuffer.cso", device, billboardWithSBufferShaderByteCode);

	// Binding - Normal, ABuffer
	{
		Egg::Mesh::Material::P billboardMaterial = Egg::Mesh::Material::create();
		billboardMaterial->setShader(Egg::Mesh::ShaderStageFlag::Vertex, billboardVertexShader);
		billboardMaterial->setShader(Egg::Mesh::ShaderStageFlag::Geometry, billboardGeometryShader);
		//billboardMaterial->setShader(Egg::Mesh::ShaderStageFlag::Pixel, billboardPixelShader);
		billboardMaterial->setCb("billboardGSTransCB", modelViewProjCB, Egg::Mesh::ShaderStageFlag::Geometry);
		billboardMaterial->setCb("billboardGSSizeCB", billboardSizeCB, Egg::Mesh::ShaderStageFlag::Geometry);

		ComPtr<ID3D11InputLayout> billboardInputLayout = inputBinder->getCompatibleInputLayout(billboardVertexShaderByteCode, billboardNothing);
		billboards = Egg::Mesh::Shaded::create(billboardNothing, billboardMaterial, billboardInputLayout);
	} 
	/*
	// Binding - SBuffer
	{
		Egg::Mesh::Material::P billboardMaterial = Egg::Mesh::Material::create();
		billboardMaterial->setShader(Egg::Mesh::ShaderStageFlag::Vertex, billboardVertexShader);
		billboardMaterial->setShader(Egg::Mesh::ShaderStageFlag::Geometry, billboardGeometryShader);
		billboardMaterial->setShader(Egg::Mesh::ShaderStageFlag::Pixel, billboardPixelShaderWithSbuffer);
		billboardMaterial->setCb("billboardGSTransCB", modelViewProjCB, Egg::Mesh::ShaderStageFlag::Geometry);
		billboardMaterial->setCb("billboardGSSizeCB", billboardSizeCB, Egg::Mesh::ShaderStageFlag::Geometry);

		ComPtr<ID3D11InputLayout> billboardInputLayout = inputBinder->getCompatibleInputLayout(billboardVertexShaderByteCode, billboardNothing);
		billboardsSBuffer = Egg::Mesh::Shaded::create(billboardNothing, billboardMaterial, billboardInputLayout);
	}
	*/

	// Create Start Offset Buffer
	D3D11_BUFFER_DESC offsetBufferDesc;
	ZeroMemory(&offsetBufferDesc, sizeof(D3D11_BUFFER_DESC));
	offsetBufferDesc.BindFlags = D3D11_BIND_UNORDERED_ACCESS | D3D11_BIND_SHADER_RESOURCE;
	offsetBufferDesc.StructureByteStride = sizeof(unsigned int);
	offsetBufferDesc.ByteWidth = windowHeight * windowWidth * offsetBufferDesc.StructureByteStride;
	offsetBufferDesc.MiscFlags = D3D11_RESOURCE_MISC_BUFFER_ALLOW_RAW_VIEWS;
	device->CreateBuffer(&offsetBufferDesc, NULL, &offsetBuffer);

	// Create Fragment and Link buffer.
	D3D11_BUFFER_DESC linkBufferDesc;
	ZeroMemory(&linkBufferDesc, sizeof(D3D11_BUFFER_DESC));
	linkBufferDesc.BindFlags = D3D11_BIND_UNORDERED_ACCESS | D3D11_BIND_SHADER_RESOURCE;
	linkBufferDesc.StructureByteStride = sizeof(unsigned int) * 2;
	linkBufferDesc.ByteWidth = windowHeight * windowWidth * linkbufferSizePerPixel * linkBufferDesc.StructureByteStride;
	linkBufferDesc.MiscFlags = D3D11_RESOURCE_MISC_BUFFER_STRUCTURED;
	device->CreateBuffer(&linkBufferDesc, NULL, &linkBuffer);

	// Create Unordered Access Views
	D3D11_UNORDERED_ACCESS_VIEW_DESC offsetUAVDesc;
	offsetUAVDesc.ViewDimension = D3D11_UAV_DIMENSION_BUFFER;
	offsetUAVDesc.Buffer.FirstElement = 0;
	offsetUAVDesc.Format = DXGI_FORMAT_R32_TYPELESS;
	offsetUAVDesc.Buffer.NumElements = windowHeight * windowWidth;
	offsetUAVDesc.Buffer.Flags = D3D11_BUFFER_UAV_FLAG_RAW;
	device->CreateUnorderedAccessView(offsetBuffer.Get(), &offsetUAVDesc, &offsetUAV);

	D3D11_UNORDERED_ACCESS_VIEW_DESC linkUAVDesc;
	linkUAVDesc.ViewDimension = D3D11_UAV_DIMENSION_BUFFER;
	linkUAVDesc.Buffer.FirstElement = 0;
	linkUAVDesc.Format = DXGI_FORMAT_UNKNOWN;
	linkUAVDesc.Buffer.NumElements = windowHeight * windowWidth * linkbufferSizePerPixel;
	linkUAVDesc.Buffer.Flags = D3D11_BUFFER_UAV_FLAG_COUNTER;
	device->CreateUnorderedAccessView(linkBuffer.Get(), &linkUAVDesc, &linkUAV);

	// Create Result Buffer
	D3D11_BUFFER_DESC resultBufferDesc;
	ZeroMemory(&resultBufferDesc, sizeof(D3D11_BUFFER_DESC));
	resultBufferDesc.BindFlags = D3D11_BIND_UNORDERED_ACCESS | D3D11_BIND_SHADER_RESOURCE;
	resultBufferDesc.StructureByteStride = sizeof(unsigned int);
	resultBufferDesc.ByteWidth = windowHeight * windowWidth * resultBufferDesc.StructureByteStride;
	resultBufferDesc.MiscFlags = D3D11_RESOURCE_MISC_BUFFER_ALLOW_RAW_VIEWS;
	device->CreateBuffer(&resultBufferDesc, NULL, &resultBuffer);

	// Create idBuffer buffer.
	D3D11_BUFFER_DESC idBufferDesc;
	ZeroMemory(&idBufferDesc, sizeof(D3D11_BUFFER_DESC));
	idBufferDesc.BindFlags = D3D11_BIND_UNORDERED_ACCESS | D3D11_BIND_SHADER_RESOURCE;
	idBufferDesc.StructureByteStride = sizeof(unsigned int);
	idBufferDesc.ByteWidth = windowHeight * windowWidth * sbufferSizePerPixel * idBufferDesc.StructureByteStride;
	idBufferDesc.MiscFlags = D3D11_RESOURCE_MISC_BUFFER_STRUCTURED;
	device->CreateBuffer(&idBufferDesc, NULL, &idBuffer);

	// Create Count buffer
	D3D11_BUFFER_DESC countBufferDesc;
	ZeroMemory(&countBufferDesc, sizeof(D3D11_BUFFER_DESC));
	countBufferDesc.BindFlags = D3D11_BIND_UNORDERED_ACCESS | D3D11_BIND_SHADER_RESOURCE;
	countBufferDesc.StructureByteStride = sizeof(unsigned int);
	countBufferDesc.ByteWidth = windowHeight * windowWidth * countBufferDesc.StructureByteStride;
	countBufferDesc.MiscFlags = D3D11_RESOURCE_MISC_BUFFER_ALLOW_RAW_VIEWS;
	device->CreateBuffer(&countBufferDesc, NULL, &countBuffer);

	// Create Unordered Access Views
	D3D11_UNORDERED_ACCESS_VIEW_DESC resultUAVDesc;
	resultUAVDesc.ViewDimension = D3D11_UAV_DIMENSION_BUFFER;
	resultUAVDesc.Buffer.FirstElement = 0;
	resultUAVDesc.Format = DXGI_FORMAT_R32_TYPELESS;
	resultUAVDesc.Buffer.NumElements = windowHeight * windowWidth;
	resultUAVDesc.Buffer.Flags = D3D11_BUFFER_UAV_FLAG_RAW;
	device->CreateUnorderedAccessView(resultBuffer.Get(), &resultUAVDesc, &resultUAV);

	D3D11_UNORDERED_ACCESS_VIEW_DESC countUAVDesc;
	countUAVDesc.ViewDimension = D3D11_UAV_DIMENSION_BUFFER;
	countUAVDesc.Buffer.FirstElement = 0;
	countUAVDesc.Format = DXGI_FORMAT_R32_TYPELESS;
	countUAVDesc.Buffer.NumElements = windowHeight * windowWidth;
	countUAVDesc.Buffer.Flags = D3D11_BUFFER_UAV_FLAG_RAW;
	device->CreateUnorderedAccessView(countBuffer.Get(), &countUAVDesc, &countUAV);

	D3D11_UNORDERED_ACCESS_VIEW_DESC idUAVDesc;
	idUAVDesc.ViewDimension = D3D11_UAV_DIMENSION_BUFFER;
	idUAVDesc.Buffer.FirstElement = 0;
	idUAVDesc.Format = DXGI_FORMAT_UNKNOWN;
	idUAVDesc.Buffer.NumElements = windowHeight * windowWidth * sbufferSizePerPixel;
	idUAVDesc.Buffer.Flags = D3D11_BUFFER_UAV_FLAG_COUNTER;
	device->CreateUnorderedAccessView(idBuffer.Get(), &idUAVDesc, &idUAV);

}

void Game::createMetaball() {
	using namespace Microsoft::WRL;

	// Create Shader Resource Views

	D3D11_SHADER_RESOURCE_VIEW_DESC offsetSRVDesc;
	offsetSRVDesc.ViewDimension = D3D11_SRV_DIMENSION_BUFFER;
	offsetSRVDesc.Buffer.FirstElement = 0;
	offsetSRVDesc.Format = DXGI_FORMAT_R32_UINT;
	offsetSRVDesc.Buffer.NumElements = windowWidth * windowHeight;
	device->CreateShaderResourceView(offsetBuffer.Get(), &offsetSRVDesc, &offsetSRV);

	D3D11_SHADER_RESOURCE_VIEW_DESC linkSRVDesc;
	linkSRVDesc.ViewDimension = D3D11_SRV_DIMENSION_BUFFER;
	linkSRVDesc.Buffer.FirstElement = 0;
	linkSRVDesc.Format = DXGI_FORMAT_UNKNOWN;
	linkSRVDesc.Buffer.NumElements = windowWidth * windowHeight * linkbufferSizePerPixel;
	device->CreateShaderResourceView(linkBuffer.Get(), &linkSRVDesc, &linkSRV);

	D3D11_SHADER_RESOURCE_VIEW_DESC idSRVDesc;
	idSRVDesc.ViewDimension = D3D11_SRV_DIMENSION_BUFFER;
	idSRVDesc.Buffer.FirstElement = 0;
	idSRVDesc.Format = DXGI_FORMAT_UNKNOWN;
	idSRVDesc.Buffer.NumElements = windowWidth * windowHeight * sbufferSizePerPixel;
	device->CreateShaderResourceView(idBuffer.Get(), &idSRVDesc, &idSRV);
	
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

	ComPtr<ID3DBlob> metaballPixelShaderByteCode;
	Egg::Mesh::Shader::P backgroundPixelShader;

	if (billboardsLoadAlgorithm == 0) {
		metaballPixelShaderByteCode = loadShaderCode("psMetaballNormal.cso");
		backgroundPixelShader = Egg::Mesh::Shader::create("psMetaballNormal.cso", device, metaballPixelShaderByteCode);
	}
	if (billboardsLoadAlgorithm == 1) {
		metaballPixelShaderByteCode = loadShaderCode("psMetaballABuffer.cso");
		backgroundPixelShader = Egg::Mesh::Shader::create("psMetaballABuffer.cso", device, metaballPixelShaderByteCode);
	}
	if (billboardsLoadAlgorithm == 2) {
		metaballPixelShaderByteCode = loadShaderCode("psMetaballSBuffer.cso");
		backgroundPixelShader = Egg::Mesh::Shader::create("psMetaballSBuffer.cso", device, metaballPixelShaderByteCode);
	}

	ComPtr<ID3DBlob> prefixSumPixelShaderByteCode = loadShaderCode("psPrefixSum.cso");
	Egg::Mesh::Shader::P prefixSumPixelShader = Egg::Mesh::Shader::create("psPrefixSum.cso", device, prefixSumPixelShaderByteCode);

	//Environment texture
	Microsoft::WRL::ComPtr<ID3D11Resource> envTexture;

	std::wstring envfile = Egg::UtfConverter::utf8to16(App::getSystemEnvironment().resolveMediaPath("cloudynoon.dds"));
	Egg::ThrowOnFail("Could not create ENV.", __FILE__, __LINE__) ^
		DirectX::CreateDDSTextureFromFile(device.Get(), envfile.c_str(), envTexture.GetAddressOf(), envSrv.GetAddressOf());

	ComPtr<ID3D11SamplerState> ss;
	CD3D11_SAMPLER_DESC ssDesc = CD3D11_SAMPLER_DESC(CD3D11_DEFAULT());
	device->CreateSamplerState(&ssDesc, ss.GetAddressOf());

	// Binding

	Egg::Mesh::Material::P metaballMaterial = Egg::Mesh::Material::create();
	metaballMaterial->setShader(Egg::Mesh::ShaderStageFlag::Vertex, backgroundVertexShader);
	metaballMaterial->setShader(Egg::Mesh::ShaderStageFlag::Pixel, backgroundPixelShader);
	metaballMaterial->setCb("metaballVSTransCB", metaballVSTransCB, Egg::Mesh::ShaderStageFlag::Vertex);
	metaballMaterial->setCb("metaballPSEyePosCB", metaballPSEyePosCB, Egg::Mesh::ShaderStageFlag::Pixel);
	metaballMaterial->setSamplerState("ss", ss, Egg::Mesh::ShaderStageFlag::Pixel);

	ComPtr<ID3D11InputLayout>metaballInputLayout = inputBinder->getCompatibleInputLayout(metaballVertexShaderByteCode, fullQuadGeometry);
	metaballMesh = Egg::Mesh::Shaded::create(fullQuadGeometry, metaballMaterial, metaballInputLayout);

	// Binding - Prefix sum
	/*{
		Egg::Mesh::Material::P prefixSumMaterial = Egg::Mesh::Material::create();
		prefixSumMaterial->setShader(Egg::Mesh::ShaderStageFlag::Vertex, backgroundVertexShader);
		prefixSumMaterial->setShader(Egg::Mesh::ShaderStageFlag::Pixel, prefixSumPixelShader);
		prefixSumMaterial->setCb("metaballVSTransCB", metaballVSTransCB, Egg::Mesh::ShaderStageFlag::Vertex);
		prefixSumMaterial->setCb("metaballPSEyePosCB", metaballPSEyePosCB, Egg::Mesh::ShaderStageFlag::Pixel);
		prefixSumMaterial->setSamplerState("ss", ss, Egg::Mesh::ShaderStageFlag::Pixel);
		prefixSumMaterial->setShaderResource("envTexture", envSrv, Egg::Mesh::ShaderStageFlag::Pixel);

		ComPtr<ID3D11InputLayout>metaballInputLayout = inputBinder->getCompatibleInputLayout(metaballVertexShaderByteCode, fullQuadGeometry);
		prefixSumMesh = Egg::Mesh::Shaded::create(fullQuadGeometry, prefixSumMaterial, metaballInputLayout);
	}*/
}

void Game::createAnimation() {
	using namespace Microsoft::WRL;

	// ComputeShader
	ComPtr<ID3DBlob>fluidSimulationShaderByteCode = loadShaderCode("csFluidSimulation.cso");
	fluidSimulationShader = Egg::Mesh::Shader::create("csFluidSimulation.cso", device, fluidSimulationShaderByteCode);

	ComPtr<ID3DBlob>simpleSortEvenShaderByteCode = loadShaderCode("csSimpleSortEven.cso");
	simpleSortEvenShader = Egg::Mesh::Shader::create("csSimpleSortEven.cso", device, simpleSortEvenShaderByteCode);

	ComPtr<ID3DBlob>simpleSortOddShaderByteCode = loadShaderCode("csSimpleSortOdd.cso");
	simpleSortOddShader = Egg::Mesh::Shader::create("csSimpleSortOdd.cso", device, simpleSortOddShaderByteCode);
}

void Game::createPrefixSum() {
	using namespace Microsoft::WRL;

	Egg::Mesh::Geometry::P fullQuadGeometry = Egg::Mesh::Indexed::createQuad(device);
	
	// Compute shaders
	ComPtr<ID3DBlob> computeShaderByteCode = loadShaderCode("csPrefixSum.cso");
	prefixSumComputeShader = Egg::Mesh::Shader::create("csPrefixSum.cso", device, computeShaderByteCode);

	ComPtr<ID3DBlob> computeShaderByteCode2 = loadShaderCode("csScanBucketResult.cso");
	prefixSumScanBucketResultShader = Egg::Mesh::Shader::create("csScanBucketResult.cso", device, computeShaderByteCode2);

	ComPtr<ID3DBlob> computeShaderByteCode5 = loadShaderCode("csScanBucketResult2.cso");
	prefixSumScanBucketResult2Shader = Egg::Mesh::Shader::create("csScanBucketResult2.cso", device, computeShaderByteCode5);

	ComPtr<ID3DBlob> computeShaderByteCode6 = loadShaderCode("csScanBucketResult3.cso");
	prefixSumScanBucketResult3Shader = Egg::Mesh::Shader::create("csScanBucketResult3.cso", device, computeShaderByteCode6);

	ComPtr<ID3DBlob> computeShaderByteCode3 = loadShaderCode("csScanAddBucketResult.cso");
	prefixSumScanAddBucketResultShader = Egg::Mesh::Shader::create("csScanAddBucketResult.cso", device, computeShaderByteCode3);

	ComPtr<ID3DBlob> computeShaderByteCode4 = loadShaderCode("csScanAddBucketResult2.cso");
	prefixSumScanAddBucketResult2Shader = Egg::Mesh::Shader::create("csScanAddBucketResult2.cso", device, computeShaderByteCode4);

	if (billboardsLoadAlgorithm == SBufferFaster) {
		ComPtr<ID3DBlob> computeShaderByteCode = loadShaderCode("csPrefixSumF.cso");
		prefixSumFComputeShader = Egg::Mesh::Shader::create("csPrefixSumF.cso", device, computeShaderByteCode);

		ComPtr<ID3DBlob> computeShaderByteCode2 = loadShaderCode("csPrefixSumFAddBucket.cso");
		prefixSumFComputeShader2 = Egg::Mesh::Shader::create("csPrefixSumFAddBucket.cso", device, computeShaderByteCode2);
	}
}

HRESULT Game::releaseResources()
{
	billboards.reset();
	return Egg::App::releaseResources();
}

void Game::clearRenderTarget(Microsoft::WRL::ComPtr<ID3D11DeviceContext> context) {
	context->OMSetRenderTargets(1, defaultRenderTargetView.GetAddressOf(), defaultDepthStencilView.Get());

	float clearColor[4] = { 0.9f, 0.7f, 0.1f, 0.0f };
	context->ClearRenderTargetView(defaultRenderTargetView.Get(), clearColor);
	context->ClearDepthStencilView(defaultDepthStencilView.Get(), D3D11_CLEAR_DEPTH, 1.0, 0);
}

void Game::clearContext(Microsoft::WRL::ComPtr<ID3D11DeviceContext> context) {
	UINT pNumViewports = 1;
	D3D11_VIEWPORT pViewports[1];
	context->RSGetViewports(&pNumViewports, pViewports);
	context->ClearState();
	context->RSSetViewports(pNumViewports, pViewports);
	context->OMSetRenderTargets(1, defaultRenderTargetView.GetAddressOf(), defaultDepthStencilView.Get());
}

void Game::renderBillboardA(Microsoft::WRL::ComPtr<ID3D11DeviceContext> context)
{
	uint values[4] = { 0,0,0,0 };
	context->ClearUnorderedAccessViewUint(offsetUAV.Get(), values);

	float4x4 matrices[4];
	matrices[0] = float4x4::identity;
	matrices[1] = float4x4::identity;
	matrices[2] = (firstPersonCam->getViewMatrix() * firstPersonCam->getProjMatrix());
	matrices[3] = firstPersonCam->getViewDirMatrix();
	context->UpdateSubresource(modelViewProjCB.Get(), 0, nullptr, matrices, 0, 0);
	context->VSSetShaderResources(0, 1, particleSRV.GetAddressOf());

	ID3D11UnorderedAccessView* ppUnorderedAccessViews[2];
	ppUnorderedAccessViews[0] = offsetUAV.Get();
	ppUnorderedAccessViews[1] = linkUAV.Get();
	uint t[2] = { 0,0 };
	context->OMSetRenderTargetsAndUnorderedAccessViews(0, NULL, defaultDepthStencilView.Get(), 0, 2, ppUnorderedAccessViews, t);

	billboards->getMaterial()->setShader(Egg::Mesh::ShaderStageFlag::Pixel, billboardsPixelShaderA);

	billboards->draw(context);

}

void Game::renderBillboardS1(Microsoft::WRL::ComPtr<ID3D11DeviceContext> context)
{
	uint values[4] = { 0,0,0,0 };
	context->ClearUnorderedAccessViewUint(offsetUAV.Get(), values);

	float4x4 matrices[4];
	matrices[0] = float4x4::identity;
	matrices[1] = float4x4::identity;
	matrices[2] = (firstPersonCam->getViewMatrix() * firstPersonCam->getProjMatrix());
	matrices[3] = firstPersonCam->getViewDirMatrix();
	context->UpdateSubresource(modelViewProjCB.Get(), 0, nullptr, matrices, 0, 0);
	context->VSSetShaderResources(0, 1, particleSRV.GetAddressOf());

	ID3D11UnorderedAccessView* ppUnorderedAccessViews[2];
	ppUnorderedAccessViews[0] = offsetUAV.Get();
	uint t[1] = { 0 };
	context->OMSetRenderTargetsAndUnorderedAccessViews(0, NULL, defaultDepthStencilView.Get(), 0, 1, ppUnorderedAccessViews, t);

	billboards->getMaterial()->setShader(Egg::Mesh::ShaderStageFlag::Pixel, billboardsPixelShaderS1);

	billboards->draw(context);
}

void Game::renderBillboardS2(Microsoft::WRL::ComPtr<ID3D11DeviceContext> context)
{
	float4x4 matrices[4];
	matrices[0] = float4x4::identity;
	matrices[1] = float4x4::identity;
	matrices[2] = (firstPersonCam->getViewMatrix() * firstPersonCam->getProjMatrix());
	matrices[3] = firstPersonCam->getViewDirMatrix();
	context->UpdateSubresource(modelViewProjCB.Get(), 0, nullptr, matrices, 0, 0);

	context->VSSetShaderResources(0, 1, particleSRV.GetAddressOf());
	ID3D11UnorderedAccessView* ppUnorderedAccessViews[3];
	ppUnorderedAccessViews[0] = offsetUAV.Get();
	ppUnorderedAccessViews[1] = countUAV.Get();
	ppUnorderedAccessViews[2] = idUAV.Get();
	uint t[3] = { 0,0,0 };
	context->OMSetRenderTargetsAndUnorderedAccessViews(0, NULL, defaultDepthStencilView.Get(), 0, 3, ppUnorderedAccessViews, t);

	billboards->getMaterial()->setShader(Egg::Mesh::ShaderStageFlag::Pixel, billboardsPixelShaderS2);

	billboards->draw(context);
}

void Game::renderMetaball(Microsoft::WRL::ComPtr<ID3D11DeviceContext> context) {
	float4x4 matrices[4];
	matrices[0] = float4x4::identity;
	matrices[1] = float4x4::identity;
	matrices[2] = (firstPersonCam->getViewMatrix() * firstPersonCam->getProjMatrix());
	matrices[3] = firstPersonCam->getViewDirMatrix();
	context->UpdateSubresource(metaballVSTransCB.Get(), 0, nullptr, matrices, 0, 0);

	float4 perFrameVectors[1];
	perFrameVectors[0] = firstPersonCam->getEyePosition().xyz1;
	context->UpdateSubresource(metaballPSEyePosCB.Get(), 0, nullptr, perFrameVectors, 0, 0);

	context->PSSetShaderResources(0, 1, envSrv.GetAddressOf());
	context->PSSetShaderResources(1, 1, particleSRV.GetAddressOf());
	if (billboardsLoadAlgorithm == ABuffer || billboardsLoadAlgorithm == SBuffer)
		context->PSSetShaderResources(2, 1, offsetSRV.GetAddressOf());
	if (billboardsLoadAlgorithm == ABuffer)
		context->PSSetShaderResources(3, 1, linkSRV.GetAddressOf());
	if (billboardsLoadAlgorithm == SBuffer)
		context->PSSetShaderResources(3, 1, idSRV.GetAddressOf());

	metaballMesh->draw(context);
}

void Game::renderAnimation(Microsoft::WRL::ComPtr<ID3D11DeviceContext> context) {
	uint zeros[2] = { 0, 0 };
	context->CSSetShader(static_cast<ID3D11ComputeShader*>(fluidSimulationShader->getShader().Get()), nullptr, 0);
	context->CSSetUnorderedAccessViews(0, 1, particleUAV.GetAddressOf(), zeros);
	context->Dispatch(defaultParticleCount, 1, 1);
}

void Game::renderSort(Microsoft::WRL::ComPtr<ID3D11DeviceContext> context) {
	uint zeros[2] = { 0, 0 };
	context->CSSetShader(static_cast<ID3D11ComputeShader*>(simpleSortEvenShader->getShader().Get()), nullptr, 0);
	context->CSSetUnorderedAccessViews(0, 1, particleUAV.GetAddressOf(), zeros);
	context->Dispatch(defaultParticleCount / 2 - 1, 1, 1);

	context->CSSetShader(static_cast<ID3D11ComputeShader*>(simpleSortOddShader->getShader().Get()), nullptr, 0);
	context->CSSetUnorderedAccessViews(0, 1, particleUAV.GetAddressOf(), zeros);
	context->Dispatch(defaultParticleCount / 2 - 2, 1, 1);
}

void Game::renderPrefixSum(Microsoft::WRL::ComPtr<ID3D11DeviceContext> context) {
	uint zeros[1] = { 0 };

	if (billboardsLoadAlgorithm != SBufferFaster)
	{
		context->CSSetShader(static_cast<ID3D11ComputeShader*>(prefixSumComputeShader->getShader().Get()), nullptr, 0);
		context->CSSetUnorderedAccessViews(0, 1, offsetUAV.GetAddressOf(), zeros);
		context->Dispatch((int)ceil((windowHeight * windowWidth / 512.0)), 1, 1);

		int loopCount = (int)ceil(((windowHeight*windowWidth) / 512.0) / 512.0);
	
		for (int i = 0; i < loopCount; i++) {
			context->CSSetShader(static_cast<ID3D11ComputeShader*>(prefixSumScanBucketResultShader->getShader().Get()), nullptr, 0);
			context->CSSetUnorderedAccessViews(0, 1, offsetUAV.GetAddressOf(), zeros);
			context->CSSetUnorderedAccessViews(1, 1, resultUAV.GetAddressOf(), zeros);
			Egg::Math::int1 sizeVector[1];
			sizeVector[0] = i;
			context->UpdateSubresource(scanBucketSizeCB.Get(), 0, nullptr, sizeVector, 0, 0);
			context->CSSetConstantBuffers(0, 1, scanBucketSizeCB.GetAddressOf());
			context->Dispatch(1, 1, 1);
		}

		context->CSSetShader(static_cast<ID3D11ComputeShader*>(prefixSumScanAddBucketResultShader->getShader().Get()), nullptr, 0);
		context->CSSetUnorderedAccessViews(0, 1, offsetUAV.GetAddressOf(), zeros);
		context->CSSetUnorderedAccessViews(1, 1, resultUAV.GetAddressOf(), zeros);
		context->Dispatch((int)ceil((windowHeight * windowWidth / 512.0)), 1, 1);
	}
	if (billboardsLoadAlgorithm != SBufferFaster) { 

		// TODO

	}

	resultBuffer.Reset();
}

void Game::render(Microsoft::WRL::ComPtr<ID3D11DeviceContext> context)
{
	using namespace Egg::Math;

	clearRenderTarget(context);

	// Billboard
	if (billboardsLoadAlgorithm == ABuffer)
	{
		renderBillboardA(context);
		clearContext(context);
	}	
	else if (billboardsLoadAlgorithm == SBuffer)
	{
		renderBillboardS1(context);
		clearContext(context);

		renderPrefixSum(context);
		clearContext(context);

		// Clear count buffer
		const UINT zeros[4] = { 0,0,0,0 };
		context->ClearUnorderedAccessViewUint(countUAV.Get(), zeros);

		renderBillboardS2(context);
		clearContext(context);
	}

	// Metaball
	renderMetaball(context);
	clearContext(context);

	// Animation
	renderAnimation(context);
	clearContext(context);

	// Sort
	renderSort(context);
	clearContext(context);
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
