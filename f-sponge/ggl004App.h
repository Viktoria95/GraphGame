#pragma once
#include "Egg/Common.h"
#include <Egg/SimpleApp.h>
#include <Egg/Importer.h>
#include <Egg/Math/Math.h>
#include <Egg/ConstantBuffer.hpp>
#include <thread>
#include <d3d11on12.h>

#include "RawBuffer.h"
#include "ComputePass.h"
#include "Game.h"

using namespace Egg::Math;

class ggl004App : public Egg::SimpleApp {
	Egg11::App::P app11;
protected:
	com_ptr<ID3D11On12Device> device11on12;
	com_ptr<ID3D11Device> device11;
	com_ptr<ID3D11DeviceContext> context11;
	std::vector<com_ptr<ID3D11Resource>> renderTargets11;
	std::vector<com_ptr<ID3D11RenderTargetView>> defaultRtv11;
	com_ptr<ID3D11Resource> depthStencil11;
	com_ptr<ID3D11DepthStencilView> defaultDsv11;

	com_ptr<ID3D12DescriptorHeap> uavHeap;

	com_ptr<ID3D12CommandAllocator> m_computeAllocator;
	com_ptr<ID3D12CommandQueue>  m_computeCommandQueue;
	com_ptr<ID3D12GraphicsCommandList> m_computeCommandList;

	RawBuffer mortons;
	RawBuffer starters;
	RawBuffer hlist;
	RawBuffer particleIndex;
	RawBuffer cbegin;
	RawBuffer hbegin;

	ComputePass localSort;
	ComputePass merge;
	ComputePass countStarters;
	ComputePass createCellList;
	ComputePass createHashList;

	com_ptr<ID3D12Fence>         m_renderResourceFence;  // fence used by async compute to start once it's texture has changed to unordered access
	uint64_t                     m_renderResourceFenceValue;

	com_ptr<ID3D12Fence>						m_computeFence; // fence used by the async compute shader to stall waiting for task is complete, so it can signal render when it's done
	uint64_t                                    m_computeFenceValue;
	Microsoft::WRL::Wrappers::Event             m_computeFenceEvent;
	Microsoft::WRL::Wrappers::Event             m_computeResumeSignal;

	enum ResourceBufferState : uint32_t
	{
		ResourceState_ReadyCompute,
		ResourceState_Computing,    // async is currently running on this resource buffer
		ResourceState_Computed     // async buffer has been updated, no one is using it, moved to this state by async thread, only render will access in this state
	};

	std::atomic<ResourceBufferState> resourceState;

public:
	virtual void Update(float dt, float T) override {
		app11->animate(dt, T);
	}

	virtual void ProcessMessage(HWND hWnd, UINT uMsg, WPARAM wParam, LPARAM lParam) override {
		if (uMsg != 18) {
			app11->processMessage(hWnd, uMsg, wParam, lParam);
		}		
	}

