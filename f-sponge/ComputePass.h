#pragma once
#include "Egg/Common.h"
#include "ComputeShader.h"

class ComputePass {
	ComputeShader shader;
	D3D12_GPU_DESCRIPTOR_HANDLE uavHandle; //uavHeap->GetGPUDescriptorHandleForHeapStart()

public:
	void createResources(ComputeShader shader, D3D12_GPU_DESCRIPTOR_HANDLE uavHandle) {
		this->shader = shader;
		this->uavHandle = uavHandle;
	}

	void populate() {

	}
};