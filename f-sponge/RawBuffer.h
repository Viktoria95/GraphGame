#pragma once
#include "Egg/Common.h"
#include <d3d11on12.h>
#include <string>


class RawBuffer {
	com_ptr<ID3D12Resource>		buffer;
	com_ptr<ID3D12Resource>     uploadBuffer;
	com_ptr<ID3D12Resource>		readbackBuffer;
	com_ptr<ID3D11Resource>		wrappedBuffer;
	uint bufferUintSize;
	std::wstring debugName;
public:
	RawBuffer(
		std::wstring debugName,
		uint bufferUintSize = 32 * 32 * 32):debugName(debugName), bufferUintSize(bufferUintSize) {
 
	}

	void createResources(com_ptr<ID3D12Device> device,
		com_ptr<ID3D11On12Device> device11on12
	) {
		const D3D12_HEAP_PROPERTIES defaultHeapProperties = CD3DX12_HEAP_PROPERTIES(D3D12_HEAP_TYPE_DEFAULT);
		const D3D12_RESOURCE_DESC bufferDesc = CD3DX12_RESOURCE_DESC::Buffer(4 * bufferUintSize,
			D3D12_RESOURCE_FLAG_ALLOW_UNORDERED_ACCESS, 0);
		DX_API("commited resource")
			device->CreateCommittedResource(
				&defaultHeapProperties,
				D3D12_HEAP_FLAG_NONE,
				&bufferDesc,
				D3D12_RESOURCE_STATE_UNORDERED_ACCESS,
				nullptr,
				IID_PPV_ARGS(buffer.ReleaseAndGetAddressOf()));
		buffer->SetName(debugName.c_str());

		CD3DX12_HEAP_PROPERTIES rbheapProps(D3D12_HEAP_TYPE_READBACK);

		D3D12_RESOURCE_ALLOCATION_INFO info = {};
		info.SizeInBytes = 4 * bufferUintSize;
		info.Alignment = 0;
		const D3D12_RESOURCE_DESC tempBufferDesc = CD3DX12_RESOURCE_DESC::Buffer(info);
		DX_API("readback resource")
			device->CreateCommittedResource(
				&rbheapProps,
				D3D12_HEAP_FLAG_NONE,
				&tempBufferDesc,
				D3D12_RESOURCE_STATE_COPY_DEST,
				nullptr,
				IID_PPV_ARGS(readbackBuffer.ReleaseAndGetAddressOf()));
		readbackBuffer->SetName((debugName + L" [READBACK]").c_str());


		CD3DX12_HEAP_PROPERTIES heapProps(D3D12_HEAP_TYPE_UPLOAD);

		DX_API("upload resource")
			device->CreateCommittedResource(
				&heapProps,
				D3D12_HEAP_FLAG_NONE,
				&tempBufferDesc,
				D3D12_RESOURCE_STATE_GENERIC_READ,
				nullptr,
				IID_PPV_ARGS(uploadBuffer.ReleaseAndGetAddressOf()));
		uploadBuffer->SetName((debugName + L" [UPLOAD]").c_str());

		D3D11_RESOURCE_FLAGS d3d11Flags = { D3D11_BIND_UNORDERED_ACCESS };
		DX_API("Failed to wrap 12 back buffer for d3d11")
			device11on12->CreateWrappedResource(
				buffer.Get(),
				&d3d11Flags,
				D3D12_RESOURCE_STATE_UNORDERED_ACCESS,
				D3D12_RESOURCE_STATE_UNORDERED_ACCESS,
				IID_PPV_ARGS(wrappedBuffer.GetAddressOf())
			);
	}

	void ReleaseResource() {
		buffer.Reset();
		uploadBuffer.Reset();
		readbackBuffer.Reset();
		wrappedBuffer.Reset();
	}
};