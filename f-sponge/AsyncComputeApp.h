#pragma once
#include "Egg/Common.h"
#include <Egg/SimpleApp.h>
#include <d3d11on12.h>
#include <algorithm>

#include "RawBuffer.h"
#include "ComputePass.h"
#include "WaveSort.h"
#include "Game.h"
#include "FenceChain.h"

class AsyncComputeApp : public Egg::SimpleApp {
	Egg11::App::P app11;
protected:
	com_ptr<ID3D11On12Device> device11on12;
	com_ptr<ID3D11Device> device11;
	com_ptr<ID3D11Device2> device211;
	com_ptr<ID3D11DeviceContext> context11;
	std::vector<com_ptr<ID3D11Resource>> renderTargets11;
	std::vector<com_ptr<ID3D11RenderTargetView>> defaultRtvs11;
	std::vector < com_ptr<ID3D11Resource> > depthStencils11;
	std::vector < com_ptr<ID3D11DepthStencilView> > defaultDsvs11;

	com_ptr<ID3D12CommandQueue>  computeCommandQueue;
	std::vector < com_ptr<ID3D12CommandAllocator> > computeAllocators;
	std::vector < com_ptr<ID3D12GraphicsCommandList> > computeCommandLists;

	std::vector < com_ptr<ID3D12CommandAllocator> > copyAllocators;
	std::vector < com_ptr<ID3D12GraphicsCommandList> > copyCommandLists;

	com_ptr<ID3D12CommandAllocator> uploadAllocator;
	com_ptr<ID3D12GraphicsCommandList> uploadCommandList;

	Fence uploadFence;
	FenceChain computeFenceChain;
	FenceChain graphicsFenceChain;
	FenceChain copyFenceChain;

	com_ptr<ID3D12DescriptorHeap> uavHeap;
	std::vector<RawBuffer> buffers;

#define BUFFERNAMES 		mortons, pins, sortedPins, sortedMortons, sortedMortonPerPageStarterCounts, hashList, cellLut, sortedCellLut, sortedHashList, sortedHashPerPageStarterCounts, hashLut

	enum BufferRole {
		BUFFERNAMES
	};
	static std::wstring bufferToString(BufferRole r) {
		switch (r) {
		case mortons: return L"mortons";
		case pins: return L"pins";
		case sortedPins: return L"sortedPins";
		case sortedMortons: return L"sortedMortons";
		case sortedMortonPerPageStarterCounts: return L"sortedMortonPerPageStarterCounts";
		case hashList: return L"hashList";
		case cellLut: return L"cellLut";
		case sortedCellLut: return L"sortedCellLut";
		case sortedHashList: return L"sortedHashList";
		case sortedHashPerPageStarterCounts: return L"sortedHashPerPageStarterCounts";
		case hashLut: return L"hashLut";
		}
	}

	WaveSort mortonSort;
	WaveSort hashSort;
	ComputePass fillPins;
	ComputePass mortonCountStarters;
	ComputePass createCellList;
	ComputePass clearHashList;
	ComputePass hashCountStarters;
	ComputePass createHashList;
public:
	AsyncComputeApp() :SimpleApp(){}