	virtual void PopulateCommandList() override {
		
		commandAllocator->Reset();
		commandList->Reset(commandAllocator.Get(), nullptr);

		if (resourceState == ResourceState_Computed) {

			//			ResourceBarrier(commandList.Get(), m_sortedArray.Get(), D3D12_RESOURCE_STATE_UNORDERED_ACCESS, D3D12_RESOURCE_STATE_COPY_SOURCE);

			starters.copyBack(commandList);
			hlist.copyBack(commandList);
			particleIndex.copyBack(commandList);
			cbegin.copyBack(commandList);
			hbegin.copyBack(commandList);

//			commandList->CopyResource(m_arrayForReadback.Get(), m_sortedArray.Get());

			//			ResourceBarrier(commandList.Get(), m_sortedArray.Get(), D3D12_RESOURCE_STATE_COPY_SOURCE, D3D12_RESOURCE_STATE_UNORDERED_ACCESS);
			//			ResourceBarrier(commandList.Get(), m_arrayForReadback.Get(), D3D12_RESOURCE_STATE_COPY_DEST, D3D12_RESOURCE_STATE_COPY_SOURCE);

			resourceState = ResourceState_ReadyCompute;
		}

		commandList->RSSetViewports(1, &viewPort);
		commandList->RSSetScissorRects(1, &scissorRect);

		commandList->ResourceBarrier(1, &CD3DX12_RESOURCE_BARRIER::Transition(renderTargets[frameIndex].Get(), D3D12_RESOURCE_STATE_PRESENT, D3D12_RESOURCE_STATE_RENDER_TARGET));

		CD3DX12_CPU_DESCRIPTOR_HANDLE rHandle(rtvDescriptorHeap->GetCPUDescriptorHandleForHeapStart(), frameIndex, rtvDescriptorHandleIncrementSize);
		CD3DX12_CPU_DESCRIPTOR_HANDLE dsvHandle(dsvHeap->GetCPUDescriptorHandleForHeapStart());
		commandList->OMSetRenderTargets(1, &rHandle, FALSE, &dsvHandle);

		const float clearColor[] = { 0.0f, 0.2f, 0.4f, 1.0f };
		commandList->ClearRenderTargetView(rHandle, clearColor, 0, nullptr);
		commandList->ClearDepthStencilView(dsvHandle, D3D12_CLEAR_FLAG_DEPTH, 1.0f, 0, 0, nullptr);
		
		//		this will be done by d3d11 now
		//11	commandList->ResourceBarrier(1, &CD3DX12_RESOURCE_BARRIER::Transition(renderTargets[frameIndex].Get(), D3D12_RESOURCE_STATE_RENDER_TARGET, D3D12_RESOURCE_STATE_PRESENT));
		
		DX_API("Failed to close command list")
			commandList->Close();

		ID3D12CommandList* cLists[] = { commandList.Get() };
		commandQueue->ExecuteCommandLists(_countof(cLists), cLists);
		
		device11on12->AcquireWrappedResources(renderTargets11[frameIndex].GetAddressOf(), 1);
		device11on12->AcquireWrappedResources(depthStencil11.GetAddressOf(), 1);

		//		float bg[] = { 1.0f, 0.0f, 0.0f, 0.0f };
		//		context11->ClearRenderTargetView(defaultRtv11[frameIndex].Get(), bg);
		app11->setDefaultViews(defaultRtv11[frameIndex], defaultDsv11);
		app11->render(context11);
		app11->releaseDefaultViews();
		
		device11on12->ReleaseWrappedResources(depthStencil11.GetAddressOf(), 1);
		device11on12->ReleaseWrappedResources(renderTargets11[frameIndex].GetAddressOf(), 1);
		
		context11->Flush();

		WaitForPreviousFrame();

		//TEST HERE
//		starters.mapReadback();
//		hlist.mapReadback();
//		particleIndex.mapReadback();
//		cbegin.mapReadback();
//		hbegin.mapReadback();

	}

	void UploadResources() {
	}

	void ResourceBarrier(_In_ ID3D12GraphicsCommandList* pCmdList, _In_ ID3D12Resource* pResource, D3D12_RESOURCE_STATES Before, D3D12_RESOURCE_STATES After, D3D12_RESOURCE_BARRIER_FLAGS Flags = D3D12_RESOURCE_BARRIER_FLAG_NONE)
	{
		D3D12_RESOURCE_BARRIER barrierDesc = {};

		barrierDesc.Type = D3D12_RESOURCE_BARRIER_TYPE_TRANSITION;
		barrierDesc.Flags = Flags;
		barrierDesc.Transition.pResource = pResource;
		barrierDesc.Transition.Subresource = D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES;
		barrierDesc.Transition.StateBefore = Before;
		barrierDesc.Transition.StateAfter = After;

		pCmdList->ResourceBarrier(1, &barrierDesc);
	}

