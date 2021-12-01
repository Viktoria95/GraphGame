#pragma once

#include "Common.h"
#include "Mesh/Shaded.h"
#include "App.h"
#include "Shader.h"

namespace Egg {

	GG_SUBCLASS(SimpleApp, App)
	protected:
		std::vector < com_ptr<ID3D12CommandAllocator> > commandAllocators;
		std::vector < com_ptr<ID3D12GraphicsCommandList> > commandLists;
		std::vector < com_ptr<ID3D12Resource> >  depthStencilBuffers;

		com_ptr<ID3D12DescriptorHeap> dsvHeap;
		D3D12_CPU_DESCRIPTOR_HANDLE dsvHandle;
		unsigned int dsvDescriptorHandleIncrementSize;

		unsigned int previousSwapChainBackBufferIndex;

		PsoManager::P psoManager;

		virtual void PopulateCommandList() = 0;

		void WaitForPreviousFrame() {
			const UINT64 fv = fenceValue;
			DX_API("Failed to signal from command queue")
				commandQueue->Signal(fence.Get(), fv);

			fenceValue++;

			if(fence->GetCompletedValue() < fv) {
				DX_API("Failed to sign up for event completion")
					fence->SetEventOnCompletion(fv, fenceEvent);
				WaitForSingleObject(fenceEvent, INFINITE);
			}

			previousSwapChainBackBufferIndex = swapChainBackBufferIndex;
			swapChainBackBufferIndex = swapChain->GetCurrentBackBufferIndex();
		}


	public:

		virtual void Render() override {
			PopulateCommandList();

			// Execute
	//		ID3D12CommandList * cLists[] = { commandList.Get() };
	//		commandQueue->ExecuteCommandLists(_countof(cLists), cLists);

			DX_API("Failed to present swap chain")
				swapChain->Present(1, 0);

			// Sync
			WaitForPreviousFrame();
		}

		virtual void CreateResources() override {
			App::CreateResources();

			psoManager = PsoManager::Create( device );
		}

		virtual void ReleaseResources() override {
			psoManager = nullptr;
			for(auto& c : commandLists) c.Reset();
			fence.Reset();
			for (auto& c : commandAllocators) c.Reset();
			App::ReleaseResources();
		}

		virtual void CreateSwapChainResources() override {
			Egg::App::CreateSwapChainResources();

			commandAllocators.resize(swapChainBackBufferCount);
			commandLists.resize(swapChainBackBufferCount);

			for (uint i = 0; i < swapChainBackBufferCount; i++) {
				DX_API("Failed to create command allocator")
					device->CreateCommandAllocator(D3D12_COMMAND_LIST_TYPE_DIRECT, IID_PPV_ARGS(commandAllocators[i].GetAddressOf()));

				DX_API("Failed to greate graphics command list")
					device->CreateCommandList(0, D3D12_COMMAND_LIST_TYPE_DIRECT, commandAllocators[i].Get(), nullptr, IID_PPV_ARGS(commandLists[i].GetAddressOf()));

				commandLists[i]->Close();

			}

			previousSwapChainBackBufferIndex = swapChainBackBufferIndex;

			D3D12_DESCRIPTOR_HEAP_DESC dsHeapDesc = {};
			dsHeapDesc.NumDescriptors = swapChainBackBufferCount;
			dsHeapDesc.Type = D3D12_DESCRIPTOR_HEAP_TYPE_DSV;
			dsHeapDesc.Flags = D3D12_DESCRIPTOR_HEAP_FLAG_NONE;

			DX_API("Failed to create depth stencil descriptor heap")
				device->CreateDescriptorHeap(&dsHeapDesc, IID_PPV_ARGS(dsvHeap.GetAddressOf()));
			dsvHandle = dsvHeap->GetCPUDescriptorHandleForHeapStart();
			dsvDescriptorHandleIncrementSize = device->GetDescriptorHandleIncrementSize(D3D12_DESCRIPTOR_HEAP_TYPE_DSV);

			D3D12_CLEAR_VALUE depthOptimizedClearValue = {};
			depthOptimizedClearValue.Format = DXGI_FORMAT_D32_FLOAT;
			depthOptimizedClearValue.DepthStencil.Depth = 1.0f;
			depthOptimizedClearValue.DepthStencil.Stencil = 0;

			depthStencilBuffers.resize(swapChainBackBufferCount);

			for (uint i = 0; i < swapChainBackBufferCount; i++) {
				DX_API("Failed to create Depth Stencil buffer")
					device->CreateCommittedResource(
						&CD3DX12_HEAP_PROPERTIES(D3D12_HEAP_TYPE_DEFAULT),
						D3D12_HEAP_FLAG_SHARED,
						&CD3DX12_RESOURCE_DESC::Tex2D(DXGI_FORMAT_D32_FLOAT, scissorRect.right, scissorRect.bottom, 1, 0, 1, 0, D3D12_RESOURCE_FLAG_ALLOW_DEPTH_STENCIL),
						D3D12_RESOURCE_STATE_DEPTH_WRITE,
						&depthOptimizedClearValue,
						IID_PPV_ARGS(depthStencilBuffers[i].GetAddressOf()));
				depthStencilBuffers[i]->SetName(L"Depth Stencil Buffer");

				D3D12_DEPTH_STENCIL_VIEW_DESC depthStencilDesc = {};
				depthStencilDesc.Format = DXGI_FORMAT_D32_FLOAT;
				depthStencilDesc.ViewDimension = D3D12_DSV_DIMENSION_TEXTURE2D;
				depthStencilDesc.Flags = D3D12_DSV_FLAG_NONE;

				CD3DX12_CPU_DESCRIPTOR_HANDLE cpuHandle{ dsvHandle };
				cpuHandle.Offset(i * dsvDescriptorHandleIncrementSize);
				device->CreateDepthStencilView(depthStencilBuffers[i].Get(), &depthStencilDesc, cpuHandle);
			}

			//TODO: this was at the end of createresources, but I moved the command alloc & list creation here because they arechained now. is is ok here?
			WaitForPreviousFrame();
		}

		virtual void ReleaseSwapChainResources() override {
			for(auto& d: depthStencilBuffers) d.Reset();
			dsvHeap.Reset();
			Egg::App::ReleaseSwapChainResources();
		}

		virtual void Resize(int width, int height) override {
			WaitForPreviousFrame();
			App::Resize(width, height);
		}


		virtual void Destroy() override {
			WaitForPreviousFrame();
			App::Destroy();
		}
	GG_ENDCLASS

}