	virtual void CreateResources() override {
		Egg::SimpleApp::CreateResources();

		UINT d3d11DeviceFlags = D3D11_CREATE_DEVICE_BGRA_SUPPORT;
		d3d11DeviceFlags |= D3D11_CREATE_DEVICE_DEBUG;

		auto featl = D3D_FEATURE_LEVEL_11_0;
		DX_API("create d3d11 device")
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
		device11->QueryInterface<ID3D11Device2>(device211.GetAddressOf());
		app11 = Game::Create(device211);

		uploadFence.createResources(device);

		D3D12_DESCRIPTOR_HEAP_DESC dhd;
		dhd.Flags = D3D12_DESCRIPTOR_HEAP_FLAG_SHADER_VISIBLE;
		dhd.NodeMask = 0;
		dhd.NumDescriptors = (uint)hashLut + 1; //TODO number of buffers
		dhd.Type = D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV;
		uint dhIncrSize = device->GetDescriptorHandleIncrementSize(D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV);

		DX_API("create descriptor heap for uavs")
			device->CreateDescriptorHeap(&dhd, IID_PPV_ARGS(uavHeap.GetAddressOf()));

		for (auto name : { BUFFERNAMES }) {
			bool sharedWithD3D11 = name == mortons || name == sortedPins || name == sortedCellLut || name == hashLut;
			std::wstring wname = bufferToString(name);
			buffers.push_back(RawBuffer(wname, sharedWithD3D11));
			CD3DX12_CPU_DESCRIPTOR_HANDLE handle(
				uavHeap->GetCPUDescriptorHandleForHeapStart(),
				name,
				device->GetDescriptorHandleIncrementSize(D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV));
			buffers[name].createResources(device, device11on12, handle);
			app11->setSharedResource(wname, buffers[name].getWrappedBuffer());
		}

		app11->createResources();

		buffers[mortons].fillRandomMask(0x7);

		auto dhStart = CD3DX12_GPU_DESCRIPTOR_HANDLE(uavHeap->GetGPUDescriptorHandleForHeapStart());
		ComputeShader csLocalSort;
		ComputeShader csMerge;
		csLocalSort.createResources(device, "Shaders/csLocalSort.cso");
		csMerge.createResources(device, "Shaders/csMerge.cso");

		mortonSort.creaseResources(csLocalSort, csMerge, dhStart, mortons, dhIncrSize, buffers);
		hashSort.creaseResources(csLocalSort, csMerge, dhStart, hashList, dhIncrSize, buffers);

		ComputeShader csStarterCount;
		csStarterCount.createResources(device, "Shaders/csStarterCount.cso");
		mortonCountStarters.createResources(csStarterCount, dhStart, 3, dhIncrSize, buffers, 2);
		hashCountStarters.createResources(csStarterCount, dhStart, sortedHashList, dhIncrSize, buffers, 2);

		ComputeShader csCreateCellList;
		csCreateCellList.createResources(device, "Shaders/csCreateCellList.cso");
		createCellList.createResources(csCreateCellList, dhStart, sortedMortons, dhIncrSize, buffers, 4);

		ComputeShader csClearHashList;
		csClearHashList.createResources(device, "Shaders/csClearBuffer.cso");
		clearHashList.createResources(csClearHashList, dhStart, hashList, dhIncrSize, buffers, 1);

		ComputeShader csFillPins;
		csFillPins.createResources(device, "Shaders/csFillBufferIndices.cso");
		fillPins.createResources(csFillPins, dhStart, pins, dhIncrSize, buffers, 1);

		ComputeShader csCreateHashList;
		csCreateHashList.createResources(device, "Shaders/csCreateHashList.cso");
		createHashList.createResources(csCreateHashList, dhStart, sortedHashList, dhIncrSize, buffers, 3);

		D3D12_COMMAND_QUEUE_DESC descCommandQueue = { D3D12_COMMAND_LIST_TYPE_COMPUTE, 0, D3D12_COMMAND_QUEUE_FLAG_NONE };
		DX_API("create compute command queue.")
			device->CreateCommandQueue(&descCommandQueue, IID_PPV_ARGS(computeCommandQueue.ReleaseAndGetAddressOf()));

		DX_API("create upload command allocator.")
			device->CreateCommandAllocator(D3D12_COMMAND_LIST_TYPE_DIRECT,
				IID_PPV_ARGS(uploadAllocator.ReleaseAndGetAddressOf()));

		DX_API("create upload command list.")
			device->CreateCommandList(
				0,
				D3D12_COMMAND_LIST_TYPE_DIRECT,
				uploadAllocator.Get(),
				nullptr,
				IID_PPV_ARGS(uploadCommandList.ReleaseAndGetAddressOf()));

		buffers[mortons].upload(uploadCommandList);

		DX_API("close command list.")
			uploadCommandList->Close();
		ID3D12CommandList* ppCommandLists[] = { uploadCommandList.Get() };
		commandQueue->ExecuteCommandLists(1, ppCommandLists);

		uploadFence.signal(commandQueue, 1);
		uploadFence.cpuWait();
	}