	virtual void CreateSwapChainResources() override {
		__super::CreateSwapChainResources();

		renderTargets11.resize(2);
		D3D11_RESOURCE_FLAGS d3d11Flags = { D3D11_BIND_RENDER_TARGET };
		DX_API("Failed to wrap 12 back buffer for d3d11")
			device11on12->CreateWrappedResource(
				renderTargets[0].Get(),
				&d3d11Flags,
				D3D12_RESOURCE_STATE_RENDER_TARGET,
				D3D12_RESOURCE_STATE_PRESENT,
				IID_PPV_ARGS(renderTargets11[0].GetAddressOf())
			);
		DX_API("Failed to wrap 12 back buffer for d3d11")
			device11on12->CreateWrappedResource(
				renderTargets[1].Get(),
				&d3d11Flags,
				D3D12_RESOURCE_STATE_RENDER_TARGET,
				D3D12_RESOURCE_STATE_PRESENT,
				IID_PPV_ARGS(renderTargets11[1].GetAddressOf())
			);
		
		D3D11_RESOURCE_FLAGS d3d11DepthFlags = { D3D11_BIND_DEPTH_STENCIL };
		DX_API("Failed to wrap 12 depth buffer for d3d11")
			device11on12->CreateWrappedResource(
				depthStencilBuffer.Get(),
				&d3d11DepthFlags,
				D3D12_RESOURCE_STATE_DEPTH_WRITE,
				D3D12_RESOURCE_STATE_DEPTH_WRITE,
				IID_PPV_ARGS(depthStencil11.GetAddressOf())
			);
		

		defaultRtv11.resize(2);

		com_ptr<ID3D11Texture2D> bbuftex;
		renderTargets11[0]->QueryInterface<ID3D11Texture2D>(bbuftex.GetAddressOf());
		D3D11_TEXTURE2D_DESC texdesc;
		bbuftex->GetDesc(&texdesc);
		D3D11_RENDER_TARGET_VIEW_DESC desc;
		desc.ViewDimension = D3D11_RTV_DIMENSION_TEXTURE2D;
		desc.Format = texdesc.Format;
		desc.Texture2D.MipSlice = 0;
		device11->CreateRenderTargetView(renderTargets11[0].Get(), &desc, defaultRtv11[0].GetAddressOf());
		device11->CreateRenderTargetView(renderTargets11[1].Get(), &desc, defaultRtv11[1].GetAddressOf());

		CD3D11_DEPTH_STENCIL_VIEW_DESC depthStencilViewDesc(D3D11_DSV_DIMENSION_TEXTURE2D);
		device11->CreateDepthStencilView(
			depthStencil11.Get(),
			&depthStencilViewDesc,
			defaultDsv11.GetAddressOf()
		);
	}

