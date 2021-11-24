#pragma once
#include "Egg/Common.h"

class ComputePass {
	com_ptr<ID3D12PipelineState> pso;
	com_ptr<ID3D12RootSignature> rootSig;
	D3D12_GPU_DESCRIPTOR_HANDLE uavHandle; //uavHeap->GetGPUDescriptorHandleForHeapStart()

public:
	void createResources(com_ptr<ID3D12Device> device, std::string csoName, D3D12_GPU_DESCRIPTOR_HANDLE uavHandle) {
		this->uavHandle = uavHandle;
		com_ptr<ID3DBlob> computeShader = Egg::Shader::LoadCso("Shaders/csLocalSort.cso");
		rootSig = Egg::Shader::LoadRootSignature(device.Get(), computeShader.Get());

		D3D12_COMPUTE_PIPELINE_STATE_DESC descComputePSO = {};
		descComputePSO.pRootSignature = rootSig.Get();
		descComputePSO.CS.pShaderBytecode = computeShader->GetBufferPointer();
		descComputePSO.CS.BytecodeLength = computeShader->GetBufferSize();

		DX_API("Failed to create compute pipeline state object.")
			device->CreateComputePipelineState(&descComputePSO, IID_PPV_ARGS(pso.ReleaseAndGetAddressOf()));
		pso->SetName(L"Compute PSO" /* + csoName*/);
	}

	void populate(com_ptr<ID3D12GraphicsCommandList> computeCommandList) {
		computeCommandList->SetComputeRootSignature(rootSig.Get());

		computeCommandList->SetComputeRootDescriptorTable(1, uavHandle);

	}
};