	virtual void CreateSwapChainResources() override {
		__super::CreateSwapChainResources();

		computeFenceChain.createResources(device, swapChainBackBufferCount);
		graphicsFenceChain.createResources(device, swapChainBackBufferCount);
		copyFenceChain.createResources(device, swapChainBackBufferCount);

		renderTargets11.resize(swapChainBackBufferCount);
		defaultRtvs11.resize(swapChainBackBufferCount);
		depthStencils11.resize(swapChainBackBufferCount);
		defaultDsvs11.resize(swapChainBackBufferCount);

		D3D11_RESOURCE_FLAGS d3d11Flags = { D3D11_BIND_RENDER_TARGET };
		D3D11_RESOURCE_FLAGS d3d11DepthFlags = { D3D11_BIND_DEPTH_STENCIL };
		for (uint i = 0; i < swapChainBackBufferCount; i++) {
			DX_API("wrap 12 back buffer for d3d11")
				device11on12->CreateWrappedResource(
					renderTargets[i].Get(),
					&d3d11Flags,
					D3D12_RESOURCE_STATE_RENDER_TARGET,
					D3D12_RESOURCE_STATE_PRESENT,
					IID_PPV_ARGS(renderTargets11[i].GetAddressOf())
				);

			com_ptr<ID3D11Texture2D> bbuftex;
			renderTargets11[i]->QueryInterface<ID3D11Texture2D>(bbuftex.GetAddressOf());
			D3D11_TEXTURE2D_DESC texdesc;
			bbuftex->GetDesc(&texdesc);
			D3D11_RENDER_TARGET_VIEW_DESC desc;
			desc.ViewDimension = D3D11_RTV_DIMENSION_TEXTURE2D;
			desc.Format = texdesc.Format;
			desc.Texture2D.MipSlice = 0;

			device11->CreateRenderTargetView(renderTargets11[i].Get(), &desc, defaultRtvs11[i].GetAddressOf());

			DX_API("wrap 12 depth buffer for d3d11")
				device11on12->CreateWrappedResource(
					depthStencilBuffers[i].Get(),
					&d3d11DepthFlags,
					D3D12_RESOURCE_STATE_DEPTH_WRITE,
					D3D12_RESOURCE_STATE_DEPTH_WRITE,
					IID_PPV_ARGS(depthStencils11[i].GetAddressOf())
				);

			CD3D11_DEPTH_STENCIL_VIEW_DESC depthStencilViewDesc(D3D11_DSV_DIMENSION_TEXTURE2D);
			device11->CreateDepthStencilView(
				depthStencils11[i].Get(),
				&depthStencilViewDesc,
				defaultDsvs11[i].GetAddressOf()
			);
		}

		computeCommandLists.resize(swapChainBackBufferCount);
		computeAllocators.resize(swapChainBackBufferCount);
		for (uint i = 0; i < swapChainBackBufferCount; i++) {
			// Create compute allocator, command queue and command list
			DX_API("create compute command allocator.")
				device->CreateCommandAllocator(D3D12_COMMAND_LIST_TYPE_COMPUTE,
					IID_PPV_ARGS(computeAllocators[i].ReleaseAndGetAddressOf()));

			DX_API("create compute command list.")
				device->CreateCommandList(
					0,
					D3D12_COMMAND_LIST_TYPE_COMPUTE,
					computeAllocators[i].Get(),
					nullptr,
					IID_PPV_ARGS(computeCommandLists[i].ReleaseAndGetAddressOf()));
			computeCommandLists[i]->Close();
		}

		copyCommandLists.resize(swapChainBackBufferCount);
		copyAllocators.resize(swapChainBackBufferCount);
		for (uint i = 0; i < swapChainBackBufferCount; i++) {
			// Create compute allocator, command queue and command list
			DX_API("create compute command allocator.")
				device->CreateCommandAllocator(D3D12_COMMAND_LIST_TYPE_DIRECT,
					IID_PPV_ARGS(copyAllocators[i].ReleaseAndGetAddressOf()));

			DX_API("create compute command list.")
				device->CreateCommandList(
					0,
					D3D12_COMMAND_LIST_TYPE_DIRECT,
					copyAllocators[i].Get(),
					nullptr,
					IID_PPV_ARGS(copyCommandLists[i].ReleaseAndGetAddressOf()));
			copyCommandLists[i]->Close();
		}
	}

	void recordComputeCommands() {
		ID3D12DescriptorHeap* pHeaps[] = { uavHeap.Get() };
		computeCommandLists[swapChainBackBufferIndex]->SetDescriptorHeaps(_countof(pHeaps), pHeaps);

		fillPins.populate(computeCommandLists[swapChainBackBufferIndex]);
		mortonSort.populate(computeCommandLists[swapChainBackBufferIndex]);
		mortonCountStarters.populate(computeCommandLists[swapChainBackBufferIndex]);
		clearHashList.populate(computeCommandLists[swapChainBackBufferIndex]);
		createCellList.populate(computeCommandLists[swapChainBackBufferIndex]);
		hashSort.populate(computeCommandLists[swapChainBackBufferIndex]);
		hashCountStarters.populate(computeCommandLists[swapChainBackBufferIndex]);
		createHashList.populate(computeCommandLists[swapChainBackBufferIndex]);
	}