	virtual void CreateResources() override {
		Egg::SimpleApp::CreateResources();

		UINT d3d11DeviceFlags = D3D11_CREATE_DEVICE_BGRA_SUPPORT;
		d3d11DeviceFlags |= D3D11_CREATE_DEVICE_DEBUG;

		auto featl = D3D_FEATURE_LEVEL_11_0;
		DX_API("Failed to create d3d11 device")
			D3D11On12CreateDevice(
				device.Get(),
				d3d11DeviceFlags,
				nullptr,
				0,
				reinterpret_cast<IUnknown**>(commandQueue.GetAddressOf()),
				1,
				0,
				device11.GetAddressOf(),
				context11.GetAddressOf(),
				nullptr
			);

		device11->QueryInterface<ID3D11On12Device>(device11on12.GetAddressOf());

		app11 = Game::Create(device11);
		app11->createResources();

		resourceState = ResourceState_ReadyCompute;

		// create compute fence and event
		m_computeFenceEvent.Attach(CreateEventEx(nullptr, FALSE, FALSE, EVENT_ALL_ACCESS));
		if (!m_computeFenceEvent.IsValid())
		{
			throw std::exception("CreateEvent");
		}

		DX_API("compute fence")
			device->CreateFence(0, D3D12_FENCE_FLAG_NONE, IID_PPV_ARGS(m_computeFence.ReleaseAndGetAddressOf()));
		m_computeFence->SetName(L"Compute");
		m_computeFenceValue = 1;

		DX_API("render resource fence")
			device->CreateFence(0, D3D12_FENCE_FLAG_NONE, IID_PPV_ARGS(m_renderResourceFence.ReleaseAndGetAddressOf()));
		m_renderResourceFence->SetName(L"Resource");
		m_renderResourceFenceValue = 1;

		D3D12_DESCRIPTOR_HEAP_DESC dhd;
		dhd.Flags = D3D12_DESCRIPTOR_HEAP_FLAG_SHADER_VISIBLE;
		dhd.NodeMask = 0;
		dhd.NumDescriptors = 6;
		dhd.Type = D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV;
		uint dhIncrSize = device->GetDescriptorHandleIncrementSize(D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV);

		DX_API("Failed to create descriptor heap for uavs")
			device->CreateDescriptorHeap(&dhd, IID_PPV_ARGS(uavHeap.GetAddressOf()));

		mortons.createResources(device, device11on12);
		starters.createResources(device, device11on12);
		hlist.createResources(device, device11on12);
		particleIndex.createResources(device, device11on12);
		cbegin.createResources(device, device11on12);
		hbegin.createResources(device, device11on12);

		mortons.uploadRandom();

		auto dhStart = uavHeap->GetGPUDescriptorHandleForHeapStart();
		localSort.createResources(device, "Shaders/csLocalSort.cso", dhStart + dhIncrSize * 0);
		merge.createResources(device, "Shaders/csMerge.cso");
		countStarters.createResources(device, "Shaders/csStarterCount.cso");
		createCellList.createResources(device, "Shaders/csCreateCellList.cso");
		createHashList.createResources(device, "Shaders/csCreateHashList.cso");

		// Create compute allocator, command queue and command list
		D3D12_COMMAND_QUEUE_DESC descCommandQueue = { D3D12_COMMAND_LIST_TYPE_COMPUTE, 0, D3D12_COMMAND_QUEUE_FLAG_NONE };
		DX_API("Failed to create compute command queue.")
			device->CreateCommandQueue(&descCommandQueue, IID_PPV_ARGS(m_computeCommandQueue.ReleaseAndGetAddressOf()));

		DX_API("Failed to create compute command allocator.")
			device->CreateCommandAllocator(D3D12_COMMAND_LIST_TYPE_COMPUTE, IID_PPV_ARGS(m_computeAllocator.ReleaseAndGetAddressOf()));

		DX_API("Failed to create compute command list.")
			device->CreateCommandList(
				0,
				D3D12_COMMAND_LIST_TYPE_COMPUTE,
				m_computeAllocator.Get(),
				nullptr,
				IID_PPV_ARGS(m_computeCommandList.ReleaseAndGetAddressOf()));
	}

	virtual void ReleaseSwapChainResources() {
		app11->releaseSwapChainResources();

		for (com_ptr<ID3D11Resource>& i : renderTargets11) {
			i.Reset();
		}
		renderTargets11.clear();

		for (com_ptr<ID3D11RenderTargetView>& i : defaultRtv11) {
			i.Reset();
		}
		defaultRtv11.clear();

		depthStencil11.Reset();
		defaultDsv11.Reset();

		context11->Flush();

		__super::ReleaseSwapChainResources();
	}

	virtual void ReleaseResources() override {
		app11->releaseResources();
		app11.reset();
		device11.Reset();
		context11.Reset();

		uavHeap.Reset();

		Egg::SimpleApp::ReleaseResources();
	}

	virtual void Resize(int width, int height) override {
		SimpleApp::Resize(width, height);

		CD3D11_VIEWPORT screenViewport(0.0f, 0.0f, width, height);
		context11->RSSetViewports(1, &screenViewport);
	}

