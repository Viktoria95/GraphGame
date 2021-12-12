#pragma once
#include "Egg/Common.h"
#include "ComputeShader.h"

class ComputePass {
	ComputeShader shader;
	D3D12_GPU_DESCRIPTOR_HANDLE uavHandle; //uavHeap->GetGPUDescriptorHandleForHeapStart()
	D3D12_RESOURCE_BARRIER uavBarriers[16];
	uint nUavs;
	uint uavOffset;

public:
	void createResources(ComputeShader shader, CD3DX12_GPU_DESCRIPTOR_HANDLE uavHandle, uint uavOffset, uint dhIncrSize,
		const std::vector<RawBuffer>& buffers, uint nUavs) {
		this->shader = shader;
		this->uavHandle = uavHandle.Offset(uavOffset, dhIncrSize);
		this->nUavs = nUavs;

		for (uint i = 0; i < nUavs; i++) {
			uavBarriers[i] = buffers[i+uavOffset].uavBarrier();
		}
	}

	void populate(com_ptr<ID3D12GraphicsCommandList> computeCommandList) {
		shader.setup(computeCommandList, uavHandle);
		computeCommandList->Dispatch(32, 1, 1);
		computeCommandList->ResourceBarrier(nUavs, uavBarriers);

	}
};