	void recordCopyCommands() {}

	virtual void PopulateCommandList() override {

		copyFenceChain.gpuWait(computeCommandQueue, previousSwapChainBackBufferIndex);

		computeAllocators[swapChainBackBufferIndex]->Reset();
		auto& computeCommandList = computeCommandLists[swapChainBackBufferIndex];
		computeCommandList->Reset(computeAllocators[swapChainBackBufferIndex].Get(), nullptr);

		recordComputeCommands();

		DX_API("close command list")
			computeCommandLists[swapChainBackBufferIndex]->Close();
		{
			// execute compute
			ID3D12CommandList* ppCommandLists[] = { computeCommandLists[swapChainBackBufferIndex].Get() };
			computeCommandQueue->ExecuteCommandLists(1, ppCommandLists);
		}
		computeFenceChain.signal(computeCommandQueue, swapChainBackBufferIndex);

		copyAllocators[swapChainBackBufferIndex]->Reset();
		auto& copyCommandList = copyCommandLists[swapChainBackBufferIndex];
		copyCommandList->Reset(copyAllocators[swapChainBackBufferIndex].Get(), nullptr);

		recordCopyCommands();

		//wait for compute to finish
		computeFenceChain.gpuWait(commandQueue, swapChainBackBufferIndex);

		DX_API("close command list")
			copyCommandLists[swapChainBackBufferIndex]->Close();
		{
			// execute copy
			ID3D12CommandList* ppCommandLists[] = { copyCommandLists[swapChainBackBufferIndex].Get() };
			commandQueue->ExecuteCommandLists(1, ppCommandLists);
		}
		copyFenceChain.signal(commandQueue, swapChainBackBufferIndex);

		commandAllocators[swapChainBackBufferIndex]->Reset();
		auto& commandList = commandLists[swapChainBackBufferIndex];
		commandList->Reset(commandAllocators[swapChainBackBufferIndex].Get(), nullptr);

		commandList->RSSetViewports(1, &viewPort);
		commandList->RSSetScissorRects(1, &scissorRect);

		commandList->ResourceBarrier(1, &CD3DX12_RESOURCE_BARRIER::Transition(renderTargets[swapChainBackBufferIndex].Get(), D3D12_RESOURCE_STATE_PRESENT, D3D12_RESOURCE_STATE_RENDER_TARGET));

		CD3DX12_CPU_DESCRIPTOR_HANDLE rHandle(rtvDescriptorHeap->GetCPUDescriptorHandleForHeapStart(), swapChainBackBufferIndex, rtvDescriptorHandleIncrementSize);
		CD3DX12_CPU_DESCRIPTOR_HANDLE dsvHandle(dsvHeap->GetCPUDescriptorHandleForHeapStart());
		commandList->OMSetRenderTargets(1, &rHandle, FALSE, &dsvHandle);

		const float clearColor[] = { 0.0f, 0.2f, 0.4f, 1.0f };
		commandList->ClearRenderTargetView(rHandle, clearColor, 0, nullptr);
		commandList->ClearDepthStencilView(dsvHandle, D3D12_CLEAR_FLAG_DEPTH, 1.0f, 0, 0, nullptr);

		//READBACK HERE?
		for (auto name : { BUFFERNAMES }) {
			buffers[name].copyBack(commandLists[swapChainBackBufferIndex]);
		}

		//TEST HERE
		//for (auto name : { BUFFERNAMES }) {
		//	buffers[name].mapReadback();
		//}
		{
			uint* pMortons = buffers[mortons].mapReadback();
			bool ok = true;
			for (uint i = 0; i < 32; i++) {
				ok = ok && std::is_sorted(pMortons + i * 32 * 32, pMortons + i * 32 * 32 + 32 * 32);
			}
			buffers[mortons].unmapReadback();
		}
		//		buffers[pins].mapReadback();
		//		
		{
			uint* pSortedPins = buffers[sortedPins].mapReadback();
			uint* pSortedMortons = buffers[sortedMortons].mapReadback();
			bool ok = std::is_sorted(pSortedMortons, pSortedMortons + 32 * 32 * 32);

			uint* pMortonStarterCount = buffers[sortedMortonPerPageStarterCounts].mapReadback();
			//TODO verify startercount

			uint* pHlist = buffers[hashList].mapReadback();
			uint* pCellLut = buffers[cellLut].mapReadback();
			uint* pSortedCellLut = buffers[sortedCellLut].mapReadback();

			uint* pSortedHlist = buffers[sortedHashList].mapReadback();
			uint* pHlistStarters = buffers[sortedHashPerPageStarterCounts].mapReadback();
			uint* pHashLut = buffers[hashLut].mapReadback();

			buffers[sortedPins].unmapReadback();
			buffers[hashLut].unmapReadback();
			buffers[sortedHashPerPageStarterCounts].unmapReadback();
			buffers[sortedHashList].unmapReadback();
			buffers[cellLut].unmapReadback();
			buffers[sortedCellLut].unmapReadback();
			buffers[hashList].unmapReadback();
			buffers[sortedMortonPerPageStarterCounts].unmapReadback();
			buffers[sortedMortons].unmapReadback();
		}

		DX_API("close command list")
			commandList->Close();

		ID3D12CommandList* cLists[] = { commandList.Get() };
		commandQueue->ExecuteCommandLists(_countof(cLists), cLists);

		device11on12->AcquireWrappedResources(renderTargets11[swapChainBackBufferIndex].GetAddressOf(), 1);
		device11on12->AcquireWrappedResources(depthStencils11[swapChainBackBufferIndex].GetAddressOf(), 1);

		device11on12->AcquireWrappedResources(buffers[mortons].getWrappedBuffer().GetAddressOf(), 1);
		device11on12->AcquireWrappedResources(buffers[sortedPins].getWrappedBuffer().GetAddressOf(), 1);
		device11on12->AcquireWrappedResources(buffers[sortedCellLut].getWrappedBuffer().GetAddressOf(), 1);
		device11on12->AcquireWrappedResources(buffers[hashLut].getWrappedBuffer().GetAddressOf(), 1);

		//		float bg[] = { 1.0f, 0.0f, 0.0f, 0.0f };
		//		context11->ClearRenderTargetView(defaultRtv11[frameIndex].Get(), bg);
		app11->setDefaultViews(defaultRtvs11[swapChainBackBufferIndex], defaultDsvs11[swapChainBackBufferIndex]);
		app11->render(context11);
		app11->releaseDefaultViews();

		device11on12->ReleaseWrappedResources(buffers[hashLut].getWrappedBuffer().GetAddressOf(), 1);
		device11on12->ReleaseWrappedResources(buffers[sortedCellLut].getWrappedBuffer().GetAddressOf(), 1);
		device11on12->ReleaseWrappedResources(buffers[sortedPins].getWrappedBuffer().GetAddressOf(), 1);
		device11on12->ReleaseWrappedResources(buffers[mortons].getWrappedBuffer().GetAddressOf(), 1);

		device11on12->ReleaseWrappedResources(depthStencils11[swapChainBackBufferIndex].GetAddressOf(), 1);
		device11on12->ReleaseWrappedResources(renderTargets11[swapChainBackBufferIndex].GetAddressOf(), 1);

		context11->Flush();

		graphicsFenceChain.signal(commandQueue, swapChainBackBufferIndex);

		WaitForPreviousFrame();

	}

	virtual void Resize(int width, int height) override {
		SimpleApp::Resize(width, height);

		CD3D11_VIEWPORT screenViewport(0.0f, 0.0f, width, height);
		context11->RSSetViewports(1, &screenViewport);
	}

	virtual void Update(float dt, float T) override {
		app11->animate(dt, T);
	}

	virtual void ProcessMessage(HWND hWnd, UINT uMsg, WPARAM wParam, LPARAM lParam) override {
		if (uMsg != 18) {
			app11->processMessage(hWnd, uMsg, wParam, lParam);
		}
	}

	virtual void ReleaseSwapChainResources() {
		app11->releaseSwapChainResources();

		for (com_ptr<ID3D11Resource>& i : renderTargets11) {
			i.Reset();
		}
		renderTargets11.clear();

		for (com_ptr<ID3D11RenderTargetView>& i : defaultRtvs11) {
			i.Reset();
		}
		defaultRtvs11.clear();

		for (com_ptr<ID3D11Resource>& i : depthStencils11) {
			i.Reset();
		}
		depthStencils11.clear();

		for (com_ptr<ID3D11DepthStencilView>& i : defaultDsvs11) {
			i.Reset();
		}
		defaultDsvs11.clear();

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

};