	virtual void LoadAssets() override {

		DX_API("Failed to reset command allocator (UploadResources)")
			commandAllocator->Reset();
		DX_API("Failed to reset command list (UploadResources)")
			commandList->Reset(commandAllocator.Get(), nullptr);

		ResourceBarrier(commandList.Get(), m_arrayToBeSorted.Get(), D3D12_RESOURCE_STATE_UNORDERED_ACCESS, D3D12_RESOURCE_STATE_COPY_DEST);
		ResourceBarrier(commandList.Get(), m_sortedArray.Get(), D3D12_RESOURCE_STATE_UNORDERED_ACCESS, D3D12_RESOURCE_STATE_COPY_DEST);

		commandList->CopyResource(m_arrayToBeSorted.Get(), m_arrayForUpload.Get());

		ResourceBarrier(commandList.Get(), m_arrayToBeSorted.Get(), D3D12_RESOURCE_STATE_COPY_DEST, D3D12_RESOURCE_STATE_UNORDERED_ACCESS);
		ResourceBarrier(commandList.Get(), m_sortedArray.Get(), D3D12_RESOURCE_STATE_COPY_DEST, D3D12_RESOURCE_STATE_UNORDERED_ACCESS);

		DX_API("Failed to close command list (UploadResources)")
			commandList->Close();

		m_computeResumeSignal.Attach(CreateEventEx(nullptr, nullptr, 0, EVENT_MODIFY_STATE | SYNCHRONIZE));
		if (!m_computeResumeSignal.IsValid())
			throw std::exception("CreateEvent");

		m_usingAsyncCompute = true;

		m_computeThread = new std::thread(&ggl004App::AsyncComputeThreadProc, this);

		ID3D12CommandList* commandLists[] = { commandList.Get() };
		commandQueue->ExecuteCommandLists(_countof(commandLists), commandLists);

		WaitForPreviousFrame();

		//release uploadresources
	}

	std::atomic<bool>                           m_terminateThread;
	std::atomic<bool>                           m_suspendThread;
	std::thread* m_computeThread;
	std::atomic<bool>                           m_usingAsyncCompute;

