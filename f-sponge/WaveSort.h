#pragma once
#include "ComputeShader.h"
#include "RawBuffer.h"

class WaveSort {
	ComputeShader localSort;
	ComputeShader merge;
	D3D12_GPU_DESCRIPTOR_HANDLE uavHandle; //uavHeap->GetGPUDescriptorHandleForHeapStart()
	uint uavOffset;

	D3D12_RESOURCE_BARRIER uavBarriers[4];

public:
	void creaseResources(ComputeShader localSort, ComputeShader merge, D3D12_GPU_DESCRIPTOR_HANDLE uavHandle, uint uavOffset, 
		const std::vector<RawBuffer>& buffers)
	{
		this->localSort = localSort;
		this->merge = merge;
		this->uavHandle = uavHandle;
		this->uavOffset = uavOffset;

		for (uint i = 0; i < 4; i++) {
			uavBarriers[i] = buffers[uavOffset + i].uavBarrier();
		}
	}

	void populate(com_ptr<ID3D12GraphicsCommandList> computeCommandList) {
		localSort.setup(computeCommandList, uavHandle); //TODO offset 

		computeCommandList->SetComputeRoot32BitConstant(0, 0, 0);
		computeCommandList->Dispatch(32, 1, 1);
		computeCommandList->ResourceBarrier(2, uavBarriers);
		computeCommandList->SetComputeRoot32BitConstant(0, 4, 0);
		computeCommandList->Dispatch(32, 1, 1);
		computeCommandList->ResourceBarrier(2, uavBarriers);
		computeCommandList->SetComputeRoot32BitConstant(0, 8, 0);
		computeCommandList->Dispatch(32, 1, 1);
		computeCommandList->ResourceBarrier(2, uavBarriers);
		computeCommandList->SetComputeRoot32BitConstant(0, 12, 0);
		computeCommandList->Dispatch(32, 1, 1);
		computeCommandList->ResourceBarrier(2, uavBarriers);
		computeCommandList->SetComputeRoot32BitConstant(0, 16, 0);
		computeCommandList->Dispatch(32, 1, 1);
		computeCommandList->ResourceBarrier(2, uavBarriers);
		computeCommandList->SetComputeRoot32BitConstant(0, 20, 0);
		computeCommandList->Dispatch(32, 1, 1);
		computeCommandList->ResourceBarrier(2, uavBarriers);
		computeCommandList->SetComputeRoot32BitConstant(0, 24, 0);
		computeCommandList->Dispatch(32, 1, 1);
		computeCommandList->ResourceBarrier(2, uavBarriers);
		computeCommandList->SetComputeRoot32BitConstant(0, 28, 0);
		computeCommandList->Dispatch(32, 1, 1);
		computeCommandList->ResourceBarrier(2, uavBarriers);

		merge.setup(computeCommandList, uavHandle); //TODO offset

		computeCommandList->Dispatch(1, 1, 1);
		computeCommandList->ResourceBarrier(2, &uavBarriers[2]);
	}
};