	void AsyncComputeThreadProc()
	{
		while (!m_terminateThread)
		{
			if (m_suspendThread)
			{
				(void)WaitForSingleObject(m_computeResumeSignal.Get(), INFINITE);
			}

			if (m_usingAsyncCompute)
			{
					if (m_suspendThread)
					{
						(void)WaitForSingleObject(m_computeResumeSignal.Get(), INFINITE);
					}

					// input is mortons [dont wanna deal with Particles here really]
					// sort mortons [output: sortedIndex]
					// csStarterCount perpage count
						// count starters per page (Morton code differs from previous particle, OR force one if no starters in row )
								// ^[latter should be an extreme case (32+ particles in a cell), forcing will cause two compacter clist entries with identical hash])
						// count left-leading non-starters per page
					//csCreateCellList clist prefix sum-compact-scatter
						// load starters per page, prefix sum it (every group does this)
						// prefix sum on clist (each page separately), add perpage preceding sum
						// if starter
							// compact: scatter write to cbegin (prefixsum position -> original location)
							// write clength
								//count left-leading non-starter ballot bits to shared mem
								//count right-trailing non-starter ballot bits, add neighbor's leading, or next page #leading
							//  - also output: hlist (hashes of compacted clist entries)
					// sort hlist, sort cstart+clength along
					// perpage leading nonstarter count for hlist
					// get hstart ( hashcode -> where it begins in hlist ), hlegth, embed
						
					// UAVS
					// u0: mortons in
					// u1: indices in
					// u2: sorted indices
					// u3: sorted mortons
					// u4: #starters per page | #leading non-starters per page
					// u5: hlist
					// u6: cbegin | clength
					// u7: sorted cbegin
					// u8: sorted hlist
					// u9: h: #starters per page | #leading non-starters pp
					// ua: embedflag: hstart | hlength OR cbegin | clength

					ID3D12DescriptorHeap* pHeaps[] = { uavHeap.Get() };
					m_computeCommandList->SetDescriptorHeaps(_countof(pHeaps), pHeaps);

					resourceState = ResourceState_Computing;

					m_computeCommandList->SetComputeRootSignature(m_computeRootSignature.Get());

					m_computeCommandList->SetComputeRootDescriptorTable(1, uavHeap->GetGPUDescriptorHandleForHeapStart());
					
					D3D12_RESOURCE_BARRIER uavBarrier;
					uavBarrier.Type = D3D12_RESOURCE_BARRIER_TYPE_UAV;
					uavBarrier.Flags = D3D12_RESOURCE_BARRIER_FLAG_NONE;
					uavBarrier.UAV.pResource = m_arrayToBeSorted.Get();

					D3D12_RESOURCE_BARRIER uav1Barrier;
					uav1Barrier.Type = D3D12_RESOURCE_BARRIER_TYPE_UAV;
					uav1Barrier.Flags = D3D12_RESOURCE_BARRIER_FLAG_NONE;
					uav1Barrier.UAV.pResource = m_sortedArray.Get();

					m_computeCommandList->SetPipelineState(m_computePSO.Get());
					m_computeCommandList->SetComputeRoot32BitConstant(0, 0, 0);
					m_computeCommandList->Dispatch(32, 1, 1);
					m_computeCommandList->ResourceBarrier(1, &uavBarrier);
					m_computeCommandList->SetComputeRoot32BitConstant(0, 4, 0);
					m_computeCommandList->Dispatch(32, 1, 1);
					m_computeCommandList->ResourceBarrier(1, &uavBarrier);
					m_computeCommandList->SetComputeRoot32BitConstant(0, 8, 0);
					m_computeCommandList->Dispatch(32, 1, 1);
					m_computeCommandList->ResourceBarrier(1, &uavBarrier);
					m_computeCommandList->SetComputeRoot32BitConstant(0, 12, 0);
					m_computeCommandList->Dispatch(32, 1, 1);
					m_computeCommandList->ResourceBarrier(1, &uavBarrier);
					m_computeCommandList->SetComputeRoot32BitConstant(0, 16, 0);
					m_computeCommandList->Dispatch(32, 1, 1);
					m_computeCommandList->ResourceBarrier(1, &uavBarrier);
					m_computeCommandList->SetComputeRoot32BitConstant(0, 20, 0);
					m_computeCommandList->Dispatch(32, 1, 1);
					m_computeCommandList->ResourceBarrier(1, &uavBarrier);
					m_computeCommandList->SetComputeRoot32BitConstant(0, 24, 0);
					m_computeCommandList->Dispatch(32, 1, 1);
					m_computeCommandList->ResourceBarrier(1, &uavBarrier);
					m_computeCommandList->SetComputeRoot32BitConstant(0, 28, 0);
					m_computeCommandList->Dispatch(32, 1, 1);
					m_computeCommandList->ResourceBarrier(1, &uavBarrier);

					m_computeCommandList->SetComputeRootSignature(m_mergeRootSignature.Get());
					m_computeCommandList->SetComputeRootDescriptorTable(1, uavHeap->GetGPUDescriptorHandleForHeapStart());

					m_computeCommandList->SetPipelineState(m_mergePSO.Get());
					m_computeCommandList->Dispatch(1, 1, 1);
					m_computeCommandList->ResourceBarrier(1, &uav1Barrier);

					// close and execute the command list
					m_computeCommandList->Close();
					ID3D12CommandList* tempList = m_computeCommandList.Get();
					m_computeCommandQueue->ExecuteCommandLists(1, &tempList);

					const uint64_t fence = m_computeFenceValue++;
					m_computeCommandQueue->Signal(m_computeFence.Get(), fence);
					if (m_computeFence->GetCompletedValue() < fence)								// block until async compute has completed using a fence
					{
						m_computeFence->SetEventOnCompletion(fence, m_computeFenceEvent.Get());
						WaitForSingleObject(m_computeFenceEvent.Get(), INFINITE);
					}
					m_resourceState[0/*ComputeIndex()*/] = ResourceState_Computed;						// signal the buffer is now ready for render thread to use

					m_computeAllocator->Reset();
					m_computeCommandList->Reset(m_computeAllocator.Get(), m_computePSO.Get());

					break;
				}
				//else
				//{
				//	SwitchToThread();
				//}
			}
			else
			{
				SwitchToThread();
			}
		}
	}
};


